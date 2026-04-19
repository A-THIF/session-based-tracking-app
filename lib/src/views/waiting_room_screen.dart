import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ably_service.dart';
import '../widgets/radar_animation_widget.dart';
import 'tracking_screen.dart';
import 'package:ably_flutter/ably_flutter.dart' as ably;
import '../services/api_service.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final String sessionCode;
  final bool isHost;

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
  List<String> _members = [];
  String? _myDeviceId;
  bool _friendJoined = false; // true once someone else is in the room

  @override
  void initState() {
    super.initState();
    _connectAbly();
  }

  Future<void> _connectAbly() async {
    try {
      _ablyService = ref.read(ablyServiceProvider);
      _myDeviceId = await ApiService().getDeviceId();

      await _ablyService.initAbly(widget.sessionCode, _myDeviceId!);
      await _ablyService.enterPresence(_myDeviceId!);

      // Check who is already in the room (handles the case where
      // one device joined before the other started listening)
      final existing = await _ablyService.getPresentMembers();
      for (final msg in existing) {
        final name = msg.clientId ?? 'Unknown';
        if (name != _myDeviceId && !_members.contains(name)) {
          setState(() {
            _members.add(name);
            _friendJoined = true;
          });
        }
      }

      // Now listen for new arrivals / departures
      _ablyService.subscribeToPresence((presenceMsg) {
        if (!mounted) return;
        final name = presenceMsg.clientId ?? 'Unknown';
        if (name == _myDeviceId) return; // ignore ourselves

        setState(() {
          if (presenceMsg.action == ably.PresenceAction.enter ||
              presenceMsg.action == ably.PresenceAction.present) {
            if (!_members.contains(name)) {
              _members.add(name);
              _friendJoined = true;
            }
          } else if (presenceMsg.action == ably.PresenceAction.leave) {
            _members.remove(name);
            _friendJoined = _members.isNotEmpty;
          }
        });

        // Guest auto-navigates when host (or anyone) is already present.
        // Host stays and taps "Start Tracking" manually.
        if (!widget.isHost && _friendJoined) {
          _navigateToTracking();
        }
      });
    } catch (e) {
      debugPrint("Ably Handshake Failed: $e");
    }
  }

  void _navigateToTracking() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          sessionCode: widget.sessionCode,
          isHost: widget.isHost,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              Text(
                widget.isHost ? 'WAITING FOR FRIEND...' : 'JOINING SESSION...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 10),

              // Session code display
              Text(
                'CODE: ${widget.sessionCode}',
                style: const TextStyle(
                  color: Color(0xFF5AB9EA),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(height: 250, child: const RadarAnimationWidget()),

              // Member list — shows who has joined
              if (_members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No one here yet...',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: _members.map((name) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name.replaceAll('_', ' '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'joined',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // White card at the bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    // HOST: show "Start Tracking" only when friend joined
                    if (widget.isHost) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _friendJoined
                            ? ElevatedButton.icon(
                                key: const ValueKey('start'),
                                onPressed: _navigateToTracking,
                                icon: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'START TRACKING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size.fromHeight(60),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              )
                            : Container(
                                key: const ValueKey('waiting'),
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Waiting for friend to join...',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // GUEST: show a waiting indicator
                    if (!widget.isHost)
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Host will start the session...'),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL SESSION',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
