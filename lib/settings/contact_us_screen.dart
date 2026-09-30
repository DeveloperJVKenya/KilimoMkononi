// lib/settings/contact_us_screen.dart
//
// Settings → Contact us: call, WhatsApp, email, website and office address
// (tap to open, long-press to copy); a message form that saves to
// `supportMessages` (admins read these in the Admin panel) with a fallback to
// the phone's email app; and the user's own previous messages with status.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';
import 'package:url_launcher/url_launcher.dart';

enum SupportTopic {
  question('question', 'Question', Icons.help_outline_rounded),
  problem('problem', 'Report a problem', Icons.bug_report_outlined),
  idea('idea', 'Suggestion', Icons.lightbulb_outline_rounded),
  account('account', 'Account & data', Icons.manage_accounts_outlined);

  final String key;
  final String label;
  final IconData icon;
  const SupportTopic(this.key, this.label, this.icon);

  static String labelFor(String key) =>
      key == 'account_deletion' ? 'Account deletion' : (values.where((t) => t.key == key).firstOrNull?.label ?? key);
}

@immutable
class SupportMessage {
  final String id;
  final String topic;
  final String message;
  final String status; // open, in_progress, resolved
  final String reply;
  final DateTime? createdAt;
  const SupportMessage(this.id, this.topic, this.message, this.status, this.reply, this.createdAt);

  factory SupportMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final ts = m['createdAt'];
    return SupportMessage(d.id, '${m['topic'] ?? ''}', '${m['message'] ?? ''}', '${m['status'] ?? 'open'}',
        '${m['reply'] ?? ''}', ts is Timestamp ? ts.toDate() : null);
  }
}

final mySupportMessagesProvider = StreamProvider.autoDispose<List<SupportMessage>>((ref) {
  final uid = ref.watch(settingsAuthProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('supportMessages')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(SupportMessage.fromDoc).toList());
});

Future<bool> openExternal(BuildContext context, String url) async {
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app on this device can open that')));
    }
    return ok;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app on this device can open that')));
    }
    return false;
  }
}

void copyText(BuildContext context, String text, String what) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied')));
}

class ContactUsScreen extends ConsumerWidget {
  final SupportTopic initialTopic;
  const ContactUsScreen({super.key, this.initialTopic = SupportTopic.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(mySupportMessagesProvider).value ?? const [];
    return SettingsPage(
      title: 'Contact us',
      subtitle: 'We usually reply within one working day',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [kSetGreenDark, kSetGreen]),
          ),
          child: const Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('We\'re here to help',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Support: ${KmContact.hours}', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 560 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          final cards = [
            _ContactCard(
              icon: Icons.call_rounded,
              color: kSetGreen,
              label: 'Call',
              value: KmContact.phone,
              onTap: () => openExternal(context, 'tel:${KmContact.phoneDial}'),
              onCopy: () => copyText(context, KmContact.phone, 'Phone number'),
            ),
            _ContactCard(
              icon: Icons.chat_rounded,
              color: const Color(0xFF128C7E),
              label: 'WhatsApp',
              value: 'Chat with us',
              onTap: () => openExternal(context,
                  'https://wa.me/${KmContact.whatsapp}?text=${Uri.encodeComponent('Hello Kilimo Mkononi team, ')}'),
              onCopy: () => copyText(context, KmContact.phone, 'WhatsApp number'),
            ),
            _ContactCard(
              icon: Icons.email_rounded,
              color: const Color(0xFF1565C0),
              label: 'Email',
              value: KmContact.email,
              onTap: () => openExternal(context, 'mailto:${KmContact.email}?subject=${Uri.encodeComponent('Kilimo Mkononi support')}'),
              onCopy: () => copyText(context, KmContact.email, 'Email address'),
            ),
            _ContactCard(
              icon: Icons.language_rounded,
              color: const Color(0xFF6A1B9A),
              label: 'Website',
              value: KmContact.website,
              onTap: () => openExternal(context, KmContact.websiteUrl),
              onCopy: () => copyText(context, KmContact.websiteUrl, 'Website'),
            ),
          ];
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final card in cards) SizedBox(width: w, child: card)]);
        }),
        const SizedBox(height: 16),
        SettingsSection(title: 'Visit us', children: [
          SettingsTile(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFB26A00),
            title: KmContact.company,
            subtitle: KmContact.address,
            trailing: const Icon(Icons.map_rounded, color: kSetMuted),
            onTap: () => openExternal(
                context, 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(KmContact.address)}'),
          ),
        ]),
        SettingsSection(
          title: 'Send us a message',
          footer: 'Messages go straight to the Kilimo Mkononi team. Please don\'t share passwords.',
          children: [Padding(padding: const EdgeInsets.all(16), child: _MessageForm(initialTopic: initialTopic))],
        ),
        if (mine.isNotEmpty)
          SettingsSection(title: 'Your messages', children: [for (final m in mine) _MessageTile(m)]),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  const _ContactCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onCopy,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kSetBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 16, color: kSetMuted),
                  onPressed: onCopy,
                ),
              ]),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kSetInk)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _MessageForm extends ConsumerStatefulWidget {
  final SupportTopic initialTopic;
  const _MessageForm({required this.initialTopic});

  @override
  ConsumerState<_MessageForm> createState() => _MessageFormState();
}

