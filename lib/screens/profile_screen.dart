import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _email = FirebaseAuth.instance.currentUser?.email ?? '';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarBase64;      // current avatar (Base64 string from Firestore)
  String? _newAvatarBase64;   // newly picked avatar (not yet saved)

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ─── LOAD EXISTING PROFILE ───────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (_uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['displayName'] ?? '';
      _bioController.text  = data['bio'] ?? '';
      _avatarBase64 = data['avatarBase64'];
    }

    setState(() => _isLoading = false);
  }

  // ─── PICK AVATAR FROM GALLERY ────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileSize = await file.length();

    // Keep avatar under 200KB for Firestore
    if (fileSize > 200 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large. Please pick one under 200KB.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final bytes = await file.readAsBytes();
    setState(() => _newAvatarBase64 = base64Encode(bytes));
  }

  // ─── SAVE PROFILE ────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updates = {
        'displayName': name,
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only update avatar if a new one was picked
      if (_newAvatarBase64 != null) {
        updates['avatarBase64'] = _newAvatarBase64;
        // Clear old photoUrl if switching to Base64 avatar
        updates['photoUrl'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update(updates);

      setState(() {
        if (_newAvatarBase64 != null) {
          _avatarBase64 = _newAvatarBase64;
          _newAvatarBase64 = null;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ─── AVATAR WIDGET ───────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    final displayBase64 = _newAvatarBase64 ?? _avatarBase64;
    final initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : _email.isNotEmpty ? _email[0].toUpperCase() : '?';

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: Colors.deepPurple[100],
            backgroundImage: displayBase64 != null
                ? MemoryImage(base64Decode(displayBase64))
                : null,
            child: displayBase64 == null
                ? Text(initial,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple))
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF5C35CC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5C35CC)),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save',
                  style: TextStyle(
                      color: Color(0xFF5C35CC),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Avatar
                  _buildAvatar(),

                  // "Change photo" label
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: const Text(
                      'Change photo',
                      style: TextStyle(
                          color: Color(0xFF5C35CC),
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Email (read-only)
                  _buildReadOnlyField(
                    label: 'Email',
                    value: _email,
                    icon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 16),

                  // Name field
                  _buildInputField(
                    label: 'Display Name',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    hint: 'Enter your name',
                    maxLength: 40,
                  ),

                  const SizedBox(height: 16),

                  // Bio field
                  _buildInputField(
                    label: 'Bio',
                    controller: _bioController,
                    icon: Icons.info_outline,
                    hint: 'Tell people a little about yourself...',
                    maxLines: 3,
                    maxLength: 120,
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C35CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ─── FIELD WIDGETS ───────────────────────────────────────────────────────────

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Text(value,
                  style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              const Spacer(),
              Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              counterStyle:
                  TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }
}