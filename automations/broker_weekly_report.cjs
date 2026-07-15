/**
 * MatchPro™ Weekly Broker Report
 * Crystal Power Investments — Mo'men Maisara
 *
 * Replaces: 10 hours/week of manual WhatsApp screening
 * Data source: 24,000+ real WhatsApp conversations
 *
 * 4-sheet Excel:
 *   Sheet 1 — HOT Buyers
 *   Sheet 2 — HOT Sellers
 *   Sheet 3 — Best Matched Pairs (top 20)
 *   Sheet 4 — New Supply This Week
 *
 * Schedule: Every Sunday at 9:00 AM Cairo (Africa/Cairo)
 * On-demand: POST /api/reports/broker-weekly
 */

'use strict'

const path    = require('path')
const fs      = require('fs')
const ExcelJS = require('exceljs')
const nodemailer = require('nodemailer')
const Database   = require('better-sqlite3')

// ─── Config ──────────────────────────────────────────────────────────────────
const DB_PATH      = path.join(__dirname, '../data/matchpro.db')
const REPORTS_DIR  = path.join(__dirname, '../reports/broker_weekly')
const HOT_MIN      = 85    // match_score threshold for HOT
const WARM_MIN     = 65    // match_score threshold for WARM
const DAYS_ACTIVE  = 7     // last active within N days
const TOP_PAIRS    = 20    // number of matched pairs to include

// Brand colours
const NAVY         = '0A1628'
const HOT_BG       = 'FFCCCC'
const WARM_BG      = 'FFE5CC'
const WHITE        = 'FFFFFF'
const HOT_FG       = 'CC0000'
const WARM_FG      = 'CC6600'

// Email config — reads from process.env or falls back to logged-only mode
const EMAIL_TO     = process.env.EMAIL_TO   || 'mmaisara@crystalpowerinvestment.com'
const EMAIL_FROM   = process.env.EMAIL_FROM || 'matchpro@crystalpowerinvestment.com'
const SMTP_HOST    = process.env.SMTP_HOST  || ''
const SMTP_PORT    = parseInt(process.env.SMTP_PORT  || '587')
const SMTP_USER    = process.env.SMTP_USER  || ''
const SMTP_PASS    = process.env.SMTP_PASS  || ''

// ─── Helpers ─────────────────────────────────────────────────────────────────
function waLink(phone) {
  if (!phone) return ''
  const digits = String(phone).replace(/\D/g, '')
  const e164 = digits.startsWith('0') ? '20' + digits.slice(1) : digits.startsWith('20') ? digits : '20' + digits
  return `https://wa.me/${e164}`
}

function fmt(n) {
  if (n == null) return ''
  return Number(n).toLocaleString('ar-EG')
}

function daysAgo(ts) {
  if (!ts) return 9999
  const ms = typeof ts === 'string' ? new Date(ts).getTime() : ts
  return (Date.now() - ms) / 86400000
}

// Header row style
function styleHeader(ws, colCount) {
  const row = ws.getRow(1)
  row.eachCell({ includeEmpty: true }, (cell, c) => {
    if (c > colCount) return
    cell.fill   = { type: 'pattern', pattern: 'solid', fgColor: { argb: NAVY } }
    cell.font   = { color: { argb: WHITE }, bold: true, size: 11, name: 'Calibri' }
    cell.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true }
    cell.border = {
      bottom: { style: 'medium', color: { argb: 'FFFFFF' } }
    }
  })
  row.height = 28
}

// Colour a data row based on score
function colourRow(row, score, colCount) {
  const bg = score >= HOT_MIN ? HOT_BG : score >= WARM_MIN ? WARM_BG : null
  if (!bg) return
  row.eachCell({ includeEmpty: true }, (cell, c) => {
    if (c > colCount) return
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: bg } }
  })
}

// Make a cell a hyperlink
function addLink(cell, url, text) {
  if (!url) { cell.value = text || ''; return }
  cell.value = { text: text || url, hyperlink: url }
  cell.font  = { color: { argb: '0563C1' }, underline: true, size: 10 }
}

