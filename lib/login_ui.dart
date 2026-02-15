import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class LoginGate extends StatelessWidget {
  final Widget signedInChild;
  const LoginGate({super.key, required this.signedInChild});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return signedInChild;
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool loading = false;
  String? error;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: Colors.white.withOpacity(.9), size: 42),
                  const SizedBox(height: 10),
                  Text(
                    "Login",
                    style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _run(() async {
                              await AuthService.instance.signInWithGoogle();
                            }),
                    icon: const Icon(Icons.login),
                    label: const Text("Mit Google anmelden"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Apple macht nur Sinn auf iOS/macOS & Web
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _run(() async {
                              await AuthService.instance.signInWithApple(
                                // Für WEB:
                                webClientId: kIsWeb ? "DEIN_APPLE_SERVICE_ID_CLIENT_ID" : null,
                                webRedirectUri: kIsWeb ? Uri.parse("https://DEINE-DOMAIN.web.app/__/auth/handler") : null,
                              );
                            }),
                    icon: const Icon(Icons.apple),
                    label: const Text("Mit Apple anmelden"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(.25)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (loading) ...[
                    const SizedBox(height: 6),
                    const CircularProgressIndicator(),
                  ],

                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Colors.redAccent.withOpacity(.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 10),
                  Text(
                    "Firebase Auth (Google/Apple).",
                    style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountAuthCard extends StatelessWidget {
  const AccountAuthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Auth",
            style: TextStyle(color: Colors.white.withOpacity(.9), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (user == null) ...[
            Text("Nicht eingeloggt", style: TextStyle(color: Colors.white.withOpacity(.75))),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
              child: const Text("Login öffnen"),
            ),
          ] else ...[
            Text(
              user.displayName ?? "User",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? user.uid,
              style: TextStyle(color: Colors.white.withOpacity(.75)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async => AuthService.instance.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(.25)),
              ),
              child: const Text("Logout"),
            ),
          ],
        ],
      ),
    );
  }
}
