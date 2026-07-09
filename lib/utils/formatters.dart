// lib/utils/formatters.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
// ignore: unused_import
import '../config/app_config.dart';

String formatPrice(int? egp) {
  if (egp == null) return 'السعر غير محدد';
  if (egp >= 1000000) return '${(egp / 1000000).toStringAsFixed(1)}M EGP';
  if (egp >= 1000) return '${(egp ~/ 1000)}K EGP';
  return '$egp EGP';
}

String? buildWhatsAppLink(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final intl = digits.startsWith('0') ? '2$digits' : digits;
  return 'https://wa.me/$intl';
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  final h = diff.inHours;
  if (h < 1) return 'منذ أقل من ساعة';
  if (h < 24) return 'منذ $h ساعة';
  return 'منذ ${diff.inDays} يوم';
}

Color gradeColor(MatchGrade grade) {
  return Color(grade.color);
}

Color gradeColorFromString(String? s) {
  return gradeColor(gradeFromString(s));
}

String formatArea(double? sqm) {
  if (sqm == null) return '—';
  return '${sqm.toStringAsFixed(0)} م²';
}

String formatBedrooms(int? br) {
  if (br == null) return '—';
  return '$br غرف';
}

String gradeLabel(MatchGrade grade) => grade.label;

IconData gradeIcon(MatchGrade grade) {
  switch (grade) {
    case MatchGrade.hot: return Icons.local_fire_department;
    case MatchGrade.warm: return Icons.bolt;
    case MatchGrade.cool: return Icons.water_drop;
    case MatchGrade.cold: return Icons.ac_unit;
  }
}

/// SACRED client-side scoring (mirrors backend logic)
int sacredScore({
  required String? supplyLocation,
  required String? demandLocation,
  required int? supplyPrice,
  required int? demandBudgetMin,
  required int? demandBudgetMax,
  required int? supplyBedrooms,
  required int? demandBedrooms,
  required double? supplyArea,
  required double? demandArea,
  required DateTime supplyCreatedAt,
  required String? supplyUrgency,
}) {
  int score = 0;

  // Location (40pts)
  final sl = (supplyLocation ?? '').toLowerCase();
  final dl = (demandLocation ?? '').toLowerCase();
  if (sl.isNotEmpty && dl.isNotEmpty) {
    if (sl == dl) {
      score += 40;
    } else if (sl.contains(dl) || dl.contains(sl)) {
      score += 25;
    }
  }

  // Price (35pts)
  if (supplyPrice != null && (demandBudgetMin != null || demandBudgetMax != null)) {
    final min = demandBudgetMin ?? 0;
    final max = demandBudgetMax ?? double.maxFinite.toInt();
    if (supplyPrice >= min && supplyPrice <= max) {
      score += 35;
    } else if (supplyPrice <= max * 1.1) {
      score += 20;
    } else if (supplyPrice <= max * 1.25) {
      score += 10;
    }
  }

  // Specs (25pts)
  int specsScore = 0;
  if (supplyBedrooms != null && demandBedrooms != null) {
    specsScore += supplyBedrooms == demandBedrooms ? 15 : (supplyBedrooms - demandBedrooms).abs() <= 1 ? 8 : 0;
  }
  if (supplyArea != null && demandArea != null) {
    final diff = (supplyArea - demandArea).abs() / demandArea;
    specsScore += diff <= 0.1 ? 10 : diff <= 0.2 ? 6 : 0;
  }
  score += specsScore.clamp(0, 25);

  // Bonuses
  final age = DateTime.now().difference(supplyCreatedAt).inHours;
  if (age < 24) score += 5;
  if ((supplyUrgency ?? '') == 'urgent') score += 5;

  return score.clamp(0, 100);
}
