// lib/widgets/grade_chip.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/formatters.dart';

class GradeChip extends StatelessWidget {
  final MatchGrade grade;
  final bool compact;

  const GradeChip({super.key, required this.grade, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    final bg = color.withValues(alpha: 0.15);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(grade.emoji, style: TextStyle(fontSize: compact ? 10 : 13)),
          const SizedBox(width: 3),
          Text(
            grade.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final int score;

  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final grade = gradeFromScore(score);
    final color = gradeColor(grade);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$score%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
