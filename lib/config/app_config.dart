// lib/config/app_config.dart
// MatchPro™ — Crystal Power Investments

class AppConfig {
  // Backend URL — update to production server IP
  // Sandbox backend (live) — switch to Render URL after deployment
  static const String baseUrl = 'https://3001-iguij3jlaf6i30ho5lyiz-ad490db5.sandbox.novita.ai';
  // Render production (use after deploy): 'https://matchpro-backend.onrender.com'
  static const bool demoMode = false;

  static const String appName = 'MatchPro™';
  static const String company = 'Crystal Power Investments';
  static const String version = '2.0.0';

  // SACRED scoring thresholds
  static const int hotThreshold = 80;
  static const int warmThreshold = 60;
  static const int coolThreshold = 40;
}

class AppColors {
  // Brand
  static const int navy = 0xFF1E3A5F;
  static const int blue = 0xFF2563EB;
  static const int navyLight = 0xFF2C5282;

  // Grades
  static const int hot = 0xFFEF4444;
  static const int warm = 0xFFF59E0B;
  static const int cool = 0xFF3B82F6;
  static const int cold = 0xFF6B7280;

  // HOT glow
  static const int hotGlow = 0x33EF4444;
  static const int hotGlowStrong = 0x66EF4444;

  // Background
  static const int bg = 0xFFF8FAFC;
  static const int card = 0xFFFFFFFF;
  static const int border = 0xFFE5E7EB;

  // Text
  static const int text = 0xFF111827;
  static const int muted = 0xFF6B7280;
  static const int inverse = 0xFFFFFFFF;

  // WhatsApp green
  static const int whatsapp = 0xFF25D366;

  // Success / live indicator
  static const int live = 0xFF10B981;
}