// Set column widths
function setCols(ws, defs) {
  defs.forEach((d, i) => {
    ws.getColumn(i + 1).width = d.width || 18
    ws.getColumn(i + 1).header = d.header
  })
}

// Freeze top row + auto-filter
function finishSheet(ws, colCount) {
  ws.views = [{ state: 'frozen', ySplit: 1 }]
  ws.autoFilter = { from: 'A1', to: `${String.fromCharCode(64 + colCount)}1` }
}

// ─── Data Layer ──────────────────────────────────────────────────────────────
function getData() {
  const db = new Database(DB_PATH, { readonly: true })

  // HOT + WARM demand (buyers) active in last DAYS_ACTIVE days
  // Join with matches to get their best score
  const buyers = db.prepare(`
    SELECT
      d.id,
      d.sender_name  AS name,
      d.sender_phone AS phone,
      d.location,
      d.budget_min,
      d.budget_max,
      d.property_type,
      d.bedrooms,
      d.notes,
      d.created_at,
      COALESCE(MAX(m.match_score), 0) AS score
    FROM demand d
    LEFT JOIN matches m ON m.demand_id = d.id
    GROUP BY d.id
    ORDER BY score DESC, d.created_at DESC
  `).all()

  // HOT + WARM supply (sellers) active in last DAYS_ACTIVE days
  const sellers = db.prepare(`
    SELECT
      s.id,
      s.sender_name  AS name,
      s.sender_phone AS phone,
      s.location,
      s.price,
      s.property_type,
      s.bedrooms,
      s.area,
      s.notes,
      s.urgent,
      s.created_at,
      COALESCE(MAX(m.match_score), 0) AS score
    FROM supply s
    LEFT JOIN matches m ON m.supply_id = s.id
    GROUP BY s.id
    ORDER BY score DESC, s.created_at DESC
  `).all()

  // Top matched pairs (full match detail)
  const pairs = db.prepare(`
    SELECT
      m.id           AS match_id,
      m.match_score  AS score,
      m.grade,
      m.supply_location,
      m.demand_location,
      m.supply_price,
      m.demand_budget_max,
      m.supply_phone,
      m.demand_phone,
      m.created_at,
      s.sender_name  AS seller_name,
      s.property_type,
      s.bedrooms,
      s.area         AS supply_area,
      d.sender_name  AS buyer_name,
      d.budget_min,
      d.budget_max
    FROM matches m
    LEFT JOIN supply s ON s.id = m.supply_id
    LEFT JOIN demand d ON d.id = m.demand_id
    ORDER BY m.match_score DESC
    LIMIT ${TOP_PAIRS}
  `).all()

  // New supply this week
  const newSupply = db.prepare(`
    SELECT
      id,
      sender_name  AS name,
      sender_phone AS phone,
      location,
      property_type,
      bedrooms,
      area,
      price,
      notes,
      urgent,
      created_at
    FROM supply
    WHERE created_at >= datetime('now', '-7 days')
    ORDER BY created_at DESC
  `).all()

  db.close()

  // Filter buyers/sellers: score >= WARM_MIN or created within DAYS_ACTIVE
  const hotBuyers  = buyers.filter(b => b.score >= WARM_MIN || daysAgo(b.created_at) <= DAYS_ACTIVE)
  const hotSellers = sellers.filter(s => s.score >= WARM_MIN || daysAgo(s.created_at) <= DAYS_ACTIVE)

  return { buyers: hotBuyers, sellers: hotSellers, pairs, newSupply }
}

