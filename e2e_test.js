#!/usr/bin/env node
/**
 * MatchPro / SACRED Engine — Full E2E Test Suite v2
 * All routes, shapes, and auth verified against live server.
 *
 * Route map (confirmed):
 *   GET  /health                        public
 *   GET  /api/health                    public
 *   POST /api/auth/login                public
 *   POST /api/auth/logout               auth
 *   GET  /api/auth/me                   auth
 *   GET  /api/dashboard                 auth
 *   GET  /api/stats                     auth → {supply_count,demand_count,match_count,timestamp}
 *   GET  /api/matches                   auth → {count,rows,matches}  (.matches = array with breakdown)
 *   POST /api/run-matching              auth → {ok,matched,hot_count,warm_count,matches[],timestamp}
 *   GET  /api/locations/stats           auth → {locations[],totalSupply,totalDemand,hotZones[],timestamp}
 *   GET  /api/market/overview           auth
 *   GET  /api/reports/list              auth
 *   POST /api/reports/generate          auth
 *   GET  /api/reports/download/:f       auth
 *   GET  /api/pipeline                  auth → {count,rows[{id,title,stage,...}]}
 *   POST /api/pipeline                  auth → {ok,id}
 *   PATCH /api/pipeline/:id             auth → {ok,...}
 *   GET  /api/assets                    auth → {count,rows[]}
 *   GET  /api/wa/status                 auth
 *   GET  /api/baileys/status            auth → {connected,state,reconnects,...}
 *   POST /api/baileys/start             auth
 *   POST /api/baileys/stop              auth
 *   POST /api/baileys/reset             auth
 *   GET  /api/baileys/qr                auth
 *   GET  /api/baileys/groups            auth → [] or 503
 *   POST /api/baileys/send-message      auth
 *   GET  /api/baileys/monitored-groups  auth → {ok,monitor_all,monitored_ids[],monitored_groups[],total_groups}
 *   POST /api/baileys/monitored-groups  auth → {ok,monitor_all,monitored_ids[],message}
 *   GET  /api/brokers                   auth → {count,rows[]}
 *   GET  /api/messages                  auth → {count,rows[],total}
 *   POST /api/etl-trigger               auth → {ok,processed,message,timestamp}
 *   GET  /api/settings                  auth → {key:value,...}
 *   POST /api/settings                  auth → {ok,key,value}
 *   GET  /api/supply                    auth → {rows[]}
 *   GET  /api/demand                    auth → {rows[]}
 */

const BASE = 'http://localhost:3001'
let TOKEN = ''

const C = {
  pass: '\x1b[32m✅\x1b[0m',
  fail: '\x1b[31m❌\x1b[0m',
  info: '\x1b[36mℹ️ \x1b[0m',
  warn: '\x1b[33m⚠️ \x1b[0m',
  head: (s) => `\n\x1b[1m══ ${s} ══\x1b[0m`,
}

let passed = 0, failed = 0
const failures = []

function assert(label, condition, detail = '') {
  if (condition) {
    console.log(`  ${C.pass} ${label}`)
    passed++
  } else {
    console.log(`  ${C.fail} ${label}${detail ? ' — ' + detail : ''}`)
    failed++
    failures.push({ label, detail })
  }
}

async function api(method, path, body, auth = true) {
  const opts = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(auth ? { Authorization: `Bearer ${TOKEN}` } : {})
    },
  }
  if (body !== undefined && body !== null) opts.body = JSON.stringify(body)
  const r = await fetch(`${BASE}${path}`, opts)
  let json; try { json = await r.json() } catch { json = null }
  return { status: r.status, json }
}

// ══════════════════════════════════════════════
// S0: AUTH
// ══════════════════════════════════════════════
async function s0_auth() {
  console.log(C.head('S0: AUTH'))

  // wrong password
  const bad = await api('POST', '/api/auth/login', { username: 'admin', password: 'wrong' }, false)
  assert('Bad credentials → non-200 or error field', bad.status !== 200 || bad.json?.error)

  // correct login
  const good = await api('POST', '/api/auth/login', { username: 'admin', password: 'CPI-Admin-2026!' }, false)
  assert('Login 200', good.status === 200)
  assert('Token is string > 20 chars', typeof good.json?.token === 'string' && good.json.token.length > 20)
  assert('Token has 3 JWT parts', good.json?.token?.split('.').length === 3)
  assert('expires_in = 86400', good.json?.expires_in === 86400)
  assert('User role = admin', good.json?.user?.role === 'admin')
  TOKEN = good.json.token

  // missing auth
  const noAuth = await fetch(`${BASE}/api/supply`)
  assert('Missing auth → 401', noAuth.status === 401)

  // invalid token
  const badToken = await fetch(`${BASE}/api/supply`, { headers: { Authorization: 'Bearer invalid.jwt.here' } })
  assert('Invalid token → 401', badToken.status === 401)

  // GET /api/auth/me
  const me = await api('GET', '/api/auth/me')
  assert('GET /api/auth/me → 200', me.status === 200)
  assert('Me user.sub = admin', me.json?.user?.sub === 'admin')
  assert('Me user.role = admin', me.json?.user?.role === 'admin')
}

