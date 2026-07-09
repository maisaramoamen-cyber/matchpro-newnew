// lib/services/api_service.dart
// MatchPro™ — Crystal Power Investments
// LIVE backend: Render.com — https://matchpro-backend.onrender.com
// All calls use JWT Bearer auth. Zero demo branches.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  static String? _token;
  static final http.Client _client = http.Client();

  // ── Token management ───────────────────────────────────────────────────────
  static void setToken(String? token) => _token = token;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Core HTTP helpers ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}$path');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }
      if (kDebugMode) debugPrint('GET $uri');
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (kDebugMode) debugPrint('  → ${res.statusCode}');
      if (res.statusCode == 401) throw ApiException('غير مصرح — سجّل دخولك مرة أخرى', 401);
      if (res.statusCode >= 400) throw ApiException('خطأ ${res.statusCode}: $path', res.statusCode);
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      // Some endpoints return a bare list — wrap it
      if (decoded is List) return {'_list': decoded};
      return {};
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('GET $path error: $e');
      throw ApiException('خطأ في الاتصال: $e', 0);
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}$path');
      if (kDebugMode) debugPrint('POST $uri');
      final res = await _client
          .post(uri, headers: _headers, body: json.encode(body))
          .timeout(timeout);
      if (kDebugMode) debugPrint('  → ${res.statusCode}');
      if (res.statusCode == 401) throw ApiException('غير مصرح', 401);
      if (res.statusCode >= 400) throw ApiException('خطأ ${res.statusCode}: $path', res.statusCode);
      final decoded = json.decode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {'ok': true};
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('POST $path error: $e');
      throw ApiException('خطأ في الإرسال: $e', 0);
    }
  }

  // ── Health check ───────────────────────────────────────────────────────────
  /// Returns true if the Render backend is reachable.
  static Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/health');
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /api/auth/login → { token, user: { name, role } }
  static Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    try {
      // Wake Render instance if sleeping (first call can take 30s)
      final res = await _post(
        '/api/auth/login',
        {'username': username, 'password': password},
        timeout: const Duration(seconds: 40),
      );
      return res.containsKey('token') ? res : null;
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('Login error: ${e.message}');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/dashboard → real SQLite counts + quality metrics + WA state
  /// Falls back to GET /api/stats if dashboard route doesn't exist.
  static Future<DashboardStats> getStats() async {
    try {
      // Primary: /api/dashboard (returns stats + qualityMetrics + msgVolume)
      final data = await _get('/api/dashboard');
      return _parseDashboard(data);
    } catch (_) {
      try {
        // Fallback: /api/stats
        final data = await _get('/api/stats');
        return _parseDashboard(data);
      } catch (e) {
        if (kDebugMode) debugPrint('getStats failed: $e');
        rethrow;
      }
    }
  }

  static DashboardStats _parseDashboard(Map<String, dynamic> data) {
    // /api/dashboard wraps counts under data.stats
    final stats = data['stats'] as Map<String, dynamic>? ?? data;

    // demandByLocation → top locations list
    final byLoc = data['demandByLocation'] as List<dynamic>? ?? [];
    final topLocs = byLoc.map((e) {
      final m = e as Map<String, dynamic>;
      return LocationStat(
        location: m['location'] as String? ?? m['normalized_location'] as String? ?? '',
        count: (m['count'] as num?)?.toInt() ?? 0,
        demandCount: (m['count'] as num?)?.toInt(),
      );
    }).toList();

    // WhatsApp status
    final waData = data['waStatus'] as Map<String, dynamic>? ?? {};
    final waConnected = waData['connected'] as bool? ??
        stats['whatsapp_connected'] as bool? ??
        false;

    return DashboardStats(
      supplyCount: (stats['supply_count'] as num?)?.toInt() ??
          (stats['supply'] as num?)?.toInt() ?? 0,
      demandCount: (stats['demand_count'] as num?)?.toInt() ??
          (stats['demand'] as num?)?.toInt() ?? 0,
      messagesCount: (stats['messages_count'] as num?)?.toInt() ??
          (stats['messages'] as num?)?.toInt() ?? 0,
      hotMatchesToday: (stats['hot_matches_today'] as num?)?.toInt() ??
          (stats['hot_matches'] as num?)?.toInt() ?? 0,
      warmMatchesToday: (stats['warm_matches_today'] as num?)?.toInt() ??
          (stats['warm_matches'] as num?)?.toInt() ?? 0,
      topLocations: topLocs,
      whatsappConnected: waConnected,
      lastSync: stats['last_sync'] != null
          ? DateTime.tryParse(stats['last_sync'] as String)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MATCHES
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/matches → real SQLite rows sorted by match_score DESC
  /// Supports ?location=&grade=&limit= filters
  static Future<List<Match>> getMatches({
    String? location,
    String? grade,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (location != null && location.isNotEmpty) query['location'] = location;
    if (grade != null && grade.isNotEmpty) query['grade'] = grade;

    try {
      final data = await _get('/api/matches', query: query);
      final list = data['matches'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return list
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } catch (e) {
      if (kDebugMode) debugPrint('getMatches error: $e');
      rethrow;
    }
  }

  /// POST /api/run-matching → trigger SACRED engine, return fresh matches
  static Future<List<Match>> runMatching() async {
    try {
      final data = await _post('/api/run-matching', {}, timeout: const Duration(seconds: 60));
      final list = data['matches'] as List<dynamic>? ?? [];
      return list
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } catch (e) {
      if (kDebugMode) debugPrint('runMatching error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARKET / LOCATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/locations/stats → real Cairo location data + baseline fallback
  static Future<List<LocationStat>> getLocationStats() async {
    try {
      final data = await _get('/api/locations/stats');
      final list = data['locations'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return list
          .map((e) => LocationStat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getLocationStats error: $e');
      rethrow;
    }
  }

  /// GET /api/market/overview → aggregate market intelligence
  static Future<Map<String, dynamic>> getMarketOverview() async {
    try {
      return await _get('/api/market/overview');
    } catch (e) {
      if (kDebugMode) debugPrint('getMarketOverview error: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/reports/list → list of generated Excel files
  static Future<List<Report>> getReports() async {
    try {
      final data = await _get('/api/reports/list');
      final raw = data['reports'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return raw.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) debugPrint('getReports error: $e');
      rethrow;
    }
  }

  /// Full download URL for a report file
  static String reportDownloadUrl(String filename) =>
      '${AppConfig.baseUrl}/api/reports/download/$filename';

  /// POST /api/reports/generate → trigger fresh Excel report generation
  static Future<bool> generateReports() async {
    try {
      final res = await _post('/api/reports/generate', {},
          timeout: const Duration(seconds: 90));
      return res['ok'] == true || res['queued'] == true || res['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('generateReports error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRM PIPELINE
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/pipeline → live leads from SQLite pipeline table
  static Future<List<CRMLead>> getPipeline() async {
    try {
      final data = await _get('/api/pipeline');
      final raw = data['leads'] as List<dynamic>?
          ?? data['pipeline'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return raw.map((e) => CRMLead.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getPipeline error: $e');
      rethrow;
    }
  }

  /// POST /api/pipeline → create or update lead stage
  static Future<bool> updatePipelineStage(
    String leadId,
    String stage,
    String? notes,
  ) async {
    try {
      final body = <String, dynamic>{
        'lead_id': leadId,
        'stage': stage,
        if (notes != null) 'notes': notes,
      };
      final res = await _post('/api/pipeline', body);
      return res['ok'] == true || res['success'] == true || res['id'] != null;
    } catch (e) {
      if (kDebugMode) debugPrint('updatePipelineStage error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ASSETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/assets → CPI assets from SQLite (or returns empty if not wired)
  static Future<List<Map<String, dynamic>>> getAssets() async {
    try {
      final data = await _get('/api/assets');
      final raw = data['assets'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getAssets error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WHATSAPP / BAILEYS
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/wa/status → Baileys connection state
  static Future<Map<String, dynamic>> getWaStatus() async {
    try {
      return await _get('/api/wa/status');
    } catch (_) {
      try {
        return await _get('/api/baileys/status');
      } catch (e) {
        if (kDebugMode) debugPrint('getWaStatus error: $e');
        return {'connected': false, 'state': 'error'};
      }
    }
  }

  /// POST /api/baileys/start → initiate Baileys WA connection
  static Future<Map<String, dynamic>> startBaileys() async {
    try {
      return await _post('/api/baileys/start', {});
    } catch (e) {
      if (kDebugMode) debugPrint('startBaileys error: $e');
      return {'ok': false};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BROKERS / ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/brokers → real broker activity from SQLite
  static Future<List<Map<String, dynamic>>> getBrokers() async {
    try {
      final data = await _get('/api/brokers');
      final raw = data['brokers'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getBrokers error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/messages → recent WhatsApp messages from SQLite
  static Future<List<Map<String, dynamic>>> getMessages({int limit = 50}) async {
    try {
      final data = await _get('/api/messages', query: {'limit': '$limit'});
      final raw = data['messages'] as List<dynamic>?
          ?? data['_list'] as List<dynamic>?
          ?? [];
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getMessages error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ETL / SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /api/etl-trigger → manual matching cycle
  static Future<bool> triggerEtl() async {
    try {
      final res = await _post('/api/etl-trigger', {'source': 'manual'},
          timeout: const Duration(seconds: 30));
      return res['ok'] == true || res['queued'] == true || res['started'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('triggerEtl error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS (backend-side config)
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/settings → backend scheduler + group config
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      return await _get('/api/settings');
    } catch (e) {
      if (kDebugMode) debugPrint('getSettings error: $e');
      return {};
    }
  }

  /// POST /api/settings → update backend settings
  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final res = await _post('/api/settings', settings);
      return res['ok'] == true || res['success'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('updateSettings error: $e');
      return false;
    }
  }
}

// ── Exception type ─────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
