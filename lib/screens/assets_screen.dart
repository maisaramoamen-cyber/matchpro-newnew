// lib/screens/assets_screen.dart  — My CPI Assets (fully upgraded)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/grade_chip.dart';
import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Extended asset data (enriches CPIAsset with specs not in the base model)
// ─────────────────────────────────────────────────────────────────────────────
class _AssetSpec {
  final String id;
  final int? price;
  final double? areaSqm;
  final int? bedrooms;
  final String? finishing;
  final String? floor;
  final String? compound;
  final String? notes;
  final DateTime lastUpdated;
  final double? roi;
  final String? paymentPlan;

  const _AssetSpec({
    required this.id,
    this.price,
    this.areaSqm,
    this.bedrooms,
    this.finishing,
    this.floor,
    this.compound,
    this.notes,
    required this.lastUpdated,
    this.roi,
    this.paymentPlan,
  });
}

final _assetSpecs = <String, _AssetSpec>{
  'NOUR-1': _AssetSpec(
    id: 'NOUR-1',
    price: 4200000,
    areaSqm: 138,
    bedrooms: 3,
    finishing: 'سوبر لوكس',
    floor: 'الطابق 5',
    compound: 'بريفادو',
    notes: 'إطلالة حديقة مباشرة، بالقرب من المدخل الرئيسي',
    lastUpdated: DateTime(2026, 7, 1),
    roi: 8.4,
    paymentPlan: '10% مقدم + 60 شهر',
  ),
  'NOUR-2': _AssetSpec(
    id: 'NOUR-2',
    price: 3850000,
    areaSqm: 120,
    bedrooms: 2,
    finishing: 'سوبر لوكس',
    floor: 'الطابق 3',
    compound: 'بريفادو',
    notes: 'مناسبة للمستثمر — عائد إيجاري مرتفع بالمنطقة',
    lastUpdated: DateTime(2026, 6, 28),
    roi: 7.9,
    paymentPlan: '15% مقدم + 48 شهر',
  ),
  'MAD-B14-1': _AssetSpec(
    id: 'MAD-B14-1',
    price: 6500000,
    areaSqm: 175,
    bedrooms: 4,
    finishing: 'تشطيب كامل',
    floor: 'الطابق 2',
    compound: 'مدينتي B14',
    notes: 'أكبر وحدة في المبنى، منظر على النادي الرياضي',
    lastUpdated: DateTime(2026, 7, 5),
    roi: 9.2,
    paymentPlan: '20% مقدم + 72 شهر',
  ),
  'MAD-B14-2': _AssetSpec(
    id: 'MAD-B14-2',
    price: 5200000,
    areaSqm: 148,
    bedrooms: 3,
    finishing: 'نصف تشطيب',
    floor: 'الطابق 7',
    compound: 'مدينتي B14',
    notes: 'سعر أقل من السوق بـ 8%، قابل للتفاوض',
    lastUpdated: DateTime(2026, 7, 3),
    roi: 8.7,
    paymentPlan: '10% مقدم + 60 شهر',
  ),
  'MAD-WANT-1': _AssetSpec(
    id: 'MAD-WANT-1',
    price: null,
    areaSqm: 350,
    bedrooms: 5,
    finishing: 'أي تشطيب',
    floor: 'أرضي مفضل',
    compound: 'مدينتي — أي كومباوند',
    notes: 'عميل مستثمر جاهز للتنفيذ الفوري — ميزانية 10M-30M EGP',
    lastUpdated: DateTime(2026, 7, 7),
    roi: null,
    paymentPlan: 'كاش أو تمويل عقاري',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _filterMode = 'الكل'; // الكل / بيع / شراء

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.navy),
        title: const Text('أصولي',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Consumer<AppProvider>(
                  builder: (_, p, __) => Text(
                    '${p.assets.length} أصل',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, prov, _) {
          final allAssets = prov.assets;
          final filtered = _filterMode == 'الكل'
              ? allAssets
              : allAssets.where((a) => (a.mode == 'sell' ? 'بيع' : 'شراء') == _filterMode).toList();

          // Summary stats
          final totalHot = allAssets.fold(0, (s, a) => s + a.hotCount);
          final totalWarm = allAssets.fold(0, (s, a) => s + a.warmCount);

          return Column(
            children: [
              // ── Summary banner ─────────────────────────────────────────
              _summaryBanner(totalHot, totalWarm, allAssets.length),
              // ── Filter chips ────────────────────────────────────────────
              _filterBar(),
              // ── Asset list ──────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == filtered.length) return _addAssetCard(context);
                    return _assetCard(context, filtered[i], prov.matches);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Summary Banner ──────────────────────────────────────────────────────────
  Widget _summaryBanner(int hot, int warm, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _bannerStat('$count', 'أصل', Colors.white),
          _divider(),
          _bannerStat('$hot', '🔥 HOT إجمالي', const Color(AppColors.hot)),
          _divider(),
          _bannerStat('$warm', '⚡ WARM إجمالي', const Color(AppColors.warm)),
          _divider(),
          _bannerStat('${hot + warm}', 'كل الفرص', Colors.white60),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label, Color color) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9), textDirection: TextDirection.rtl),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4));

  // ── Filter Bar ──────────────────────────────────────────────────────────────
  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['الكل', 'بيع', 'شراء'].map((f) {
          final active = _filterMode == f;
          return GestureDetector(
            onTap: () => setState(() => _filterMode = f),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(AppColors.navy) : const Color(AppColors.bg),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? const Color(AppColors.navy) : const Color(AppColors.border),
                ),
              ),
              child: Text(f,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : const Color(AppColors.muted),
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                  textDirection: TextDirection.rtl),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Asset Card (upgraded) ───────────────────────────────────────────────────
  Widget _assetCard(BuildContext context, CPIAsset asset, List<Match> allMatches) {
    final spec = _assetSpecs[asset.id];
    final isSell = asset.mode == 'sell';
    final modeColor = isSell ? const Color(AppColors.blue) : const Color(0xFF7C3AED);
    final modeLabel = isSell ? 'بيع' : 'شراء';
    final totalMatches = asset.hotCount + asset.warmCount;
    final hotPct = totalMatches > 0 ? (asset.hotCount / totalMatches * 100).toInt() : 0;

    return GestureDetector(
      onTap: () => _showAssetDetail(context, asset, allMatches),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            // ── Header gradient ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(AppColors.navy), modeColor.withValues(alpha: 0.85)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Mode badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(modeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(asset.label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            textDirection: TextDirection.rtl),
                      ),
                      // ID badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(asset.id,
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  if (spec?.compound != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text('${asset.location} — ${spec!.compound}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            textDirection: TextDirection.rtl),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Specs row ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF0F4F8),
              child: Row(
                children: [
                  if (spec?.areaSqm != null) _specChip(Icons.straighten, '${spec!.areaSqm!.toInt()} م²'),
                  if (spec?.bedrooms != null) _specChip(Icons.bed_outlined, '${spec!.bedrooms} غرف'),
                  if (spec?.finishing != null) _specChip(Icons.layers_outlined, spec!.finishing!),
                  if (spec?.floor != null) _specChip(Icons.apartment_outlined, spec!.floor!),
                ],
              ),
            ),

            // ── Price + ROI ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (spec?.price != null) ...[
                    const Icon(Icons.attach_money, size: 16, color: Color(AppColors.navy)),
                    const SizedBox(width: 4),
                    Text(
                      formatPrice(spec!.price),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
                    ),
                  ] else ...[
                    const Icon(Icons.search, size: 16, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 4),
                    Text(
                      isSell ? '' : '${formatPrice(asset.minPrice)} — ${formatPrice(asset.maxPrice)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Spacer(),
                  if (spec?.roi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.live).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(AppColors.live).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'ROI ${spec!.roi}%',
                        style: const TextStyle(fontSize: 11, color: Color(AppColors.live), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // ── Match counts ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppColors.bg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.border)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _matchStat('🔥 HOT', asset.hotCount, const Color(AppColors.hot)),
                        Container(width: 1, height: 30, color: const Color(AppColors.border)),
                        _matchStat('⚡ WARM', asset.warmCount, const Color(AppColors.warm)),
                        Container(width: 1, height: 30, color: const Color(AppColors.border)),
                        _matchStat('إجمالي', totalMatches, const Color(AppColors.navy)),
                      ],
                    ),
                    if (totalMatches > 0) ...[
                      const SizedBox(height: 10),
                      // HOT ratio bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hotPct / 100,
                          backgroundColor: const Color(AppColors.warm).withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(Color(AppColors.hot)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$hotPct% من المطابقات HOT 🔥',
                        style: const TextStyle(fontSize: 10, color: Color(AppColors.muted)),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Notes (if any) ───────────────────────────────────────────
            if (spec?.notes != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(AppColors.warm).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(spec!.notes!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                            textDirection: TextDirection.rtl),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Action buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssetDetail(context, asset, allMatches),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppColors.navy),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.bar_chart, color: Colors.white, size: 16),
                      label: Text(
                        'عرض ${asset.hotCount + asset.warmCount} مطابقة',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadExcel(context, asset),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: const BorderSide(color: Color(AppColors.blue)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, color: Color(AppColors.blue), size: 16),
                      label: const Text('Excel', style: TextStyle(color: Color(AppColors.blue), fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(AppColors.navy)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(AppColors.text), fontWeight: FontWeight.w500),
              textDirection: TextDirection.rtl),
        ],
      ),
    );
  }

  Widget _matchStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(AppColors.muted)),
            textDirection: TextDirection.rtl),
      ],
    );
  }

  Widget _addAssetCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddAssetSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(AppColors.blue).withValues(alpha: 0.4),
              width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(AppColors.blue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Color(AppColors.blue), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('إضافة أصل جديد',
                style: TextStyle(color: Color(AppColors.blue), fontWeight: FontWeight.bold, fontSize: 15),
                textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }

  void _downloadExcel(BuildContext context, CPIAsset asset) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 جاري تحميل تقرير ${asset.id}...', textDirection: TextDirection.rtl),
        backgroundColor: const Color(AppColors.navy),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'فتح',
          textColor: const Color(AppColors.warm),
          onPressed: () {},
        ),
      ),
    );
  }

  void _showAssetDetail(BuildContext context, CPIAsset asset, List<Match> allMatches) {
    final spec = _assetSpecs[asset.id];
    final assetMatches = allMatches
        .where((m) =>
            (m.supply.location ?? '').contains(asset.location.substring(0, 3)) ||
            (m.demand.location ?? '').contains(asset.location.substring(0, 3)))
        .toList();
    assetMatches.sort((a, b) => b.score.compareTo(a.score));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetDetailSheet(asset: asset, spec: spec, matches: assetMatches),
    );
  }

  void _showAddAssetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAssetSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASSET DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AssetDetailSheet extends StatefulWidget {
  final CPIAsset asset;
  final _AssetSpec? spec;
  final List<Match> matches;

  const _AssetDetailSheet({required this.asset, required this.spec, required this.matches});

  @override
  State<_AssetDetailSheet> createState() => _AssetDetailSheetState();
}