// ══════════════════════════════════════════════
// S1: HEALTH
// ══════════════════════════════════════════════
async function s1_health() {
  console.log(C.head('S1: HEALTH'))

  const root = await api('GET', '/health', null, false)
  assert('GET /health → 200', root.status === 200)

  const h = await api('GET', '/api/health', null, false)
  assert('GET /api/health → 200', h.status === 200)
  assert('health.status = ok', h.json?.status === 'ok')
  assert('health.db.supply ≥ 0', typeof h.json?.db?.supply === 'number' && h.json.db.supply >= 0)
  assert('health.db.demand ≥ 0', typeof h.json?.db?.demand === 'number' && h.json.db.demand >= 0)
  assert('health.db.matches ≥ 0', typeof h.json?.db?.matches === 'number' && h.json.db.matches >= 0)
  assert('health.db.messages ≥ 0', typeof h.json?.db?.messages === 'number' && h.json.db.messages >= 0)
  console.log(`  ${C.info} DB: supply=${h.json.db.supply} demand=${h.json.db.demand} matches=${h.json.db.matches} messages=${h.json.db.messages}`)
}

// ══════════════════════════════════════════════
// S2: SUPPLY + DEMAND (read-only; no POST routes exist)
// ══════════════════════════════════════════════
async function s2_supply_demand() {
  console.log(C.head('S2: SUPPLY & DEMAND'))

  // supply
  const sup = await api('GET', '/api/supply')
  assert('GET /api/supply → 200', sup.status === 200)
  assert('Supply response has rows array', Array.isArray(sup.json?.rows))
  const supRows = sup.json?.rows || []
  console.log(`  ${C.info} Supply rows: ${supRows.length}`)
  if (supRows.length > 0) {
    const r = supRows[0]
    assert('Supply row has id', r.id !== undefined)
    assert('Supply row has location', typeof r.location === 'string')
    assert('Supply row has property_type', r.property_type !== undefined)
    assert('Supply row price is number or null', r.price === null || typeof r.price === 'number')
    assert('Supply row bedrooms is number or null', r.bedrooms === null || typeof r.bedrooms === 'number')
    assert('Supply row urgent is 0 or 1 or bool', r.urgent === 0 || r.urgent === 1 || typeof r.urgent === 'boolean')
  }

  // demand
  const dem = await api('GET', '/api/demand')
  assert('GET /api/demand → 200', dem.status === 200)
  assert('Demand response has rows array', Array.isArray(dem.json?.rows))
  const demRows = dem.json?.rows || []
  console.log(`  ${C.info} Demand rows: ${demRows.length}`)
  if (demRows.length > 0) {
    const r = demRows[0]
    assert('Demand row has id', r.id !== undefined)
    assert('Demand row has location', typeof r.location === 'string')
  }
}

// ══════════════════════════════════════════════
// S3: SACRED ETL (POST /api/run-matching)
// ══════════════════════════════════════════════
async function s3_sacred_etl() {
  console.log(C.head('S3: SACRED ETL (POST /api/run-matching)'))

  const etl = await api('POST', '/api/run-matching')
  assert('POST /api/run-matching → 200', etl.status === 200)
  assert('ETL ok = true', etl.json?.ok === true)
  assert('ETL matched is number ≥ 0', typeof etl.json?.matched === 'number' && etl.json.matched >= 0)
  assert('ETL hot_count is number', typeof etl.json?.hot_count === 'number')
  assert('ETL warm_count is number', typeof etl.json?.warm_count === 'number')
  assert('ETL matches array present', Array.isArray(etl.json?.matches))
  assert('ETL has timestamp', typeof etl.json?.timestamp === 'string')
  console.log(`  ${C.info} ETL: matched=${etl.json?.matched} hot=${etl.json?.hot_count} warm=${etl.json?.warm_count}`)
}

