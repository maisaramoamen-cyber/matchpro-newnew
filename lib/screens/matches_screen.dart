// lib/screens/matches_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/grade_chip.dart';
import '../config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String _selectedFilter = 'الكل';
  bool _loading = false;

  final filters = ['الكل', '🔥 HOT', '⚡ WARM', 'مدينتي', 'نور سيتي', 'التجمع'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    String? grade;
    String? location;
    if (_selectedFilter == '🔥 HOT') grade = 'HOT';
    if (_selectedFilter == '⚡ WARM') grade = 'WARM';
    if (_selectedFilter == 'مدينتي') location = 'مدينتي';
    if (_selectedFilter == 'نور سيتي') location = 'نور سيتي';
    if (_selectedFilter == 'التجمع') location = 'التجمع الخامس';
    await context.read<AppProvider>().fetchMatches(grade: grade, location: location);
    if (mounted) setState(() => _loading = false);
  }

  List<Match> _filteredMatches(List<Match> all) {
    if (_selectedFilter == 'الكل') return all;
    if (_selectedFilter == '🔥 HOT') return all.where((m) => m.grade == MatchGrade.hot).toList();
    if (_selectedFilter == '⚡ WARM') return all.where((m) => m.grade == MatchGrade.warm).toList();
    if (_selectedFilter == 'مدينتي') return all.where((m) => (m.supply.location ?? '').contains('مدينتي')).toList();
    if (_selectedFilter == 'نور سيتي') return all.where((m) => (m.supply.location ?? '').contains('نور')).toList();
    if (_selectedFilter == 'التجمع') return all.where((m) => (m.supply.location ?? '').contains('التجمع')).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.navy),
        title: const Text('التطابقات المباشرة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, prov, _) {
          final matches = _filteredMatches(prov.matches);

          return Column(
            children: [
              // Filter bar
              Container(
                color: const Color(AppColors.navy),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: filters.map((f) {
                      final sel = f == _selectedFilter;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = f);
                          _load();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? const Color(AppColors.navy) : Colors.white,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Matches list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(AppColors.navy)))
                    : matches.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🔍', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('لا توجد تطابقات بهذا الفلتر',
                                    style: TextStyle(color: Color(AppColors.muted), fontSize: 15),
                                    textDirection: TextDirection.rtl),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: matches.length,
                              itemBuilder: (ctx, i) => _matchCard(matches[i]),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _matchCard(Match m) {
    final color = gradeColor(m.grade);

    return GestureDetector(
      onTap: () => _showDetail(m),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: m.grade == MatchGrade.hot ? color.withValues(alpha: 0.4) : const Color(AppColors.border),
            width: m.grade == MatchGrade.hot ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: m.grade == MatchGrade.hot ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  GradeChip(grade: m.grade),
                  const SizedBox(width: 8),
                  Text('${m.score}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Icon(Icons.location_on, size: 13, color: const Color(AppColors.muted)),
                  Text(m.supply.location ?? '—', style: const TextStyle(fontSize: 12, color: Color(AppColors.muted))),
                  const SizedBox(width: 8),
                  Text(timeAgo(m.supply.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.home, const Color(0xFF2563EB), 'عرض', _supplyText(m)),
                  const Divider(height: 14, color: Color(0xFFF3F4F6)),
                  _infoRow(Icons.person_search, const Color(0xFF7C3AED), 'طلب', _demandText(m)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _actionBtn(Icons.chat_rounded, 'واتساب', const Color(AppColors.whatsapp),
                          () => _openWa(m.supply.senderPhone)),
                      const SizedBox(width: 8),
                      _actionBtn(Icons.call_rounded, 'اتصال', const Color(AppColors.blue),
                          () => _call(m.supply.senderPhone)),
                      const Spacer(),
                      _actionBtn(Icons.info_outline, 'التفاصيل', const Color(AppColors.muted),
                          () => _showDetail(m)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _supplyText(Match m) {
    final parts = <String>[];
    if (m.supply.propertyType != null) parts.add(m.supply.propertyType!);
    if (m.supply.areaSqm != null) parts.add('${m.supply.areaSqm!.toInt()} م²');
    if (m.supply.price != null) parts.add(formatPrice(m.supply.price));
    if (m.supply.bedrooms != null) parts.add('${m.supply.bedrooms} غرف');
    return parts.isEmpty ? m.supply.rawMessage.substring(0, m.supply.rawMessage.length.clamp(0, 60)) : parts.join(' | ');
  }

  String _demandText(Match m) {
    final parts = <String>[];
    if (m.demand.propertyType != null) parts.add('مشتري ${m.demand.propertyType!}');
    if (m.demand.areaSqm != null) parts.add('${m.demand.areaSqm!.toInt()}-${(m.demand.areaSqm! + 20).toInt()} م²');
    if (m.demand.budgetMax != null) parts.add('≤${formatPrice(m.demand.budgetMax)}');
    return parts.isEmpty ? m.demand.rawMessage.substring(0, m.demand.rawMessage.length.clamp(0, 60)) : parts.join(' | ');
  }

  Widget _infoRow(IconData icon, Color iconColor, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(AppColors.muted), fontWeight: FontWeight.w500)),
              Text(text, style: const TextStyle(fontSize: 12, color: Color(AppColors.text), fontWeight: FontWeight.w500),
                  textDirection: TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openWa(String? phone) async {
    final link = buildWhatsAppLink(phone);
    if (link == null) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _call(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showDetail(Match m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchDetailSheet(match: m),
    );
  }
}

class _MatchDetailSheet extends StatelessWidget {
  final Match match;

  const _MatchDetailSheet({required this.match});

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(match.grade);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GradeChip(grade: match.grade),
                const SizedBox(width: 10),
                Text('${match.score}% تطابق',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score breakdown
                  _section('تفاصيل النقاط', child: _scoreBreakdown(color)),
                  const SizedBox(height: 16),
                  // Supply details
                  _section('تفاصيل العرض', child: _supplyDetails()),
                  const SizedBox(height: 16),
                  // Demand details
                  _section('تفاصيل الطلب', child: _demandDetails()),
                  const SizedBox(height: 20),
                  // Contact buttons
                  _contactButtons(context),
                  const SizedBox(height: 20),
                  // Feedback
                  _feedbackButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
            textDirection: TextDirection.rtl),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _scoreBreakdown(Color color) {
    final items = [
      ('الموقع', match.breakdown.location, 40),
      ('السعر', match.breakdown.price, 35),
      ('المواصفات', match.breakdown.specs, 25),
    ];

    return Column(
      children: items.map((item) {
        final ratio = item.$3 > 0 ? item.$2 / item.$3 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.$1,
                      style: const TextStyle(fontSize: 13, color: Color(AppColors.text)),
                      textDirection: TextDirection.rtl)),
                  Text('${item.$2}/${item.$3}',
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _supplyDetails() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('الموقع', match.supply.location ?? '—'),
          _detailRow('النوع', match.supply.propertyType ?? '—'),
          _detailRow('السعر', formatPrice(match.supply.price)),
          _detailRow('الغرف', match.supply.bedrooms != null ? '${match.supply.bedrooms}' : '—'),
          _detailRow('المساحة', match.supply.areaSqm != null ? '${match.supply.areaSqm!.toInt()} م²' : '—'),
          _detailRow('التشطيب', match.supply.finishing ?? '—'),
          _detailRow('المصدر', match.supply.groupName ?? '—'),
          if (match.supply.rawMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                match.supply.rawMessage,
                style: const TextStyle(fontSize: 11, color: Color(AppColors.muted), fontStyle: FontStyle.italic),
                textDirection: TextDirection.rtl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _demandDetails() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('الموقع المطلوب', match.demand.location ?? '—'),
          _detailRow('النوع', match.demand.propertyType ?? '—'),
          _detailRow('الميزانية', '${formatPrice(match.demand.budgetMin)} - ${formatPrice(match.demand.budgetMax)}'),
          _detailRow('الغرف المطلوبة', match.demand.bedrooms != null ? '${match.demand.bedrooms}' : '—'),
          _detailRow('المساحة', match.demand.areaSqm != null ? '${match.demand.areaSqm!.toInt()} م²' : '—'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(AppColors.muted))),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(AppColors.text), fontWeight: FontWeight.w500),
                textDirection: TextDirection.rtl),
          ),
        ],
      ),
    );
  }

  Widget _contactButtons(BuildContext context) {
    final phone = match.supply.senderPhone;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final link = buildWhatsAppLink(phone);
              if (link == null) return;
              final uri = Uri.parse(link);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.whatsapp),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.chat, color: Colors.white, size: 18),
            label: const Text('واتساب', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              if (phone == null) return;
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(AppColors.blue)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.call, color: Color(AppColors.blue), size: 18),
            label: const Text('اتصال', style: TextStyle(color: Color(AppColors.blue))),
          ),
        ),
      ],
    );
  }

  Widget _feedbackButtons(BuildContext context) {
    final options = ['تم التواصل', 'غير مناسب', 'تم الإغلاق'];
    final colors = [const Color(AppColors.live), const Color(AppColors.hot), const Color(AppColors.muted)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الإجراء', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
            textDirection: TextDirection.rtl),
        const SizedBox(height: 8),
        Row(
          children: List.generate(options.length, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i < options.length - 1 ? 6 : 0),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${options[i]}'), backgroundColor: colors[i]),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors[i].withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(options[i], style: TextStyle(fontSize: 10, color: colors[i]),
                    textDirection: TextDirection.rtl),
              ),
            ),
          )),
        ),
      ],
    );
  }
}