// ─── Sheet 1: HOT Buyers ─────────────────────────────────────────────────────
function buildBuyersSheet(wb, buyers) {
  const ws = wb.addWorksheet('🔴 HOT Buyers', { properties: { tabColor: { argb: 'FFCCCC' } } })

  const cols = [
    { header: 'Name',            width: 22 },
    { header: 'Phone',           width: 18 },
    { header: 'WhatsApp Link',   width: 32 },
    { header: 'Area / Location', width: 20 },
    { header: 'Property Type',   width: 18 },
    { header: 'Bedrooms',        width: 12 },
    { header: 'Budget Min (EGP)',  width: 18 },
    { header: 'Budget Max (EGP)',  width: 18 },
    { header: 'SACRED Score',    width: 14 },
    { header: 'Grade',           width: 10 },
    { header: 'Notes',           width: 30 },
    { header: 'Last Active',     width: 20 },
  ]
  setCols(ws, cols)
  styleHeader(ws, cols.length)

  buyers.forEach((b, i) => {
    const row = ws.addRow([
      b.name        || '—',
      b.phone       || '—',
      '',                         // WA link — set below
      b.location    || '—',
      b.property_type || '—',
      b.bedrooms    || '—',
      b.budget_min  ? fmt(b.budget_min)  : '—',
      b.budget_max  ? fmt(b.budget_max)  : '—',
      b.score,
      b.score >= HOT_MIN ? '🔴 HOT' : b.score >= WARM_MIN ? '🟠 WARM' : '—',
      b.notes       || '—',
      b.created_at  ? new Date(b.created_at).toLocaleDateString('en-GB') : '—',
    ])
    addLink(row.getCell(3), waLink(b.phone), `wa.me/${String(b.phone).replace(/\D/,'').slice(-9)}`)
    colourRow(row, b.score, cols.length)
    row.height = 20
  })

  finishSheet(ws, cols.length)

  // Summary row
  const hotCount  = buyers.filter(b => b.score >= HOT_MIN).length
  const warmCount = buyers.filter(b => b.score >= WARM_MIN && b.score < HOT_MIN).length
  ws.addRow([])
  const sum = ws.addRow([`TOTAL: ${buyers.length} buyers | 🔴 HOT: ${hotCount} | 🟠 WARM: ${warmCount}`])
  sum.getCell(1).font = { bold: true, size: 11 }

  return { hotCount, warmCount, total: buyers.length }
}

// ─── Sheet 2: HOT Sellers ────────────────────────────────────────────────────
function buildSellersSheet(wb, sellers) {
  const ws = wb.addWorksheet('🟠 HOT Sellers', { properties: { tabColor: { argb: 'FFE5CC' } } })

  const cols = [
    { header: 'Name',            width: 22 },
    { header: 'Phone',           width: 18 },
    { header: 'WhatsApp Link',   width: 32 },
    { header: 'Area / Location', width: 20 },
    { header: 'Property Type',   width: 18 },
    { header: 'Bedrooms',        width: 12 },
    { header: 'Area (m²)',        width: 12 },
    { header: 'Asking Price (EGP)', width: 20 },
    { header: 'SACRED Score',    width: 14 },
    { header: 'Grade',           width: 10 },
    { header: 'Urgent',          width: 10 },
    { header: 'Notes',           width: 30 },
    { header: 'Date Listed',     width: 18 },
  ]
  setCols(ws, cols)
  styleHeader(ws, cols.length)

  sellers.forEach((s) => {
    const row = ws.addRow([
      s.name         || '—',
      s.phone        || '—',
      '',
      s.location     || '—',
      s.property_type || '—',
      s.bedrooms     || '—',
      s.area         || '—',
      s.price        ? fmt(s.price) : '—',
      s.score,
      s.score >= HOT_MIN ? '🔴 HOT' : s.score >= WARM_MIN ? '🟠 WARM' : '—',
      s.urgent       ? '⚡ YES' : 'No',
      s.notes        || '—',
      s.created_at   ? new Date(s.created_at).toLocaleDateString('en-GB') : '—',
    ])
    addLink(row.getCell(3), waLink(s.phone), `wa.me/${String(s.phone).replace(/\D/,'').slice(-9)}`)
    colourRow(row, s.score, cols.length)
    row.height = 20
  })

  finishSheet(ws, cols.length)

  const hotCount  = sellers.filter(s => s.score >= HOT_MIN).length
  const warmCount = sellers.filter(s => s.score >= WARM_MIN && s.score < HOT_MIN).length
  ws.addRow([])
  const sum = ws.addRow([`TOTAL: ${sellers.length} sellers | 🔴 HOT: ${hotCount} | 🟠 WARM: ${warmCount}`])
  sum.getCell(1).font = { bold: true, size: 11 }

  return { hotCount, warmCount, total: sellers.length }
}

