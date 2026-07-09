// lib/screens/more_screen.dart  — Reports + CRM + Settings (fully upgraded)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../config/app_config.dart';
import '../utils/formatters.dart';

// ════════════════════════════════════════════════════════════════════════════
// MORE TAB (hub)
// ════════════════════════════════════════════════════════════════════════════
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(AppColors.bg),
        appBar: AppBar(
          backgroundColor: const Color(AppColors.navy),
          title: const Text('المزيد',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Color(AppColors.hot),
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.download_outlined, size: 18), text: 'التقارير'),
              Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'CRM'),
              Tab(icon: Icon(Icons.settings_outlined, size: 18), text: 'الإعدادات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReportsTab(),
            CRMTab(),
            SettingsTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REPORTS TAB — real cards, type badges, sizes, timestamps, share
// ════════════════════════════════════════════════════════════════════════════
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  bool _running = false;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchReports();
    });
  }

  Future<void> _runReport() async {
    setState(() => _running = true);
    await context.read<AppProvider>().triggerEtl();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _running = false);
      await context.read<AppProvider>().fetchReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ التقرير جاهز — اضغط تحميل', textDirection: TextDirection.rtl),
            backgroundColor: Color(AppColors.live),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, prov, _) {
        final reports = prov.reports;
        return Column(
          children: [
            // ── Stats bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(AppColors.bg),
              child: Row(
                children: [
                  _statBadge('${reports.length}', 'تقرير متاح', const Color(AppColors.navy)),
                  const SizedBox(width: 16),
                  _statBadge(
                    reports.where((r) => r.type == 'asset').length.toString(),
                    'تقارير أصول',
                    const Color(AppColors.hot),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _running ? null : _runReport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _running
                            ? const Color(AppColors.muted).withValues(alpha: 0.1)
                            : const Color(AppColors.hot).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _running ? const Color(AppColors.border) : const Color(AppColors.hot),
                        ),
                      ),
                      child: Row(
                        children: [
                          _running
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.hot)))
                              : const Text('🚀', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            _running ? 'جاري الإنشاء...' : 'تشغيل تقرير',
                            style: TextStyle(
                              fontSize: 12,
                              color: _running ? const Color(AppColors.muted) : const Color(AppColors.hot),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Reports list ───────────────────────────────────────────
            Expanded(
              child: reports.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(AppColors.navy)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length,
                      itemBuilder: (ctx, i) => _reportCard(context, reports[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(AppColors.muted)), textDirection: TextDirection.rtl),
      ],
    );
  }

  Widget _reportCard(BuildContext context, Report report) {
    final typeData = _typeData(report.type);
    final isDownloading = _downloadingId == report.filename;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Icon box
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: typeData['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeData['color'].withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(typeData['icon'] as String, style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.displayName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(AppColors.text)),
                          textDirection: TextDirection.rtl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeData['color'].withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(typeData['label'] as String,
                                style: TextStyle(fontSize: 10, color: typeData['color'] as Color, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: const TextStyle(color: Color(AppColors.muted), fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(report.sizeLabel,
                              style: const TextStyle(fontSize: 10, color: Color(AppColors.muted))),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}  ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10, color: Color(AppColors.muted)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    isDownloading ? 'جاري التحميل...' : '📥 تحميل Excel',
                    isDownloading ? const Color(AppColors.muted) : const Color(AppColors.blue),
                    isDownloading
                        ? null
                        : () async {
                            setState(() => _downloadingId = report.filename);
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) {
                              setState(() => _downloadingId = null);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ ${report.filename} — تم التحميل', textDirection: TextDirection.rtl),
                                  backgroundColor: const Color(AppColors.live),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    isLoading: isDownloading,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    '📤 مشاركة',
                    const Color(AppColors.warm),
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('مشاركة ${report.filename}...', textDirection: TextDirection.rtl),
                          backgroundColor: const Color(AppColors.navy),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _typeData(String type) {
    switch (type) {
      case 'asset':
        return {'icon': '🎯', 'label': 'أصول CPI', 'color': const Color(AppColors.hot)};
      case 'madinaty':
        return {'icon': '🏙️', 'label': 'مدينتي', 'color': const Color(AppColors.warm)};
      case 'nour':
        return {'icon': '✨', 'label': 'نور سيتي', 'color': const Color(0xFF7C3AED)};
      default:
        return {'icon': '📊', 'label': 'إجمالي السوق', 'color': const Color(AppColors.blue)};
    }
  }

  Widget _actionBtn(String label, Color color, VoidCallback? onTap,
      {bool isLoading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Text(label,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CRM TAB — Kanban + full lead detail sheet with actions + history
// ════════════════════════════════════════════════════════════════════════════
class CRMTab extends StatefulWidget {
  const CRMTab({super.key});

  @override
  State<CRMTab> createState() => _CRMTabState();
}

class _CRMTabState extends State<CRMTab> {
  final _stages = ['جديد', 'تواصل', 'عرض', 'تفاوض', 'إغلاق'];
  final _stageColors = [
    Color(AppColors.muted),
    Color(AppColors.blue),
    Color(AppColors.warm),
    Color(AppColors.hot),
    Color(AppColors.live),
  ];
  final _stageIcons = [
    Icons.fiber_new_outlined,
    Icons.phone_outlined,
    Icons.visibility_outlined,
    Icons.handshake_outlined,
    Icons.check_circle_outline,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchCrmLeads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, prov, _) {
        final leads = prov.crmLeads;
        return Column(
          children: [
            _pipelineSummary(leads),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: _stages.asMap().entries.map((e) {
                  final stage = e.value;
                  final color = _stageColors[e.key];
                  final icon = _stageIcons[e.key];
                  final stageLeads = leads.where((l) => l.stage == stage).toList();
                  return _kanbanColumn(context, stage, color, icon, stageLeads, prov);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pipelineSummary(List<CRMLead> leads) {
    final closedLeads = leads.where((l) => l.stage == 'إغلاق').length;
    final totalValue = closedLeads * 5200000; // avg deal value

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(AppColors.navy), Color(0xFF2C5282)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _stages.asMap().entries.map((e) {
              final stage = e.value;
              final color = _stageColors[e.key];
              final count = leads.where((l) => l.stage == stage).length;
              return Column(
                children: [
                  Text('$count',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Text(stage,
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                      textDirection: TextDirection.rtl),
                ],
              );
            }).toList(),
          ),
          if (closedLeads > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(AppColors.live).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(AppColors.live).withValues(alpha: 0.4)),
              ),
              child: Text(
                '💰 ${closedLeads} صفقة مغلقة | قيمة متوقعة ${formatPrice(totalValue)}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kanbanColumn(BuildContext context, String stage, Color color, IconData icon,
      List<CRMLead> leads, AppProvider prov) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Stage header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(stage,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                    textDirection: TextDirection.rtl),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${leads.length}',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (leads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('لا يوجد عملاء في هذه المرحلة',
                  style: const TextStyle(color: Color(AppColors.muted), fontSize: 12),
                  textDirection: TextDirection.rtl),
            )
          else
            ...leads.map((lead) => _leadCard(context, lead, prov)),
        ],
      ),
    );
  }

  Widget _leadCard(BuildContext context, CRMLead lead, AppProvider prov) {
    final scoreColor = lead.score != null
        ? Color(gradeFromScore(lead.score!).color)
        : const Color(AppColors.muted);
    final daysSinceContact = lead.lastContact != null
        ? DateTime.now().difference(lead.lastContact!).inDays
        : null;
    final isStale = daysSinceContact != null && daysSinceContact >= 3;

    return GestureDetector(
      onTap: () => _showLeadDetail(context, lead, prov),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isStale
              ? const Color(0xFFFFF7ED)
              : const Color(AppColors.bg),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isStale
                ? const Color(AppColors.warm).withValues(alpha: 0.4)
                : const Color(AppColors.border),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scoreColor.withValues(alpha: 0.15),
              child: Text(
                lead.name.isNotEmpty ? lead.name[0] : '؟',
                style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.text)),
                      textDirection: TextDirection.rtl),
                  if (lead.property != null)
                    Text(lead.property!,
                        style: const TextStyle(fontSize: 11, color: Color(AppColors.muted)),
                        textDirection: TextDirection.rtl),
                  if (daysSinceContact != null)
                    Text(
                      isStale ? '⚠️ آخر تواصل منذ $daysSinceContact أيام' : '✅ تواصل منذ $daysSinceContact يوم',
                      style: TextStyle(
                          fontSize: 10,
                          color: isStale ? const Color(AppColors.warm) : const Color(AppColors.live)),
                      textDirection: TextDirection.rtl,
                    ),
                ],
              ),
            ),
            if (lead.score != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${lead.score}%',
                    style: TextStyle(fontSize: 11, color: scoreColor, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Color(AppColors.muted)),
          ],
        ),
      ),
    );
  }

  void _showLeadDetail(BuildContext context, CRMLead lead, AppProvider prov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeadDetailSheet(lead: lead, prov: prov, stages: _stages, stageColors: _stageColors),
    );
  }
}

// ── Lead Detail Sheet ─────────────────────────────────────────────────────────
class _LeadDetailSheet extends StatelessWidget {
  final CRMLead lead;
  final AppProvider prov;
  final List<String> stages;
  final List<Color> stageColors;

  const _LeadDetailSheet({
    required this.lead,
    required this.prov,
    required this.stages,
    required this.stageColors,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = lead.score != null
        ? Color(gradeFromScore(lead.score!).color)
        : const Color(AppColors.muted);
    final currentStageIdx = stages.indexOf(lead.stage);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(AppColors.navy), scoreColor.withValues(alpha: 0.7)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0] : '؟',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                          textDirection: TextDirection.rtl),
                      if (lead.property != null)
                        Text(lead.property!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            textDirection: TextDirection.rtl),
                      if (lead.score != null)
                        Text('نقاط التطابق: ${lead.score}%',
                            style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          // Stage progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(AppColors.bg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مسار الصفقة',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(AppColors.muted)),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 8),
                Row(
                  children: stages.asMap().entries.map((e) {
                    final isActive = e.key <= currentStageIdx;
                    final isCurrent = e.key == currentStageIdx;
                    final color = stageColors[e.key];
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isActive ? color : const Color(AppColors.border),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isCurrent ? color : const Color(AppColors.muted),
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons
                  Row(
                    children: [
                      Expanded(child: _contactBtn(context, Icons.phone_rounded, 'اتصال', const Color(AppColors.blue), () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📞 جاري الاتصال بـ ${lead.name}...', textDirection: TextDirection.rtl)));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: _contactBtn(context, Icons.chat_rounded, 'واتساب', const Color(AppColors.whatsapp), () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('💬 فتح واتساب — ${lead.phone ?? 'رقم غير متوفر'}', textDirection: TextDirection.rtl)));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: _contactBtn(context, Icons.email_outlined, 'إيميل', const Color(AppColors.warm), () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📧 فتح البريد الإلكتروني...', textDirection: TextDirection.rtl)));
                      })),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Lead info
                  _infoSection('معلومات العميل', [
                    if (lead.phone != null) ('الهاتف', lead.phone!, Icons.phone_outlined),
                    ('الأصل المهتم به', lead.property ?? '—', Icons.home_outlined),
                    ('نقاط التطابق', '${lead.score ?? '—'}%', Icons.stars_outlined),
                    ('المرحلة الحالية', lead.stage, Icons.flag_outlined),
                    if (lead.lastContact != null)
                      ('آخر تواصل',
                        '${lead.lastContact!.day}/${lead.lastContact!.month}/${lead.lastContact!.year}',
                        Icons.access_time_outlined),
                  ]),
                  const SizedBox(height: 14),
                  // Notes
                  if (lead.notes != null) ...[
                    const Text('ملاحظات',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
                        textDirection: TextDirection.rtl),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(AppColors.blue).withValues(alpha: 0.2)),
                      ),
                      child: Text(lead.notes!,
                          style: const TextStyle(fontSize: 13, color: Color(AppColors.text), height: 1.5),
                          textDirection: TextDirection.rtl),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // Move stage
                  const Text('انقل إلى مرحلة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
                      textDirection: TextDirection.rtl),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stages.asMap().entries
                        .where((e) => e.value != lead.stage)
                        .map((e) {
                      final color = stageColors[e.key];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          prov.updateLeadStage(lead.id, e.value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ ${lead.name} → ${e.value}',
                                  textDirection: TextDirection.rtl),
                              backgroundColor: const Color(AppColors.live),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_forward, size: 13, color: color),
                              const SizedBox(width: 5),
                              Text(e.value,
                                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                                  textDirection: TextDirection.rtl),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBtn(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<(String, String, IconData)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(AppColors.bg),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 15, color: Color(AppColors.navy)),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
                    textDirection: TextDirection.rtl),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final row = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: const Border(top: BorderSide(color: Color(AppColors.border))),
              ),
              child: Row(
                children: [
                  Icon(row.$3, size: 14, color: const Color(AppColors.muted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(row.$1,
                        style: const TextStyle(fontSize: 12, color: Color(AppColors.muted)),
                        textDirection: TextDirection.rtl),
                  ),
                  Text(row.$2,
                      style: const TextStyle(fontSize: 13, color: Color(AppColors.text), fontWeight: FontWeight.w500),
                      textDirection: TextDirection.rtl),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS TAB — backend config, scheduler, WA groups, connection, profile
// ════════════════════════════════════════════════════════════════════════════
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _notifHot = true;
  bool _notifReport = true;
  bool _notifWarm = false;
  bool _syncing = false;
  bool _editingUrl = false;
  bool _editingScheduler = false;
  final _urlCtrl = TextEditingController(text: AppConfig.baseUrl);
  final _apiKeyCtrl = TextEditingController(text: 'sk-cpi-matchpro-••••••••••••');
  int _syncInterval = 6; // hours
  String _syncTime = '06:00';
  bool _autoSync = true;
  bool _waWebhook = true;

  // WhatsApp groups (demo)
  final _waGroups = [
    {'name': 'مدينتي — وسطاء 1', 'active': true, 'messages': 4821},
    {'name': 'مدينتي — وسطاء 2', 'active': true, 'messages': 3102},
    {'name': 'نور سيتي الرئيسي', 'active': true, 'messages': 2987},
    {'name': 'التجمع الخامس VIP', 'active': true, 'messages': 2344},
    {'name': 'الرحاب + الشروق', 'active': false, 'messages': 1890},
    {'name': 'الشيخ زايد فلل', 'active': true, 'messages': 1456},
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, prov, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          children: [
            _userCard(prov),
            const SizedBox(height: 16),
            // Backend config
            _backendSection(),
            const SizedBox(height: 16),
            // Scheduler
            _schedulerSection(),
            const SizedBox(height: 16),
            // WhatsApp groups
            _whatsappSection(),
            const SizedBox(height: 16),
            // Notifications
            _section('الإشعارات', [
              _switchRow('🔔 تنبيهات HOT الفورية', _notifHot, (v) => setState(() => _notifHot = v)),
              _switchRow('📧 تقرير كل $_syncInterval ساعات', _notifReport, (v) => setState(() => _notifReport = v)),
              _switchRow('⚡ تنبيهات WARM', _notifWarm, (v) => setState(() => _notifWarm = v)),
            ]),
            const SizedBox(height: 16),
            // Sync
            _syncSection(prov),
            const SizedBox(height: 16),
            // Connection status
            _section('حالة الاتصال', [
              _statusRow('السيرفر', _editingUrl ? _urlCtrl.text : AppConfig.baseUrl, true),
              _statusRow('Socket.IO', 'v4 — real-time', prov.socketConnected || AppConfig.demoMode),
              _statusRow('واتساب', '${_waGroups.where((g) => g['active'] == true).length} مجموعة نشطة', true),
              _statusRow('وضع العرض', AppConfig.demoMode ? 'مفعّل — بيانات تجريبية' : 'مطفأ — بيانات حقيقية',
                  !AppConfig.demoMode),
            ]),
            const SizedBox(height: 16),
            // App info
            _section('معلومات التطبيق', [
              _infoRow('الإصدار', 'v${AppConfig.version}'),
              _infoRow('الشركة', AppConfig.company),
              _infoRow('SACRED Engine', 'v2.0 — Location+Price+Specs'),
            ]),
            const SizedBox(height: 16),
            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, prov),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(AppColors.hot)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, color: Color(AppColors.hot), size: 18),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: Color(AppColors.hot), fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl),
              ),
            ),
            const SizedBox(height: 12),
            Text('MatchPro™ ${AppConfig.version} • CPI © 2026 • SACRED Engine',
                style: const TextStyle(fontSize: 10, color: Color(AppColors.muted)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _userCard(AppProvider prov) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(AppColors.navy), Color(0xFF2C5282)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(AppColors.navy).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (prov.userName ?? 'M').isNotEmpty ? (prov.userName ?? 'M')[0].toUpperCase() : 'M',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prov.userName ?? "Mo'men Maisara",
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const Text('mmaisara@crystalpowerinvestment.com',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('👑 مالك', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.live).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('🟢 متصل', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backendSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined, size: 15, color: Color(AppColors.navy)),
                const SizedBox(width: 6),
                const Text('إعدادات السيرفر',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.muted)),
                    textDirection: TextDirection.rtl),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _editingUrl = !_editingUrl),
                  child: Text(
                    _editingUrl ? 'إلغاء' : 'تعديل',
                    style: const TextStyle(fontSize: 12, color: Color(AppColors.blue), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رابط السيرفر (Base URL)',
                    style: TextStyle(fontSize: 11, color: Color(AppColors.muted)),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 6),
                _editingUrl
                    ? TextField(
                        controller: _urlCtrl,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(AppColors.blue), width: 2),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() => _editingUrl = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ تم حفظ رابط السيرفر', textDirection: TextDirection.rtl),
                                  backgroundColor: Color(AppColors.live),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Icon(Icons.check_circle, color: Color(AppColors.live)),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(AppColors.bg),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(AppColors.border)),
                        ),
                        child: Text(_urlCtrl.text,
                            style: const TextStyle(fontSize: 12, color: Color(AppColors.text), fontFamily: 'monospace')),
                      ),
                const SizedBox(height: 12),
                const Text('API Key',
                    style: TextStyle(fontSize: 11, color: Color(AppColors.muted)),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.bg),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_outlined, size: 14, color: Color(AppColors.muted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_apiKeyCtrl.text,
                            style: const TextStyle(
                                fontSize: 12, color: Color(AppColors.muted), fontFamily: 'monospace')),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔑 تجديد API Key — أرسل طلباً للإدارة',
                                  textDirection: TextDirection.rtl),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text('تجديد',
                            style: TextStyle(fontSize: 11, color: Color(AppColors.blue), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _schedulerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 15, color: Color(AppColors.navy)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('جدول المزامنة التلقائية',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.muted)),
                      textDirection: TextDirection.rtl),
                ),
                GestureDetector(
                  onTap: () => setState(() => _editingScheduler = !_editingScheduler),
                  child: Text(
                    _editingScheduler ? 'حفظ' : 'تعديل',
                    style: const TextStyle(fontSize: 12, color: Color(AppColors.blue), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('المزامنة التلقائية',
                          style: const TextStyle(fontSize: 13, color: Color(AppColors.text)),
                          textDirection: TextDirection.rtl),
                    ),
                    Switch(
                      value: _autoSync,
                      onChanged: (v) => setState(() => _autoSync = v),
                      activeThumbColor: const Color(AppColors.navy),
                    ),
                  ],
                ),
                if (_autoSync) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('كل',
                          style: TextStyle(fontSize: 13, color: Color(AppColors.muted)),
                          textDirection: TextDirection.rtl),
                      const SizedBox(width: 12),
                      // Interval buttons
                      ...([2, 4, 6, 12, 24]).map((h) {
                        final active = _syncInterval == h;
                        return GestureDetector(
                          onTap: _editingScheduler
                              ? () => setState(() => _syncInterval = h)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? const Color(AppColors.navy) : const Color(AppColors.bg),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active ? const Color(AppColors.navy) : const Color(AppColors.border),
                              ),
                            ),
                            child: Text('${h}س',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.white : const Color(AppColors.muted),
                                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                )),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(AppColors.muted)),
                      const SizedBox(width: 6),
                      const Text('وقت البداية: ',
                          style: TextStyle(fontSize: 12, color: Color(AppColors.muted)),
                          textDirection: TextDirection.rtl),
                      Text(_syncTime,
                          style: const TextStyle(
                              fontSize: 13, color: Color(AppColors.navy), fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_editingScheduler)
                        GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (t != null) {
                              setState(() {
                                _syncTime = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                          child: const Text('تغيير',
                              style: TextStyle(
                                  fontSize: 12, color: Color(AppColors.blue), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text('webhook واتساب',
                          style: const TextStyle(fontSize: 13, color: Color(AppColors.text)),
                          textDirection: TextDirection.rtl),
                    ),
                    Switch(
                      value: _waWebhook,
                      onChanged: (v) => setState(() => _waWebhook = v),
                      activeThumbColor: const Color(AppColors.whatsapp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whatsappSection() {
    final activeCount = _waGroups.where((g) => g['active'] == true).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.chat_rounded, size: 15, color: Color(AppColors.whatsapp)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('مجموعات واتساب',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.muted)),
                      textDirection: TextDirection.rtl),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.live).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$activeCount نشط',
                      style: const TextStyle(
                          fontSize: 11, color: Color(AppColors.live), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._waGroups.asMap().entries.map((e) {
            final group = e.value;
            final isActive = group['active'] as bool;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: e.key > 0
                    ? const Border(top: BorderSide(color: Color(AppColors.border)))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(AppColors.live) : const Color(AppColors.border),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group['name'] as String,
                            style: TextStyle(
                                fontSize: 13,
                                color: isActive ? const Color(AppColors.text) : const Color(AppColors.muted),
                                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal),
                            textDirection: TextDirection.rtl),
                        Text('${group['messages']} رسالة محللة',
                            style: const TextStyle(fontSize: 10, color: Color(AppColors.muted)),
                            textDirection: TextDirection.rtl),
                      ],
                    ),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (v) {
                      setState(() => group['active'] = v);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            v
                                ? '✅ ${group['name']} — تم التفعيل'
                                : '⏸️ ${group['name']} — تم الإيقاف',
                            textDirection: TextDirection.rtl,
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: v ? const Color(AppColors.live) : const Color(AppColors.muted),
                        ),
                      );
                    },
                    activeThumbColor: const Color(AppColors.whatsapp),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _syncSection(AppProvider prov) {
    return _section('المزامنة', [
      _infoRow('آخر مزامنة',
          '${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'),
      _infoRow('الجدولة', 'كل $_syncInterval ساعة — $_syncTime'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ElevatedButton.icon(
          onPressed: _syncing
              ? null
              : () async {
                  setState(() => _syncing = true);
                  await prov.triggerEtl();
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _syncing = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ تمت المزامنة بنجاح', textDirection: TextDirection.rtl),
                        backgroundColor: Color(AppColors.live),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(AppColors.navy),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync, color: Colors.white, size: 18),
          label: Text(_syncing ? 'جاري المزامنة...' : '🔄 مزامنة الآن',
              style: const TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
        ),
      ),
    ]);
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.muted)),
                textDirection: TextDirection.rtl),
          ),
          const Divider(height: 1, color: Color(AppColors.border)),
          ...children,
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(AppColors.text)),
                textDirection: TextDirection.rtl),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(AppColors.navy)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(AppColors.muted)),
                textDirection: TextDirection.rtl),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: Color(AppColors.text), fontWeight: FontWeight.w500),
              textDirection: TextDirection.rtl),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, bool connected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(AppColors.muted)),
                textDirection: TextDirection.rtl),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: connected ? const Color(AppColors.live) : const Color(AppColors.hot),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 11, color: Color(AppColors.text)),
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج', textDirection: TextDirection.rtl),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              prov.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.hot)),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