class _MessageFormState extends ConsumerState<_MessageForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  late SupportTopic _topic = widget.initialTopic;
  bool _prefilled = false;
  bool _sending = false;
  String? _sentId;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _mailto => 'mailto:${KmContact.email}'
      '?subject=${Uri.encodeComponent('Kilimo Mkononi — ${_topic.label}')}'
      '&body=${Uri.encodeComponent('${_message.text}\n\n${_name.text}\n${_email.text}')}';

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      final ref = await FirebaseFirestore.instance.collection('supportMessages').add({
        'userId': uid,
        'topic': _topic.key,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'message': _message.text.trim(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'appVersion': kAppVersion,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _sentId = ref.id;
        _message.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Couldn\'t send right now.'),
        action: SnackBarAction(label: 'Use email', onPressed: () => openExternal(context, _mailto)),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(settingsProfileProvider(false)).value;
    if (!_prefilled && p != null) {
      _prefilled = true;
      _name.text = p.fullName;
      _email.text = p.email;
    }
    if (_sentId != null) {
      return Column(children: [
        const Icon(Icons.check_circle_rounded, color: kSetGreen, size: 48),
        const SizedBox(height: 8),
        const Text('Message sent — thank you!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Reference ${_sentId!.substring(0, 6).toUpperCase()} · we\'ll reply to ${_email.text}',
            textAlign: TextAlign.center, style: const TextStyle(color: kSetMuted)),
        const SizedBox(height: 10),
        TextButton(onPressed: () => setState(() => _sentId = null), child: const Text('Send another message')),
      ]);
    }
    InputDecoration dec(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('What is it about?', style: TextStyle(fontWeight: FontWeight.w700, color: kSetInk)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in SupportTopic.values)
            ChoiceChip(
              avatar: Icon(t.icon, size: 16, color: _topic == t ? Colors.white : kSetGreen),
              label: Text(t.label),
              selected: _topic == t,
              showCheckmark: false,
              selectedColor: kSetGreen,
              labelStyle: TextStyle(color: _topic == t ? Colors.white : kSetInk, fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _topic = t),
            ),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: dec('Your name', Icons.person_rounded),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: dec('Email for our reply', Icons.email_rounded),
          validator: (v) =>
              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 1500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _topic == SupportTopic.problem ? 'What happened? Which screen?' : 'Your message',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          validator: (v) => (v ?? '').trim().length < 10 ? 'Please write a little more (10+ characters)' : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => openExternal(context, _mailto),
              icon: const Icon(Icons.email_outlined, size: 18),
              label: const Text('Use my email app'),
            ),
            CompactButton(
              icon: Icons.send_rounded,
              label: _sending ? 'Sending…' : 'Send message',
              busy: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ]),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final SupportMessage m;
  const _MessageTile(this.m);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (m.status) {
      'resolved' => ('Answered', kSetGreen),
      'in_progress' => ('In progress', const Color(0xFF1565C0)),
      _ => ('Received', const Color(0xFFB26A00)),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(SupportTopic.labelFor(m.topic),
                style: const TextStyle(fontWeight: FontWeight.w800, color: kSetInk)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(m.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kSetMuted)),
        if (m.reply.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
            child: Text('Reply: ${m.reply}', style: const TextStyle(color: kSetInk)),
          ),
        ],
        if (m.createdAt != null) ...[
          const SizedBox(height: 4),
          Text(DateFormat('EEE d MMM yyyy · HH:mm').format(m.createdAt!),
              style: const TextStyle(color: kSetMuted, fontSize: 11.5)),
        ],
      ]),
    );
  }
}
