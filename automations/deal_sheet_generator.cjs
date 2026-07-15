'use strict'
/**
 * MatchPro™ Deal Sheet PDF Generator — Crystal Power Investments
 * =============================================================
 * Generates a branded A4 PDF deal sheet for any asset or supply listing.
 *
 * Sources (resolved in order):
 *   1. assets table   → CPI portfolio projects (a1, a2, ...)
 *   2. supply table   → WhatsApp-sourced listings (s1, s2, ...)
 *
 * Output: reports/deal_sheets/DealSheet_<id>_<date>.pdf
 *
 * Usage:
 *   const { generate } = require('./deal_sheet_generator.cjs')
 *   const result = await generate('a1')
 *   // result: { ok, filePath, fileName, asset, timestamp }
 *
 * Direct test:
 *   node automations/deal_sheet_generator.cjs a1
 *   node automations/deal_sheet_generator.cjs s1
 */

const puppeteer  = require('puppeteer-core')
const Database   = require('better-sqlite3')
const path       = require('path')
const fs         = require('fs')

// ─── Config ──────────────────────────────────────────────────────────────────
const DB_PATH      = path.join(__dirname, '../data/matchpro.db')
const OUT_DIR      = path.join(__dirname, '../reports/deal_sheets')
const CHROME_PATH  = process.env.CHROME_PATH || '/usr/bin/google-chrome'

// Brand palette
const NAVY   = '#0A1628'
const GOLD   = '#C9A84C'
const LIGHT  = '#F5F7FA'
const WHITE  = '#FFFFFF'
const GREEN  = '#1A7F4B'
const RED    = '#C0392B'

// ─── Helpers ─────────────────────────────────────────────────────────────────
function log(msg)  { console.log(`[DealSheet] ${msg}`) }
function fmtPrice(n) {
  if (!n) return 'N/A'
  const num = Number(n)
  if (num >= 1_000_000) return (num / 1_000_000).toFixed(2).replace(/\.?0+$/, '') + ' M EGP'
  if (num >= 1_000)     return (num / 1_000).toFixed(0) + ' K EGP'
  return num.toLocaleString() + ' EGP'
}
function fmtDate(d) {
  try { return new Date(d).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }) }
  catch { return d || 'N/A' }
}
function fmtROI(r) { return r ? `${Number(r).toFixed(1)}%` : 'N/A' }
function badge(status) {
  const map = {
    active:            { bg: '#E8F8F0', color: GREEN,  label: 'Active' },
    under_construction:{ bg: '#FFF3CD', color: '#856404', label: 'Under Construction' },
    sold:              { bg: '#F8D7DA', color: RED,    label: 'Sold' },
    sale:              { bg: '#E8F8F0', color: GREEN,  label: 'For Sale' },
    rent:              { bg: '#E3F2FD', color: '#1565C0', label: 'For Rent' },
  }
  const s = map[status] || { bg: '#EEE', color: '#555', label: status || 'Unknown' }
  return `<span style="background:${s.bg};color:${s.color};padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600;">${s.label}</span>`
}

// ─── Data resolver ────────────────────────────────────────────────────────────
function resolveAsset(assetId) {
  const db = new Database(DB_PATH, { readonly: true })

  // Try assets table first
  let row = db.prepare('SELECT * FROM assets WHERE id = ?').get(assetId)
  if (row) {
    db.close()
    return {
      source:       'assets',
      id:           row.id,
      title:        row.name,
      type:         row.asset_type  || 'N/A',
      location:     row.location    || 'N/A',
      price:        row.value,
      roi:          row.roi,
      status:       row.status      || 'active',
      bedrooms:     null,
      area:         null,
      finishing:    null,
      purpose:      null,
      notes:        row.notes,
      seller_name:  'Crystal Power Investments',
      seller_phone: null,
      created_at:   row.created_at,
      is_urgent:    false,
    }
  }

  // Try supply table
  row = db.prepare('SELECT * FROM supply WHERE id = ?').get(assetId)
  db.close()
  if (row) {
    return {
      source:       'supply',
      id:           row.id,
      title:        `${row.property_type || 'Property'} — ${row.location || 'N/A'}`,
      type:         row.property_type || 'N/A',
      location:     row.location    || 'N/A',
      price:        row.price,
      roi:          null,
      status:       row.purpose     || 'sale',
      bedrooms:     row.bedrooms,
      area:         row.area,
      finishing:    row.finishing,
      purpose:      row.purpose,
      notes:        row.notes       || row.raw_message,
      seller_name:  row.sender_name || 'N/A',
      seller_phone: row.sender_phone,
      created_at:   row.created_at,
      is_urgent:    !!row.urgent,
    }
  }

  return null
}