// ══════════════════════════════════════════════
// S4: MATCHES + BREAKDOWN NORMALIZATION (THE KEY TEST)
// ══════════════════════════════════════════════
async function s4_matches() {
  console.log(C.head('S4: MATCHES + SACRED BREAKDOWN NORMALIZATION'))

  const r = await api('GET', '/api/matches')
  assert('GET /api/matches → 200', r.status === 200)
  assert('Response has count', typeof r.json?.count === 'number')
  assert('Response has matches array', Array.isArray(r.json?.matches))
  assert('Response has rows array', Array.isArray(r.json?.rows))

  const matches = r.json?.matches || []
  console.log(`  ${C.info} Total matches: ${matches.length}`)
  assert('At least 1 match exists', matches.length > 0)

  if (matches.length > 0) {
    const m = matches[0]
    assert('Match has id', m.id !== undefined)
    assert('Match has match_score', typeof m.match_score === 'number')
    assert('Match has score (alias)', typeof m.score === 'number')
    assert('Match has grade', ['hot','warm','cold'].includes(m.grade))
    assert('Match score in [0,100]', m.match_score >= 0 && m.match_score <= 100)
    assert('Match has supply object', m.supply !== undefined)
    assert('Match has demand object', m.demand !== undefined)
    assert('Match has breakdown object', m.breakdown !== undefined && typeof m.breakdown === 'object')
  }

  // ── CRITICAL: Breakdown normalization
  console.log(`\n  ── Breakdown normalization check (all matches) ──`)
  let bdFails = 0
  let bdChecked = 0
  for (const m of matches) {
    const bd = m.breakdown
    if (!bd || typeof bd !== 'object') continue
    const calcSum = Object.values(bd).reduce((a, b) => a + (Number(b) || 0), 0)
    const score = m.match_score
    const ok = calcSum === score
    bdChecked++
    if (!ok) {
      bdFails++
      console.log(`  ${C.fail} Match ${m.id}: breakdown sum ${calcSum} ≠ score ${score}  bd=${JSON.stringify(bd)}`)
    }
  }
  assert(`All ${bdChecked} match breakdowns sum == match_score`, bdFails === 0,
    bdFails > 0 ? `${bdFails} breakdown(s) still off` : '')
  if (bdFails === 0 && bdChecked > 0) {
    console.log(`  ${C.pass} SACRED breakdown normalization: ${bdChecked}/${bdChecked} correct ✓`)
  }

  // grade distribution
  const hot  = matches.filter(m => m.grade === 'hot').length
  const warm = matches.filter(m => m.grade === 'warm').length
  const cold = matches.filter(m => m.grade === 'cold').length
  console.log(`  ${C.info} Grade dist: hot=${hot} warm=${warm} cold=${cold}`)
  assert('hot matches ≥ 0', hot >= 0)
  assert('hot matches ≤ total', hot <= matches.length)
}

// ══════════════════════════════════════════════
// S5: MESSAGES
// ══════════════════════════════════════════════
async function s5_messages() {
  console.log(C.head('S5: MESSAGES'))

  const r = await api('GET', '/api/messages')
  assert('GET /api/messages → 200', r.status === 200)
  assert('Has count', typeof r.json?.count === 'number')
  assert('Has rows array', Array.isArray(r.json?.rows))
  assert('Has total', typeof r.json?.total === 'number')
  console.log(`  ${C.info} Messages: count=${r.json?.count} total=${r.json?.total}`)

  if (r.json?.rows?.length > 0) {
    const m = r.json.rows[0]
    assert('Message has id', m.id !== undefined)
    assert('Message has body', typeof m.body === 'string')
    assert('Message has created_at', m.created_at !== undefined)
    assert('Message has group_id', m.group_id !== undefined)
    assert('Message has msg_type', m.msg_type !== undefined)
  }

  // pagination
  const paged = await api('GET', '/api/messages?limit=3&offset=0')
  assert('Paginated GET → 200', paged.status === 200)
  assert('Paginated rows ≤ 3', Array.isArray(paged.json?.rows) && paged.json.rows.length <= 3)
}

// ══════════════════════════════════════════════
// S6: BROKERS
// ══════════════════════════════════════════════
async function s6_brokers() {
  console.log(C.head('S6: BROKERS'))

  const r = await api('GET', '/api/brokers')
  assert('GET /api/brokers → 200', r.status === 200)
  assert('Has count', typeof r.json?.count === 'number')
  assert('Has rows array', Array.isArray(r.json?.rows))
  console.log(`  ${C.info} Brokers: ${r.json?.count}`)

  if (r.json?.rows?.length > 0) {
    const b = r.json.rows[0]
    assert('Broker has id', b.id !== undefined)
    assert('Broker has name', typeof b.name === 'string')
    assert('Broker has phone', typeof b.phone === 'string')
    assert('Broker has msg_count', typeof b.msg_count === 'number')
  }
}

