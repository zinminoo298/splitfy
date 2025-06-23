// lib/AuthScreen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitfy/screens/mainscreen.dart';
import 'auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final authRepository = ref.watch(authRepositoryProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
      data: (user) {
        if (user == null) {
          // User is signed out, show login screen
          return Scaffold(
            appBar: AppBar(title: const Text("Welcome to Splitfy")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Split expenses with friends easily",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => authRepository.signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: const Text("Sign in with Google"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // User is signed in, navigate to MainScreen
          return const MainScreen();
        }
      },
    );
  }
}