// ─── HTML template ────────────────────────────────────────────────────────────
function buildHTML(asset, dateStr) {
  const specs = [
    asset.type      && ['Property Type', asset.type.replace(/_/g,' ').replace(/\b\w/g,c=>c.toUpperCase())],
    asset.location  && ['Location', asset.location],
    asset.bedrooms  && ['Bedrooms', asset.bedrooms],
    asset.area      && ['Area', `${asset.area} m²`],
    asset.finishing && ['Finishing', asset.finishing],
    asset.roi       && ['Expected ROI', fmtROI(asset.roi)],
    asset.purpose   && ['Purpose', asset.purpose.toUpperCase()],
  ].filter(Boolean)

  const specsRows = specs.map(([k, v]) => `
    <tr>
      <td style="padding:9px 14px;color:#555;font-size:12px;border-bottom:1px solid #EEE;width:40%;">${k}</td>
      <td style="padding:9px 14px;font-weight:600;font-size:12px;border-bottom:1px solid #EEE;">${v}</td>
    </tr>`).join('')

  const sellerSection = asset.seller_phone ? `
    <div style="margin-top:6px;font-size:12px;color:#555;">
      Contact: <strong>${asset.seller_name}</strong> &nbsp;|&nbsp;
      <a href="https://wa.me/${asset.seller_phone.replace(/\D/g,'').replace(/^0/,'20')}"
         style="color:${GREEN};text-decoration:none;font-weight:600;">
        💬 WhatsApp: ${asset.seller_phone}
      </a>
    </div>` : `<div style="margin-top:6px;font-size:12px;color:#555;">Contact: <strong>${asset.seller_name}</strong></div>`

  const urgentBanner = asset.is_urgent ? `
    <div style="background:#FFF3CD;border-left:4px solid #F39C12;padding:10px 16px;margin-bottom:16px;border-radius:4px;font-size:12px;color:#856404;">
      ⚡ <strong>URGENT LISTING</strong> — Seller is highly motivated. Respond within 24 hours.
    </div>` : ''

  const notesSection = asset.notes ? `
    <div style="margin-top:24px;">
      <h3 style="color:${NAVY};font-size:13px;margin:0 0 8px;border-bottom:2px solid ${GOLD};padding-bottom:4px;">Notes / Description</h3>
      <p style="font-size:12px;color:#444;line-height:1.7;margin:0;">${asset.notes}</p>
    </div>` : ''

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>Deal Sheet — ${asset.title}</title>
<style>
  * { margin:0;padding:0;box-sizing:border-box; }
  body { font-family:'Segoe UI',Arial,sans-serif; background:#F0F2F5; color:#222; }
  @page { size:A4; margin:0; }
  .page { width:210mm; min-height:297mm; background:${WHITE}; margin:0 auto; display:flex; flex-direction:column; }
  .header { background:${NAVY}; padding:28px 36px 22px; }
  .header-top { display:flex; justify-content:space-between; align-items:flex-start; }
  .brand { color:${GOLD}; font-size:22px; font-weight:800; letter-spacing:1px; }
  .brand-sub { color:#8899BB; font-size:10px; margin-top:2px; letter-spacing:2px; text-transform:uppercase; }
  .doc-label { text-align:right; }
  .doc-label .title { color:${WHITE}; font-size:13px; font-weight:700; letter-spacing:1px; text-transform:uppercase; }
  .doc-label .ref   { color:#8899BB; font-size:10px; margin-top:3px; }
  .divider { height:2px; background:linear-gradient(90deg,${GOLD},transparent); margin:18px 0 0; }
  .body { padding:28px 36px; flex:1; }
  .asset-title { font-size:20px; font-weight:800; color:${NAVY}; margin-bottom:6px; }
  .meta-row { display:flex; align-items:center; gap:12px; margin-bottom:20px; flex-wrap:wrap; }
  .price-block { background:${NAVY}; color:${WHITE}; padding:12px 20px; border-radius:8px; margin-bottom:20px; display:flex; align-items:center; gap:20px; }
  .price-label { font-size:10px; color:#8899BB; text-transform:uppercase; letter-spacing:1px; }
  .price-value { font-size:24px; font-weight:800; color:${GOLD}; }
  .roi-value  { font-size:16px; font-weight:700; color:#4CD97B; }
  .section-title { font-size:13px; font-weight:700; color:${NAVY}; border-bottom:2px solid ${GOLD}; padding-bottom:4px; margin-bottom:12px; }
  .specs-table { width:100%; border-collapse:collapse; border-radius:8px; overflow:hidden; border:1px solid #EEE; }
  .footer { background:${NAVY}; padding:16px 36px; display:flex; justify-content:space-between; align-items:center; }
  .footer-brand { color:${GOLD}; font-size:11px; font-weight:700; }
  .footer-date  { color:#8899BB; font-size:10px; }
  .footer-conf  { color:#8899BB; font-size:9px; text-align:right; }
  .watermark { position:fixed; bottom:90px; right:30px; color:#EEE; font-size:48px; font-weight:900; opacity:0.08; transform:rotate(-30deg); pointer-events:none; }
</style>
</head>
<body>
<div class="page">
  <!-- HEADER -->
  <div class="header">
    <div class="header-top">
      <div>
        <div class="brand">Crystal Power <span style="color:${WHITE};">Investments</span></div>
        <div class="brand-sub">MatchPro™ Real Estate Intelligence</div>
      </div>
      <div class="doc-label">
        <div class="title">Deal Sheet</div>
        <div class="ref">Ref: ${asset.id.toUpperCase()} &nbsp;|&nbsp; ${dateStr}</div>
      </div>
    </div>
    <div class="divider"></div>
  </div>

  <!-- BODY -->
  <div class="body">
    ${urgentBanner}

    <div class="asset-title">${asset.title}</div>
    <div class="meta-row">
      ${badge(asset.status)}
      <span style="font-size:11px;color:#888;">📍 ${asset.location}</span>
      <span style="font-size:11px;color:#888;">🗓 Listed: ${fmtDate(asset.created_at)}</span>
    </div>

    <!-- Price Block -->
    <div class="price-block">
      <div>
        <div class="price-label">Asking Price</div>
        <div class="price-value">${fmtPrice(asset.price)}</div>
      </div>
      ${asset.roi ? `
      <div style="border-left:1px solid #1D3158;padding-left:20px;">
        <div class="price-label">Expected ROI</div>
        <div class="roi-value">📈 ${fmtROI(asset.roi)} / yr</div>
      </div>` : ''}
      <div style="border-left:1px solid #1D3158;padding-left:20px;margin-left:auto;">
        <div class="price-label">Source</div>
        <div style="color:#AAC;font-size:12px;font-weight:600;">${asset.source === 'assets' ? 'CPI Portfolio' : 'Market Listing'}</div>
      </div>
    </div>

    <!-- Property Specs -->
    ${specsRows ? `
    <div style="margin-bottom:24px;">
      <div class="section-title">Property Specifications</div>
      <table class="specs-table">
        <tbody>${specsRows}</tbody>
      </table>
    </div>` : ''}

    <!-- Notes -->
    ${notesSection}

    <!-- Seller Contact -->
    <div style="margin-top:24px;background:${LIGHT};border-radius:8px;padding:14px 16px;border-left:4px solid ${GOLD};">
      <div class="section-title" style="border:none;margin-bottom:4px;">Seller / Contact</div>
      ${sellerSection}
    </div>

    <!-- CPI Disclaimer -->
    <div style="margin-top:28px;padding:12px 16px;background:#FFFBF0;border:1px solid #F0DFA0;border-radius:6px;">
      <p style="font-size:10px;color:#888;line-height:1.6;">
        <strong style="color:${NAVY};">Crystal Power Investments</strong> — This deal sheet is generated by MatchPro™ SACRED Scoring Engine
        and is intended for authorized broker and investor use only. All figures are indicative and subject to
        due diligence. CPI operates on a no-commission model. <em>"We only win when you do."</em>
      </p>
    </div>
  </div>

  <!-- WATERMARK -->
  <div class="watermark">CPI</div>

  <!-- FOOTER -->
  <div class="footer">
    <div class="footer-brand">MatchPro™ by Crystal Power Investments</div>
    <div class="footer-date">Generated: ${dateStr}</div>
    <div class="footer-conf">CONFIDENTIAL — Authorized Use Only</div>
  </div>
</div>
</body>
</html>`
}

// ─── PDF Generator ────────────────────────────────────────────────────────────
async function generate(assetId) {
  if (!assetId) throw new Error('assetId is required')

  log(`📄 Generating deal sheet for: ${assetId}`)

  // Resolve asset data
  const asset = resolveAsset(assetId)
  if (!asset) {
    return { ok: false, error: `Asset not found: ${assetId}` }
  }
  log(`   Found: "${asset.title}" [${asset.source}]`)

  // Ensure output directory
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true })

  const dateStr  = new Date().toISOString().slice(0, 10)
  const fileName = `DealSheet_${assetId}_${dateStr}.pdf`
  const filePath = path.join(OUT_DIR, fileName)

  // Build HTML
  const html = buildHTML(asset, dateStr)

  // Launch Chrome and print to PDF
  log(`   Launching Chrome headless...`)
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-extensions',
    ]
  })

  try {
    const page = await browser.newPage()
    await page.setContent(html, { waitUntil: 'networkidle0' })
    await page.pdf({
      path:   filePath,
      format: 'A4',
      printBackground: true,
      margin: { top: '0', right: '0', bottom: '0', left: '0' }
    })
    log(`   ✅ PDF written: ${filePath}`)
  } finally {
    await browser.close()
  }

  const stat = fs.statSync(filePath)
  log(`   Size: ${(stat.size / 1024).toFixed(1)} KB`)

  return {
    ok:        true,
    filePath,
    fileName,
    dateStr,
    asset: {
      id:       asset.id,
      title:    asset.title,
      location: asset.location,
      price:    asset.price,
      status:   asset.status,
      source:   asset.source,
    },
    sizeKB:    Math.round(stat.size / 1024),
    timestamp: new Date().toISOString(),
  }
}

module.exports = { generate }

// ─── CLI test ─────────────────────────────────────────────────────────────────
if (require.main === module) {
  const id = process.argv[2] || 'a1'
  log(`🧪 CLI test — generating deal sheet for asset: ${id}`)
  generate(id).then(r => {
    if (r.ok) {
      log(`✅ Done: ${r.filePath} (${r.sizeKB} KB)`)
      log(`   Asset: ${r.asset.title} | ${r.asset.location} | ${fmtPrice(r.asset.price)}`)
    } else {
      log(`❌ Failed: ${r.error}`)
      process.exit(1)
    }
  }).catch(e => {
    log(`❌ Crash: ${e.message}`)
    process.exit(1)
  })
}