class _AssetDetailSheetState extends State<_AssetDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final spec = widget.spec;
    final isSell = a.mode == 'sell';
    final modeColor = isSell ? const Color(AppColors.blue) : const Color(0xFF7C3AED);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(AppColors.navy), modeColor],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(isSell ? 'بيع' : 'شراء',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          textDirection: TextDirection.rtl),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                if (spec?.price != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(formatPrice(spec!.price),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                // Grade pills
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _gradePill('🔥 ${a.hotCount} HOT', const Color(AppColors.hot)),
                      const SizedBox(width: 8),
                      _gradePill('⚡ ${a.warmCount} WARM', const Color(AppColors.warm)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('📥 جاري تحميل ${a.id}.xlsx', textDirection: TextDirection.rtl),
                              backgroundColor: const Color(AppColors.navy),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.download, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Excel', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs
                TabBar(
                  controller: _tabs,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(AppColors.warm),
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'المطابقات'),
                    Tab(text: 'تفاصيل الأصل'),
                  ],
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _matchesTab(),
                _specTab(spec),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchesTab() {
    final matches = widget.matches;
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('لا توجد مطابقات حتى الآن',
                style: TextStyle(color: Color(AppColors.muted), fontSize: 15),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 6),
            const Text('جاري تحليل السوق — تحقق لاحقاً',
                style: TextStyle(color: Color(AppColors.muted), fontSize: 12),
                textDirection: TextDirection.rtl),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: matches.length,
      itemBuilder: (ctx, i) => _demandMatchTile(matches[i], i),
    );
  }

  Widget _demandMatchTile(Match m, int rank) {
    final color = gradeColor(m.grade);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppColors.bg),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${rank + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
          ),
          const SizedBox(width: 8),
          GradeChip(grade: m.grade, compact: true),
          const SizedBox(width: 6),
          Text('${m.score}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ميزانية: ${formatPrice(m.demand.budgetMin)}–${formatPrice(m.demand.budgetMax)}',
                  style: const TextStyle(fontSize: 12, color: Color(AppColors.text), fontWeight: FontWeight.w500),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  '${m.demand.areaSqm?.toInt() ?? '—'} م² | ${m.demand.bedrooms ?? '—'} غرف | ${m.demand.location ?? '—'}',
                  style: const TextStyle(fontSize: 11, color: Color(AppColors.muted)),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _waBtn(m.demand.senderPhone),
        ],
      ),
    );
  }

  Widget _specTab(_AssetSpec? spec) {
    if (spec == null) {
      return const Center(child: Text('لا تتوفر تفاصيل إضافية', textDirection: TextDirection.rtl));
    }

    final rows = <(String, String, IconData)>[
      if (spec.areaSqm != null) ('المساحة', '${spec.areaSqm!.toInt()} م²', Icons.straighten),
      if (spec.bedrooms != null) ('غرف النوم', '${spec.bedrooms}', Icons.bed_outlined),
      if (spec.finishing != null) ('التشطيب', spec.finishing!, Icons.layers_outlined),
      if (spec.floor != null) ('الطابق', spec.floor!, Icons.apartment_outlined),
      if (spec.compound != null) ('الكومباوند', spec.compound!, Icons.location_city),
      if (spec.paymentPlan != null) ('خطة الدفع', spec.paymentPlan!, Icons.payments_outlined),
      if (spec.roi != null) ('العائد المتوقع', '${spec.roi}% سنوياً', Icons.trending_up),
      ('آخر تحديث', '${spec.lastUpdated.day}/${spec.lastUpdated.month}/${spec.lastUpdated.year}', Icons.update),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Spec rows
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(AppColors.border)),
            ),
            child: Column(
              children: rows.asMap().entries.map((e) {
                final row = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: e.key > 0
                        ? const Border(top: BorderSide(color: Color(AppColors.border)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(row.$3, size: 15, color: const Color(AppColors.navy)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(row.$1,
                            style: const TextStyle(fontSize: 13, color: Color(AppColors.muted)),
                            textDirection: TextDirection.rtl),
                      ),
                      Text(row.$2,
                          style: const TextStyle(fontSize: 13, color: Color(AppColors.text), fontWeight: FontWeight.w600),
                          textDirection: TextDirection.rtl),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Notes
          if (spec.notes != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.warm).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('💡', style: TextStyle(fontSize: 15)),
                      SizedBox(width: 6),
                      Text('ملاحظات',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          textDirection: TextDirection.rtl),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(spec.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.5),
                      textDirection: TextDirection.rtl),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _waBtn(String? phone) {
    return GestureDetector(
      onTap: () {
        buildWhatsAppLink(phone);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فتح واتساب...', textDirection: TextDirection.rtl)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(AppColors.whatsapp).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(AppColors.whatsapp).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.chat_rounded, size: 16, color: Color(AppColors.whatsapp)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD ASSET SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddAssetSheet extends StatefulWidget {
  const _AddAssetSheet();

  @override
  State<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends State<_AddAssetSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _compoundCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'بيع';
  String _location = 'مدينتي';
  String _type = 'شقة';
  String _finishing = 'سوبر لوكس';
  int _bedrooms = 3;

  final _locations = ['مدينتي', 'نور سيتي', 'التجمع الخامس', 'الرحاب', 'الشيخ زايد'];
  final _types = ['شقة', 'فيلا', 'دوبلكس', 'بنتهاوس', 'وحدة تجارية'];
  final _finishings = ['سوبر لوكس', 'تشطيب كامل', 'نصف تشطيب', 'أوف بلان', 'أي تشطيب'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _compoundCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.navy).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_home_outlined, color: Color(AppColors.navy), size: 20),
                ),
                const SizedBox(width: 10),
                const Text('إضافة أصل جديد',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(AppColors.navy)),
                    textDirection: TextDirection.rtl),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                  _field('اسم / رمز الأصل', _nameCtrl, hint: 'NOUR-3 — شقة بريفادو'),
                  const SizedBox(height: 14),
                  _label('وضع الأصل'),
                  Row(
                    children: ['بيع', 'شراء'].map((m) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mode = m),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _mode == m ? const Color(AppColors.navy) : const Color(AppColors.bg),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _mode == m ? const Color(AppColors.navy) : const Color(AppColors.border),
                            ),
                          ),
                          child: Text(m,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _mode == m ? Colors.white : const Color(AppColors.text),
                                fontWeight: FontWeight.w600,
                              ),
                              textDirection: TextDirection.rtl),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                  _label('الموقع'),
                  _dropdown(_location, _locations, (v) => setState(() => _location = v!)),
                  const SizedBox(height: 14),
                  _field('الكومباوند', _compoundCtrl, hint: 'اسم الكومباوند'),
                  const SizedBox(height: 14),
                  _label('نوع العقار'),
                  _dropdown(_type, _types, (v) => setState(() => _type = v!)),
                  const SizedBox(height: 14),
                  _label('التشطيب'),
                  _dropdown(_finishing, _finishings, (v) => setState(() => _finishing = v!)),
                  const SizedBox(height: 14),
                  _field(_mode == 'شراء' ? 'الميزانية (EGP)' : 'السعر (EGP)', _priceCtrl, hint: '4500000', isNumber: true),
                  const SizedBox(height: 14),
                  _field('المساحة (م²)', _areaCtrl, hint: '138', isNumber: true),
                  const SizedBox(height: 14),
                  _label('غرف النوم'),
                  Row(
                    children: [1, 2, 3, 4, 5, 6].map((b) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _bedrooms = b),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          height: 44,
                          decoration: BoxDecoration(
                            color: _bedrooms == b ? const Color(AppColors.navy) : const Color(AppColors.bg),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _bedrooms == b ? const Color(AppColors.navy) : const Color(AppColors.border),
                            ),
                          ),
                          child: Center(
                            child: Text('$b',
                                style: TextStyle(
                                  color: _bedrooms == b ? Colors.white : const Color(AppColors.text),
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                  _field('ملاحظات', _notesCtrl,
                      hint: 'أي تفاصيل إضافية — إطلالة، موقع، مميزات...', maxLines: 3),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ تم حفظ الأصل — سيظهر بعد المزامنة',
                                textDirection: TextDirection.rtl),
                            backgroundColor: Color(AppColors.live),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppColors.navy),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                      label: const Text('حفظ الأصل',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          textDirection: TextDirection.rtl),
                    ),
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(fontSize: 13, color: Color(AppColors.muted), fontWeight: FontWeight.w600),
        textDirection: TextDirection.rtl),
  );

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(AppColors.blue), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(AppColors.border)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(AppColors.border)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(AppColors.blue), width: 2),
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i, textDirection: TextDirection.rtl)))
          .toList(),
    );
  }
}