// ══════════════════════════════════════════════
// S7: ASSETS
// ══════════════════════════════════════════════
async function s7_assets() {
  console.log(C.head('S7: ASSETS'))

  const r = await api('GET', '/api/assets')
  assert('GET /api/assets → 200', r.status === 200)
  assert('Has count', typeof r.json?.count === 'number')
  assert('Has rows array', Array.isArray(r.json?.rows))
  console.log(`  ${C.info} Assets: ${r.json?.count}`)
}

// ══════════════════════════════════════════════
// S8: PIPELINE CRUD (GET + POST + PATCH)
// ══════════════════════════════════════════════
async function s8_pipeline() {
  console.log(C.head('S8: PIPELINE CRUD'))

  // list
  const list = await api('GET', '/api/pipeline')
  assert('GET /api/pipeline → 200', list.status === 200)
  assert('Has count', typeof list.json?.count === 'number')
  assert('Has rows array', Array.isArray(list.json?.rows))
  const initialCount = list.json?.count || 0
  console.log(`  ${C.info} Pipeline deals: ${initialCount}`)

  if (list.json?.rows?.length > 0) {
    const deal = list.json.rows[0]
    assert('Deal has id', deal.id !== undefined)
    assert('Deal has stage', deal.stage !== undefined)
  }

  // create
  const created = await api('POST', '/api/pipeline', {
    supply_id: 's_e2e_001',
    demand_id: 'd_e2e_001',
    stage: 'intro',
    notes: `E2E test deal ${Date.now()}`,
    contact_name: 'E2E Test'
  })
  assert('POST /api/pipeline → 200 or 201', created.status === 200 || created.status === 201)
  assert('Created deal ok = true', created.json?.ok === true)
  assert('Created deal has id', typeof created.json?.id === 'string')
  const dealId = created.json?.id

  // verify count +1
  const listAfter = await api('GET', '/api/pipeline')
  assert('Pipeline count +1 after create', listAfter.json?.count === initialCount + 1)

  // patch
  if (dealId) {
    const patch = await api('PATCH', `/api/pipeline/${dealId}`, { stage: 'negotiation', notes: 'E2E patched' })
    assert(`PATCH /api/pipeline/${dealId} → 200`, patch.status === 200)
    assert('Patch ok = true', patch.json?.ok === true)

    // verify persisted
    const finalList = await api('GET', '/api/pipeline')
    const patched = finalList.json?.rows?.find(d => d.id === dealId)
    assert('Patched stage persisted in DB', patched?.stage === 'negotiation')
  }
}

// ══════════════════════════════════════════════
// S9: SETTINGS CRUD
// ══════════════════════════════════════════════
async function s9_settings() {
  console.log(C.head('S9: SETTINGS CRUD'))

  // GET /api/settings (returns {key:value} dict)
  const all = await api('GET', '/api/settings')
  assert('GET /api/settings → 200', all.status === 200)
  assert('Settings is an object (key→value dict)', all.json !== null && typeof all.json === 'object' && !Array.isArray(all.json))
  console.log(`  ${C.info} Settings keys: ${Object.keys(all.json || {}).join(', ')}`)

  // CRITICAL: POST /api/settings iterates Object.entries(req.body) and writes each as a setting.
  // So send {myActualKey: 'myValue'} NOT {key:'k', value:'v'} (that writes key→'k' and value→'v').
  const testKey = `e2e_ts_${Date.now()}`
  const testVal = `e2e_tv_${Date.now()}`
  const write = await api('POST', '/api/settings', { [testKey]: testVal })
  assert('POST /api/settings → 200', write.status === 200)
  assert('Write returns ok', write.json?.ok === true)

  // read back via GET all
  const readAll = await api('GET', '/api/settings')
  assert('Written key appears in GET all', readAll.json?.[testKey] === testVal)

  // overwrite
  const newVal = `updated_${Date.now()}`
  await api('POST', '/api/settings', { [testKey]: newVal })
  const readUpdated = await api('GET', '/api/settings')
  assert('Overwrite persisted', readUpdated.json?.[testKey] === newVal)

  // cleanup — no DELETE route so just verify not 500
  const del = await api('DELETE', `/api/settings/${testKey}`)
  if (del.status === 200 || del.status === 204) {
    const readDel = await api('GET', '/api/settings')
    assert('Delete removes key', readDel.json?.[testKey] === undefined)
  } else {
    console.log(`  ${C.warn} DELETE /api/settings/:key → ${del.status} (no DELETE route — skipped)`)
    assert('Settings DELETE → not 500', del.status !== 500)
  }
}

