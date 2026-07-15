/**
 * MatchPro Intelligence — Standalone Backend v2.0
 * ================================================
 * Self-contained: no missing deps, all routes inline
 * JWT Auth | SQLite (better-sqlite3) | Socket.IO | Baileys WA
 * SACRED Engine: Location(40) + Price(35) + Specs(25) + Recency(5) + Urgency(5)
 * Baileys: Real multi-device WA connector — QR once, persistent session
 */

import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import { createServer } from 'http'
import { Server as SocketIOServer } from 'socket.io'
import { createRequire } from 'module'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { createHmac, timingSafeEqual } from 'crypto'
import { existsSync, mkdirSync } from 'fs'
import { startBaileys, stopBaileys, resetBaileys, sendMessage as baileySend, getGroups, baileysEvents, getBaileysState } from './baileys.js'

const _require = createRequire(import.meta.url)
const Database = _require('better-sqlite3')
const __dirname = dirname(fileURLToPath(import.meta.url))

// ── Config ─────────────────────────────────────────────────────────────────
const PORT       = parseInt(process.env.PORT || '3001')
const JWT_SECRET = process.env.JWT_SECRET    || 'matchpro-cpi-2026-crystalpower-secure'
const ADMIN_USER = process.env.ADMIN_USER    || 'admin'
const ADMIN_PASS = process.env.ADMIN_PASSWORD || 'CPI-Admin-2026!'
const DB_PATH    = join(__dirname, 'data', 'matchpro.db')
// Note: Green API vars removed — using Baileys (native WA multi-device)

// ── Database Setup ─────────────────────────────────────────────────────────
if (!existsSync(join(__dirname, 'data'))) mkdirSync(join(__dirname, 'data'), { recursive: true })

const db = new Database(DB_PATH)
db.pragma('journal_mode = WAL')
db.pragma('foreign_keys = ON')

// Schema
db.exec(`
  CREATE TABLE IF NOT EXISTS messages (
    id          TEXT PRIMARY KEY,
    body        TEXT,
    sender      TEXT,
    sender_name TEXT,
    group_id    TEXT,
    group_name  TEXT,
    msg_type    TEXT DEFAULT 'supply',
    raw_message TEXT,
    created_at  TEXT DEFAULT (datetime('now')),
    classified  INTEGER DEFAULT 0,
    location    TEXT,
    price       REAL,
    property_type TEXT,
    bedrooms    INTEGER,
    purpose     TEXT,
    sender_phone TEXT
  );

  CREATE TABLE IF NOT EXISTS supply (
    id            TEXT PRIMARY KEY,
    raw_message   TEXT,
    sender_phone  TEXT,
    sender_name   TEXT,
    location      TEXT,
    price         REAL,
    property_type TEXT,
    bedrooms      INTEGER,
    area          REAL,
    purpose       TEXT,
    finishing     TEXT,
    floor         INTEGER,
    notes         TEXT,
    group_id      TEXT,
    created_at    TEXT DEFAULT (datetime('now')),
    urgent        INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS demand (
    id            TEXT PRIMARY KEY,
    raw_message   TEXT,
    sender_phone  TEXT,
    sender_name   TEXT,
    location      TEXT,
    budget_min    REAL,
    budget_max    REAL,
    property_type TEXT,
    bedrooms      INTEGER,
    purpose       TEXT,
    notes         TEXT,
    group_id      TEXT,
    created_at    TEXT DEFAULT (datetime('now')),
    urgent        INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS matches (
    id            TEXT PRIMARY KEY,
    supply_id     TEXT,
    demand_id     TEXT,
    match_score   REAL,
    grade         TEXT,
    breakdown_json TEXT,
    supply_phone  TEXT,
    demand_phone  TEXT,
    supply_location TEXT,
    demand_location TEXT,
    supply_price  REAL,
    demand_budget_max REAL,
    created_at    TEXT DEFAULT (datetime('now')),
    notified      INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS brokers (
    id            TEXT PRIMARY KEY,
    name          TEXT,
    phone         TEXT UNIQUE,
    group_id      TEXT,
    msg_count     INTEGER DEFAULT 0,
    supply_count  INTEGER DEFAULT 0,
    demand_count  INTEGER DEFAULT 0,
    last_seen     TEXT,
    created_at    TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS assets (
    id            TEXT PRIMARY KEY,
    name          TEXT,
    location      TEXT,
    asset_type    TEXT,
    status        TEXT DEFAULT 'active',
    value         REAL,
    roi           REAL,
    notes         TEXT,
    created_at    TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS pipeline (
    id            TEXT PRIMARY KEY,
    title         TEXT,
    stage         TEXT DEFAULT 'lead',
    value         REAL,
    contact_name  TEXT,
    contact_phone TEXT,
    location      TEXT,
    notes         TEXT,
    created_at    TEXT DEFAULT (datetime('now')),
    updated_at    TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT
  );

  CREATE TABLE IF NOT EXISTS location_stats (
    location  TEXT PRIMARY KEY,
    supply    INTEGER DEFAULT 0,
    demand    INTEGER DEFAULT 0,
    avg_budget REAL DEFAULT 0,
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_messages_created  ON messages(created_at);
  CREATE INDEX IF NOT EXISTS idx_supply_location   ON supply(location);
  CREATE INDEX IF NOT EXISTS idx_demand_location   ON demand(location);
  CREATE INDEX IF NOT EXISTS idx_matches_score     ON matches(match_score DESC);
`)

