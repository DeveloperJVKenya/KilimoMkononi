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

  InputDecoration _dec(String label, IconData icon, {String? hint, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kSetBorder)),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProfileProvider(false));
    final p = async.value;
    if (p != null) _fill(p);
    Uint8List? bytes;
    if (_image != null && _image!.isNotEmpty) {
      try {
        bytes = base64Decode(_image!);
      } catch (_) {}
    }
    final counties = kenyaLocations.keys.toList()..sort();
    final constituencies = _county == null ? const <String>[] : (kenyaLocations[_county]!.toList()..sort());

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: SettingsPage(
        title: 'Edit profile',
        subtitle: 'How you appear in Kilimo Mkononi',
        children: [
          if (!_loaded)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            EnterToSubmit(
              onSubmit: _save,
              enabled: !_saving,
              child: Form(
                key: _form,
                onChanged: _changed,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: const Color(0xFFD8EFD9),
                        backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                        child: bytes == null
                            ? Text(p?.initials ?? '',
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: kSetGreen))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: kSetGreen,
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
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(onPressed: _photoOptions, child: const Text('Change photo')),
                  ),
                  const SizedBox(height: 12),
                  const _Label('Personal details'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('Full name', Icons.person_rounded),
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
                    decoration: _dec('Phone number', Icons.phone_rounded, hint: '0712 345 678'),
                    validator: validateKenyanPhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: p?.email ?? '',
                    readOnly: true,
                    enabled: false,
                    decoration: _dec('Email', Icons.email_rounded,
                        helper: 'Change your email in Account & security'),
                  ),
                  const SizedBox(height: 20),
                  const _Label('Farm location'),
                  DropdownButtonFormField<String>(
                    initialValue: _county,
                    isExpanded: true,
                    menuMaxHeight: 380,
                    decoration: _dec('County', Icons.map_rounded),
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
                    decoration: _dec('Constituency (sub-county)', Icons.location_city_rounded),
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
                    decoration: _dec('Ward', Icons.place_rounded),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your ward' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kSetGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Saving…' : 'Save changes'),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: kSetMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );
}
