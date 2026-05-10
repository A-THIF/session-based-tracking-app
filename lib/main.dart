import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/constants/retro_theme.dart';
import 'src/providers/user_provider.dart';
import 'src/views/home_screen.dart';
import 'src/views/identity/identity_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TraceApp()));
}

class TraceApp extends ConsumerWidget {
  const TraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return MaterialApp(
      title: 'Trace',
      theme: buildRetroTheme(),
      // If user profile exists, go home. If not, go to identity setup.
      home: userAsync.when(
        data: (user) =>
            user == null ? const IdentityScreen() : const HomeScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => const IdentityScreen(),
      ),
    );
  }
}