// ─── Sheet 3: Best Matched Pairs ─────────────────────────────────────────────
function buildPairsSheet(wb, pairs) {
  const ws = wb.addWorksheet('🤝 Matched Pairs', { properties: { tabColor: { argb: 'CCE5FF' } } })

  const cols = [
    { header: '#',                width: 5  },
    { header: 'Buyer Name',       width: 22 },
    { header: 'Buyer Phone',      width: 18 },
    { header: 'Buyer WA Link',    width: 32 },
    { header: 'Seller Name',      width: 22 },
    { header: 'Seller Phone',     width: 18 },
    { header: 'Seller WA Link',   width: 32 },
    { header: 'Match Score',      width: 14 },
    { header: 'Grade',            width: 10 },
    { header: 'Location',         width: 20 },
    { header: 'Property Type',    width: 18 },
    { header: 'Asking Price (EGP)', width: 20 },
    { header: 'Budget Max (EGP)', width: 20 },
    { header: 'Deal Value (EGP)', width: 20 },
  ]
  setCols(ws, cols)
  styleHeader(ws, cols.length)

  pairs.forEach((p, i) => {
    const dealVal = p.supply_price || p.demand_budget_max || null
    const row = ws.addRow([
      i + 1,
      p.buyer_name   || '—',
      p.demand_phone || '—',
      '',
      p.seller_name  || '—',
      p.supply_phone || '—',
      '',
      p.score,
      p.score >= HOT_MIN ? '🔴 HOT' : p.score >= WARM_MIN ? '🟠 WARM' : '—',
      p.supply_location || p.demand_location || '—',
      p.property_type   || '—',
      p.supply_price    ? fmt(p.supply_price)    : '—',
      p.demand_budget_max ? fmt(p.demand_budget_max) : '—',
      dealVal           ? fmt(dealVal) : '—',
    ])
    addLink(row.getCell(4), waLink(p.demand_phone), 'WhatsApp Buyer')
    addLink(row.getCell(7), waLink(p.supply_phone), 'WhatsApp Seller')
    colourRow(row, p.score, cols.length)
    row.height = 22
  })

  finishSheet(ws, cols.length)

  ws.addRow([])
  const note = ws.addRow([
    `Top ${Math.min(pairs.length, TOP_PAIRS)} matches by SACRED score. Call BOTH contacts on the same row. First come first close.`
  ])
  note.getCell(1).font = { italic: true, size: 10 }

  return { total: pairs.length }
}

// ─── Sheet 4: New Supply This Week ───────────────────────────────────────────
function buildNewSupplySheet(wb, newSupply) {
  const ws = wb.addWorksheet('🆕 New This Week', { properties: { tabColor: { argb: 'CCFFCC' } } })

  const cols = [
    { header: 'Seller Name',       width: 22 },
    { header: 'Phone',             width: 18 },
    { header: 'WhatsApp Link',     width: 32 },
    { header: 'Location',          width: 20 },
    { header: 'Property Type',     width: 18 },
    { header: 'Bedrooms',          width: 12 },
    { header: 'Area (m²)',          width: 12 },
    { header: 'Asking Price (EGP)', width: 20 },
    { header: 'Urgent',            width: 10 },
    { header: 'Notes',             width: 35 },
    { header: 'Date Added',        width: 18 },
  ]
  setCols(ws, cols)
  styleHeader(ws, cols.length)

  if (newSupply.length === 0) {
    const row = ws.addRow(['No new listings added in the past 7 days.'])
    row.getCell(1).font = { italic: true, color: { argb: '888888' } }
  } else {
    newSupply.forEach((s) => {
      const row = ws.addRow([
        s.name         || '—',
        s.phone        || '—',
        '',
        s.location     || '—',
        s.property_type || '—',
        s.bedrooms     || '—',
        s.area         || '—',
        s.price        ? fmt(s.price) : '—',
        s.urgent       ? '⚡ YES' : 'No',
        s.notes        || '—',
        s.created_at   ? new Date(s.created_at).toLocaleDateString('en-GB') : '—',
      ])
      addLink(row.getCell(3), waLink(s.phone), `wa.me/${String(s.phone||'').replace(/\D/,'').slice(-9)}`)
      // Green tint for new listings
      row.eachCell({ includeEmpty: true }, (cell, c) => {
        if (c > cols.length) return
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'F0FFF0' } }
      })
      row.height = 20
    })
  }

  finishSheet(ws, cols.length)

  ws.addRow([])
  const sum = ws.addRow([`${newSupply.length} new listings added in the past 7 days`])
  sum.getCell(1).font = { bold: true, size: 11 }

  return { total: newSupply.length }
}

