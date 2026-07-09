// lib/screens/wa_screen.dart
// MatchPro™ — WhatsApp / Baileys Connection Screen
// QR scan → link WA → live group list + status monitor

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class WaScreen extends StatefulWidget {
  const WaScreen({super.key});

  @override
  State<WaScreen> createState() => _WaScreenState();
}

class _WaScreenState extends State<WaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchBaileysStatus();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(AppColors.live),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _doStart() async {
    setState(() => _actionBusy = true);
    final ok = await context.read<AppProvider>().startBaileys();
    if (mounted) {
      setState(() => _actionBusy = false);
      _showSnack(ok ? '✅ جاري تشغيل واتساب — امسح الـ QR' : '❌ فشل التشغيل', isError: !ok);
    }
  }

  Future<void> _doStop() async {
    final confirmed = await _confirmDialog(
      title: 'إيقاف واتساب',
      body: 'سيتم قطع الاتصال بواتساب. يمكنك إعادة الربط لاحقاً.',
      confirmLabel: 'إيقاف',
      confirmColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    final ok = await context.read<AppProvider>().stopBaileys();
    if (mounted) {
      setState(() => _actionBusy = false);
      _showSnack(ok ? '⏹️ تم إيقاف واتساب' : '❌ فشل الإيقاف', isError: !ok);
    }
  }

  Future<void> _doReset() async {
    final confirmed = await _confirmDialog(
      title: 'تجديد الـ QR',
      body: 'سيتم مسح الجلسة الحالية وإنشاء QR جديد. ستحتاج لربط واتساب مرة أخرى.',
      confirmLabel: 'تجديد',
      confirmColor: const Color(AppColors.warm),
    );
    if (confirmed != true) return;
    setState(() => _actionBusy = true);
    final ok = await context.read<AppProvider>().resetBaileys();
    if (mounted) {
      setState(() => _actionBusy = false);
      _showSnack(ok ? '🔄 تم التجديد — امسح الـ QR الجديد' : '❌ فشل التجديد', isError: !ok);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(AppColors.navy))),
        content: Text(body, textDirection: TextDirection.rtl,
            style: const TextStyle(color: Color(AppColors.text))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Color(AppColors.muted)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.navy),
        title: const Text('واتساب',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            onPressed: () => context.read<AppProvider>().fetchBaileysStatus(),
            tooltip: 'تحديث',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(AppColors.live),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner, size: 18), text: 'الربط'),
            Tab(icon: Icon(Icons.group_outlined, size: 18), text: 'المجموعات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ConnectionTab(
            onStart: _doStart,
            onStop: _doStop,
            onReset: _doReset,
            actionBusy: _actionBusy,
          ),
          const _GroupsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONNECTION TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ConnectionTab extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final bool actionBusy;

  const _ConnectionTab({
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.actionBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, prov, _) {
      final connected = prov.baileysConnected;
      final state = prov.baileysWaState;
      final st = prov.baileysState;
      final qr = prov.baileysQrBase64;
      final busy = prov.baileysLoading || actionBusy;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _StatusCard(connected: connected, state: state, st: st, isLoading: busy),
            const SizedBox(height: 20),
            if (connected)
              _ConnectedCard(phone: st['phone']?.toString())
            else
              _QrSection(qr: qr, state: state, isLoading: busy),
            const SizedBox(height: 20),
            _ControlButtons(
              connected: connected,
              isLoading: busy,
              onStart: onStart,
              onStop: onStop,
              onReset: onReset,
            ),
            if (!connected) ...[
              const SizedBox(height: 20),
              const _HowToCard(),
            ],
          ],
        ),
      );
    });
  }
}

