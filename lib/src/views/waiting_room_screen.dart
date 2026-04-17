import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ably_service.dart';
import '../widgets/radar_animation_widget.dart'; // We'll create this below
import 'tracking_screen.dart';
import 'package:ably_flutter/ably_flutter.dart' as ably;

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final String sessionCode;
  final bool isHost; // To know if we are sharing location or following

  const WaitingRoomScreen({
    Key? key,
    required this.sessionCode,
    required this.isHost,
  }) : super(key: key);

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  late AblyService _ablyService;

  @override
  void initState() {
    super.initState();
    _connectAbly();
  }

  Future<void> _connectAbly() async {
  try {
    _ablyService = ref.read(ablyServiceProvider);
    
    // 1. Wait for connection and channel initialization
    await _ablyService.initAbly(widget.sessionCode);

    // 2. ONLY subscribe after initAbly is done
    _ablyService.subscribeToPresence((presenceMsg) {
      if (presenceMsg.action == ably.PresenceAction.enter ||
          presenceMsg.action == ably.PresenceAction.present) {
        
        if (!mounted) return;
        
        // Navigation logic...
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              sessionCode: widget.sessionCode,
              isHost: widget.isHost,
            ),
          ),
        );
      }
    });
  } catch (e) {
    debugPrint("Ably Connection Failed: $e");
    // Show a snackbar so you know if the token failed
  }
}

  @override
  void dispose() {
    // Very important to close Ably when they cancel the session
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate Background
      appBar: AppBar(
        title: const Text('THE WAITING ROOM (HANDSHAKE)'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          children: [
            // 1. Radar Animation
            const Expanded(child: RadarAnimationWidget()),

            // 2. Code display and sharing card
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        const TextSpan(text: 'CODE: '),
                        TextSpan(
                          text: widget.sessionCode,
                          style: const TextStyle(color: Color(0xFF5AB9EA)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SHARE THIS CODE TO INVITE YOUR FRIEND',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5AB9EA),
                      minimumSize: const Size.fromHeight(60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      /* Will implement Share package later */
                    },
                    child: const Text(
                      'SHARE LINK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      backgroundColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'CANCEL SESSION',
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