// ─── Cover / Info sheet ───────────────────────────────────────────────────────
function buildCoverSheet(wb, stats, dateStr) {
  const ws = wb.addWorksheet('📊 Summary', { properties: { tabColor: { argb: NAVY } } })
  wb.views = [{ activeTab: 0 }]  // make cover the default tab

  const addLine = (label, value, bold = false) => {
    const row = ws.addRow([label, value])
    row.getCell(1).font = { bold: true, size: 11, name: 'Calibri' }
    row.getCell(2).font = { bold, size: 11, color: { argb: bold ? HOT_FG : '000000' } }
    row.height = 22
    return row
  }

  ws.getColumn(1).width = 35
  ws.getColumn(2).width = 35

  // Title block
  const titleRow = ws.addRow(['MatchPro™ Weekly Broker Intelligence'])
  titleRow.getCell(1).font = { bold: true, size: 16, color: { argb: NAVY }, name: 'Calibri' }
  titleRow.height = 32
  ws.mergeCells('A1:B1')
  titleRow.getCell(1).alignment = { horizontal: 'center' }

  const subRow = ws.addRow(['Replacing 10 hours of manual WhatsApp screening'])
  subRow.getCell(1).font = { italic: true, size: 11, color: { argb: '555555' } }
  ws.mergeCells('A2:B2')
  subRow.getCell(1).alignment = { horizontal: 'center' }

  ws.addRow([])

  addLine('Report Date:', dateStr)
  addLine('Report Period:', 'Last 7 days')
  addLine('Data Source:', '24,000+ real WhatsApp conversations')
  ws.addRow([])

  addLine('🔴 HOT Buyers:', `${stats.hotBuyers} active buyers (score ≥ ${HOT_MIN})`, true)
  addLine('🟠 WARM Buyers:', `${stats.warmBuyers} active buyers (score ≥ ${WARM_MIN})`)
  addLine('🔴 HOT Sellers:', `${stats.hotSellers} active sellers (score ≥ ${HOT_MIN})`, true)
  addLine('🟠 WARM Sellers:', `${stats.warmSellers} active sellers (score ≥ ${WARM_MIN})`)
  addLine('🤝 Best Matched Pairs:', `${stats.totalPairs} shown (top ${TOP_PAIRS} by score)`)
  addLine('🆕 New Listings This Week:', `${stats.newListings}`)
  ws.addRow([])

  addLine('Contact:', 'Mo\'men Maisara | Crystal Power Investments')
  addLine('Email:', 'mmaisara@crystalpowerinvestment.com')
  addLine('WhatsApp:', '+20 106 650 5665')
  ws.addRow([])

  const disclaimer = ws.addRow(['Based on 24,153 real WhatsApp conversations from active buyers and sellers in Greater Cairo. Not a survey. Not extrapolation.'])
  disclaimer.getCell(1).font = { italic: true, size: 9, color: { argb: '888888' } }
  ws.mergeCells(`A${disclaimer.number}:B${disclaimer.number}`)

  const pricing = ws.addRow(['Full API access from 5,000 EGP/month. Contact: mmaisara@crystalpowerinvestment.com'])
  pricing.getCell(1).font = { italic: true, size: 9, color: { argb: '888888' } }
  ws.mergeCells(`A${pricing.number}:B${pricing.number}`)
}

