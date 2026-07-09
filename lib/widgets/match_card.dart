// lib/widgets/match_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import 'grade_chip.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;
  final bool compact;

  const MatchCard({super.key, required this.match, this.onTap, this.compact = false});

  void _openWhatsApp(String? phone) async {
    final link = buildWhatsAppLink(phone);
    if (link == null) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(match.grade);
    final isHot = match.grade == MatchGrade.hot;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHot ? color.withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
            width: isHot ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isHot ? color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  GradeChip(grade: match.grade),
                  const SizedBox(width: 8),
                  Text(
                    '${match.score}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (match.supply.location != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 13, color: const Color(0xFF6B7280)),
                        const SizedBox(width: 2),
                        Text(
                          match.supply.location!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo(match.supply.createdAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supply row
                  _infoRow(
                    label: 'عرض',
                    icon: Icons.home_outlined,
                    iconColor: const Color(0xFF2563EB),
                    text: _supplyText(),
                  ),
                  const Divider(height: 16, color: Color(0xFFF3F4F6)),
                  // Demand row
                  _infoRow(
                    label: 'طلب',
                    icon: Icons.person_search,
                    iconColor: const Color(0xFF7C3AED),
                    text: _demandText(),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      _actionBtn(
                        icon: Icons.chat_rounded,
                        label: 'واتساب',
                        color: const Color(0xFF25D366),
                        onTap: () => _openWhatsApp(match.supply.senderPhone),
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        icon: Icons.call_rounded,
                        label: 'اتصال',
                        color: const Color(0xFF2563EB),
                        onTap: () async {
                          final phone = match.supply.senderPhone;
                          if (phone == null) return;
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: Color(0xFF6B7280)),
                            SizedBox(width: 4),
                            Text('التفاصيل', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
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

  String _supplyText() {
    final parts = <String>[];
    if (match.supply.propertyType != null) parts.add(match.supply.propertyType!);
    if (match.supply.areaSqm != null) parts.add('${match.supply.areaSqm!.toInt()} م²');
    if (match.supply.price != null) parts.add(formatPrice(match.supply.price));
    if (match.supply.bedrooms != null) parts.add('${match.supply.bedrooms} غرف');
    return parts.join(' | ');
  }

  String _demandText() {
    final parts = <String>[];
    if (match.demand.propertyType != null) parts.add('مشتري ${match.demand.propertyType!}');
    if (match.demand.areaSqm != null) parts.add('${match.demand.areaSqm!.toInt()}-${(match.demand.areaSqm! + 20).toInt()} م²');
    if (match.demand.budgetMax != null) parts.add('≤${formatPrice(match.demand.budgetMax)}');
    return parts.join(' | ');
  }

  Widget _infoRow({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            Text(text,
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827), fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
}


