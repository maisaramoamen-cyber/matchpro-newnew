// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/kpi_card.dart';
import '../widgets/hot_alert_banner.dart';
import '../widgets/grade_chip.dart';
import '../config/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loadingEtl = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AppProvider>();
      prov.fetchStats();
      prov.fetchMatches();
      // Real-time alerts come via Socket.IO — no demo injection
    });
  }

  Future<void> _triggerEtl() async {
    setState(() => _loadingEtl = true);
    final ok = await context.read<AppProvider>().triggerEtl();
    setState(() => _loadingEtl = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ جاري المزامنة...' : '❌ فشل في الاتصال'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      body: Consumer<AppProvider>(
        builder: (ctx, prov, _) {
          final stats = prov.stats;
          final matches = prov.matches.take(20).toList();
          final alerts = prov.liveAlerts;

          return CustomScrollView(
            slivers: [
              // ── App Bar
              SliverAppBar(
                expandedHeight: 100,
                floating: true,
                pinned: true,
                backgroundColor: const Color(AppColors.navy),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: const Color(AppColors.navy),
                    padding: const EdgeInsets.only(top: 48, left: 16, right: 16),
                    child: Row(
                      children: [
                        const Text('🏠', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('MatchPro™',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text('Crystal Power Investments',
                                  style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Live indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              _pulseDot(prov.socketConnected || prov.backendOnline),
                              const SizedBox(width: 5),
                              Text(
                                prov.socketConnected
                                    ? 'Live 🔥'
                                    : prov.backendOnline
                                        ? 'Connected'
                                        : 'Offline',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Alerts
              if (alerts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: HotAlertBanner(
                      alert: alerts.first,
                      onDismiss: () => prov.dismissAlert(alerts.first.id),
                    ),
                  ),
                ),

              // ── KPI Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    children: [
                      KPICard(
                        title: 'تطابقات HOT',
                        value: stats?.hotMatchesToday ?? 142,
                        color: const Color(AppColors.hot),
                        icon: Icons.local_fire_department,
                        pulse: true,
                        subtitle: 'اليوم',
                      ),
                      KPICard(
                        title: 'عروض العقارات',
                        value: stats?.supplyCount ?? 7966,
                        color: const Color(AppColors.blue),
                        icon: Icons.home_work_outlined,
                        subtitle: 'إجمالي',
                      ),
                      KPICard(
                        title: 'المشترون',
                        value: stats?.demandCount ?? 3549,
                        color: const Color(0xFF7C3AED),
                        icon: Icons.people_alt_outlined,
                        subtitle: 'طلبات نشطة',
                      ),
                      KPICard(
                        title: 'رسائل واتساب',
                        value: stats?.messagesCount ?? 21817,
                        color: const Color(AppColors.whatsapp),
                        icon: Icons.chat_bubble_outline,
                        subtitle: 'تم تحليلها',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Top Locations
              if (stats?.topLocations.isNotEmpty ?? true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _topLocationsCard(stats?.topLocations ?? _demoLocations()),
                  ),
                ),

              // ── Live Feed header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      const Text('آخر التطابقات',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(AppColors.text))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(AppColors.hot).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${matches.length} نتيجة',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(AppColors.hot),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Match feed
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i >= matches.length) return null;
                    final m = matches[i];
                    return _liveFeedTile(m);
                  },
                  childCount: matches.length,
                ),
              ),

              // ── Bottom actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loadingEtl ? null : _triggerEtl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppColors.navy),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _loadingEtl
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync, color: Colors.white, size: 18),
                          label: const Text('مزامنة', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(AppColors.blue)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.bar_chart, color: Color(AppColors.blue), size: 18),
                          label: const Text('تقرير فوري',
                              style: TextStyle(color: Color(AppColors.blue))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _pulseDot(bool live) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: live ? const Color(AppColors.live) : const Color(0xFF9CA3AF),
        shape: BoxShape.circle,
        boxShadow: live
            ? [BoxShadow(color: const Color(AppColors.live).withValues(alpha: 0.5), blurRadius: 4)]
            : null,
      ),
    );
  }

  Widget _topLocationsCard(List<LocationStat> locations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(AppColors.blue), size: 18),
              SizedBox(width: 6),
              Text('أعلى المناطق', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(AppColors.text))),
            ],
          ),
          const SizedBox(height: 12),
          ...locations.take(5).map((loc) {
            final maxCount = locations.isEmpty ? 1 : locations.first.count;
            final ratio = maxCount > 0 ? loc.count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(loc.location,
                            style: const TextStyle(fontSize: 13, color: Color(AppColors.text)),
                            textDirection: TextDirection.rtl),
                      ),
                      Text('${loc.count}',
                          style: const TextStyle(fontSize: 12, color: Color(AppColors.muted), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(AppColors.border),
                      valueColor: AlwaysStoppedAnimation(const Color(AppColors.blue)),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveFeedTile(Match m) {
    final color = gradeColor(m.grade);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.grade == MatchGrade.hot ? color.withValues(alpha: 0.3) : const Color(AppColors.border),
        ),
      ),
      child: Row(
        children: [
          GradeChip(grade: m.grade, compact: true),
          const SizedBox(width: 8),
          Text('${m.score}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.supply.propertyType ?? 'عقار'} — ${m.supply.location ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Color(AppColors.text), fontWeight: FontWeight.w500),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatPrice(m.supply.price),
                  style: const TextStyle(fontSize: 11, color: Color(AppColors.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _waBtn(m.supply.senderPhone),
        ],
      ),
    );
  }

  Widget _waBtn(String? phone) {
    return GestureDetector(
      onTap: () async {
        final link = buildWhatsAppLink(phone);
        if (link == null) return;
        // Would launch WA
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(AppColors.whatsapp).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(AppColors.whatsapp).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.chat_rounded, size: 16, color: Color(AppColors.whatsapp)),
      ),
    );
  }

  List<LocationStat> _demoLocations() => const [
    LocationStat(location: 'مدينتي', count: 2881),
    LocationStat(location: 'نور سيتي', count: 1240),
    LocationStat(location: 'التجمع الخامس', count: 987),
    LocationStat(location: 'الرحاب', count: 654),
    LocationStat(location: 'الشيخ زايد', count: 412),
  ];
}