// ── Status card ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final bool connected;
  final String state;
  final Map<String, dynamic> st;
  final bool isLoading;

  const _StatusCard({
    required this.connected,
    required this.state,
    required this.st,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final Color dot;
    final Color bg;
    final String label;

    switch (state) {
      case 'open':
      case 'connected':
        dot = const Color(AppColors.live);
        bg = const Color(0xFFF0FDF4);
        label = 'متصل ✅';
        break;
      case 'qr_ready':
        dot = const Color(AppColors.warm);
        bg = const Color(0xFFFFFBEB);
        label = 'في انتظار المسح 📱';
        break;
      case 'connecting':
        dot = const Color(AppColors.blue);
        bg = const Color(0xFFEFF6FF);
        label = 'جاري الاتصال...';
        break;
      case 'error':
        dot = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        label = 'خطأ في الاتصال';
        break;
      default:
        dot = const Color(AppColors.muted);
        bg = const Color(AppColors.bg);
        label = 'غير متصل';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dot.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Status dot with pulse ring
          Stack(
            alignment: Alignment.center,
            children: [
              if (connected || state == 'qr_ready')
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dot.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading ? 'جاري التحديث...' : label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dot),
                  textDirection: TextDirection.rtl,
                ),
                if (st['phone'] != null && connected)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('📞 ${st['phone']}',
                        style: const TextStyle(fontSize: 12, color: Color(AppColors.muted))),
                  ),
                if ((st['reconnects'] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('🔄 إعادة الاتصال: ${st['reconnects']}',
                        style: const TextStyle(fontSize: 11, color: Color(AppColors.muted))),
                  ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(AppColors.navy)),
            ),
        ],
      ),
    );
  }
}

// ── QR section ────────────────────────────────────────────────────────────────
class _QrSection extends StatelessWidget {
  final String? qr;
  final String state;
  final bool isLoading;

  const _QrSection({required this.qr, required this.state, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (qr != null && qr!.isNotEmpty) {
      return _QrCard(qrBase64: qr!);
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Center(
        child: isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(AppColors.navy)),
                  SizedBox(height: 14),
                  Text('جاري تحميل الـ QR...',
                      style: TextStyle(color: Color(AppColors.muted), fontSize: 13)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2,
                      size: 60,
                      color: const Color(AppColors.navy).withValues(alpha: 0.2)),
                  const SizedBox(height: 14),
                  Text(
                    state == 'error'
                        ? 'خطأ في توليد الـ QR\nاضغط تجديد'
                        : 'اضغط "تشغيل واتساب"\nلتوليد رمز الـ QR',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(AppColors.muted),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
      ),
    );
  }
}

// ── QR image card ─────────────────────────────────────────────────────────────
class _QrCard extends StatelessWidget {
  final String qrBase64;
  const _QrCard({required this.qrBase64});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      String b64 = qrBase64;
      if (b64.contains(',')) b64 = b64.split(',').last;
      bytes = base64Decode(b64);
    } catch (_) {
      bytes = null;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(AppColors.warm), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('QR جاهز — امسح الآن',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(AppColors.warm))),
              const SizedBox(width: 8),
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(AppColors.warm), shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 16),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            )
          else
            const SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: Text('تعذّر عرض الـ QR',
                    style: TextStyle(color: Color(AppColors.muted))),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'سيتجدد الـ QR تلقائياً إذا انتهت صلاحيته\nانتظر ثواني بعد المسح',
            style: TextStyle(fontSize: 11, color: Color(AppColors.muted)),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Connected success card ────────────────────────────────────────────────────
