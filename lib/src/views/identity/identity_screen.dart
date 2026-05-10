import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isClaiming = false;

  // lib/src/views/identity/identity_screen.dart

Future<void> _shuffleName() async {
  // Show a little loading state on the dice if you want, 
  // but for now, let's just make it work.
  try {
    final suggestions = await ref.read(userProvider.notifier).fetchSuggestions();
    if (suggestions.isNotEmpty) {
      setState(() {
        // 🟢 This picks a random name from the 5 suggestions returned
        final randomName = (suggestions..shuffle()).first;
        _nameController.text = randomName;
      });
    } else {
      throw Exception("No suggestions returned");
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dice failed: Check backend connection"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "TRACE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "No account. No number.\nJust your identity.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 13),
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                "PICK YOUR NAME", 
                style: TextStyle(color: Color(0xFF7A9BC0), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: "Enter your name...",
                  hintStyle: const TextStyle(color: Color(0xFF3D5A80)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide.none
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.casino_outlined, color: Color(0xFF4ECDC4)),
                    onPressed: _shuffleName,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isClaiming ? null : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  
                  setState(() => _isClaiming = true);
                  try {
                    final success = await ref.read(userProvider.notifier).claimIdentity(name);
                    if (success && mounted) {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isClaiming = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4ECDC4)),
                  ),
                  child: Center(
                    child: _isClaiming 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4ECDC4)))
                      : const Text(
                          "CLAIM IDENTITY",
                          style: TextStyle(color: Color(0xFF4ECDC4), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}