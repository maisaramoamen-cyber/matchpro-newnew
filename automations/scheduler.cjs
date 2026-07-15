'use strict'
/**
 * MatchPro™ Scheduler — Crystal Power Investments
 * ================================================
 * Manages all timed automations for the MatchPro platform.
 *
 * Schedules:
 *   • Sunday 9:00 AM Africa/Cairo  → Weekly Broker Excel Report (email + file)
 *   • Every 6 hours                → SACRED matching engine run (handled by PM2 in production)
 *   • 1st of month, 8:00 AM Cairo  → Monthly investor summary + market intelligence trigger
 *
 * Usage:
 *   node automations/scheduler.cjs          # Run scheduler daemon
 *   node automations/scheduler.cjs --test   # Fire all jobs immediately (dry-run)
 *
 * PM2 process name: matchpro-scheduler
 */

const cron = require('node-cron')
const path  = require('path')

// ─── Helpers ────────────────────────────────────────────────────────────────
function log(msg) {
  const ts = new Date().toISOString()
  console.log(`[Scheduler][${ts}] ${msg}`)
}

function err(msg, e) {
  const ts = new Date().toISOString()
  console.error(`[Scheduler][${ts}] ❌ ${msg}`, e ? e.message : '')
}

// ─── Job: Weekly Broker Excel Report ────────────────────────────────────────
//
//   Cron:     0 9 * * 0   (minute=0, hour=9, any day-of-month, any month, weekday=Sunday)
//   Timezone: Africa/Cairo
//   Output:   reports/broker_weekly/Broker_Report_YYYY-MM-DD.xlsx
//   Email:    mmaisara@crystalpowerinvestment.com + broker_emails from settings
//
async function runBrokerWeeklyReport() {
  log('🗓  BROKER WEEKLY REPORT — Starting...')
  try {
    const { run } = require('./broker_weekly_report.cjs')
    const result = await run()
    if (result.ok) {
      log(`✅ Broker report done → ${result.filePath}`)
      log(`   Stats: HOT buyers=${result.stats.hotBuyers} | HOT sellers=${result.stats.hotSellers} | Pairs=${result.stats.totalPairs} | New=${result.stats.newListings}`)
      log(`   Email: ${JSON.stringify(result.emailResult)}`)
    } else {
      err('Broker report returned ok=false', { message: result.error })
    }
  } catch (e) {
    err('Broker report crashed', e)
  }
}

// ─── Job: Monthly Investor Summary (placeholder — implemented in Phase C2) ──
async function runMonthlyInvestorSummary() {
  log('📅 MONTHLY INVESTOR SUMMARY — placeholder (implement Phase C2)')
  // TODO: call /api/reports/investor-monthly when built
}

// ─── Schedule Registration ───────────────────────────────────────────────────

/**
 * SUNDAY 9:00 AM CAIRO — Weekly Broker Excel Report
 *
 * Cron expression: '0 9 * * 0'
 *   ┌──── minute (0)
 *   │ ┌── hour (9)
 *   │ │ ┌ day of month (*)
 *   │ │ │ ┌ month (*)
 *   │ │ │ │ ┌ day of week (0 = Sunday)
 *   0 9 * * 0
 */
const brokerWeeklyJob = cron.schedule('0 9 * * 0', () => {
  log('⏰ Cron fired: Sunday 9:00 AM Cairo → Broker Weekly Report')
  runBrokerWeeklyReport()
}, {
  timezone: 'Africa/Cairo',
  scheduled: true   // starts immediately when scheduler boots
})

/**
 * 1ST OF MONTH, 8:00 AM CAIRO — Monthly Investor Summary
 *
 * Cron expression: '0 8 1 * *'
 */
const monthlyInvestorJob = cron.schedule('0 8 1 * *', () => {
  log('⏰ Cron fired: 1st of month 8:00 AM Cairo → Monthly Investor Summary')
  runMonthlyInvestorSummary()
}, {
  timezone: 'Africa/Cairo',
  scheduled: true
})

// ─── --test flag: fire all jobs immediately ──────────────────────────────────
if (process.argv.includes('--test')) {
  log('🧪 --test flag detected — firing all jobs immediately')
  runBrokerWeeklyReport().then(() => {
    log('🧪 Test run complete. Exiting.')
    process.exit(0)
  }).catch(e => {
    err('Test run failed', e)
    process.exit(1)
  })
} else {
  log('✅ MatchPro™ Scheduler active')
  log('   📅 Broker Weekly Report  → Every Sunday at 09:00 Africa/Cairo  [cron: 0 9 * * 0]')
  log('   📅 Monthly Investor Summary → 1st of month 08:00 Africa/Cairo [cron: 0 8 1 * *]')
  log('   Waiting for next trigger...')
}

// ─── Graceful shutdown ───────────────────────────────────────────────────────
process.on('SIGTERM', () => {
  log('SIGTERM received — stopping scheduler')
  brokerWeeklyJob.stop()
  monthlyInvestorJob.stop()
  process.exit(0)
})

process.on('SIGINT', () => {
  log('SIGINT received — stopping scheduler')
  brokerWeeklyJob.stop()
  monthlyInvestorJob.stop()
  process.exit(0)
})
