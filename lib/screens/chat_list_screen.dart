import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // StreamBuilder in main.dart handles the navigation back to login
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: uid)
            // It's good practice to order these by the last message time
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No conversations yet. Tap + to start one!'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final participants = data['participants'] as List<dynamic>;
              
              // Get the other person's ID (not the current user's)
              final otherUser = participants.firstWhere((id) => id != uid, orElse: () => 'Unknown');

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('Chat with $otherUser'),
                subtitle: Text(
                  data['lastMessage'] ?? 'No messages yet...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(conversationId: doc.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // NEW: FAB to search for users and start a new chat
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/new-chat');
        },
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}