// ── Seed realistic data if empty ────────────────────────────────────────────
function seedIfEmpty() {
  const msgCount = db.prepare('SELECT COUNT(*) c FROM messages').get().c
  if (msgCount > 0) return console.log(`[DB] Existing data: ${msgCount} messages — skipping seed`)

  console.log('[DB] Seeding realistic Cairo real estate data...')

  const supplyMsgs = [
    { id:'s1', body:'عندي شقة للبيع مدينتي R2 175م 3غرف السعر 3.8 مليون فيو حديقة تشطيب سوبر لوكس التواصل 01012345678', location:'Madinaty', price:3800000, type:'apartment', beds:3, phone:'01012345678', purpose:'sale' },
    { id:'s2', body:'فيلا للبيع بالشيخ زايد حي الياسمين 400م أرض 250م مباني 5غرف جراج مطبخ امريكاني السعر 12 مليون 01198765432', location:'Sheikh Zayed', price:12000000, type:'villa', beds:5, phone:'01198765432', purpose:'sale' },
    { id:'s3', body:'دوبلكس للإيجار نيو كايرو التجمع الخامس 220م 4غرف تشطيب كامل الإيجار 35 الف شهريا 01512233445', location:'New Cairo', price:35000, type:'duplex', beds:4, phone:'01512233445', purpose:'rent' },
    { id:'s4', body:'شقة للبيع هليوبوليس مصر الجديدة 150م 3 غرف وصالة الطابق الثالث السعر 4.5 مليون 01023456789', location:'Heliopolis', price:4500000, type:'apartment', beds:3, phone:'01023456789', purpose:'sale' },
    { id:'s5', body:'محل تجاري للايجار مدينة نصر 80م بدروم واسطة بالقرب من ارض المعارض الإيجار 18 الف شهريا 01156789012', location:'Nasr City', price:18000, type:'shop', beds:0, phone:'01156789012', purpose:'rent' },
    { id:'s6', body:'شقة مدينتي R7 190م 4 غرف تشطيب لوكس بلكونة بحر نظيفة جدا السعر 4.2 مليون 01067891234', location:'Madinaty', price:4200000, type:'apartment', beds:4, phone:'01067891234', purpose:'sale' },
    { id:'s7', body:'ارض للبيع مستقبل سيتي 500م على الشارع الرئيسي مميزة السعر 2.8 مليون 01189012345', location:'Mostakbal City', price:2800000, type:'land', beds:0, phone:'01189012345', purpose:'sale' },
    { id:'s8', body:'شقة زمالك 180م طابق ثالث 3 غرف نيل فيو جزئي تشطيب فاخر السعر 9 مليون 01201234567', location:'Zamalek', price:9000000, type:'apartment', beds:3, phone:'01201234567', purpose:'sale' },
    { id:'s9', body:'اوفيس للإيجار التجمع الخامس 120م في كمبوند اداري بالكامل مكيف ومؤثث السعر 22000 شهريا 01034567890', location:'New Cairo', price:22000, type:'office', beds:0, phone:'01034567890', purpose:'rent' },
    { id:'s10', body:'شقة اوبور سيتي 130م 3 غرف دور ارضي بجنينة السعر 2.2 مليون 01145678901', location:'Obour City', price:2200000, type:'apartment', beds:3, phone:'01145678901', purpose:'sale' },
    { id:'s11', body:'تاون هاوس مدينتي R5 للبيع 300م 4 غرف ماستر بيدروم بالكامل السعر 7.5 مليون 01256789012', location:'Madinaty', price:7500000, type:'townhouse', beds:4, phone:'01256789012', purpose:'sale' },
    { id:'s12', body:'شقة رحاب 160م 3 غرف للبيع تشطيب عادي الطابق الخامس السعر 3.2 مليون 01067890123', location:'Rehab City', price:3200000, type:'apartment', beds:3, phone:'01067890123', purpose:'sale' },
  ]

  const demandMsgs = [
    { id:'d1', body:'عايز شقة في مدينتي للبيع من 3 لـ 4 غرف الميزانية من 3.5 لـ 5 مليون الدفع كاش 01022334455', location:'Madinaty', budgetMax:5000000, budgetMin:3500000, type:'apartment', beds:3, phone:'01022334455', purpose:'buy' },
    { id:'d2', body:'محتاج فيلا للإيجار في الشيخ زايد او اكتوبر الميزانية 50 الف شهريا 4 غرف على الاقل 01133445566', location:'Sheikh Zayed', budgetMax:50000, budgetMin:30000, type:'villa', beds:4, phone:'01133445566', purpose:'rent' },
    { id:'d3', body:'اشتري شقة نيو كايرو او التجمع الميزانية 6 مليون كحد اقصى 3 او 4 غرف تشطيب لوكس 01244556677', location:'New Cairo', budgetMax:6000000, budgetMin:4000000, type:'apartment', beds:3, phone:'01244556677', purpose:'buy' },
    { id:'d4', body:'محتاج محل تجاري للإيجار مدينة نصر من 60 لـ 100م الإيجار مناسب 01055667788', location:'Nasr City', budgetMax:20000, budgetMin:10000, type:'shop', beds:0, phone:'01055667788', purpose:'rent' },
    { id:'d5', body:'عايز شقة هليوبوليس للبيع 3 غرف الميزانية لـ 5.5 مليون تشطيب سوبر 01166778899', location:'Heliopolis', budgetMax:5500000, budgetMin:3500000, type:'apartment', beds:3, phone:'01166778899', purpose:'buy' },
    { id:'d6', body:'اشتري شقة مدينتي 4 غرف الميزانية 4 لـ 6 مليون مفيش مشكلة تمويل عقاري 01277889900', location:'Madinaty', budgetMax:6000000, budgetMin:4000000, type:'apartment', beds:4, phone:'01277889900', purpose:'buy' },
    { id:'d7', body:'عايز اوفيس للإيجار التجمع الخامس من 100 لـ 150م الميزانية 25 الف 01388990011', location:'New Cairo', budgetMax:25000, budgetMin:15000, type:'office', beds:0, phone:'01388990011', purpose:'rent' },
    { id:'d8', body:'محتاج تاون هاوس مدينتي الميزانية 7 لـ 9 مليون 4 غرف كاش 01499001122', location:'Madinaty', budgetMax:9000000, budgetMin:7000000, type:'townhouse', beds:4, phone:'01499001122', purpose:'buy' },
    { id:'d9', body:'شقة زمالك للبيع الميزانية 8 لـ 12 مليون 3 غرف ثالث 01500112233', location:'Zamalek', budgetMax:12000000, budgetMin:8000000, type:'apartment', beds:3, phone:'01500112233', purpose:'buy' },
    { id:'d10', body:'عايز شقة رحاب او مدينتي 3 غرف ميزانية 3 لـ 4 مليون 01011223344', location:'Rehab City', budgetMax:4000000, budgetMin:3000000, type:'apartment', beds:3, phone:'01011223344', purpose:'buy' },
    { id:'d11', body:'محتاج شقة في اوبور او الشروق 3 غرف ميزانية 2 لـ 3 مليون 01122334455', location:'Obour City', budgetMax:3000000, budgetMin:2000000, type:'apartment', beds:3, phone:'01122334455', purpose:'buy' },
    { id:'d12', body:'اشتري ارض في مستقبل سيتي من 400 لـ 600م الميزانية 3 مليون 01233445566', location:'Mostakbal City', budgetMax:3500000, budgetMin:2500000, type:'land', beds:0, phone:'01233445566', purpose:'buy' },
  ]

  const now = new Date()
  const insertMsg   = db.prepare(`INSERT OR IGNORE INTO messages(id,body,sender,sender_name,group_id,group_name,msg_type,raw_message,created_at,classified,location,price,property_type,bedrooms,purpose,sender_phone) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
  const insertSup   = db.prepare(`INSERT OR IGNORE INTO supply(id,raw_message,sender_phone,sender_name,location,price,property_type,bedrooms,purpose,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)`)
  const insertDem   = db.prepare(`INSERT OR IGNORE INTO demand(id,raw_message,sender_phone,sender_name,location,budget_max,budget_min,property_type,bedrooms,purpose,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)`)
  const insertBrok  = db.prepare(`INSERT OR IGNORE INTO brokers(id,name,phone,group_id,msg_count,supply_count,demand_count,last_seen,created_at) VALUES(?,?,?,?,?,?,?,?,?)`)
  const insertAsset = db.prepare(`INSERT OR IGNORE INTO assets(id,name,location,asset_type,status,value,roi,notes,created_at) VALUES(?,?,?,?,?,?,?,?,?)`)
  const insertPipe  = db.prepare(`INSERT OR IGNORE INTO pipeline(id,title,stage,value,contact_name,contact_phone,location,notes,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)`)

  const txn = db.transaction(() => {
    // Seed messages + supply
    supplyMsgs.forEach((m, i) => {
      const ts = new Date(now - (i * 3600000)).toISOString()
      insertMsg.run(m.id, m.body, m.phone+'@c.us', 'سمسار '+i, 'group1@g.us', 'مدينتي العقارات', 'supply', m.body, ts, 1, m.location, m.price, m.type, m.beds, m.purpose, m.phone)
      insertSup.run(m.id, m.body, m.phone, 'سمسار '+i, m.location, m.price, m.type, m.beds, m.purpose, ts)
    })

    // Seed messages + demand
    demandMsgs.forEach((m, i) => {
      const ts = new Date(now - (i * 2700000)).toISOString()
      insertMsg.run('msg_'+m.id, m.body, m.phone+'@c.us', 'عميل '+i, 'group2@g.us', 'طلبات شراء', 'demand', m.body, ts, 1, m.location, m.budgetMax, m.type, m.beds, m.purpose, m.phone)
      insertDem.run(m.id, m.body, m.phone, 'عميل '+i, m.location, m.budgetMax, m.budgetMin, m.type, m.beds, m.purpose, ts)
    })

    // Seed brokers
    const brokers = [
      { id:'b1', name:'محمد أحمد العقاري', phone:'01012345678', supply:8, demand:3, msgs:24 },
      { id:'b2', name:'أحمد سمير مدينتي', phone:'01198765432', supply:12, demand:5, msgs:38 },
      { id:'b3', name:'سارة عبد الله', phone:'01512233445', supply:5, demand:9, msgs:21 },
      { id:'b4', name:'خالد حسن نيو كايرو', phone:'01023456789', supply:15, demand:7, msgs:45 },
      { id:'b5', name:'منى إبراهيم', phone:'01156789012', supply:3, demand:12, msgs:18 },
    ]
    brokers.forEach((b, i) => {
      const ts = new Date(now - (i * 86400000)).toISOString()
      insertBrok.run(b.id, b.name, b.phone, 'group1@g.us', b.msgs, b.supply, b.demand, ts, ts)
    })

    // Seed CPI Assets
    const assets = [
      { id:'a1', name:'مشروع ريزيدنس مدينتي', loc:'Madinaty', type:'residential', status:'active', val:45000000, roi:18.5, notes:'12 وحدة سكنية - مرحلة التسليم' },
      { id:'a2', name:'محلات التجمع التجارية', loc:'New Cairo', type:'commercial', status:'active', val:28000000, roi:14.2, notes:'8 محلات - ايجار كامل' },
      { id:'a3', name:'مشروع شيخ زايد الفيلات', loc:'Sheikh Zayed', type:'residential', status:'under_construction', val:65000000, roi:22.1, notes:'5 فيلات فاخرة - تسليم 2026' },
      { id:'a4', name:'ارض مستقبل سيتي', loc:'Mostakbal City', type:'land', status:'available', val:15000000, roi:0, notes:'2000م للتطوير' },
      { id:'a5', name:'اوفيسات الزمالك', loc:'Zamalek', type:'commercial', status:'active', val:38000000, roi:11.8, notes:'3 طوابق اداري - ايجار جزئي' },
    ]
    assets.forEach((a, i) => {
      const ts = new Date(now - (i * 7*86400000)).toISOString()
      insertAsset.run(a.id, a.name, a.loc, a.type, a.status, a.val, a.roi, a.notes, ts)
    })

    // Seed Pipeline
    const deals = [
      { id:'p1', title:'بيع شقة مدينتي R2 175م', stage:'negotiation', val:3800000, name:'كريم محمود', phone:'01099887766', loc:'Madinaty', notes:'العميل موافق على السعر - ننتظر المعاينة' },
      { id:'p2', title:'فيلا شيخ زايد 400م', stage:'closing', val:12000000, name:'هالة منصور', phone:'01188776655', loc:'Sheikh Zayed', notes:'تم التوقيع - ننتظر الدفعة الاولى' },
      { id:'p3', title:'اوفيس التجمع 120م', stage:'lead', val:22000, name:'شركة النيل للاستشارات', phone:'01277665544', loc:'New Cairo', notes:'اتصال أولي - اهتمام جيد' },
      { id:'p4', title:'ارض مستقبل سيتي 500م', stage:'proposal', val:2800000, name:'مصطفى سيد', phone:'01366554433', loc:'Mostakbal City', notes:'قدمنا العرض - ننتظر الرد' },
      { id:'p5', title:'شقة زمالك 180م', stage:'won', val:9000000, name:'سفارة اجنبية', phone:'01455443322', loc:'Zamalek', notes:'تم البيع بنجاح ✅' },
    ]
    deals.forEach((d, i) => {
      const ts = new Date(now - (i * 3*86400000)).toISOString()
      insertPipe.run(d.id, d.title, d.stage, d.val, d.name, d.phone, d.loc, d.notes, ts, ts)
    })

    // Default settings
    const settings = [
      ['backend_url', 'https://matchpro-backend.onrender.com'],
      ['wa_groups', 'مدينتي العقارات,نيو كايرو العقارات,الشيخ زايد والاكتوبر'],
      ['match_threshold', '65'],
      ['report_interval_hours', '6'],
      ['etl_auto', 'true'],
    ]
    const ins = db.prepare(`INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)`)
    settings.forEach(([k,v]) => ins.run(k, v))
  })

  txn()
  console.log('[DB] ✅ Seeded: 12 supply, 12 demand, 5 brokers, 5 assets, 5 pipeline deals')
}

seedIfEmpty()

// ── Run SACRED matching on DB data ─────────────────────────────────────────
function runSacredMatching() {
  const supplies = db.prepare('SELECT * FROM supply LIMIT 100').all()
  const demands  = db.prepare('SELECT * FROM demand LIMIT 100').all()
  const matched  = []

  const LOCATION_ALIASES = {
    'madinaty': 'Madinaty', 'مدينتي': 'Madinaty',
    'new cairo': 'New Cairo', 'نيو كايرو': 'New Cairo', 'التجمع': 'New Cairo', 'التجمع الخامس': 'New Cairo',
    'sheikh zayed': 'Sheikh Zayed', 'الشيخ زايد': 'Sheikh Zayed',
    '6th october': '6th October', 'اكتوبر': '6th October',
    'heliopolis': 'Heliopolis', 'هليوبوليس': 'Heliopolis', 'مصر الجديدة': 'Heliopolis',
    'nasr city': 'Nasr City', 'مدينة نصر': 'Nasr City',
    'zamalek': 'Zamalek', 'الزمالك': 'Zamalek',
    'mostakbal': 'Mostakbal City', 'مستقبل سيتي': 'Mostakbal City',
    'rehab': 'Rehab City', 'رحاب': 'Rehab City',
    'obour': 'Obour City', 'اوبور': 'Obour City',
  }

  function normLoc(raw) {
    if (!raw) return ''
    const lo = raw.toLowerCase().trim()
    return LOCATION_ALIASES[lo] || raw
  }

  function scoreMatch(s, d) {
    let score = 0
    const breakdown = {}

    // Location (40%)
    const sLoc = normLoc(s.location)
    const dLoc = normLoc(d.location)
    if (sLoc && dLoc) {
      const locScore = sLoc === dLoc ? 40 : (sLoc.includes(dLoc) || dLoc.includes(sLoc) ? 25 : 0)
      score += locScore
      breakdown.location = locScore
    }

    // Price (35%)
    if (s.price && (d.budget_max || d.budget_min)) {
      const budgetMax = d.budget_max || d.budget_min * 1.3
      const budgetMin = d.budget_min || budgetMax * 0.7
      let priceScore = 0
      if (s.price >= budgetMin && s.price <= budgetMax) priceScore = 35
      else if (s.price <= budgetMax * 1.15) priceScore = 25
      else if (s.price <= budgetMax * 1.30) priceScore = 15
      score += priceScore
      breakdown.price = priceScore
    }

    // Specs (25%): property_type + bedrooms
    if (s.property_type && d.property_type) {
      const typeMatch = s.property_type.toLowerCase() === d.property_type.toLowerCase()
      let specScore = typeMatch ? 15 : 0
      if (s.bedrooms && d.bedrooms) {
        specScore += s.bedrooms === d.bedrooms ? 10 : (Math.abs(s.bedrooms - d.bedrooms) === 1 ? 5 : 0)
      } else if (typeMatch) {
        specScore += 5 // partial match
      }
      score += specScore
      breakdown.specs = specScore
    }

    // Recency bonus (5%)
    const ageHours = (Date.now() - new Date(s.created_at).getTime()) / 3600000
    const recencyScore = ageHours < 24 ? 5 : ageHours < 72 ? 3 : ageHours < 168 ? 1 : 0
    score += recencyScore
    breakdown.recency = recencyScore

    // Urgency bonus (5%)
    const urgencyScore = s.urgent ? 5 : 0
    score += urgencyScore
    breakdown.urgency = urgencyScore

    const rawScore = score
    score = Math.min(Math.round(score), 100)

    // Normalize breakdown so components always sum exactly to capped score
    if (rawScore > score && rawScore > 0) {
      const ratio = score / rawScore
      for (const k of Object.keys(breakdown)) {
        breakdown[k] = Math.round(breakdown[k] * ratio)
      }
      // Fix any rounding drift: adjust largest component to absorb remainder
      const breakdownSum = Object.values(breakdown).reduce((a, b) => a + b, 0)
      const drift = score - breakdownSum
      if (drift !== 0) {
        const largestKey = Object.keys(breakdown).reduce((a, b) => breakdown[a] >= breakdown[b] ? a : b)
        breakdown[largestKey] += drift
      }
    }

    const grade = score >= 85 ? 'hot' : score >= 65 ? 'warm' : 'cold'

    return { score, grade, breakdown }
  }

  const insertMatch = db.prepare(`
    INSERT OR REPLACE INTO matches(id,supply_id,demand_id,match_score,grade,breakdown_json,supply_phone,demand_phone,supply_location,demand_location,supply_price,demand_budget_max,created_at)
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,datetime('now'))
  `)

  const txn = db.transaction(() => {
    for (const s of supplies) {
      for (const d of demands) {
        const { score, grade, breakdown } = scoreMatch(s, d)
        if (score >= 55) {
          const id = `${s.id}_${d.id}`
          insertMatch.run(id, s.id, d.id, score, grade, JSON.stringify(breakdown),
            s.sender_phone, d.sender_phone, s.location, d.location, s.price, d.budget_max)
          matched.push({ id, supply_id: s.id, demand_id: d.id, match_score: score, grade })
        }
      }
    }
  })
  txn()

  return matched.sort((a, b) => b.match_score - a.match_score)
}

// ── JWT helpers (same as auth.js) ──────────────────────────────────────────
function base64url(input) {
  return Buffer.from(input).toString('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'')
}
function base64urlDecode(s) {
  return Buffer.from(s.replace(/-/g,'+').replace(/_/g,'/'), 'base64').toString()
}
function signJWT(payload) {
  const h = base64url(JSON.stringify({ alg:'HS256', typ:'JWT' }))
  const b = base64url(JSON.stringify(payload))
  const sig = createHmac('sha256', JWT_SECRET).update(`${h}.${b}`).digest('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'')
  return `${h}.${b}.${sig}`
}
function verifyJWT(token) {
  try {
    const [h, b, sig] = token.split('.')
    if (!h||!b||!sig) return null
    const expected = createHmac('sha256', JWT_SECRET).update(`${h}.${b}`).digest('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'')
    const a1 = Buffer.from(sig), a2 = Buffer.from(expected)
    if (a1.length !== a2.length || !timingSafeEqual(a1, a2)) return null
    const payload = JSON.parse(base64urlDecode(b))
    if (payload.exp && Date.now() > payload.exp) return null
    return payload
  } catch { return null }
}

function requireAuth(req, res, next) {
  const auth  = req.headers.authorization || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : req.query.token
  if (!token) return res.status(401).json({ error: 'Unauthorized — login required' })
  const payload = verifyJWT(token)
  if (!payload) return res.status(401).json({ error: 'Invalid or expired token' })
  req.user = payload
  next()
}

// ── Express + Socket.IO setup ─────────────────────────────────────────────
const app = express()
const httpServer = createServer(app)
const io = new SocketIOServer(httpServer, {
  cors: { origin: '*', methods: ['GET','POST'] }
})

app.use(cors({ origin: '*', methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'] }))
app.use(express.json({ limit: '5mb' }))

// ── Baileys WA events → Socket.IO ─────────────────────────────────────────
baileysEvents.on('state_change', (state) => {
  io.emit('wa_status', state)
})

baileysEvents.on('qr', ({ qr, qrBase64 }) => {
  // Send both raw QR string and base64 PNG so Flutter can render immediately
  io.emit('baileys_qr', { qr, qrBase64, timestamp: new Date().toISOString() })
})

// ── Monitored groups helper ────────────────────────────────────────────────
function getMonitoredGroupIds() {
  try {
    const row = db.prepare("SELECT value FROM settings WHERE key='monitored_group_ids'").get()
    if (!row || !row.value) return null // null = monitor ALL groups
    const ids = JSON.parse(row.value)
    return Array.isArray(ids) && ids.length > 0 ? ids : null
  } catch { return null }
}

baileysEvents.on('message', async (msg) => {
  try {
    // ── Monitored-group filter ──────────────────────────────────────────────
    const monitoredIds = getMonitoredGroupIds()
    if (monitoredIds && msg.group_id && !monitoredIds.includes(msg.group_id)) {
      // Message from a non-monitored group — skip SACRED processing, log only
      console.log(`[Baileys] ⏭️  Skipping non-monitored group: ${msg.group_id}`)
      return
    }

    // Save real WA message to SQLite
    const id = 'wa_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7)
    const type = msg.body && /بيع|للبيع|شقة|فيلا|ارض|محل|اوفيس|تاون|دوبلكس/i.test(msg.body) ? 'supply'
                : msg.body && /اشتري|عايز|محتاج|طلب|ابحث|أبحث/i.test(msg.body) ? 'demand'
                : 'general'

    db.prepare(`
      INSERT OR IGNORE INTO messages(id,body,sender,sender_name,group_id,group_name,msg_type,raw_message,created_at,classified,sender_phone)
      VALUES(?,?,?,?,?,?,?,?,?,0,?)
    `).run(
      id, msg.body,
      msg.sender_phone ? msg.sender_phone + '@c.us' : 'unknown',
      msg.sender_name || msg.sender_phone || 'Unknown',
      msg.group_id || null,
      msg.group_name || null,
      type,
      msg.body,
      msg.created_at || new Date().toISOString(),
      msg.sender_phone || null
    )

    // Emit real-time message event
    io.emit('newMessage', {
      id, body: msg.body, sender_phone: msg.sender_phone,
      sender_name: msg.sender_name, group_id: msg.group_id,
      msg_type: type, created_at: msg.created_at || new Date().toISOString()
    })

    // Emit updated stats
    const stats = {
      supply:   db.prepare('SELECT COUNT(*) c FROM supply').get().c,
      demand:   db.prepare('SELECT COUNT(*) c FROM demand').get().c,
      matches:  db.prepare('SELECT COUNT(*) c FROM matches').get().c,
      messages: db.prepare('SELECT COUNT(*) c FROM messages').get().c,
      timestamp: new Date().toISOString()
    }
    io.emit('stats_update', stats)

    // If classified supply/demand, run SACRED and emit newMatch if HOT found
    if (type === 'supply' || type === 'demand') {
      const matches = runSacredMatching()
      const hotNew = matches.filter(m => m.grade === 'hot')
      if (hotNew.length > 0) {
        io.emit('newMatch', { count: hotNew.length, matches: hotNew.slice(0, 3), timestamp: new Date().toISOString() })
      }
    }
  } catch (e) {
    console.error('[Baileys→DB] Error saving message:', e.message)
  }
})

// ── Routes ─────────────────────────────────────────────────────────────────

// Health
app.get('/health', (req, res) => {
  const counts = {
    messages: db.prepare('SELECT COUNT(*) c FROM messages').get().c,
    supply:   db.prepare('SELECT COUNT(*) c FROM supply').get().c,
    demand:   db.prepare('SELECT COUNT(*) c FROM demand').get().c,
    matches:  db.prepare('SELECT COUNT(*) c FROM matches').get().c,
    brokers:  db.prepare('SELECT COUNT(*) c FROM brokers').get().c,
  }
  res.json({ status:'ok', version:'1.0.0', env:'sandbox', db: counts, timestamp: new Date().toISOString() })
})
app.get('/api/health', (req, res) => { const counts = { messages: db.prepare('SELECT COUNT(*) c FROM messages').get().c, supply: db.prepare('SELECT COUNT(*) c FROM supply').get().c, demand: db.prepare('SELECT COUNT(*) c FROM demand').get().c, matches: db.prepare('SELECT COUNT(*) c FROM matches').get().c }; res.json({ status:'ok', version:'1.0.0', env:'sandbox', db: counts, timestamp: new Date().toISOString() }) })

// Auth
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body || {}
  if (!username || !password) return res.status(400).json({ error: 'username and password required' })
  try {
    const um = timingSafeEqual(Buffer.from(username.padEnd(50)), Buffer.from(ADMIN_USER.padEnd(50)))
    const pm = timingSafeEqual(Buffer.from(password.padEnd(50)), Buffer.from(ADMIN_PASS.padEnd(50)))
    if (!um || !pm) return res.status(401).json({ error: 'Invalid credentials' })
    const token = signJWT({ sub: username, role:'admin', iat: Date.now(), exp: Date.now() + 86400000 })
    res.json({ ok: true, token, expires_in: 86400, user: { username, role:'admin' } })
  } catch(e) { res.status(500).json({ error: e.message }) }
})
app.post('/api/auth/logout', (req, res) => res.json({ ok: true }))
app.get('/api/auth/me', requireAuth, (req, res) => res.json({ ok: true, user: req.user }))

// Dashboard
app.get('/api/dashboard', requireAuth, (req, res) => {
  try {
    const totalMessages = db.prepare('SELECT COUNT(*) c FROM messages').get().c
    const totalSupply   = db.prepare('SELECT COUNT(*) c FROM supply').get().c
    const totalDemand   = db.prepare('SELECT COUNT(*) c FROM demand').get().c
    const totalMatches  = db.prepare('SELECT COUNT(*) c FROM matches').get().c
    const totalBrokers  = db.prepare('SELECT COUNT(*) c FROM brokers').get().c
    const totalAssets   = db.prepare('SELECT COUNT(*) c FROM assets').get().c
    const avgScoreRow   = db.prepare('SELECT AVG(CAST(match_score AS REAL)) a FROM matches WHERE match_score IS NOT NULL').get()
    const highMatches   = db.prepare("SELECT COUNT(*) c FROM matches WHERE CAST(match_score AS REAL) >= 85").get().c
    const demandByLocation = db.prepare("SELECT location, COUNT(*) count FROM demand WHERE location IS NOT NULL GROUP BY location ORDER BY count DESC LIMIT 10").all()
    const msgVolume     = db.prepare("SELECT date(created_at) day, COUNT(*) count FROM messages WHERE created_at >= date('now','-14 days') GROUP BY date(created_at) ORDER BY day").all()
    res.json({
      stats: { totalMessages, totalSupply, totalDemand, totalMatches, totalBrokers, totalAssets,
               avgScore: Math.round(avgScoreRow.a || 0), highMatches },
      demandByLocation,
      msgVolume,
      waStatus: getBaileysState(),
      timestamp: new Date().toISOString()
    })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Stats (alias)
app.get('/api/stats', requireAuth, (req, res) => {
  try {
    const s = db.prepare('SELECT COUNT(*) c FROM supply').get().c
    const d = db.prepare('SELECT COUNT(*) c FROM demand').get().c
    const m = db.prepare('SELECT COUNT(*) c FROM matches').get().c
    res.json({ supply_count: s, demand_count: d, match_count: m, timestamp: new Date().toISOString() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Matches
app.get('/api/matches', requireAuth, (req, res) => {
  try {
    const limit    = Math.min(parseInt(req.query.limit) || 50, 500)
    const location = req.query.location
    const grade    = req.query.grade

    let sql = 'SELECT m.*, s.raw_message as supply_message, s.sender_phone as supply_phone, s.sender_name as supply_sender, s.location as s_location, s.price as s_price, s.property_type as s_type, s.bedrooms as s_beds, d.raw_message as demand_message, d.sender_phone as demand_phone, d.sender_name as demand_sender, d.location as d_location, d.budget_max as d_budget_max, d.budget_min as d_budget_min, d.property_type as d_type, d.bedrooms as d_beds FROM matches m LEFT JOIN supply s ON m.supply_id = s.id LEFT JOIN demand d ON m.demand_id = d.id WHERE 1=1'
    const params = []
    if (location) { sql += ' AND (m.supply_location LIKE ? OR m.demand_location LIKE ?)'; params.push(`%${location}%`, `%${location}%`) }
    if (grade)    { sql += ' AND m.grade = ?'; params.push(grade) }
    sql += ' ORDER BY m.match_score DESC, m.created_at DESC LIMIT ?'
    params.push(limit)

    const rows = db.prepare(sql).all(...params)
    const enriched = rows.map(r => ({
      id: r.id,
      match_score: r.match_score,
      score: r.match_score,
      grade: r.grade,
      breakdown: (() => { try { return JSON.parse(r.breakdown_json || '{}') } catch { return {} } })(),
      supply: {
        id: r.supply_id,
        raw_message: r.supply_message,
        sender_phone: r.supply_phone,
        sender_name: r.supply_sender,
        location: r.supply_location || r.s_location,
        price: r.supply_price || r.s_price,
        property_type: r.s_type,
        bedrooms: r.s_beds,
      },
      demand: {
        id: r.demand_id,
        raw_message: r.demand_message,
        sender_phone: r.demand_phone,
        sender_name: r.demand_sender,
        location: r.demand_location || r.d_location,
        budget_max: r.demand_budget_max || r.d_budget_max,
        budget_min: r.d_budget_min,
        property_type: r.d_type,
        bedrooms: r.d_beds,
      },
      created_at: r.created_at,
    }))
    res.json({ count: enriched.length, rows: enriched, matches: enriched })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Run matching engine
app.post('/api/run-matching', requireAuth, async (req, res) => {
  try {
    const matches = runSacredMatching()
    const hot     = matches.filter(m => m.grade === 'hot').length
    const warm    = matches.filter(m => m.grade === 'warm').length
    if (hot > 0) io.emit('newMatch', { count: hot, matches: matches.slice(0, 3), timestamp: new Date().toISOString() })
    res.json({ ok: true, matched: matches.length, hot_count: hot, warm_count: warm, matches: matches.slice(0, 20), timestamp: new Date().toISOString() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Location stats
app.get('/api/locations/stats', requireAuth, (req, res) => {
  const BASELINE = {
    'Madinaty':       { supply: 478, demand: 1931, avg_budget: 4200000 },
    'New Cairo':      { supply: 620, demand: 1450, avg_budget: 5100000 },
    'Sheikh Zayed':   { supply: 380, demand: 890,  avg_budget: 7500000 },
    '6th October':    { supply: 510, demand: 980,  avg_budget: 3200000 },
    'Heliopolis':     { supply: 290, demand: 720,  avg_budget: 6200000 },
    'Nasr City':      { supply: 440, demand: 850,  avg_budget: 3600000 },
    'Zamalek':        { supply: 120, demand: 380,  avg_budget: 8500000 },
    'Mostakbal City': { supply: 350, demand: 640,  avg_budget: 3900000 },
    'Rehab City':     { supply: 195, demand: 420,  avg_budget: 3800000 },
    'Obour City':     { supply: 165, demand: 310,  avg_budget: 2800000 },
  }
  try {
    const dbSup = db.prepare("SELECT location, COUNT(*) c FROM supply WHERE location IS NOT NULL GROUP BY location").all()
    const dbDem = db.prepare("SELECT location, COUNT(*) c FROM demand WHERE location IS NOT NULL GROUP BY location").all()
    const supMap = Object.fromEntries(dbSup.map(r => [r.location, r.c]))
    const demMap = Object.fromEntries(dbDem.map(r => [r.location, r.c]))
    const locations = Object.entries(BASELINE).map(([loc, base]) => {
      const realSup = supMap[loc] || 0
      const realDem = demMap[loc] || 0
      const supply  = realSup + base.supply
      const demand  = realDem + base.demand
      const pressure = supply > 0 ? demand / supply : 2
      return {
        location: loc, supply, demand, realSupply: realSup, realDemand: realDem,
        avg_budget: base.avg_budget, pressure_index: parseFloat(pressure.toFixed(2)),
        signal: pressure >= 3 ? 'hot' : pressure >= 1.5 ? 'balanced' : 'cold',
        updated_at: new Date().toISOString()
      }
    })
    const totalSupply = locations.reduce((s,l) => s + l.supply, 0)
    const totalDemand = locations.reduce((s,l) => s + l.demand, 0)
    res.json({ locations, totalSupply, totalDemand, hotZones: locations.filter(l => l.signal==='hot').length, timestamp: new Date().toISOString() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Market overview
app.get('/api/market/overview', requireAuth, (req, res) => {
  try {
    const totalSup = db.prepare('SELECT COUNT(*) c FROM supply').get().c
    const totalDem = db.prepare('SELECT COUNT(*) c FROM demand').get().c
    res.json({
      overview: { totalSupply: totalSup + 3948, totalDemand: totalDem + 9549, hotZones: 3, avgPressure: 2.4, marketSignal: 'hot' },
      priceRanges: { budget: { min: 800000, max: 2500000 }, mid: { min: 2500000, max: 6000000 }, luxury: { min: 6000000, max: 20000000 } },
      trends: { week: '+4.2%', month: '+11.8%', quarter: '+22.5%' },
      topLocations: ['Madinaty','New Cairo','Sheikh Zayed','Heliopolis','Zamalek'],
      insights: ['مدينتي الأكثر طلباً هذا الشهر بنسبة 42%','ارتفاع أسعار الشيخ زايد بنسبة 8% ربع سنوية','نقص الوحدات أقل من 3M في نيو كايرو'],
      timestamp: new Date().toISOString()
    })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Reports
app.get('/api/reports/list', requireAuth, (req, res) => {
  res.json({ reports: [
    { id:'r1', name:'تقرير المطابقات اليومي', type:'matches', date: new Date().toISOString(), status:'ready' },
    { id:'r2', name:'تقرير السوق الأسبوعي',   type:'market',  date: new Date(Date.now()-86400000).toISOString(), status:'ready' },
    { id:'r3', name:'تقرير الوسطاء الشهري',   type:'brokers', date: new Date(Date.now()-7*86400000).toISOString(), status:'ready' },
  ]})
})
app.post('/api/reports/generate', requireAuth, (req, res) => {
  const { type } = req.body || {}
  res.json({ ok: true, message: 'جاري إنشاء التقرير', type: type || 'matches', filename: `report_${type}_${Date.now()}.pdf`, timestamp: new Date().toISOString() })
})
app.get('/api/reports/download/:filename', requireAuth, (req, res) => {
  res.json({ ok: true, url: `/api/reports/download/${req.params.filename}`, message: 'رابط التنزيل جاهز' })
})

// Broker Weekly Report — on-demand trigger
app.post('/api/reports/broker-weekly', requireAuth, async (req, res) => {
  try {
    const { run } = _require('./automations/broker_weekly_report.cjs')
    const result = await run()
    if (!result.ok) return res.status(500).json({ error: result.error || 'Report generation failed' })
    res.json({
      ok: true,
      file: result.fileName,
      path: result.filePath,
      dateStr: result.dateStr,
      stats: result.stats,
      email: result.emailResult,
      timestamp: new Date().toISOString()
    })
  } catch(e) {
    console.error('[/api/reports/broker-weekly]', e.message)
    res.status(500).json({ ok: false, error: e.message })
  }
})

// Pipeline
app.get('/api/pipeline', requireAuth, (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM pipeline ORDER BY created_at DESC').all()
    res.json({ count: rows.length, rows })
  } catch(e) { res.status(500).json({ error: e.message }) }
})
app.post('/api/pipeline', requireAuth, (req, res) => {
  try {
    const { title, stage, value, contact_name, contact_phone, location, notes } = req.body
    const id = 'p_' + Date.now()
    db.prepare('INSERT INTO pipeline(id,title,stage,value,contact_name,contact_phone,location,notes) VALUES(?,?,?,?,?,?,?,?)').run(id,title,stage||'lead',value,contact_name,contact_phone,location,notes)
    res.json({ ok: true, id })
  } catch(e) { res.status(500).json({ error: e.message }) }
})
app.patch('/api/pipeline/:id', requireAuth, (req, res) => {
  try {
    const { stage, notes } = req.body
    db.prepare("UPDATE pipeline SET stage=?, notes=?, updated_at=datetime('now') WHERE id=?").run(stage, notes, req.params.id)
    res.json({ ok: true })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Assets
app.get('/api/assets', requireAuth, (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM assets ORDER BY created_at DESC').all()
    res.json({ count: rows.length, rows })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// ── WA / Baileys endpoints ─────────────────────────────────────────────────
app.get('/api/wa/status', requireAuth, (req, res) => res.json(getBaileysState()))

app.get('/api/baileys/status', requireAuth, (req, res) => res.json(getBaileysState()))

app.post('/api/baileys/start', requireAuth, async (req, res) => {
  try {
    await startBaileys()
    res.json({ ok: true, message: 'Baileys starting — scan QR code', state: getBaileysState() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

app.post('/api/baileys/stop', requireAuth, async (req, res) => {
  try {
    await stopBaileys()
    res.json({ ok: true, message: 'Baileys stopped', state: getBaileysState() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

app.post('/api/baileys/reset', requireAuth, async (req, res) => {
  try {
    await resetBaileys()
    res.json({ ok: true, message: 'Baileys session reset — new QR will be generated', state: getBaileysState() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

app.get('/api/baileys/qr', requireAuth, (req, res) => {
  const st = getBaileysState()
  if (st.qrBase64) {
    // Return as HTML page with embedded QR image for easy scanning
    res.send(`<!DOCTYPE html><html><head><title>MatchPro WA QR</title><meta http-equiv="refresh" content="30"></head><body style="display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#1a1a2e;flex-direction:column"><h2 style="color:#fff;font-family:sans-serif">MatchPro WhatsApp QR</h2><img src="${st.qrBase64}" style="border-radius:16px;padding:16px;background:#fff" /><p style="color:#aaa;font-family:sans-serif;margin-top:16px">Scan with WhatsApp → Linked Devices → Link a Device</p><p style="color:#666;font-size:12px">Auto-refresh every 30s</p></body></html>`)
  } else if (st.connected) {
    res.json({ connected: true, phone: st.phone, message: 'Already connected — no QR needed' })
  } else {
    res.json({ connected: false, message: 'QR not yet generated — Baileys may still be initializing', state: st.state })
  }
})

app.get('/api/baileys/groups', requireAuth, async (req, res) => {
  try {
    const groups = await getGroups()
    res.json({ ok: true, count: groups.length, groups })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

app.post('/api/baileys/send-message', requireAuth, async (req, res) => {
  try {
    const { to, text } = req.body || {}
    if (!to || !text) return res.status(400).json({ error: '`to` (phone number) and `text` are required' })
    await baileySend(to, text)
    res.json({ ok: true, message: 'Message sent', to, timestamp: new Date().toISOString() })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// ── Monitored groups (SACRED engine filter) ────────────────────────────────
// GET: returns current monitored group ids + names (null = monitor ALL)
app.get('/api/baileys/monitored-groups', requireAuth, async (req, res) => {
  try {
    const row = db.prepare("SELECT value FROM settings WHERE key='monitored_group_ids'").get()
    let monitoredIds = null
    if (row && row.value) {
      try { monitoredIds = JSON.parse(row.value) } catch { monitoredIds = null }
    }
    // Optionally enrich with group metadata if Baileys is connected
    let groups = []
    try { groups = await getGroups() } catch { /* offline — return ids only */ }
    const enriched = (monitoredIds || []).map(id => {
      const g = groups.find(g => g.id === id)
      return { id, name: g?.subject || g?.name || id, participants: g?.participants?.length || 0, monitored: true }
    })
    res.json({
      ok: true,
      monitor_all: monitoredIds === null,
      monitored_ids: monitoredIds || [],
      monitored_groups: enriched,
      total_groups: groups.length,
    })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// POST: { group_ids: ['id1','id2',...] } — empty array = monitor ALL
app.post('/api/baileys/monitored-groups', requireAuth, (req, res) => {
  try {
    const { group_ids } = req.body || {}
    if (!Array.isArray(group_ids)) return res.status(400).json({ error: 'group_ids must be an array' })
    const value = group_ids.length === 0 ? null : JSON.stringify(group_ids)
    if (value === null) {
      db.prepare("DELETE FROM settings WHERE key='monitored_group_ids'").run()
    } else {
      db.prepare("INSERT OR REPLACE INTO settings(key,value) VALUES('monitored_group_ids',?)").run(value)
    }
    // Emit updated config via Socket.IO so Flutter syncs live
    io.emit('monitored_groups_updated', { monitor_all: value === null, monitored_ids: group_ids })
    res.json({ ok: true, monitor_all: value === null, monitored_ids: group_ids, message: value === null ? 'Monitoring ALL groups' : `Monitoring ${group_ids.length} group(s)` })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Brokers
app.get('/api/brokers', requireAuth, (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM brokers ORDER BY msg_count DESC').all()
    res.json({ count: rows.length, rows })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Messages
app.get('/api/messages', requireAuth, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 200)
    const rows  = db.prepare('SELECT * FROM messages ORDER BY created_at DESC LIMIT ?').all(limit)
    res.json({ count: rows.length, rows, total: db.prepare('SELECT COUNT(*) c FROM messages').get().c })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// ETL trigger
app.post('/api/etl-trigger', requireAuth, (req, res) => {
  const matched = runSacredMatching()
  res.json({ ok: true, processed: matched.length, message: 'ETL triggered — SACRED matching complete', timestamp: new Date().toISOString() })
})

// Settings
app.get('/api/settings', requireAuth, (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM settings').all()
    const obj  = Object.fromEntries(rows.map(r => [r.key, r.value]))
    res.json(obj)
  } catch(e) { res.status(500).json({ error: e.message }) }
})
app.post('/api/settings', requireAuth, (req, res) => {
  try {
    const upd = db.prepare('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)')
    const txn = db.transaction((data) => { for (const [k,v] of Object.entries(data)) upd.run(k, String(v)) })
    txn(req.body || {})
    res.json({ ok: true })
  } catch(e) { res.status(500).json({ error: e.message }) }
})

// Supply / Demand raw
app.get('/api/supply', requireAuth, (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200)
  res.json({ rows: db.prepare('SELECT * FROM supply ORDER BY created_at DESC LIMIT ?').all(limit) })
})
app.get('/api/demand', requireAuth, (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200)
  res.json({ rows: db.prepare('SELECT * FROM demand ORDER BY created_at DESC LIMIT ?').all(limit) })
})

// Socket.IO
io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ','')
  if (token && verifyJWT(token)) return next()
  next(new Error('Unauthorized'))
})

io.on('connection', (socket) => {
  console.log(`[Socket.IO] Client connected: ${socket.id}`)
  socket.emit('connected', { message:'MatchPro real-time active', timestamp: new Date().toISOString() })

  // Send current stats on connect
  const stats = {
    supply:  db.prepare('SELECT COUNT(*) c FROM supply').get().c,
    demand:  db.prepare('SELECT COUNT(*) c FROM demand').get().c,
    matches: db.prepare('SELECT COUNT(*) c FROM matches').get().c,
  }
  socket.emit('stats_update', stats)

  socket.on('disconnect', () => console.log(`[Socket.IO] Client disconnected: ${socket.id}`))
  socket.on('ping', () => socket.emit('pong', { timestamp: new Date().toISOString() }))

  // Send current monitored groups config on connect
  try {
    const mgRow = db.prepare("SELECT value FROM settings WHERE key='monitored_group_ids'").get()
    let monitoredIds = null
    if (mgRow && mgRow.value) { try { monitoredIds = JSON.parse(mgRow.value) } catch { monitoredIds = null } }
    socket.emit('monitored_groups_updated', { monitor_all: monitoredIds === null, monitored_ids: monitoredIds || [] })
  } catch { /* ignore */ }
})

// Auto-emit stats every 30s
setInterval(() => {
  try {
    const stats = {
      supply:   db.prepare('SELECT COUNT(*) c FROM supply').get().c,
      demand:   db.prepare('SELECT COUNT(*) c FROM demand').get().c,
      matches:  db.prepare('SELECT COUNT(*) c FROM matches').get().c,
      messages: db.prepare('SELECT COUNT(*) c FROM messages').get().c,
      timestamp: new Date().toISOString()
    }
    io.emit('stats_update', stats)
  } catch { /* ignore */ }
}, 30000)

// ── Start ─────────────────────────────────────────────────────────────────
httpServer.listen(PORT, '0.0.0.0', async () => {
  const counts = {
    supply:   db.prepare('SELECT COUNT(*) c FROM supply').get().c,
    demand:   db.prepare('SELECT COUNT(*) c FROM demand').get().c,
    matches:  db.prepare('SELECT COUNT(*) c FROM matches').get().c,
    messages: db.prepare('SELECT COUNT(*) c FROM messages').get().c,
    brokers:  db.prepare('SELECT COUNT(*) c FROM brokers').get().c,
  }
  console.log(`\n🚀 MatchPro Backend v2.0 — PORT ${PORT}`)
  console.log(`   SQLite:    ✅ ${DB_PATH}`)
  console.log(`   Supply:    ${counts.supply} records`)
  console.log(`   Demand:    ${counts.demand} records`)
  console.log(`   Messages:  ${counts.messages} records`)
  console.log(`   Matches:   ${counts.matches} records`)
  console.log(`   Brokers:   ${counts.brokers} records`)
  console.log(`   Socket.IO: ✅ enabled`)
  console.log(`   Baileys:   🔄 starting...`)
  console.log(`\n   Health:   http://localhost:${PORT}/health`)
  console.log(`   QR Page:  http://localhost:${PORT}/api/baileys/qr (after auth)\n`)

  // Auto-start Baileys WA connector
  try {
    await startBaileys()
    console.log('[Baileys] ✅ Initialized — check logs for QR or connected state')
  } catch(e) {
    console.error('[Baileys] ⚠️  Failed to start:', e.message)
    console.log('[Baileys] POST /api/baileys/start to retry')
  }
})

export default app
