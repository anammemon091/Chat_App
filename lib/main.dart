import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for status updates

import 'firebase_options.dart'; 
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/new_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

// Changed to StatefulWidget to use WidgetsBindingObserver for status tracking
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    // Start listening to app lifecycle (foreground/background)
    WidgetsBinding.instance.addObserver(this);
    _updateStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FEATURE: Presence Tracking (Online/Offline)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus(true); // User opened the app
    } else {
      _updateStatus(false); // User closed/minimized the app
    }
  }

  void _updateStatus(bool isOnline) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastseen': FieldValue.serverTimestamp(), // Matches image_945b4d.png
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat Starter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/chats': (_) => const ChatListScreen(),
        '/new-chat': (_) => const NewChatScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            // Ensure status updates to online immediately upon login
            _updateStatus(true);
            return const ChatListScreen();
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}