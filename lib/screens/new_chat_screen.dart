import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String _searchQuery = "";
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Logic to start or find a conversation
  Future<void> _startConversation(String targetUserId) async {
    if (_currentUserId == null) return;

    // 1. Check if a conversation between these two already exists
    final existingConvo = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .get();

    // Check if the target user is also in any of these conversations
    String? convoId;
    for (var doc in existingConvo.docs) {
      List participants = doc['participants'];
      if (participants.contains(targetUserId)) {
        convoId = doc.id;
        break;
      }
    }

    // 2. If it doesn't exist, create a new one
    if (convoId == null) {
      final newConvo = await FirebaseFirestore.instance.collection('conversations').add({
        'participants': [_currentUserId, targetUserId],
        'lastMessage': 'No messages yet',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'typingStatus': {
          _currentUserId: false,
          targetUserId: false,
        },
      });
      convoId = newConvo.id;
    }

    // 3. Navigate to the chat screen
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: convoId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search by email...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase().trim();
            });
          },
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: _searchQuery)
            .where('email', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs.where((doc) => doc.id != _currentUserId).toList() ?? [];

          if (users.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(userData['email'] ?? 'Unknown'),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () => _startConversation(users[index].id),
              );
            },
          );
        },
      ),
    );
  }
}