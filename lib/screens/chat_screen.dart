import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isSearching = false;
  String _searchQuery = "";
  
  // NEW: Tracking state for editing
  String? _editingId; 

  @override
  void initState() {
    super.initState();
    _updateReadReceipt();
  }

  void _updateReadReceipt() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'lastRead.$_uid': FieldValue.serverTimestamp()});
  }

  void _setTyping(bool isTyping) {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'typingStatus.$_uid': isTyping});
  }

  void _react(String msgId, String emoji) {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(msgId)
        .update({'reactions.$_uid': emoji});
  }

  void _deleteMessage(String id) {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(id)
        .delete();
  }

  // UPDATED: Logic to enter edit mode
  void _editMessage(String id, String oldText) {
    setState(() {
      _editingId = id;
      _textController.text = oldText;
    });
  }

  void _showMenu(String messageId, String currentText, bool isMine) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMine) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(messageId, currentText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 20,
              children: ['👍', '❤️', '😂', '😮', '😢'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _react(messageId, emoji);
                    Navigator.pop(context);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages');

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            )
          : const Text('Chat'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              _searchQuery = "";
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypingIndicator(), // Moved inside body for better layout
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) => (d['text'] as String).toLowerCase().contains(_searchQuery)).toList();
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onLongPress: () => _showMenu(doc.id, data['text'], data['senderId'] == _uid),
                      child: _buildMessageBubble(data, data['senderId'] == _uid),
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(messagesRef),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMine) {
    Map reactions = data['reactions'] ?? {};
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMine ? Colors.deepPurple : Colors.grey[300],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['text'], style: TextStyle(color: isMine ? Colors.white : Colors.black87)),
                if (data['isEdited'] == true)
                  const Text("(edited)", style: TextStyle(fontSize: 8, color: Colors.white70)),
              ],
            ),
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(reactions.values.join(" "), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReadStatus(Map<String, dynamic> data) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final convData = snapshot.data!.data() as Map<String, dynamic>;
        final lastReadMap = convData['lastRead'] as Map<String, dynamic>? ?? {};

        // Find the timestamp of the other participant
        final otherUserEntry = lastReadMap.entries.firstWhere(
          (e) => e.key != _uid,
          orElse: () => const MapEntry("", null),
        );

        final lastReadTime = otherUserEntry.value as Timestamp?;
        final messageTime = data['createdAt'] as Timestamp?;

        // If other user has seen the chat AFTER this message was sent
        if (lastReadTime != null && messageTime != null && 
            messageTime.toDate().isBefore(lastReadTime.toDate())) {
          return const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
        }

        return const Icon(Icons.done, size: 12, color: Colors.white60);
      },
    );
  }

  Widget _buildInputArea(CollectionReference ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _textController,
              onChanged: (val) => _setTyping(val.isNotEmpty),
              decoration: const InputDecoration(hintText: 'Type...', border: InputBorder.none),
            ),
          ),
          IconButton(
            // Change icon if we are editing
            icon: Icon(_editingId == null ? Icons.send : Icons.check_circle, color: Colors.deepPurple),
            onPressed: () => _sendMessage(ref),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(CollectionReference messagesRef) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_editingId != null) {
      // Logic for UPDATING a message
      await messagesRef.doc(_editingId).update({
        'text': text,
        'isEdited': true,
      });
      setState(() => _editingId = null);
    } else {
      // Logic for NEW message
      await messagesRef.add({
        'senderId': _uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
      });
    }

    _textController.clear();
    _setTyping(false);
    _updateReadReceipt();
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        Map typing = (snapshot.data!.data() as Map)['typingStatus'] ?? {};
        bool otherTyping = typing.entries.any((e) => e.key != _uid && e.value == true);
        return otherTyping 
          ? const Padding(
              padding: EdgeInsets.all(4.0),
              child: Text("typing...", style: TextStyle(color: Colors.green, fontSize: 10, fontStyle: FontStyle.italic)),
            ) 
          : const SizedBox();
      },
    );
  }
}