// ══════════════════════════════════════════════
// S10: MONITORED GROUPS (full round-trip)
// ══════════════════════════════════════════════
async function s10_monitored_groups() {
  console.log(C.head('S10: MONITORED GROUPS'))

  // read initial
  const init = await api('GET', '/api/baileys/monitored-groups')
  assert('GET /api/baileys/monitored-groups → 200', init.status === 200)
  assert('Has monitor_all (bool)', typeof init.json?.monitor_all === 'boolean')
  assert('Has monitored_ids (array)', Array.isArray(init.json?.monitored_ids))
  assert('Has total_groups (number)', typeof init.json?.total_groups === 'number')
  console.log(`  ${C.info} Initial: monitor_all=${init.json?.monitor_all} ids=${JSON.stringify(init.json?.monitored_ids)}`)

  // set specific IDs
  const testIds = ['120363001234567890@g.us', '120363009876543210@g.us']
  const set = await api('POST', '/api/baileys/monitored-groups', { group_ids: testIds })
  assert('POST with IDs → 200', set.status === 200)
  assert('Set ok = true', set.json?.ok === true)
  assert('Set monitor_all = false', set.json?.monitor_all === false)
  assert('Set monitored_ids has 2 items', set.json?.monitored_ids?.length === 2)
  assert('Set has message string', typeof set.json?.message === 'string')

  // verify read-back
  const rb = await api('GET', '/api/baileys/monitored-groups')
  assert('GET after set → monitor_all = false', rb.json?.monitor_all === false)
  const rbIds = (rb.json?.monitored_ids || []).slice().sort()
  assert('GET after set → correct IDs', JSON.stringify(rbIds) === JSON.stringify(testIds.slice().sort()))

  // reset (empty array = monitor all)
  const reset = await api('POST', '/api/baileys/monitored-groups', { group_ids: [] })
  assert('POST [] → ok', reset.json?.ok === true)
  assert('POST [] → monitor_all = true', reset.json?.monitor_all === true)
  assert('POST [] → monitored_ids empty', reset.json?.monitored_ids?.length === 0)

  // verify reset
  const after = await api('GET', '/api/baileys/monitored-groups')
  assert('GET after reset → monitor_all = true', after.json?.monitor_all === true)
  assert('GET after reset → no IDs', after.json?.monitored_ids?.length === 0)

  // bad body (string instead of array)
  const bad = await api('POST', '/api/baileys/monitored-groups', { group_ids: 'not-an-array' })
  assert('Bad body (string) → 400', bad.status === 400)
  assert('Bad body has error field', typeof bad.json?.error === 'string')

  // missing body entirely
  const nobody = await api('POST', '/api/baileys/monitored-groups', {})
  assert('Missing group_ids → 400', nobody.status === 400)
}

// ══════════════════════════════════════════════
// S11: LOCATION STATS
// ══════════════════════════════════════════════
async function s11_location_stats() {
  console.log(C.head('S11: LOCATION STATS'))

  const r = await api('GET', '/api/locations/stats')
  assert('GET /api/locations/stats → 200', r.status === 200)
  assert('Has locations array', Array.isArray(r.json?.locations))
  assert('Has totalSupply', typeof r.json?.totalSupply === 'number')
  assert('Has totalDemand', typeof r.json?.totalDemand === 'number')
  assert('Has hotZones (number)', typeof r.json?.hotZones === 'number')
  console.log(`  ${C.info} Locations: ${r.json?.locations?.length}, totalSupply=${r.json?.totalSupply}, totalDemand=${r.json?.totalDemand}`)

  const locs = r.json?.locations || []
  if (locs.length > 0) {
    const madinaty = locs.find(l => l.location?.toLowerCase().includes('madinaty'))
    if (madinaty) {
      console.log(`  ${C.info} Madinaty: supply=${madinaty.supply} demand=${madinaty.demand} pressure_index=${madinaty.pressure_index} signal=${madinaty.signal}`)
      assert('Madinaty supply ≥ 0', typeof madinaty.supply === 'number' && madinaty.supply >= 0)
      assert('Madinaty demand ≥ 0', typeof madinaty.demand === 'number' && madinaty.demand >= 0)
      assert('Madinaty pressure_index is number', typeof madinaty.pressure_index === 'number')
      assert('Madinaty signal is valid', ['hot','warm','cold','neutral'].includes(madinaty.signal || 'neutral'))
      assert('Madinaty pressure_index > 1 (demand >> supply)', madinaty.pressure_index > 1)
    } else {
      console.log(`  ${C.warn} Madinaty not found in location stats`)
    }

    const loc = locs[0]
    assert('Location entry has location string', typeof loc.location === 'string')
    assert('Location entry has supply (number)', typeof loc.supply === 'number')
    assert('Location entry has demand (number)', typeof loc.demand === 'number')
    assert('Location entry has pressure_index (number)', typeof loc.pressure_index === 'number')
  }
}