// ─── Generate Excel ───────────────────────────────────────────────────────────
async function generateReport() {
  const now     = new Date()
  const dateStr = now.toISOString().slice(0, 10)
  const fileName = `Broker_Report_${dateStr}.xlsx`
  const filePath = path.join(REPORTS_DIR, fileName)

  fs.mkdirSync(REPORTS_DIR, { recursive: true })

  console.log(`[BrokerReport] 📊 Generating ${fileName}...`)

  // Pull data
  const { buyers, sellers, pairs, newSupply } = getData()
  console.log(`[BrokerReport] Data: buyers=${buyers.length} sellers=${sellers.length} pairs=${pairs.length} newSupply=${newSupply.length}`)

  const wb = new ExcelJS.Workbook()
  wb.creator  = 'MatchPro™ — Crystal Power Investments'
  wb.lastModifiedBy = 'MatchPro™ Engine'
  wb.created  = now
  wb.modified = now
  wb.properties.date1904 = false

  // Build sheets (cover first so it's the default tab)
  const hotBuyers   = buyers.filter(b => b.score >= HOT_MIN).length
  const warmBuyers  = buyers.filter(b => b.score >= WARM_MIN && b.score < HOT_MIN).length
  const hotSellers  = sellers.filter(s => s.score >= HOT_MIN).length
  const warmSellers = sellers.filter(s => s.score >= WARM_MIN && s.score < HOT_MIN).length

  const stats = {
    hotBuyers, warmBuyers,
    hotSellers, warmSellers,
    totalPairs: pairs.length,
    newListings: newSupply.length,
  }

  buildCoverSheet(wb, stats, dateStr)
  buildBuyersSheet(wb, buyers)
  buildSellersSheet(wb, sellers)
  buildPairsSheet(wb, pairs)
  buildNewSupplySheet(wb, newSupply)

  await wb.xlsx.writeFile(filePath)
  console.log(`[BrokerReport] ✅ Excel written: ${filePath}`)

  return { filePath, fileName, dateStr, stats, buyers, sellers, pairs, newSupply }
}

