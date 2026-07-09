// lib/widgets/hot_alert_banner.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/formatters.dart';

class HotAlertBanner extends StatefulWidget {
  final HotMatchAlert alert;
  final VoidCallback onDismiss;

  const HotAlertBanner({super.key, required this.alert, required this.onDismiss});

  @override
  State<HotAlertBanner> createState() => _HotAlertBannerState();
}

class _HotAlertBannerState extends State<HotAlertBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66EF4444),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'تطابق جديد HOT — ${widget.alert.location ?? 'عقار'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${widget.alert.score}%  |  ${formatPrice(widget.alert.price)}  |  ${widget.alert.location ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _bannerBtn(
                      icon: Icons.call_rounded,
                      label: 'اتصال',
                      onTap: () async {
                        final phone = widget.alert.phone;
                        if (phone == null) return;
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                    ),
                    const SizedBox(width: 8),
                    _bannerBtn(
                      icon: Icons.chat_rounded,
                      label: 'واتساب',
                      onTap: () async {
                        final link = widget.alert.waLink ?? buildWhatsAppLink(widget.alert.phone);
                        if (link == null) return;
                        final uri = Uri.parse(link);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
