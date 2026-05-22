import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId; // NEW: needed for avatar, name, online status
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isSearching = false;
  String _searchQuery = "";
  String? _editingId;

  // NEW: Reply state
  Map<String, dynamic>? _replyingTo;
  String? _replyingToId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateReadReceipt();
    _setOnlineStatus(true);
    _setupFCM();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // NEW: React to app lifecycle for online/offline
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  // ─── ONLINE / OFFLINE STATUS ────────────────────────────────────────────────

  void _setOnlineStatus(bool isOnline) {
    if (_uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(_uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // ─── FCM PUSH NOTIFICATIONS ─────────────────────────────────────────────────

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Save token to Firestore so backend can target this device
    final token = await messaging.getToken();
    if (token != null && _uid != null) {
      FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }

    // Refresh token whenever it rotates
    messaging.onTokenRefresh.listen((newToken) {
      if (_uid != null) {
        FirebaseFirestore.instance.collection('users').doc(_uid).update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        });
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${notification.title}: ${notification.body}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ─── EXISTING HELPERS ───────────────────────────────────────────────────────

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

  void _editMessage(String id, String oldText) {
    setState(() {
      _editingId = id;
      _replyingTo = null; // clear reply if switching to edit
      _replyingToId = null;
      _textController.text = oldText;
    });
  }

  // NEW: Enter reply mode
  void _startReply(String msgId, Map<String, dynamic> data) {
    setState(() {
      _replyingToId = msgId;
      _replyingTo = data;
      _editingId = null; // clear edit if switching to reply
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReplyOrEdit() {
    setState(() {
      _replyingTo = null;
      _replyingToId = null;
      _editingId = null;
      _textController.clear();
    });
  }

  void _showMenu(String messageId, String currentText, bool isMine,
      Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // NEW: Reply option for everyone
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _startReply(messageId, data);
              },
            ),
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
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Wrap(
                spacing: 20,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
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
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTypingIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs
                      .where((d) => (d['text'] as String)
                          .toLowerCase()
                          .contains(_searchQuery))
                      .toList();
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMine = data['senderId'] == _uid;

                    // Show date separator if date changes between messages
                    final showDateSep = index == docs.length - 1 ||
                        _isDifferentDay(
                          data['createdAt'],
                          (docs[index + 1].data() as Map)['createdAt'],
                        );

                    return Column(
                      children: [
                        if (showDateSep) _buildDateSeparator(data['createdAt']),
                        GestureDetector(
                          onLongPress: () => _showMenu(
                              doc.id, data['text'], isMine, data),
                          child: _buildMessageBubble(doc.id, data, isMine),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // NEW: Reply / Edit preview banner
          if (_replyingTo != null || _editingId != null)
            _buildReplyEditBanner(),
          _buildInputArea(messagesRef),
        ],
      ),
    );
  }

  // ─── APP BAR (with online status) ───────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      titleSpacing: 0,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Search messages...', border: InputBorder.none),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            )
          : StreamBuilder<DocumentSnapshot>(
              // NEW: Real-time online status in app bar
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                bool isOnline = false;
                String name = 'Chat';
                String? photoUrl;
                String lastSeenText = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data =
                      snapshot.data!.data() as Map<String, dynamic>;
                  name = data['displayName'] ?? 'Chat';
                  photoUrl = data['photoUrl'];
                  isOnline = data['isOnline'] == true;

                  if (!isOnline && data['lastSeen'] != null) {
                    final lastSeen =
                        (data['lastSeen'] as Timestamp).toDate();
                    lastSeenText = _formatLastSeen(lastSeen);
                  }
                }

                return Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.deepPurple[100],
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        // Online dot
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        Text(
                          isOnline ? 'Online' : lastSeenText,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isOnline ? Colors.green : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            _searchQuery = '';
            _searchController.clear();
          }),
        ),
      ],
    );
  }

  // ─── MESSAGE BUBBLE (redesigned + reply thread) ──────────────────────────────

  Widget _buildMessageBubble(
      String docId, Map<String, dynamic> data, bool isMine) {
    final Map reactions = data['reactions'] ?? {};
    final replyData = data['replyTo'] as Map<String, dynamic>?;

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 60 : 10,
        right: isMine ? 10 : 60,
        top: 3,
        bottom: 3,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // NEW: Sender name for received messages
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 2),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['senderId'])
                    .get(),
                builder: (context, snap) {
                  final name = snap.hasData && snap.data!.exists
                      ? (snap.data!.data() as Map)['displayName'] ?? ''
                      : '';
                  return Text(name,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500));
                },
              ),
            ),

          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // NEW: Avatar for received messages
              if (!isMine)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['senderId'])
                      .get(),
                  builder: (context, snap) {
                    String? photoUrl;
                    String name = '?';
                    if (snap.hasData && snap.data!.exists) {
                      final u = snap.data!.data() as Map;
                      photoUrl = u['photoUrl'];
                      name = (u['displayName'] ?? '?')[0].toUpperCase();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.deepPurple[100],
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Text(name,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                    );
                  },
                ),

              // Bubble
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFF5C35CC)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW: Reply preview inside bubble
                      if (replyData != null)
                        _buildReplyPreviewInBubble(replyData, isMine),

                      Text(
                        data['text'],
                        style: TextStyle(
                          color: isMine ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (data['isEdited'] == true)
                            Text(
                              'edited · ',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMine
                                    ? Colors.white54
                                    : Colors.grey[400],
                              ),
                            ),
                          Text(
                            _formatTime(data['createdAt']),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMine
                                  ? Colors.white54
                                  : Colors.grey[400],
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            _buildReadStatus(data),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Reactions
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                  left: isMine ? 0 : 44, right: 4, top: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha:0.08),
                        blurRadius: 4)
                  ],
                ),
                child: Text(reactions.values.join(' '),
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  // NEW: Reply preview inside bubble
  Widget _buildReplyPreviewInBubble(
      Map<String, dynamic> replyData, bool isMine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha:0.15)
            : Colors.grey.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white60 : Colors.deepPurple,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyData['senderName'] ?? 'User',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMine ? Colors.white70 : Colors.deepPurple,
            ),
          ),
          Text(
            replyData['text'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMine ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ─── REPLY / EDIT BANNER ─────────────────────────────────────────────────────

  Widget _buildReplyEditBanner() {
    final isEdit = _editingId != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Editing message' : 'Replying to',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
                Text(
                  isEdit
                      ? _textController.text
                      : (_replyingTo?['text'] ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelReplyOrEdit,
          ),
        ],
      ),
    );
  }

  // ─── INPUT AREA ──────────────────────────────────────────────────────────────

  Widget _buildInputArea(CollectionReference ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Colors.deepPurple),
              onPressed: () {}),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                onChanged: (val) => _setTyping(val.isNotEmpty),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _sendMessage(ref),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF5C35CC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _editingId != null ? Icons.check : Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEND / EDIT MESSAGE ────────────────────────────────────────────────────

  Future<void> _sendMessage(CollectionReference messagesRef) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_editingId != null) {
      await messagesRef.doc(_editingId).update({
        'text': text,
        'isEdited': true,
      });
      setState(() => _editingId = null);
    } else {
      // NEW: Attach reply data if replying
      final Map<String, dynamic> msgData = {
        'senderId': _uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
      };

      if (_replyingTo != null && _replyingToId != null) {
        // Fetch sender name for reply preview
        final senderSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_replyingTo!['senderId'])
            .get();
        final senderName =
            (senderSnap.data() as Map?)?['displayName'] ?? 'User';

        msgData['replyTo'] = {
          'messageId': _replyingToId,
          'text': _replyingTo!['text'],
          'senderId': _replyingTo!['senderId'],
          'senderName': senderName,
        };
      }

      await messagesRef.add(msgData);

      // ✅ Update conversation preview so chat list shows latest message instantly
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      setState(() {
        _replyingTo = null;
        _replyingToId = null;
      });
    }

    _textController.clear();
    _setTyping(false);
    _updateReadReceipt();
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────────

  Widget _buildReadStatus(Map<String, dynamic> data) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final convData =
            snapshot.data!.data() as Map<String, dynamic>;
        final lastReadMap =
            convData['lastRead'] as Map<String, dynamic>? ?? {};
        final otherUserEntry = lastReadMap.entries.firstWhere(
          (e) => e.key != _uid,
          orElse: () => const MapEntry('', null),
        );
        final lastReadTime = otherUserEntry.value as Timestamp?;
        final messageTime = data['createdAt'] as Timestamp?;

        if (lastReadTime != null &&
            messageTime != null &&
            messageTime.toDate().isBefore(lastReadTime.toDate())) {
          return const Icon(Icons.done_all, size: 12, color: Colors.blueAccent);
        }
        return const Icon(Icons.done, size: 12, color: Colors.white54);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final Map typing =
            (snapshot.data!.data() as Map)['typingStatus'] ?? {};
        final otherTyping =
            typing.entries.any((e) => e.key != _uid && e.value == true);
        return otherTyping
            ? Container(
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: const Text(
                  'typing...',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              )
            : const SizedBox();
      },
    );
  }

  Widget _buildDateSeparator(Timestamp? ts) {
    if (ts == null) return const SizedBox();
    final date = ts.toDate();
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  bool _isDifferentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final t = ts.toDate().toLocal();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatLastSeen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    return 'last seen ${diff.inDays}d ago';
  }
}