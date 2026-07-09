/**
 * MatchPro — Baileys WhatsApp Connector
 * ======================================
 * Multi-device WA connector using @whiskeysockets/baileys v7
 * • QR-based first-time auth, persistent session in data/baileys_auth/
 * • Emits events: 'qr', 'connected', 'disconnected', 'message'
 * • Real phone extraction: sender_phone from @c.us JID
 * • Real message body from WA messages (no Green API)
 * • Auto-reconnect with exponential backoff
 */

import { makeWASocket, useMultiFileAuthState, DisconnectReason,
         fetchLatestBaileysVersion, makeCacheableSignalKeyStore,
         isJidBroadcast, isJidGroup, jidNormalizedUser } from '@whiskeysockets/baileys'
import { Boom } from '@hapi/boom'
import { EventEmitter } from 'events'
import { existsSync, mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'
import pino from 'pino'

const __dirname = dirname(fileURLToPath(import.meta.url))
const AUTH_DIR   = join(__dirname, 'data', 'baileys_auth')
const RECONNECT_DELAY_MS = 5000
const MAX_RECONNECTS     = 10

// Ensure auth dir exists
if (!existsSync(AUTH_DIR)) mkdirSync(AUTH_DIR, { recursive: true })

// ── Public state ────────────────────────────────────────────────────────────
export const baileysEvents = new EventEmitter()
baileysEvents.setMaxListeners(50)

let _sock         = null
let _state        = 'idle'       // idle | connecting | qr_ready | open | closed
let _qrCode       = null
let _qrBase64     = null
let _phone        = null
let _reconnectCount = 0
let _autoReconnect  = true
let _startCalled    = false

export function getBaileysState() {
  return {
    connected:    _state === 'open',
    state:        _state,
    phone:        _phone,
    qrAvailable:  _state === 'qr_ready',
    qrCode:       _qrCode,
    qrBase64:     _qrBase64,
    type:         'baileys',
    reconnects:   _reconnectCount,
    authDir:      AUTH_DIR,
    note:         _state === 'open'
      ? `Connected as ${_phone}`
      : _state === 'qr_ready'
        ? 'Scan QR code at /api/baileys/qr to link WhatsApp'
        : _state === 'connecting'
          ? 'Connecting to WhatsApp...'
          : 'Not connected — call POST /api/baileys/start',
  }
}

// ── Extract real Egyptian phone from WA JID ─────────────────────────────────
function jidToPhone(jid = '') {
  if (!jid || jid.includes('@g.us') || jid.includes('@lid')) return ''
  const raw = jid.replace(/@c\.us$/, '').replace(/[^0-9]/g, '')
  // 201XXXXXXXXX → 01XXXXXXXXX
  if (/^201[0125][0-9]{8}$/.test(raw)) return '0' + raw.slice(2)
  // Already 01XXXXXXXXX
  if (/^01[0125][0-9]{8}$/.test(raw)) return raw
  return ''
}

// ── Parse incoming message into MatchPro-compatible object ─────────────────
function parseMessage(msg) {
  try {
    const key      = msg.key || {}
    const jid      = key.remoteJid || ''
    const fromMe   = key.fromMe || false
    if (fromMe) return null                         // skip self-sent
    if (isJidBroadcast(jid)) return null            // skip broadcast

    const msgContent = msg.message || {}
    // Extract text from different message types
    const body = (
      msgContent.conversation ||
      msgContent.extendedTextMessage?.text ||
      msgContent.imageMessage?.caption ||
      msgContent.videoMessage?.caption ||
      msgContent.documentMessage?.caption ||
      msgContent.buttonsResponseMessage?.selectedButtonId ||
      msgContent.listResponseMessage?.singleSelectReply?.selectedRowId ||
      ''
    ).trim()

    if (!body) return null

    const isGroup   = isJidGroup(jid)
    const groupId   = isGroup ? jid : null
    const senderJid = isGroup
      ? (msg.key.participant || msg.participant || '')
      : jid

    const phone       = jidToPhone(senderJid)
    const senderName  = msg.pushName || ''
    const timestamp   = msg.messageTimestamp
      ? new Date(Number(msg.messageTimestamp) * 1000).toISOString()
      : new Date().toISOString()

    return {
      id:           key.id || `baileys_${Date.now()}`,
      body,
      raw_message:  body,
      sender:       senderJid,
      sender_phone: phone,
      sender_name:  senderName,
      group_id:     groupId,
      group_name:   null,   // populated via group metadata if needed
      is_group:     isGroup,
      from_me:      fromMe,
      created_at:   timestamp,
      msg_type:     'incoming',
      classified:   0,
    }
  } catch { return null }
}

// ── Core Baileys connection ──────────────────────────────────────────────────
async function connect() {
  try {
    _state = 'connecting'
    baileysEvents.emit('state_change', getBaileysState())

    const { state: authState, saveCreds } = await useMultiFileAuthState(AUTH_DIR)
    const { version, isLatest } = await fetchLatestBaileysVersion()
    console.log(`[Baileys] Using WA v${version.join('.')} (latest: ${isLatest})`)

    const sock = makeWASocket({
      version,
      auth: {
        creds: authState.creds,
        keys:  makeCacheableSignalKeyStore(authState.keys, pino({ level: 'silent' })),
      },
      printQRInTerminal: true,           // also show in logs for convenience
      browser:           ['MatchPro CPI', 'Chrome', '120.0.0'],
      logger:            pino({ level: 'silent' }),
      generateHighQualityLinkPreview: false,
      syncFullHistory:   false,          // faster startup
      markOnlineOnConnect: false,
    })
    _sock = sock

    // ── Credentials update ─────────────────────────────────────────────────
    sock.ev.on('creds.update', saveCreds)

    // ── Connection updates ─────────────────────────────────────────────────
    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update

      if (qr) {
        _state    = 'qr_ready'
        _qrCode   = qr
        // Generate base64 PNG for /api/baileys/qr endpoint
        try {
          const QRCode = (await import('qrcode')).default
          _qrBase64 = await QRCode.toDataURL(qr, { width: 300, margin: 2 })
        } catch { _qrBase64 = null }

        console.log('[Baileys] 📱 QR ready — scan at /api/baileys/qr')
        baileysEvents.emit('qr', qr)
        baileysEvents.emit('state_change', getBaileysState())
      }

      if (connection === 'open') {
        _state          = 'open'
        _qrCode         = null
        _qrBase64       = null
        _reconnectCount = 0
        const meJid     = sock.user?.id || ''
        _phone          = jidToPhone(meJid) || sock.user?.name || meJid

        console.log(`[Baileys] ✅ Connected as ${_phone}`)
        baileysEvents.emit('connected', _phone)
        baileysEvents.emit('state_change', getBaileysState())
      }

      if (connection === 'close') {
        const code   = (lastDisconnect?.error)
          ? new Boom(lastDisconnect.error)?.output?.statusCode
          : undefined
        const reason = DisconnectReason

        _state = 'closed'
        baileysEvents.emit('disconnected', code)
        baileysEvents.emit('state_change', getBaileysState())

        const shouldReconnect = code !== reason.loggedOut && _autoReconnect
        console.log(`[Baileys] ❌ Closed. Code=${code} reconnect=${shouldReconnect}`)

        if (code === reason.loggedOut) {
          console.log('[Baileys] 🔓 Logged out — session cleared, restart to re-scan QR')
          // Clear auth so fresh QR is generated on next start
          try {
            const { rmSync } = await import('fs')
            rmSync(AUTH_DIR, { recursive: true, force: true })
            mkdirSync(AUTH_DIR, { recursive: true })
          } catch { /* ignore */ }
        }

        if (shouldReconnect && _reconnectCount < MAX_RECONNECTS) {
          _reconnectCount++
          const delay = RECONNECT_DELAY_MS * Math.min(_reconnectCount, 5)
          console.log(`[Baileys] ♻️  Reconnecting in ${delay}ms (attempt ${_reconnectCount}/${MAX_RECONNECTS})`)
          setTimeout(connect, delay)
        }
      }
    })

    // ── Incoming messages ──────────────────────────────────────────────────
    sock.ev.on('messages.upsert', async ({ messages, type }) => {
      if (type !== 'notify') return   // only process new push messages

      for (const msg of messages) {
        const parsed = parseMessage(msg)
        if (!parsed) continue

        console.log(`[Baileys] 📨 ${parsed.is_group ? 'Group' : 'DM'} from ${parsed.sender_phone || parsed.sender}: "${parsed.body.slice(0,60)}"`)
        baileysEvents.emit('message', parsed)
      }
    })

    // ── Message status updates ────────────────────────────────────────────
    sock.ev.on('messages.update', (updates) => {
      // Could be used for delivery receipts if needed
    })

  } catch (err) {
    _state = 'closed'
    console.error('[Baileys] ❌ Connect error:', err.message)
    baileysEvents.emit('error', err)
    if (_autoReconnect && _reconnectCount < MAX_RECONNECTS) {
      _reconnectCount++
      setTimeout(connect, RECONNECT_DELAY_MS * 2)
    }
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

/** Start Baileys connector (idempotent) */
export async function startBaileys() {
  if (_startCalled && _state !== 'closed') {
    console.log(`[Baileys] Already running (state=${_state})`)
    return getBaileysState()
  }
  _startCalled  = true
  _autoReconnect = true
  _reconnectCount = 0
  await connect()
  return getBaileysState()
}

/** Disconnect and stop reconnecting */
export async function stopBaileys() {
  _autoReconnect = false
  _startCalled   = false
  if (_sock) {
    try { await _sock.logout() } catch { /* ignore */ }
    _sock = null
  }
  _state = 'idle'
  console.log('[Baileys] 🛑 Stopped')
  return { ok: true }
}

/** Clear session files and restart (forces new QR scan) */
export async function resetBaileys() {
  await stopBaileys()
  try {
    const { rmSync } = await import('fs')
    rmSync(AUTH_DIR, { recursive: true, force: true })
    mkdirSync(AUTH_DIR, { recursive: true })
  } catch { /* ignore */ }
  console.log('[Baileys] 🔄 Session cleared — restarting')
  return startBaileys()
}

/** Send a text message to a JID or phone number */
export async function sendMessage(to, text) {
  if (!_sock || _state !== 'open') throw new Error('Baileys not connected')
  // Normalize phone to JID
  const jid = to.includes('@') ? to : `${to.replace(/^0/, '20')}@c.us`
  const result = await _sock.sendMessage(jid, { text })
  return result
}

/** Get list of groups the WA account is in */
export async function getGroups() {
  if (!_sock || _state !== 'open') return []
  try {
    const chats = await _sock.groupFetchAllParticipating()
    return Object.values(chats).map(g => ({
      id:           g.id,
      name:         g.subject || '',
      participants: g.participants?.length || 0,
      creation:     g.creation,
    }))
  } catch { return [] }
}