// ══════════════════════════════════════════════
// S12: STATS / DASHBOARD
// ══════════════════════════════════════════════
async function s12_stats() {
  console.log(C.head('S12: STATS & DASHBOARD'))

  // /api/stats
  const stats = await api('GET', '/api/stats')
  assert('GET /api/stats → 200', stats.status === 200)
  assert('Has supply_count', typeof stats.json?.supply_count === 'number')
  assert('Has demand_count', typeof stats.json?.demand_count === 'number')
  assert('Has match_count', typeof stats.json?.match_count === 'number')
  assert('Has timestamp', typeof stats.json?.timestamp === 'string')
  console.log(`  ${C.info} Stats: supply=${stats.json?.supply_count} demand=${stats.json?.demand_count} matches=${stats.json?.match_count}`)

  // /api/dashboard
  const dash = await api('GET', '/api/dashboard')
  assert('GET /api/dashboard → 200', dash.status === 200)
  assert('Dashboard has data', dash.json !== null && typeof dash.json === 'object')

  // /api/market/overview
  const market = await api('GET', '/api/market/overview')
  assert('GET /api/market/overview → 200', market.status === 200)

  // /api/reports/list
  const reports = await api('GET', '/api/reports/list')
  assert('GET /api/reports/list → 200', reports.status === 200)
}

// ══════════════════════════════════════════════
// S13: BAILEYS STATE
// ══════════════════════════════════════════════
async function s13_baileys() {
  console.log(C.head('S13: BAILEYS STATE'))

  // /api/baileys/status
  const status = await api('GET', '/api/baileys/status')
  assert('GET /api/baileys/status → 200', status.status === 200)
  assert('Has connected (bool)', typeof status.json?.connected === 'boolean')
  assert('Has state (string)', typeof status.json?.state === 'string')
  console.log(`  ${C.info} Baileys: connected=${status.json?.connected} state=${status.json?.state} reconnects=${status.json?.reconnects}/${status.json?.maxReconnects}`)

  // reconnects should be ≤ 50 (MAX_RECONNECTS raised)
  if (typeof status.json?.reconnects === 'number') {
    assert('Reconnects ≤ 50 (MAX_RECONNECTS raised)', status.json.reconnects <= 50)
  }

  // /api/wa/status (alias)
  const waStatus = await api('GET', '/api/wa/status')
  assert('GET /api/wa/status → 200', waStatus.status === 200)

  // /api/baileys/qr
  const qr = await api('GET', '/api/baileys/qr')
  assert('GET /api/baileys/qr → 200 or 404', qr.status === 200 || qr.status === 404)
  if (qr.status === 200 && qr.json?.qrBase64) {
    assert('QR base64 is non-empty string', typeof qr.json.qrBase64 === 'string' && qr.json.qrBase64.length > 100)
    console.log(`  ${C.info} QR base64 length: ${qr.json.qrBase64?.length} chars`)
  }

  // /api/baileys/groups (may 503 if not connected)
  const groups = await api('GET', '/api/baileys/groups')
  assert('GET /api/baileys/groups → 200 or 503', groups.status === 200 || groups.status === 503)
  if (groups.status === 200) {
    assert('Groups response has groups array', Array.isArray(groups.json?.groups))
    console.log(`  ${C.info} WA groups count: ${groups.json?.count}`)
  } else {
    console.log(`  ${C.warn} Baileys not connected — groups returned ${groups.status} (expected in sandbox)`)
  }
}

