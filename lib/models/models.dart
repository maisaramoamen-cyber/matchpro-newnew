// lib/models/models.dart — MatchPro™ data models
import 'dart:convert';

// ─── Grade helpers ────────────────────────────────────────────────────────────
enum MatchGrade { hot, warm, cool, cold }

extension MatchGradeExt on MatchGrade {
  String get label {
    switch (this) {
      case MatchGrade.hot: return 'HOT';
      case MatchGrade.warm: return 'WARM';
      case MatchGrade.cool: return 'COOL';
      case MatchGrade.cold: return 'COLD';
    }
  }

  int get color {
    switch (this) {
      case MatchGrade.hot: return 0xFFEF4444;
      case MatchGrade.warm: return 0xFFF59E0B;
      case MatchGrade.cool: return 0xFF3B82F6;
      case MatchGrade.cold: return 0xFF6B7280;
    }
  }

  String get emoji {
    switch (this) {
      case MatchGrade.hot: return '🔥';
      case MatchGrade.warm: return '⚡';
      case MatchGrade.cool: return '💧';
      case MatchGrade.cold: return '❄️';
    }
  }
}

MatchGrade gradeFromScore(int score) {
  if (score >= 80) return MatchGrade.hot;
  if (score >= 60) return MatchGrade.warm;
  if (score >= 40) return MatchGrade.cool;
  return MatchGrade.cold;
}

MatchGrade gradeFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'HOT': return MatchGrade.hot;
    case 'WARM': return MatchGrade.warm;
    case 'COOL': return MatchGrade.cool;
    default: return MatchGrade.cold;
  }
}

// ─── Supply Listing ──────────────────────────────────────────────────────────
class SupplyListing {
  final int id;
  final String rawMessage;
  final String? senderPhone;
  final String? senderName;
  final String? location;
  final String? normalizedLocation;
  final String? propertyType;
  final String purpose;
  final int? price;
  final int? bedrooms;
  final double? areaSqm;
  final String? finishing;
  final bool? furnished;
  final String? urgency;
  final String? groupName;
  final DateTime createdAt;

  const SupplyListing({
    required this.id,
    required this.rawMessage,
    this.senderPhone,
    this.senderName,
    this.location,
    this.normalizedLocation,
    this.propertyType,
    this.purpose = 'sale',
    this.price,
    this.bedrooms,
    this.areaSqm,
    this.finishing,
    this.furnished,
    this.urgency,
    this.groupName,
    required this.createdAt,
  });

