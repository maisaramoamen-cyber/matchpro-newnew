// lib/widgets/kpi_card.dart
import 'package:flutter/material.dart';

class KPICard extends StatefulWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  final bool pulse;
  final String? subtitle;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.pulse = false,
    this.subtitle,
  });

  @override
  State<KPICard> createState() => _KPICardState();
}

class _KPICardState extends State<KPICard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  late Animation<int> _counter;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulse = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _counter = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
    if (widget.pulse) {
      _ctrl.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _ctrl.reverse();
        } else if (s == AnimationStatus.dismissed) {
          _ctrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Transform.scale(
        scale: widget.pulse ? _pulse.value : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.pulse ? widget.color.withValues(alpha: 0.5) : const Color(0xFFE5E7EB),
              width: widget.pulse ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.pulse
                    ? widget.color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: widget.pulse ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 18),
                    ),
                    const Spacer(),
                    if (widget.pulse)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _counter.value >= 1000
                      ? '${(_counter.value / 1000).toStringAsFixed(1)}K'
                      : '${_counter.value}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.pulse ? widget.color : const Color(0xFF6B7280),
                    fontWeight: widget.pulse ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