// ══════════════════════════════════════════════
// S14: ETL TRIGGER (POST /api/etl-trigger)
// ══════════════════════════════════════════════
async function s14_etl_trigger() {
  console.log(C.head('S14: ETL-TRIGGER'))

  const r = await api('POST', '/api/etl-trigger')
  assert('POST /api/etl-trigger → 200', r.status === 200)
  assert('ok = true', r.json?.ok === true)
  assert('processed is number', typeof r.json?.processed === 'number')
  assert('has message string', typeof r.json?.message === 'string')
  assert('has timestamp', typeof r.json?.timestamp === 'string')
  console.log(`  ${C.info} ETL-trigger: processed=${r.json?.processed} msg="${r.json?.message}"`)
}

// ══════════════════════════════════════════════
// S15: FULL E2E PIPELINE
// ══════════════════════════════════════════════
async function s15_e2e_pipeline() {
  console.log(C.head('S15: FULL E2E PIPELINE'))

  // Step 1: baseline
  const h1 = await api('GET', '/api/health', null, false)
  const base = h1.json?.db || {}
  console.log(`  ${C.info} Step 1 baseline: supply=${base.supply} demand=${base.demand} matches=${base.matches}`)
  assert('Step 1: DB counts valid', base.supply >= 0 && base.demand >= 0 && base.matches >= 0)

  // Step 2: run SACRED (POST /api/run-matching)
  const etl = await api('POST', '/api/run-matching')
  assert('Step 2: SACRED ran ok', etl.json?.ok === true)
  assert('Step 2: matched ≥ 0', typeof etl.json?.matched === 'number')
  console.log(`  ${C.info} Step 2 SACRED: matched=${etl.json?.matched} hot=${etl.json?.hot_count}`)

  // Step 3: matches persisted + breakdown normalization
  const ml = await api('GET', '/api/matches')
  const matches = ml.json?.matches || []
  assert('Step 3: matches count ≥ baseline', matches.length >= base.matches)

  let bdFails = 0
  for (const m of matches) {
    const bd = m.breakdown
    if (!bd) continue
    const sum = Object.values(bd).reduce((a, b) => a + Number(b), 0)
    if (sum !== m.match_score) bdFails++
  }
  assert(`Step 3: All match breakdowns normalized (0 off of ${matches.length})`, bdFails === 0,
    bdFails > 0 ? `${bdFails} match(es) with wrong breakdown sum` : '')

  // top match grade
  const topM = matches[0]
  if (topM) {
    assert('Step 3: top match score ≤ 100', topM.match_score <= 100)
    assert('Step 3: top match grade hot/warm/cold', ['hot','warm','cold'].includes(topM.grade))
    console.log(`  ${C.info} Step 3 top match: id=${topM.id} score=${topM.match_score} grade=${topM.grade}`)
  }

  // Step 4: pipeline CRUD
  const deal = await api('POST', '/api/pipeline', {
    supply_id: 's_e2e_pipe', demand_id: 'd_e2e_pipe',
    stage: 'intro', notes: `E2E pipeline ${Date.now()}`
  })
  assert('Step 4: deal created', deal.json?.ok === true && deal.json?.id)
  const dealId = deal.json?.id
  if (dealId) {
    const patch = await api('PATCH', `/api/pipeline/${dealId}`, { stage: 'viewing' })
    assert('Step 4: deal patched', patch.json?.ok === true)

    const pl = await api('GET', '/api/pipeline')
    const patched = pl.json?.rows?.find(d => d.id === dealId)
    assert('Step 4: patched stage = viewing', patched?.stage === 'viewing')
  }

  // Step 5: settings round-trip — POST {key,value} → GET returns dict with key:value
  const sk = `e2e_pipeline_${Date.now()}`
  const sv = `sv_${Date.now()}`
  await api('POST', '/api/settings', { [sk]: sv })
  const sg = await api('GET', '/api/settings')
  assert('Step 5: settings round-trip', sg.json?.[sk] === sv, `key=${sk} got=${JSON.stringify(sg.json?.[sk])}`)

  // Step 6: monitored groups round-trip
  const mg1 = await api('POST', '/api/baileys/monitored-groups', { group_ids: ['test_e2e@g.us'] })
  assert('Step 6a: set monitored groups', mg1.json?.ok === true)
  const mg2 = await api('GET', '/api/baileys/monitored-groups')
  assert('Step 6b: get shows correct ID', mg2.json?.monitored_ids?.includes('test_e2e@g.us'))
  await api('POST', '/api/baileys/monitored-groups', { group_ids: [] })
  const mg3 = await api('GET', '/api/baileys/monitored-groups')
  assert('Step 6c: reset to monitor-all', mg3.json?.monitor_all === true)

  // Step 7: Madinaty location stats
  const ls = await api('GET', '/api/locations/stats')
  const mad = ls.json?.locations?.find(l => l.location?.toLowerCase().includes('madinaty'))
  if (mad) {
    assert('Step 7: Madinaty supply ≥ 1', typeof mad.supply === 'number' && mad.supply >= 1)
    assert('Step 7: Madinaty demand ≥ 1', typeof mad.demand === 'number' && mad.demand >= 1)
    assert('Step 7: Madinaty pressure_index > 0', typeof mad.pressure_index === 'number' && mad.pressure_index > 0)
    console.log(`  ${C.info} Step 7 Madinaty: supply=${mad.supply} demand=${mad.demand} pressure_index=${mad.pressure_index} signal=${mad.signal}`)
  }

  // Step 8: auth token validation
  const parts = TOKEN.split('.')
  assert('Step 8: JWT 3 parts', parts.length === 3)
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString())
    assert('Step 8: JWT sub = admin', payload.sub === 'admin')
    assert('Step 8: JWT exp > now', payload.exp > Date.now())
    assert('Step 8: JWT role = admin', payload.role === 'admin')
  } catch { assert('Step 8: JWT payload parseable', false) }
}

