// lib/settings/profile_edit_screen.dart
//
// Settings → Edit profile (farmers): photo, full name, phone, county,
// constituency and ward, saved to `Users/{uid}` (the photo as a small base64
// JPEG in `profileImage`, which Home and the menu already show).

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart' show EnterToSubmit;
import 'package:kilimomkononi/data/kenya_locations.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

/// Kenyan phone: 07XXXXXXXX / 01XXXXXXXX or +2547… / +2541….
String? validateKenyanPhone(String? v) {
  final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (t.isEmpty) return 'Enter your phone number';
  if (!RegExp(r'^(?:\+?254|0)[17]\d{8}$').hasMatch(t)) return 'Use a Kenyan number, e.g. 0712 345 678';
  return null;
}

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _ward = TextEditingController();
  String? _county;
  String? _constituency;
  String? _image; // base64; '' = removed
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  int _generation = 0; // bumped by Undo so the pickers reset too

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _ward.dispose();
    super.dispose();
  }

  void _fill(ProfileSummary p) {
    if (_loaded) return;
    _loaded = true;
    _name.text = p.fullName;
    _phone.text = p.phone;
    _ward.text = p.ward;
    _county = kenyaLocations.keys.where((k) => k.toLowerCase() == p.county.toLowerCase()).firstOrNull;
    final list = _county == null ? const <String>[] : kenyaLocations[_county]!;
    _constituency = list.where((c) => c.toLowerCase() == p.constituency.toLowerCase()).firstOrNull;
    _image = p.imageBase64;
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 480, maxHeight: 480, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 600 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('That photo is too large — please choose another')));
        }
        return;
      }
      setState(() {
        _image = base64Encode(bytes);
        _dirty = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open the photo: $e')));
    }
  }

  void _photoOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery'),
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take a photo'),
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
          if (_image != null && _image!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: kSetRed),
              title: const Text('Remove photo', style: TextStyle(color: kSetRed)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _image = '';
                  _dirty = true;
                });
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'fullName': _name.text.trim(),
        'phoneNumber': _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
        'county': _county ?? '',
        'constituency': _constituency ?? '',
        'ward': _ward.text.trim(),
        'profileImage': (_image == null || _image!.isEmpty) ? null : _image,
      });
      final name = _name.text.trim();
      if (FirebaseAuth.instance.currentUser?.displayName != name) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name).catchError((_) {});
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved'), backgroundColor: kSetGreen));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard your changes?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
            ],
          ),
        ) ==
        true;
  }

  InputDecoration _dec(String label, IconData icon, Color color, {String? hint, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20, color: color),
        filled: true,
        fillColor: const Color(0xFFF5F8F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(settingsProfileProvider(false)).value;
    if (p != null) _fill(p);
    Uint8List? bytes;
    if (_image != null && _image!.isNotEmpty) {
      try {
        bytes = base64Decode(_image!);
      } catch (_) {}
    }
    final counties = kenyaLocations.keys.toList()..sort();
    final constituencies = _county == null ? const <String>[] : (kenyaLocations[_county]!.toList()..sort());
    const blue = Color(0xFF1565C0);
    const teal = Color(0xFF00897B);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: kSetPage,
        appBar: AppBar(
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          backgroundColor: kSetGreenDark,
          title: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        bottomNavigationBar: AnimatedSlide(
          offset: _dirty ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 220),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -2))],
              ),
              child: Row(children: [
                const Icon(Icons.edit_note_rounded, color: kSetMuted),
                const SizedBox(width: 8),
                const Expanded(child: Text('Unsaved changes', style: TextStyle(color: kSetMuted, fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _loaded = false;
                            _dirty = false;
                            _generation++;
                          }),
                  child: const Text('Undo'),
                ),
                const SizedBox(width: 6),
                CompactButton(icon: Icons.check_rounded, label: 'Save', busy: _saving, onPressed: _save),
              ]),
            ),
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator(color: kSetGreen))
            : EnterToSubmit(
                key: ValueKey(_generation),
                onSubmit: _save,
                enabled: !_saving,
                child: Form(
                  key: _form,
                  onChanged: _changed,
                  child: ListView(padding: EdgeInsets.zero, children: [
                    // Header: gradient band with the photo overlapping it.
                    SizedBox(
                      height: 210,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          height: 130,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kSetGreenDark, kSetGreen, Color(0xFF43A047)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                          ),
                        ),
                        Positioned(
                          top: 60,
                          left: 0,
                          right: 0,
                          child: Column(children: [
                            GestureDetector(
                              onTap: _photoOptions,
                              child: Stack(children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))],
                                  ),
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundColor: const Color(0xFFD8EFD9),
                                    backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                                    child: bytes == null
                                        ? Text(p?.initials ?? '',
                                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: kSetGreen))
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Material(
                                    color: const Color(0xFFFFB300),
                                    shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                                    child: IconButton(
                                      tooltip: 'Change photo',
                                      icon: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                                      onPressed: _photoOptions,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    Center(
                      child: Column(children: [
                        Text(_name.text.trim().isEmpty ? 'Your name' : _name.text.trim(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kSetInk)),
                        if ((p?.email ?? '').isNotEmpty)
                          Text(p!.email, style: const TextStyle(color: kSetMuted)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            _FormCard(
                              icon: Icons.person_rounded,
                              color: blue,
                              title: 'Personal details',
                              subtitle: 'Shown on your profile and used by our support team',
                              children: [
                                TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _dec('Full name', Icons.badge_rounded, blue),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return 'Enter your name';
                                    if (t.length < 3) return 'Enter your full name';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                                  decoration: _dec('Phone number', Icons.phone_rounded, blue, hint: '0712 345 678'),
                                  validator: validateKenyanPhone,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: p?.email ?? '',
                                  readOnly: true,
                                  enabled: false,
                                  decoration: _dec('Email', Icons.email_rounded, blue,
                                      helper: 'Change it in Settings → Account & security'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _FormCard(
                              icon: Icons.agriculture_rounded,
                              color: teal,
                              title: 'Farm location',
                              subtitle: 'Used for local weather, advice and prices',
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _county,
                                  isExpanded: true,
                                  menuMaxHeight: 380,
                                  borderRadius: BorderRadius.circular(14),
                                  decoration: _dec('County', Icons.map_rounded, teal),
                                  items: [for (final c in counties) DropdownMenuItem(value: c, child: Text(c))],
                                  onChanged: (v) => setState(() {
                                    _county = v;
                                    _constituency = null;
                                    _dirty = true;
                                  }),
                                  validator: (v) => v == null ? 'Choose your county' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_county),
                                  initialValue: _constituency,
                                  isExpanded: true,
                                  menuMaxHeight: 380,
                                  borderRadius: BorderRadius.circular(14),
                                  decoration: _dec('Constituency (sub-county)', Icons.location_city_rounded, teal),
                                  items: [for (final c in constituencies) DropdownMenuItem(value: c, child: Text(c))],
                                  onChanged: _county == null
                                      ? null
                                      : (v) => setState(() {
                                            _constituency = v;
                                            _dirty = true;
                                          }),
                                  validator: (v) => v == null ? 'Choose your constituency' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _ward,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _dec('Ward', Icons.place_rounded, teal),
                                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your ward' : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: CompactButton(
                                icon: Icons.check_rounded,
                                label: _saving ? 'Saving…' : 'Save changes',
                                busy: _saving,
                                onPressed: _save,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }
}

/// A white card with a coloured icon heading, grouping related fields.
class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _FormCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kSetInk)),
                Text(subtitle, style: const TextStyle(color: kSetMuted, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      );
}
