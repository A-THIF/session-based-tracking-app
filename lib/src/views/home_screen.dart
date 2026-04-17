import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import 'waiting_room_screen.dart';
import '../widgets/permission_guard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _statusMessage = 'Waiting to connect...';

  // --- Logic for User A (Start Session) ---
  Future<void> _handleStartSession() async {
    final hasPermission = await PermissionGuard.checkSettings(context);
    if (!hasPermission) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating session...';
    });

    try {
      // 1. Call your Render API (default 60 min duration)
      final sessionData = await _apiService.createSession(60);
      final String code = sessionData['sessionCode'];

      // 2. Navigate to Waiting Room
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WaitingRoomScreen(sessionCode: code, isHost: true),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create session')));
    } finally {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Waiting to connect...';
      });
    }
  }

  // --- Logic for User B (Join Session) ---
  Future<void> _handleJoinSession() async {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) return;

    // 1. Check Permissions FIRST
    final hasPermission = await PermissionGuard.checkSettings(context);
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Joining...';
    });

    try {
      // 2. Get the real unique Device ID
      final String deviceId = await _apiService.getDeviceId();

      // 3. Join with the dynamic ID
      final Session session = await _apiService.joinSession(code, deviceId);

      // 4. Navigate to Waiting Room
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WaitingRoomScreen(sessionCode: session.code, isHost: false),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code or expired session')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Waiting to connect...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TRACE', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF132036), // Dark Blue from mockup
        leading: const CircleAvatar(
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=1'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 1. Large "Start New Session" Button Card
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50.0),
                  child: CircularProgressIndicator(),
                )
              else
                GestureDetector(
                  onTap: _handleStartSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5AB9EA), // Blue from mockup
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          size: 70,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'START NEW SESSION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              // 2. Join Session Row Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'ENTER JOIN CODE',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5AB9EA),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _handleJoinSession,
                      child: const Text(
                        'JOIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Status Message
              Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
