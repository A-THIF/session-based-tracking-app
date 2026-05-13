import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/constants/retro_theme.dart';
import 'src/providers/user_provider.dart';
import 'src/services/background_service.dart'; // Note: I am using the paths you provided in your earlier snippets
import 'src/views/home_screen.dart'; 
import 'src/views/identity/identity_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Keep this! This ensures tracking works when the app is closed.
  await initializeService(); 
  
  runApp(const ProviderScope(child: TraceApp()));
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trace',
      debugShowCheckedModeBanner: false,
      theme: buildRetroTheme(),
      // initialRoute points to our logic-checker below
      initialRoute: '/',
      routes: {
        '/': (context) => const _RootRouter(),
        '/home': (context) => const HomeScreen(),
        '/identity': (context) => const IdentityScreen(),
      },
    );
  }
}

/// This widget checks if the user is "Logged In" (has a UUID/Identity)
/// and directs them to the correct screen.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
      ),
      error: (err, stack) {
        debugPrint("Auth Route Error: $err");
        return const IdentityScreen();
      },
      data: (user) {
        // If profile exists in storage, go Home. Otherwise, get a Name.
        if (user == null) {
          return const IdentityScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}