// lib/providers/app_provider.dart
// MatchPro™ — Crystal Power Investments
// Real-time: Socket.IO → newMatch, stats_update, wa_status events
// Backend: Render.com — wakes on first connection (may take 30s)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  // ── Auth ───────────────────────────────────────────────────────────────────
  String? _token;
  String? _userName;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  String? get userName => _userName;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Backend state ──────────────────────────────────────────────────────────
  bool _backendOnline = false;
  bool _backendChecking = false;
  String _backendStatus = 'لم يتم الاتصال';

  bool get backendOnline => _backendOnline;
  bool get backendChecking => _backendChecking;
  String get backendStatus => _backendStatus;

  // ── Data ───────────────────────────────────────────────────────────────────
  DashboardStats? _stats;
  List<Match> _matches = [];
  List<Report> _reports = [];
  List<LocationStat> _locationStats = [];
  List<CRMLead> _crmLeads = [];
  List<HotMatchAlert> _liveAlerts = [];

  DashboardStats? get stats => _stats;
  List<Match> get matches => _matches;
  List<Report> get reports => _reports;
  List<LocationStat> get locationStats => _locationStats;
  List<CRMLead> get crmLeads => _crmLeads;
  List<HotMatchAlert> get liveAlerts => _liveAlerts;

  // ── Socket.IO ──────────────────────────────────────────────────────────────
  sio.Socket? _socket;
  bool _socketConnected = false;
  bool get socketConnected => _socketConnected;

  // ── CPI Assets (5 hardcoded assets — merged with backend match counts) ─────
  List<CPIAsset> _assets = const [
    CPIAsset(
      id: 'NOUR-1',
      mode: 'sell',
      label: 'شقة نور سيتي / بريفادو',
      location: 'نور سيتي',
      propertyType: 'شقة',
      hotCount: 0,
      warmCount: 0,
    ),
    CPIAsset(
      id: 'NOUR-2',
      mode: 'sell',
      label: 'شقة نور سيتي / بريفادو 2',
      location: 'نور سيتي',
      propertyType: 'شقة',
      hotCount: 0,
      warmCount: 0,
    ),
    CPIAsset(
      id: 'MAD-B14-1',
      mode: 'sell',
      label: 'وحدة مدينتي B14',
      location: 'مدينتي',
      propertyType: 'شقة',
      hotCount: 0,
      warmCount: 0,
    ),
    CPIAsset(
      id: 'MAD-B14-2',
      mode: 'sell',
      label: 'وحدة مدينتي B14 / 2',
      location: 'مدينتي',
      propertyType: 'شقة',
      hotCount: 0,
      warmCount: 0,
    ),
    CPIAsset(
      id: 'MAD-WANT-1',
      mode: 'buy',
      label: 'فيلا مطلوبة — مدينتي',
      location: 'مدينتي',
      propertyType: 'فيلا',
      minPrice: 10000000,
      maxPrice: 30000000,
      hotCount: 0,
      warmCount: 0,
    ),
  ];

  List<CPIAsset> get assets => _assets;

  // ── Notification prefs ────────────────────────────────────────────────────
  bool notifHot = true;
  bool notifReport = true;
  bool notifWarm = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userName = prefs.getString('userName');
    if (_token != null) {
      _isLoggedIn = true;
      ApiService.setToken(_token);
    }
    notifyListeners();
    // Silently probe backend on startup (don't block UI)
    _probeBackend();
  }

  Future<void> _probeBackend() async {
    _backendChecking = true;
    _backendStatus = 'جارٍ الاتصال...';
    notifyListeners();
    final online = await ApiService.healthCheck();
    _backendOnline = online;
    _backendStatus = online ? 'متصل ✅' : 'غير متصل — جارٍ الإيقاظ...';
    _backendChecking = false;
    notifyListeners();
    if (online && _isLoggedIn) {
      _connectSocket();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Render.com cold starts take up to 40s — timeout is set in ApiService
      final result = await ApiService.login(username, password);
      if (result != null) {
        _token = result['token'] as String;
        final user = result['user'] as Map<String, dynamic>?;
        _userName = user?['name'] as String? ?? username;
        _isLoggedIn = true;
        _backendOnline = true;
        _backendStatus = 'متصل ✅';
        ApiService.setToken(_token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('userName', _userName ?? '');
        _isLoading = false;
        notifyListeners();
        // Connect real-time socket after login
        _connectSocket();
        return true;
      } else {
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        _error = 'كلمة المرور غير صحيحة';
      } else if (msg.contains('timeout') || msg.contains('Connection')) {
        _error = 'السيرفر في وضع السكون — انتظر 30 ثانية وحاول مرة أخرى';
      } else {
        _error = 'خطأ في الاتصال — تحقق من الإنترنت';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _disconnectSocket();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userName');
    _token = null;
    _userName = null;
    _isLoggedIn = false;
    _backendOnline = false;
    _backendStatus = 'لم يتم الاتصال';
    ApiService.setToken(null);
    _stats = null;
    _matches = [];
    _reports = [];
    _locationStats = [];
    _crmLeads = [];
    _liveAlerts = [];
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCKET.IO — Real-time events
  // ═══════════════════════════════════════════════════════════════════════════
  void _connectSocket() {
    if (_socket != null) return; // already connected
    if (kDebugMode) debugPrint('Socket.IO: connecting to ${AppConfig.baseUrl}');

    _socket = sio.io(
      AppConfig.baseUrl,
      sio.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .setExtraHeaders({'Authorization': 'Bearer $_token'})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(3000)
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) debugPrint('Socket.IO: connected ✅');
      _socketConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) debugPrint('Socket.IO: disconnected');
      _socketConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((e) {
      if (kDebugMode) debugPrint('Socket.IO connect error: $e');
      _socketConnected = false;
      notifyListeners();
    });

    // ── NEW MATCH event — push HOT alert banner ────────────────────────────
    _socket!.on('newMatch', (data) {
      if (kDebugMode) debugPrint('Socket.IO newMatch: $data');
      try {
        final m = data as Map<String, dynamic>;
        final alert = HotMatchAlert.fromJson({
          'id': m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'score': m['match_score'] ?? m['score'] ?? 0,
          'grade': m['grade'] ?? 'HOT',
          'location': m['location'] ?? m['supply_location'],
          'price': m['price'] ?? m['supply_price'],
          'phone': m['phone'] ?? m['supply_phone'] ?? m['seller_phone'],
          'wa_link': m['wa_link'] ?? m['waLink'],
          'original_message': m['original_message'] ?? m['supply_message'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        addLiveAlert(alert);
        // Refresh matches list in background
        fetchMatches();
      } catch (e) {
        if (kDebugMode) debugPrint('newMatch parse error: $e');
      }
    });

    // ── STATS UPDATE — refresh dashboard counters ──────────────────────────
    _socket!.on('stats_update', (data) {
      if (kDebugMode) debugPrint('Socket.IO stats_update: $data');
      try {
        final m = data as Map<String, dynamic>;
        if (_stats != null) {
          _stats = DashboardStats(
            supplyCount: (m['supply_count'] as num?)?.toInt() ?? _stats!.supplyCount,
            demandCount: (m['demand_count'] as num?)?.toInt() ?? _stats!.demandCount,
            messagesCount: (m['messages_count'] as num?)?.toInt() ?? _stats!.messagesCount,
            hotMatchesToday: (m['hot_matches_today'] as num?)?.toInt() ?? _stats!.hotMatchesToday,
            warmMatchesToday: (m['warm_matches_today'] as num?)?.toInt() ?? _stats!.warmMatchesToday,
            topLocations: _stats!.topLocations,
            whatsappConnected: _stats!.whatsappConnected,
            lastSync: DateTime.now(),
          );
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('stats_update parse error: $e');
      }
    });

    // ── NEW MESSAGE — bump message count ───────────────────────────────────
    _socket!.on('newMessage', (data) {
      if (kDebugMode) debugPrint('Socket.IO newMessage');
      if (_stats != null) {
        _stats = DashboardStats(
          supplyCount: _stats!.supplyCount,
          demandCount: _stats!.demandCount,
          messagesCount: _stats!.messagesCount + 1,
          hotMatchesToday: _stats!.hotMatchesToday,
          warmMatchesToday: _stats!.warmMatchesToday,
          topLocations: _stats!.topLocations,
          whatsappConnected: _stats!.whatsappConnected,
          lastSync: DateTime.now(),
        );
        notifyListeners();
      }
    });

    // ── WA STATUS change ───────────────────────────────────────────────────
    _socket!.on('wa_status', (data) {
      if (kDebugMode) debugPrint('Socket.IO wa_status: $data');
      try {
        final m = data as Map<String, dynamic>;
        final connected = m['connected'] as bool? ?? false;
        if (_stats != null) {
          _stats = DashboardStats(
            supplyCount: _stats!.supplyCount,
            demandCount: _stats!.demandCount,
            messagesCount: _stats!.messagesCount,
            hotMatchesToday: _stats!.hotMatchesToday,
            warmMatchesToday: _stats!.warmMatchesToday,
            topLocations: _stats!.topLocations,
            whatsappConnected: connected,
            lastSync: _stats!.lastSync,
          );
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('wa_status parse error: $e');
      }
    });

    _socket!.connect();
  }

  void _disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _socketConnected = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA FETCHING
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> fetchStats() async {
    try {
      _stats = await ApiService.getStats();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchStats error: $e');
      // Keep stale data — don't clear on error
    }
  }

  Future<void> fetchMatches({String? location, String? grade}) async {
    try {
      _matches = await ApiService.getMatches(location: location, grade: grade);
      // Update asset hot/warm counts based on real matches
      _updateAssetMatchCounts();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchMatches error: $e');
    }
  }

  /// Merge live match counts into asset cards
  void _updateAssetMatchCounts() {
    final matchesByLoc = <String, List<Match>>{};
    for (final m in _matches) {
      final loc = m.supply.normalizedLocation ?? m.supply.location ?? '';
      matchesByLoc.putIfAbsent(loc, () => []).add(m);
    }

    _assets = _assets.map((a) {
      final locMatches = matchesByLoc[a.location] ?? [];
      final hot = locMatches.where((m) => m.grade == MatchGrade.hot).length;
      final warm = locMatches.where((m) => m.grade == MatchGrade.warm).length;
      return CPIAsset(
        id: a.id,
        mode: a.mode,
        label: a.label,
        location: a.location,
        propertyType: a.propertyType,
        minPrice: a.minPrice,
        maxPrice: a.maxPrice,
        bedrooms: a.bedrooms,
        areaSqm: a.areaSqm,
        finishing: a.finishing,
        notes: a.notes,
        matches: locMatches,
        hotCount: hot,
        warmCount: warm,
      );
    }).toList();
  }

  Future<void> fetchReports() async {
    try {
      _reports = await ApiService.getReports();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchReports error: $e');
    }
  }

  Future<void> fetchLocationStats() async {
    try {
      _locationStats = await ApiService.getLocationStats();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchLocationStats error: $e');
    }
  }

  Future<void> fetchCrmLeads() async {
    try {
      _crmLeads = await ApiService.getPipeline();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('fetchCrmLeads error: $e');
    }
  }

  Future<bool> triggerEtl() async {
    return ApiService.triggerEtl();
  }

  Future<bool> runMatching() async {
    try {
      _matches = await ApiService.runMatching();
      _updateAssetMatchCounts();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('runMatching error: $e');
      return false;
    }
  }

  // ── Live alerts ────────────────────────────────────────────────────────────
  void addLiveAlert(HotMatchAlert alert) {
    _liveAlerts = [alert, ..._liveAlerts].take(50).toList();
    if (_stats != null) {
      _stats = DashboardStats(
        supplyCount: _stats!.supplyCount,
        demandCount: _stats!.demandCount,
        messagesCount: _stats!.messagesCount,
        hotMatchesToday: _stats!.hotMatchesToday + 1,
        warmMatchesToday: _stats!.warmMatchesToday,
        topLocations: _stats!.topLocations,
        whatsappConnected: _stats!.whatsappConnected,
        lastSync: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void dismissAlert(String id) {
    _liveAlerts = _liveAlerts.where((a) => a.id != id).toList();
    notifyListeners();
  }

  // ── CRM stage update ───────────────────────────────────────────────────────
  Future<void> updateLeadStage(String leadId, String stage) async {
    await ApiService.updatePipelineStage(leadId, stage, null);
    _crmLeads = _crmLeads.map((l) => l.id == leadId
        ? CRMLead(
            id: l.id, name: l.name, stage: stage,
            property: l.property, phone: l.phone, score: l.score,
            notes: l.notes, lastContact: l.lastContact)
        : l).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }
}