class _ConnectedCard extends StatelessWidget {
  final String? phone;
  const _ConnectedCard({this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('واتساب متصل بنجاح',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textDirection: TextDirection.rtl),
          if (phone != null) ...[
            const SizedBox(height: 6),
            Text('📞 $phone',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'الرسائل الجديدة تصل تلقائياً 🚀',
              style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control buttons ───────────────────────────────────────────────────────────
class _ControlButtons extends StatelessWidget {
  final bool connected;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;

  const _ControlButtons({
    required this.connected,
    required this.isLoading,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!connected)
          _actionBtn(
            label: 'تشغيل واتساب',
            icon: Icons.play_circle_filled,
            color: const Color(AppColors.navy),
            onTap: isLoading ? null : onStart,
            isLoading: isLoading,
          ),
        if (connected) ...[
          _actionBtn(
            label: 'إيقاف واتساب',
            icon: Icons.stop_circle_outlined,
            color: const Color(0xFFDC2626),
            onTap: isLoading ? null : onStop,
          ),
          const SizedBox(height: 10),
        ],
        if (!isLoading) ...[
          const SizedBox(height: 10),
          _actionBtn(
            label: 'تجديد الـ QR',
            icon: Icons.qr_code_2,
            color: const Color(AppColors.warm),
            onTap: onReset,
            outline: true,
          ),
        ],
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool outline = false,
    bool isLoading = false,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outline
              ? Colors.transparent
              : (disabled ? color.withValues(alpha: 0.3) : color),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled ? color.withValues(alpha: 0.3) : color,
            width: outline ? 1.5 : 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: outline ? color : Colors.white),
              )
            else
              Icon(icon, color: outline ? color : Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: outline ? color : Colors.white,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}

// ── How-to steps card ─────────────────────────────────────────────────────────
class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      '1. افتح واتساب على هاتفك',
      '2. اضغط ⋮ القائمة → "الأجهزة المرتبطة"',
      '3. اضغط "ربط جهاز"',
      '4. امسح الـ QR الظاهر بالأعلى',
      '5. انتظر ثواني — سيتحول الحالة لـ "متصل" ✅',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.navy).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('كيفية ربط واتساب',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(AppColors.navy)),
                  textDirection: TextDirection.rtl),
              SizedBox(width: 8),
              Text('📋', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s,
                    style:
                        const TextStyle(fontSize: 12, color: Color(AppColors.text)),
                    textDirection: TextDirection.rtl),
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GROUPS TAB
// ══════════════════════════════════════════════════════════════════════════════
class _GroupsTab extends StatefulWidget {
  const _GroupsTab();

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AppProvider>();
      if (prov.baileysConnected) _load();
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final groups = await ApiService.getBaileysGroups();
      if (mounted) setState(() => _groups = groups);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, prov, _) {
      final connected = prov.baileysConnected;

      if (!connected) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_outlined,
                  size: 64,
                  color: const Color(AppColors.muted).withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'يجب ربط واتساب أولاً\nاذهب لتبويب "الربط"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(AppColors.muted), fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Text('${_groups.length} مجموعة',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(AppColors.navy)),
                    textDirection: TextDirection.rtl),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : _load,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.navy).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(AppColors.navy).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        _loading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(AppColors.navy)))
                            : const Icon(Icons.refresh,
                                size: 14, color: Color(AppColors.navy)),
                        const SizedBox(width: 6),
                        const Text('تحديث',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(AppColors.navy),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading && _groups.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(AppColors.navy)))
                : _groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text(
                              'لم يتم العثور على مجموعات\nاضغط تحديث بعد ربط واتساب',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Color(AppColors.muted), fontSize: 13),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _GroupCard(group: _groups[i]),
                      ),
          ),
        ],
      );
    });
  }
}

// ── Group card ────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final name = group['subject']?.toString() ??
        group['name']?.toString() ??
        group['id']?.toString() ??
        'مجموعة';
    final participants =
        (group['participants'] as List?)?.length ??
        group['participant_count'] ??
        0;
    final id = group['id']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(AppColors.navy), Color(0xFF2C5282)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('💬', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(AppColors.text)),
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                if (participants != 0)
                  Text('$participants مشارك',
                      style: const TextStyle(
                          fontSize: 11, color: Color(AppColors.muted)),
                      textDirection: TextDirection.rtl),
                if (id.isNotEmpty)
                  Text(
                    id.length > 30 ? '${id.substring(0, 30)}...' : id,
                    style:
                        const TextStyle(fontSize: 10, color: Color(AppColors.muted)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(AppColors.live).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('نشطة',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(AppColors.live),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
