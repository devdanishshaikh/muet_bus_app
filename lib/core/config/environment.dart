abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jmurvxbpeoiznzmpwzrb.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;
}
