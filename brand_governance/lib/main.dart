import 'package:brand_governance/app/my_days_app.dart';
import 'package:brand_governance/features/auth/data/demo_auth_service.dart';
import 'package:brand_governance/features/auth/data/supabase_auth_service.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  if (supabaseUrl.isEmpty && supabasePublishableKey.isEmpty) {
    runApp(MyDaysApp(authService: DemoAuthenticationService()));
    return;
  }

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(
      const ConfigurationRequiredApp(
        message:
            'Both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required '
            'for cloud sign-in.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    runApp(
      MyDaysApp(
        authService: DemoAuthenticationService(
          cloudService: SupabaseAuthService(),
        ),
      ),
    );
  } on Exception {
    runApp(
      const ConfigurationRequiredApp(
        message:
            'Supabase could not be initialized. Verify the project URL and '
            'publishable key, then restart the app.',
      ),
    );
  }
}