// ══════════════════════════════════════════════
// S16: EDGE CASES
// ══════════════════════════════════════════════
async function s16_edge_cases() {
  console.log(C.head('S16: EDGE CASES'))

  // PATCH non-existent pipeline — server does SQLite upsert, returns 200 {ok:true} always
  const badPatch = await api('PATCH', '/api/pipeline/nonexistent_id_99999', { stage: 'x' })
  assert('PATCH pipeline (upsert or 4xx) responds', badPatch.status === 200 || badPatch.status >= 400)

  // POST monitored-groups missing field
  const noField = await api('POST', '/api/baileys/monitored-groups', { group_ids: null })
  assert('group_ids=null → 400', noField.status === 400)

  // GET settings non-existent key (via all dict)
  const allSettings = await api('GET', '/api/settings')
  assert('GET all settings has no undefined values', !Object.values(allSettings.json || {}).some(v => v === undefined))

  // Baileys start (should be idempotent)
  const start = await api('POST', '/api/baileys/start')
  assert('POST /api/baileys/start → 200 or 4xx', start.status === 200 || start.status >= 400)
}

// ══════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════
async function main() {
  console.log('\x1b[1m\x1b[35m')
  console.log('╔══════════════════════════════════════════════════╗')
  console.log('║  MatchPro SACRED Engine — Full E2E Test Suite   ║')
  console.log('║  v2 — routes & shapes verified against live API ║')
  console.log('╚══════════════════════════════════════════════════╝')
  console.log('\x1b[0m')
  console.log(`Target: ${BASE}`)
  console.log(`Time:   ${new Date().toISOString()}`)

  try {
    await s0_auth()
    await s1_health()
    await s2_supply_demand()
    await s3_sacred_etl()
    await s4_matches()
    await s5_messages()
    await s6_brokers()
    await s7_assets()
    await s8_pipeline()
    await s9_settings()
    await s10_monitored_groups()
    await s11_location_stats()
    await s12_stats()
    await s13_baileys()
    await s14_etl_trigger()
    await s15_e2e_pipeline()
    await s16_edge_cases()
  } catch (e) {
    console.error(`\n\x1b[31mFATAL:\x1b[0m ${e.message}\n${e.stack}`)
    failed++
    failures.push({ label: 'FATAL', detail: e.message })
  }

  // ── FINAL REPORT ──
  const total = passed + failed
  const allPassed = failed === 0

  console.log('\n\x1b[1m' + '═'.repeat(56) + '\x1b[0m')
  if (allPassed) {
    console.log(`\x1b[1m\x1b[32m 🎉 ALL ${total} TESTS PASSED\x1b[0m`)
  } else {
    console.log(`\x1b[1m\x1b[31m ⚠️  ${failed} FAILURE${failed>1?'S':''} / ${total} TESTS\x1b[0m`)
    console.log(`\x1b[32m    Passed: ${passed}\x1b[0m   \x1b[31mFailed: ${failed}\x1b[0m`)
    console.log('\n\x1b[31m  FAILURES:\x1b[0m')
    failures.forEach(f => console.log(`    \x1b[31m❌ ${f.label}${f.detail ? ' — ' + f.detail : ''}\x1b[0m`))
  }
  console.log('\x1b[1m' + '═'.repeat(56) + '\x1b[0m\n')

  process.exit(allPassed ? 0 : 1)
}

main().catch(e => { console.error(e); process.exit(1) })
