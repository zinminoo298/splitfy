// lib/main.dart (updated)
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'AuthScreen.dart';
import 'providers/group_provider.dart';
import 'package:app_links/app_links.dart';

bool _initialUriIsHandled = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    // _sub = _appLinks.uriLinkStream.listen((uri) {
    //   if (uri != null) _handleLink(uri);
    // }, onError: (err) {
    //   print(err);
    //   // Handle errors
    // });
  }

  Future<void> _initAppLinks() async {
    // Check initial link if app was started by a link
    final initialLink = await _appLinks.getInitialLinkString();
    if (initialLink != null) {
      // Wait for app to properly initialize before handling the link
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleLink(Uri.parse(initialLink));
      });
    }

    // Handle app links when app is running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _handleLink(uri);
    }, onError: (err) {
      print('App links error: $err');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleLink(Uri uri) {
    final segments = uri.pathSegments;
    // if (segments.length >= 2 && segments[0] == 'group') {
    //   final groupId = segments[1];
    //   _joinGroup(groupId);
    // }
    _joinGroup(segments[0]);
  }

  Future<void> _joinGroup(String groupId) async {
    final groupRepo = ref.read(groupRepositoryProvider);
    await groupRepo.joinGroup(groupId);
    final overlay = Overlay.of(context)!;
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 50,
        left: 10,
        right: 10,
        child: Material(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Successfully joined the group!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splitfy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }

}