// ─── Send Email ───────────────────────────────────────────────────────────────
async function sendEmail(filePath, fileName, dateStr, stats) {
  const hotTotal = stats.hotBuyers + stats.hotSellers

  const subject = `MatchPro™ Weekly Report — ${dateStr} | ${hotTotal} HOT matches`
  const html = `
<div style="font-family:Calibri,Arial,sans-serif; max-width:600px; margin:0 auto">
  <div style="background:#0A1628; color:#fff; padding:24px; border-radius:8px 8px 0 0">
    <h1 style="margin:0; font-size:22px">MatchPro™ Weekly Broker Intelligence</h1>
    <p style="margin:8px 0 0; opacity:0.7; font-size:13px">Replacing 10 hours of manual WhatsApp screening</p>
  </div>
  <div style="background:#f9f9f9; padding:24px; border:1px solid #ddd">
    <p style="margin:0 0 16px">Hi,</p>
    <p>Attached is this week's MatchPro™ report for <strong>${dateStr}</strong>.</p>
    <table style="border-collapse:collapse; width:100%; margin:16px 0">
      <tr style="background:#FFCCCC">
        <td style="padding:10px; font-weight:bold">🔴 HOT Buyers</td>
        <td style="padding:10px; font-weight:bold; font-size:20px">${stats.hotBuyers}</td>
      </tr>
      <tr style="background:#FFE5CC">
        <td style="padding:10px">🟠 WARM Buyers</td>
        <td style="padding:10px; font-size:18px">${stats.warmBuyers}</td>
      </tr>
      <tr style="background:#FFCCCC">
        <td style="padding:10px; font-weight:bold">🔴 HOT Sellers</td>
        <td style="padding:10px; font-weight:bold; font-size:20px">${stats.hotSellers}</td>
      </tr>
      <tr style="background:#FFE5CC">
        <td style="padding:10px">🟠 WARM Sellers</td>
        <td style="padding:10px; font-size:18px">${stats.warmSellers}</td>
      </tr>
      <tr style="background:#eef">
        <td style="padding:10px">🤝 Matched Pairs</td>
        <td style="padding:10px">${stats.totalPairs}</td>
      </tr>
      <tr style="background:#efe">
        <td style="padding:10px">🆕 New Listings This Week</td>
        <td style="padding:10px">${stats.newListings}</td>
      </tr>
    </table>
    <p><strong>First come, first close.</strong></p>
    <p>The Excel file has 4 sheets: HOT Buyers · HOT Sellers · Best Matched Pairs · New Supply This Week</p>
    <p>All phone numbers are clickable WhatsApp links.</p>
  </div>
  <div style="background:#0A1628; color:#aaa; padding:16px; font-size:11px; border-radius:0 0 8px 8px">
    Crystal Power Investments | mmaisara@crystalpowerinvestment.com | +20 106 650 5665<br>
    Based on 24,153 real WhatsApp conversations · Not a survey · Not extrapolation
  </div>
</div>
  `.trim()

  const text = `MatchPro™ Weekly Report — ${dateStr}

HOT Buyers: ${stats.hotBuyers}  |  WARM Buyers: ${stats.warmBuyers}
HOT Sellers: ${stats.hotSellers}  |  WARM Sellers: ${stats.warmSellers}
Matched Pairs: ${stats.totalPairs}  |  New Listings: ${stats.newListings}

Attached Excel has 4 sheets with full contact details and WhatsApp links.
First come, first close.

Crystal Power Investments | mmaisara@crystalpowerinvestment.com | +20 106 650 5665`

  // Build extra broker emails from settings
  let extraTo = []
  try {
    const db  = new Database(DB_PATH, { readonly: true })
    const row = db.prepare("SELECT value FROM settings WHERE key='broker_emails'").get()
    if (row && row.value) extraTo = row.value.split(',').map(e => e.trim()).filter(Boolean)
    db.close()
  } catch { /* ignore */ }

  const allTo = [EMAIL_TO, ...extraTo].join(', ')

  // If no SMTP configured → log and return (graceful degradation)
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    console.log('[BrokerReport] ⚠️  No SMTP config — email would send to:', allTo)
    console.log('[BrokerReport]    Subject:', subject)
    console.log('[BrokerReport]    Attachment:', fileName)
    console.log('[BrokerReport]    To enable email: set SMTP_HOST, SMTP_USER, SMTP_PASS in .env')
    return { sent: false, reason: 'no_smtp_config', wouldSendTo: allTo }
  }

  const transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  })

  try {
    await transporter.verify()
    const info = await transporter.sendMail({
      from: `"MatchPro™ Intelligence" <${EMAIL_FROM}>`,
      to:   allTo,
      subject,
      text,
      html,
      attachments: [{ filename: fileName, path: filePath }],
    })
    console.log(`[BrokerReport] ✅ Email sent → ${allTo} | msgId: ${info.messageId}`)
    return { sent: true, to: allTo, messageId: info.messageId }
  } catch (err) {
    console.error('[BrokerReport] ❌ Email failed:', err.message)
    return { sent: false, error: err.message }
  }
}

// ─── Main Entry ───────────────────────────────────────────────────────────────
async function run() {
  try {
    const { filePath, fileName, dateStr, stats, buyers } = await generateReport()
    const emailResult = await sendEmail(filePath, fileName, dateStr, stats)

    // Print 3 sample HOT buyers for verification
    const hotSample = buyers.filter(b => b.score >= HOT_MIN).slice(0, 3)
    if (hotSample.length > 0) {
      console.log('\n[BrokerReport] 📋 Sample HOT Buyers:')
      hotSample.forEach((b, i) => {
        console.log(`  ${i+1}. ${b.name || '—'} | ${b.phone || '—'} | ${b.location || '—'} | Budget: ${b.budget_max ? fmt(b.budget_max) + ' EGP' : '—'} | Score: ${b.score}`)
      })
    }

    return { ok: true, filePath, fileName, dateStr, stats, emailResult }
  } catch (err) {
    console.error('[BrokerReport] ❌ FATAL:', err.message, err.stack)
    return { ok: false, error: err.message }
  }
}

// Run directly if called as script
if (require.main === module) {
  run().then(r => {
    if (r.ok) {
      console.log('\n[BrokerReport] ✅ Complete')
      console.log('  File:', r.filePath)
      console.log('  Stats:', JSON.stringify(r.stats))
      console.log('  Email:', JSON.stringify(r.emailResult))
    } else {
      console.error('\n[BrokerReport] ❌ Failed:', r.error)
      process.exit(1)
    }
  })
}

module.exports = { run, generateReport, sendEmail }