  factory SupplyListing.fromJson(Map<String, dynamic> j) => SupplyListing(
    id: j['id'] as int? ?? 0,
    rawMessage: j['raw_message'] as String? ?? '',
    senderPhone: j['sender_phone'] as String?,
    senderName: j['sender_name'] as String?,
    location: j['location'] as String?,
    normalizedLocation: j['normalized_location'] as String?,
    propertyType: j['property_type'] as String?,
    purpose: j['purpose'] as String? ?? 'sale',
    price: j['price'] as int?,
    bedrooms: j['bedrooms'] as int?,
    areaSqm: (j['area_sqm'] as num?)?.toDouble(),
    finishing: j['finishing'] as String?,
    furnished: j['furnished'] as bool?,
    urgency: j['urgency'] as String?,
    groupName: j['group_name'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

// ─── Demand Buyer ─────────────────────────────────────────────────────────────
class DemandBuyer {
  final int id;
  final String rawMessage;
  final String? senderPhone;
  final String? senderName;
  final String? location;
  final String? normalizedLocation;
  final String? propertyType;
  final String purpose;
  final int? budgetMin;
  final int? budgetMax;
  final int? bedrooms;
  final double? areaSqm;
  final String? urgency;
  final String? groupName;
  final DateTime createdAt;

  const DemandBuyer({
    required this.id,
    required this.rawMessage,
    this.senderPhone,
    this.senderName,
    this.location,
    this.normalizedLocation,
    this.propertyType,
    this.purpose = 'buy',
    this.budgetMin,
    this.budgetMax,
    this.bedrooms,
    this.areaSqm,
    this.urgency,
    this.groupName,
    required this.createdAt,
  });

  factory DemandBuyer.fromJson(Map<String, dynamic> j) => DemandBuyer(
    id: j['id'] as int? ?? 0,
    rawMessage: j['raw_message'] as String? ?? '',
    senderPhone: j['sender_phone'] as String?,
    senderName: j['sender_name'] as String?,
    location: j['location'] as String?,
    normalizedLocation: j['normalized_location'] as String?,
    propertyType: j['property_type'] as String?,
    purpose: j['purpose'] as String? ?? 'buy',
    budgetMin: j['budget_min'] as int?,
    budgetMax: j['budget_max'] as int?,
    bedrooms: j['bedrooms'] as int?,
    areaSqm: (j['area_sqm'] as num?)?.toDouble(),
    urgency: j['urgency'] as String?,
    groupName: j['group_name'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

// ─── Match ────────────────────────────────────────────────────────────────────
class ScoreBreakdown {
  final int location;
  final int price;
  final int specs;
  final int recencyBonus;
  final int urgencyBonus;

  const ScoreBreakdown({
    this.location = 0,
    this.price = 0,
    this.specs = 0,
    this.recencyBonus = 0,
    this.urgencyBonus = 0,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
    location: (j['location'] as num?)?.toInt() ?? 0,
    price: (j['price'] as num?)?.toInt() ?? 0,
    specs: (j['specs'] as num?)?.toInt() ?? 0,
    recencyBonus: (j['recency_bonus'] as num?)?.toInt() ?? 0,
    urgencyBonus: (j['urgency_bonus'] as num?)?.toInt() ?? 0,
  );
}

class Match {
  final String id;
  final SupplyListing supply;
  final DemandBuyer demand;
  final int score;
  final MatchGrade grade;
  final ScoreBreakdown breakdown;
  final DateTime createdAt;

  const Match({
    required this.id,
    required this.supply,
    required this.demand,
    required this.score,
    required this.grade,
    required this.breakdown,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> j) {
    // Real backend uses match_score; fallback to score for API consistency
    final score = (j['match_score'] as num?)?.toInt()
        ?? (j['score'] as num?)?.toInt()
        ?? 0;

    // breakdown may be stored as JSON string in SQLite
    Map<String, dynamic> breakdown = {};
    final rawBreakdown = j['breakdown'] ?? j['breakdown_json'] ?? j['score_breakdown'];
    if (rawBreakdown is Map<String, dynamic>) {
      breakdown = rawBreakdown;
    } else if (rawBreakdown is String && rawBreakdown.isNotEmpty) {
      try { breakdown = json.decode(rawBreakdown) as Map<String, dynamic>; } catch (_) {}
    }

    // supply/demand can be nested objects OR flat fields on the match row
    Map<String, dynamic> supplyData = j['supply'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic> demandData = j['demand'] as Map<String, dynamic>? ?? {};

    // Flat-row fallback: backend may return flattened supply_* / demand_* fields
    if (supplyData.isEmpty) {
      supplyData = {
        'id': j['supply_id'],
        'raw_message': j['supply_message'] ?? j['supply_raw'] ?? '',
        'sender_phone': j['supply_phone'] ?? j['seller_phone'],
        'sender_name': j['supply_name'] ?? j['seller_name'],
        'location': j['supply_location'] ?? j['location'],
        'normalized_location': j['normalized_location'] ?? j['location'],
        'property_type': j['property_type'] ?? j['supply_type'],
        'purpose': 'sale',
        'price': j['price'] ?? j['supply_price'],
        'bedrooms': j['bedrooms'] ?? j['supply_bedrooms'],
        'area_sqm': j['area_sqm'] ?? j['supply_area'],
        'finishing': j['finishing'] ?? j['supply_finishing'],
        'group_name': j['group_name'] ?? j['supply_group'],
        'created_at': j['supply_created_at'] ?? j['created_at'],
      };
    }
    if (demandData.isEmpty) {
      demandData = {
        'id': j['demand_id'],
        'raw_message': j['demand_message'] ?? j['demand_raw'] ?? '',
        'sender_phone': j['demand_phone'] ?? j['buyer_phone'],
        'sender_name': j['demand_name'] ?? j['buyer_name'],
        'location': j['demand_location'] ?? j['location'],
        'normalized_location': j['normalized_location'] ?? j['location'],
        'property_type': j['property_type'] ?? j['demand_type'],
        'purpose': 'buy',
        'budget_min': j['budget_min'] ?? j['demand_budget_min'],
        'budget_max': j['budget_max'] ?? j['demand_budget_max'],
        'bedrooms': j['bedrooms'] ?? j['demand_bedrooms'],
        'area_sqm': j['area_sqm'] ?? j['demand_area'],
        'group_name': j['demand_group'],
        'created_at': j['demand_created_at'] ?? j['created_at'],
      };
    }

    return Match(
      id: j['id']?.toString()
          ?? '${j['supply_id']}_${j['demand_id']}_$score',
      supply: SupplyListing.fromJson(supplyData),
      demand: DemandBuyer.fromJson(demandData),
      score: score,
      grade: j['grade'] != null
          ? gradeFromString(j['grade'] as String)
          : gradeFromScore(score),
      breakdown: ScoreBreakdown.fromJson(breakdown),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Dashboard Stats ──────────────────────────────────────────────────────────
class DashboardStats {
  final int supplyCount;
  final int demandCount;
  final int messagesCount;
  final int hotMatchesToday;
  final int warmMatchesToday;
  final List<LocationStat> topLocations;
  final bool whatsappConnected;
  final DateTime? lastSync;

  const DashboardStats({
    this.supplyCount = 0,
    this.demandCount = 0,
    this.messagesCount = 0,
    this.hotMatchesToday = 0,
    this.warmMatchesToday = 0,
    this.topLocations = const [],
    this.whatsappConnected = false,
    this.lastSync,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    // /api/dashboard wraps real counts under j['stats']
    final s = j['stats'] as Map<String, dynamic>? ?? j;
    final topLocs = (j['top_locations'] as List<dynamic>?
            ?? j['demandByLocation'] as List<dynamic>?
            ?? [])
        .map((e) => LocationStat.fromJson(e as Map<String, dynamic>))
        .toList();
    final waData = j['waStatus'] as Map<String, dynamic>? ?? {};
    return DashboardStats(
      supplyCount: (s['supply_count'] as num?)?.toInt()
          ?? (s['supply'] as num?)?.toInt() ?? 0,
      demandCount: (s['demand_count'] as num?)?.toInt()
          ?? (s['demand'] as num?)?.toInt() ?? 0,
      messagesCount: (s['messages_count'] as num?)?.toInt()
          ?? (s['messages'] as num?)?.toInt() ?? 0,
      hotMatchesToday: (s['hot_matches_today'] as num?)?.toInt()
          ?? (s['hot_matches'] as num?)?.toInt() ?? 0,
      warmMatchesToday: (s['warm_matches_today'] as num?)?.toInt()
          ?? (s['warm_matches'] as num?)?.toInt() ?? 0,
      topLocations: topLocs,
      whatsappConnected: waData['connected'] as bool?
          ?? s['whatsapp_connected'] as bool? ?? false,
      lastSync: s['last_sync'] != null
          ? DateTime.tryParse(s['last_sync'] as String)
          : null,
    );
  }
}

class LocationStat {
  final String location;
  final int count;
  final int? supplyCount;
  final int? demandCount;
  final int? avgPrice;
  final int? hotCount;

  const LocationStat({
    required this.location,
    required this.count,
    this.supplyCount,
    this.demandCount,
    this.avgPrice,
    this.hotCount,
  });

  factory LocationStat.fromJson(Map<String, dynamic> j) => LocationStat(
    location: j['location'] as String? ?? j['name'] as String? ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
    supplyCount: (j['supply_count'] as num?)?.toInt(),
    demandCount: (j['demand_count'] as num?)?.toInt(),
    avgPrice: (j['avg_price'] as num?)?.toInt(),
    hotCount: (j['hot_count'] as num?)?.toInt(),
  );
}

// ─── CPI Asset ────────────────────────────────────────────────────────────────
class CPIAsset {
  final String id;
  final String mode; // 'sell' | 'buy'
  final String label;
  final String location;
  final String propertyType;
  final int? minPrice;
  final int? maxPrice;
  final int? bedrooms;
  final double? areaSqm;
  final String? finishing;
  final String? notes;
  final List<Match> matches;
  final int hotCount;
  final int warmCount;

  const CPIAsset({
    required this.id,
    required this.mode,
    required this.label,
    required this.location,
    required this.propertyType,
    this.minPrice,
    this.maxPrice,
    this.bedrooms,
    this.areaSqm,
    this.finishing,
    this.notes,
    this.matches = const [],
    this.hotCount = 0,
    this.warmCount = 0,
  });
}

// ─── Report ───────────────────────────────────────────────────────────────────
class Report {
  final String filename;
  final int size; // bytes
  final DateTime createdAt;
  final String type; // 'multi_area' | 'asset' | 'madinaty' | 'intelligence'
  final String url;

  const Report({
    required this.filename,
    required this.size,
    required this.createdAt,
    required this.type,
    required this.url,
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    filename: j['filename'] as String? ?? '',
    size: (j['size'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    type: j['type'] as String? ?? 'multi_area',
    url: j['url'] as String? ?? '',
  );

  String get displayName {
    if (filename.contains('NOUR')) return 'نور سيتي — مطابقات الأصول';
    if (filename.contains('MAD')) return 'مدينتي — مطابقات الأصول';
    if (filename.contains('ALL_MARKETS')) return 'تقرير السوق الشامل — 10 مناطق';
    if (filename.contains('madinaty')) return 'مدينتي — مبيعات 48h';
    return filename.replaceAll('_', ' ').replaceAll('.xlsx', '');
  }

  String get sizeLabel {
    if (size >= 1024 * 1024) return '${(size / 1024 / 1024).toStringAsFixed(1)}MB';
    if (size >= 1024) return '${(size / 1024).toStringAsFixed(0)}KB';
    return '${size}B';
  }
}

// ─── Hot Match Alert ──────────────────────────────────────────────────────────
class HotMatchAlert {
  final String id;
  final int score;
  final String grade;
  final String? location;
  final int? price;
  final String? phone;
  final String? waLink;
  final String? originalMessage;
  final DateTime timestamp;

  const HotMatchAlert({
    required this.id,
    required this.score,
    required this.grade,
    this.location,
    this.price,
    this.phone,
    this.waLink,
    this.originalMessage,
    required this.timestamp,
  });

  factory HotMatchAlert.fromJson(Map<String, dynamic> j) => HotMatchAlert(
    id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    score: (j['score'] as num?)?.toInt() ?? 0,
    grade: j['grade'] as String? ?? 'HOT',
    location: j['location'] as String?,
    price: (j['price'] as num?)?.toInt(),
    phone: j['phone'] as String?,
    waLink: j['wa_link'] as String? ?? j['waLink'] as String?,
    originalMessage: j['original_message'] as String? ?? j['originalMessage'] as String?,
    timestamp: j['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch((j['timestamp'] as num).toInt())
        : DateTime.now(),
  );
}

// ─── CRM Lead ─────────────────────────────────────────────────────────────────
class CRMLead {
  final String id;
  final String name;
  final String stage; // جديد | تواصل | عرض | تفاوض | إغلاق
  final String? property;
  final String? phone;
  final int? score;
  final String? notes;
  final DateTime? lastContact;

  const CRMLead({
    required this.id,
    required this.name,
    required this.stage,
    this.property,
    this.phone,
    this.score,
    this.notes,
    this.lastContact,
  });

  factory CRMLead.fromJson(Map<String, dynamic> j) => CRMLead(
    id: j['id']?.toString() ?? '',
    name: j['name'] as String? ?? j['lead_name'] as String? ?? 'عميل',
    stage: j['stage'] as String? ?? 'جديد',
    property: j['property'] as String?,
    phone: j['phone'] as String?,
    score: (j['score'] as num?)?.toInt(),
    notes: j['notes'] as String?,
    lastContact: j['last_contact'] != null ? DateTime.tryParse(j['last_contact'] as String) : null,
  );
}
