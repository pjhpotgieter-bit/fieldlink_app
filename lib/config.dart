class AppConfig {
  // Use --dart-define=ENABLE_PAYMENTS=false to disable payment UI at build/run time.
  static const String _enablePayments = String.fromEnvironment('ENABLE_PAYMENTS', defaultValue: 'true');
  static bool get enablePayments => _enablePayments.toLowerCase() != 'false';
}
