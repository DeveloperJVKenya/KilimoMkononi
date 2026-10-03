// lib/settings/account_settings_screen.dart
//
// Settings → Account & security: who you're signed in as, email
// verification, change email / password (with re-authentication), password
// reset link, log out, and account deletion (farmers: profile + own records
// deleted now, the rest queued for the team via supportMessages; education
// users: a deletion request to the team).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/session_service.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

/// Farmer collections whose documents carry `userId` and that owners may
/// delete (see firestore.rules).
const kOwnedCollections = [
  'fielddata',
  'marketdata',
  'field_costs',
  'pest_costs',
  'disease_costs',
  'field_reminders',
];

String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' => 'That password is not correct.',
      'weak-password' => 'Choose a stronger password (at least 8 characters).',
      'email-already-in-use' => 'Another account already uses that email.',
      'invalid-email' => 'That email address doesn\'t look right.',
      'requires-recent-login' => 'For your security, log out and sign in again, then try once more.',
      'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
      'network-request-failed' => 'No internet connection. Check your data or Wi-Fi.',
      _ => friendlyError(e),
    };
  }
  return friendlyError(e);
}

/// Where the verification / reset emails send people back to.
final _returnToApp = ActionCodeSettings(url: 'https://kilimomkononi-e1031.web.app/', handleCodeInApp: false);

class AccountSettingsScreen extends ConsumerStatefulWidget {
  final bool isEducation;
  const AccountSettingsScreen({super.key, this.isEducation = false});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> with WidgetsBindingObserver {
  // The signed-in user caches emailVerified until reload(), so the badge is
  // refreshed on open, when the app comes back to the front, every few
  // seconds while unverified, and on "I've verified".
  bool? _verified;
  bool _checking = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshVerified();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshVerified();
  }

  Future<void> _refreshVerified({bool announce = false}) async {
    final User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return; // Firebase not ready (e.g. tests)
    }
    if (user == null) return;
    if (mounted) setState(() => _checking = true);
    try {
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      final ok = fresh?.emailVerified ?? false;
      // A fresh ID token carries email_verified to the security rules.
      if (ok && _verified != true) await fresh?.getIdToken(true);
      if (!mounted) return;
      setState(() => _verified = ok);
      _poll?.cancel();
      if (!ok) _poll = Timer(const Duration(seconds: 8), _refreshVerified);
      if (announce) {
        _snack(ok ? 'Email verified — thank you!' : 'Not verified yet. Open the link in the email, then try again.',
            ok: ok);
      }
    } catch (_) {
      // Offline: keep the last known value.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? kSetGreen : null, duration: const Duration(seconds: 5)));

  Future<void> _sendVerification(String email) async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification(_returnToApp);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: kSetGreen, size: 36),
          title: const Text('Check your email'),
          content: Text(
            'We sent a link to $email.\n\n'
            'Can\'t find it? Look in your Spam or Junk folder and mark it "Not spam" so our emails reach your inbox. '
            'After tapping the link, come back here — this page updates by itself.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      _refreshVerified();
    } catch (e) {
      _snack(authErrorMessage(e));
    }
  }

  Future<void> _sendReset(String email, {required bool addsPassword}) async {
    final ok = await confirmAction(
      context,
      icon: Icons.outgoing_mail,
      title: addsPassword ? 'Add a password?' : 'Send a reset link?',
      message: 'We\'ll email a link to $email. Your current password keeps working until you set a new one.',
      confirmLabel: 'Send link',
    );
    if (!ok) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email, actionCodeSettings: _returnToApp);
      _snack('Link sent to $email — check Spam if it isn\'t in your inbox.', ok: true);
    } catch (e) {
      _snack(authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEducation = widget.isEducation;
    final user = ref.watch(settingsAuthProvider).value;
    final profile = ref.watch(settingsProfileProvider(isEducation)).value;
    final methods = signInMethods(user);
    final hasPassword = methods.contains('password');
    final google = methods.contains('google.com');
    final email = user?.email ?? profile?.email ?? '';
    final since = profile?.createdAt ?? user?.metadata.creationTime;
    final verified = _verified ?? user?.emailVerified ?? false;

    return SettingsPage(
      title: 'Account & security',
      subtitle: 'Sign-in details and your data',
      children: [
        if (user != null && !verified && email.isNotEmpty)
          _VerifyBanner(
            email: email,
            checking: _checking,
            onSend: () => _sendVerification(email),
            onCheck: () => _refreshVerified(announce: true),
          ),
        SettingsSection(title: 'Signed in as', color: const Color(0xFF1565C0), children: [
          SettingsTile(
            icon: Icons.email_rounded,
            color: const Color(0xFF1565C0),
            title: email.isEmpty ? 'No email' : email,
            subtitle: google && hasPassword
                ? 'Google and password sign-in'
                : google
                    ? 'Signed in with Google'
                    : 'Email and password sign-in',
            trailing: verified
                ? const _Badge('Verified', kSetGreen, icon: Icons.verified_rounded)
                : const _Badge('Not verified', Color(0xFFB26A00), icon: Icons.error_outline_rounded),
          ),
          SettingsTile(
            icon: Icons.badge_rounded,
            color: const Color(0xFF1565C0),
            title: 'Account type',
            value: '${profile?.roleLabel ?? (isEducation ? 'Education' : 'Farmer')} · Free',
          ),
          if (since != null)
            SettingsTile(
              icon: Icons.event_available_rounded,
              color: const Color(0xFF1565C0),
              title: 'Member since',
              value: DateFormat('d MMM yyyy').format(since),
            ),
        ]),
        SettingsSection(
          title: 'Sign-in',
          color: const Color(0xFF2E7D32),
          footer: google && !hasPassword ? 'Your password is managed by your Google account.' : null,
          children: [
            if (hasPassword) ...[
              SettingsTile(
                icon: Icons.lock_reset_rounded,
                title: 'Change password',
                subtitle: 'You\'ll confirm your current password first',
                onTap: () => _sheet(const _ChangePasswordForm()),
              ),
              SettingsTile(
                icon: Icons.alternate_email_rounded,
                color: const Color(0xFF00838F),
                title: 'Change email',
                subtitle: 'We send a confirmation link to the new address',
                onTap: () => _sheet(_ChangeEmailForm(current: email)),
              ),
            ],
            SettingsTile(
              icon: Icons.outgoing_mail,
              color: const Color(0xFF6A1B9A),
              title: google && !hasPassword ? 'Add a password' : 'Send password reset link',
              subtitle: google && !hasPassword ? 'Sign in with email too' : 'If you\'ve forgotten your password',
              onTap: email.isEmpty ? null : () => _sendReset(email, addsPassword: google && !hasPassword),
            ),
            SettingsTile(
              icon: Icons.logout_rounded,
              color: const Color(0xFF546E7A),
              title: 'Log out of this device',
              onTap: () => confirmAndLogOut(context, isEducation: isEducation),
            ),
          ],
        ),
        SettingsSection(
          title: 'Danger zone',
          color: kSetRed,
          footer: isEducation
              ? 'Education accounts are linked to your school, so deletion is handled by our team.'
              : 'Deletes your profile and your records. This can\'t be undone.',
          children: [
            SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: isEducation ? 'Request account deletion' : 'Delete account and data',
              destructive: true,
              onTap: () => _sheet(_DeleteAccountForm(isEducation: isEducation, needsPassword: hasPassword, email: email)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sheet(Widget form) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => _SheetPadding(child: form),
      );
}

class _VerifyBanner extends StatelessWidget {
  final String email;
  final bool checking;
  final VoidCallback onSend;
  final VoidCallback onCheck;
  const _VerifyBanner({required this.email, required this.checking, required this.onSend, required this.onCheck});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFFFFF4E0), Color(0xFFFFE9C7)]),
          border: Border.all(color: const Color(0xFFF3D19C)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.mark_email_unread_rounded, color: Color(0xFFB26A00)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Verify your email',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Color(0xFF7A4A00))),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Confirm $email so you can recover your account. The email may land in Spam — '
            'this page updates by itself once you tap the link.',
            style: const TextStyle(color: Color(0xFF7A4A00), height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB26A00)),
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send link'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7A4A00)),
              onPressed: checking ? null : onCheck,
              icon: checking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('I\'ve verified'),
            ),
          ]),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge(this.label, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _SheetPadding extends StatelessWidget {
  final Widget child;
  const _SheetPadding({required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child)),
        ),
      );
}

InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

Future<void> _reauth(String password) async {
  final user = FirebaseAuth.instance.currentUser!;
  await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  const _PasswordField(this.controller, this.label, {this.validator});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hide,
        decoration: _dec(widget.label, Icons.lock_rounded,
            suffix: IconButton(
              tooltip: _hide ? 'Show password' : 'Hide password',
              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              onPressed: () => setState(() => _hide = !_hide),
            )),
        validator: widget.validator ?? (v) => (v ?? '').isEmpty ? 'Required' : null,
      );
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String text;
  const _SheetHeader(this.title, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: kSetMuted, height: 1.4)),
        ]),
      );
}

class _Error extends StatelessWidget {
  final String? text;
  const _Error(this.text);

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: kSetRed, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text!, style: const TextStyle(color: kSetRed))),
          ]),
        );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final ok = await confirmAction(
      context,
      icon: Icons.lock_reset_rounded,
      title: 'Change your password?',
      message: 'You\'ll use the new password the next time you sign in on any device.',
      confirmLabel: 'Change password',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauth(_current.text);
      await FirebaseAuth.instance.currentUser!.updatePassword(_next.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed'), backgroundColor: kSetGreen));
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _SheetHeader('Change password', 'Use at least 8 characters with letters and numbers.'),
          _Error(_error),
          _PasswordField(_current, 'Current password'),
          const SizedBox(height: 12),
          _PasswordField(_next, 'New password', validator: (v) {
            final t = v ?? '';
            if (t.length < 8) return 'At least 8 characters';
            if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) return 'Use letters and numbers';
            if (t == _current.text) return 'Choose a different password';
            return null;
          }),
          const SizedBox(height: 12),
          _PasswordField(_confirm, 'Confirm new password',
              validator: (v) => v != _next.text ? 'Passwords don\'t match' : null),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: CompactButton(
              icon: Icons.lock_reset_rounded,
              label: _busy ? 'Changing…' : 'Change password',
              busy: _busy,
              onPressed: _submit,
            ),
          ),
        ]),
      );
}

class _ChangeEmailForm extends StatefulWidget {
  final String current;
  const _ChangeEmailForm({required this.current});

  @override
  State<_ChangeEmailForm> createState() => _ChangeEmailFormState();
}

class _ChangeEmailFormState extends State<_ChangeEmailForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final next = _email.text.trim();
    final ok = await confirmAction(
      context,
      icon: Icons.alternate_email_rounded,
      title: 'Change your email?',
      message: 'We\'ll send a confirmation link to $next. Until you tap it, keep signing in with '
          '${widget.current}.',
      confirmLabel: 'Send link',
      color: const Color(0xFF00838F),
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauth(_password.text);
      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(next, _returnToApp);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Check $next (and Spam) and tap the link to finish. Your email changes after that.'),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SheetHeader('Change email', 'Currently ${widget.current}. We\'ll send a link to the new address.'),
          _Error(_error),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('New email', Icons.alternate_email_rounded),
            validator: (v) {
              final t = (v ?? '').trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Enter a valid email';
              if (t.toLowerCase() == widget.current.toLowerCase()) return 'That\'s your current email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _PasswordField(_password, 'Current password'),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: CompactButton(
              icon: Icons.send_rounded,
              label: _busy ? 'Sending…' : 'Send confirmation link',
              color: const Color(0xFF00838F),
              busy: _busy,
              onPressed: _submit,
            ),
          ),
        ]),
      );
}

class _DeleteAccountForm extends StatefulWidget {
  final bool isEducation;
  final bool needsPassword;
  final String email;
  const _DeleteAccountForm({required this.isEducation, required this.needsPassword, required this.email});

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _form = GlobalKey<FormState>();
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _progress;

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _queueRequest(String uid, String note) => FirebaseFirestore.instance.collection('supportMessages').add({
        'userId': uid,
        'topic': 'account_deletion',
        'name': FirebaseAuth.instance.currentUser?.displayName ?? '',
        'email': widget.email,
        'message': note,
        'platform': widget.isEducation ? 'education' : 'farmer',
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.isEducation) {
        await _queueRequest(user.uid, 'Please delete my education account and data.');
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(
            content: Text('Request sent. Our team will confirm by email within 7 days.'), backgroundColor: kSetGreen));
        return;
      }
      if (widget.needsPassword) {
        setState(() => _progress = 'Confirming your password…');
        await _reauth(_password.text);
      }
      final db = FirebaseFirestore.instance;
      setState(() => _progress = 'Recording your request…');
      await _queueRequest(user.uid, 'Account deleted from the app — remove any remaining records.');
      for (final c in kOwnedCollections) {
        setState(() => _progress = 'Deleting your records ($c)…');
        try {
          final snap = await db.collection(c).where('userId', isEqualTo: user.uid).get();
          for (var i = 0; i < snap.docs.length; i += 400) {
            final batch = db.batch();
            for (final d in snap.docs.skip(i).take(400)) {
              batch.delete(d.reference);
            }
            await batch.commit();
          }
        } catch (_) {/* the team request above covers anything left */}
      }
      setState(() => _progress = 'Deleting your profile…');
      await db.collection('notificationPrefs').doc(user.uid).delete().catchError((_) {});
      await db.collection('Users').doc(user.uid).delete();
      await user.delete();
      await SessionService.signOut().catchError((_) {});
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(e);
          _progress = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SheetHeader(
            widget.isEducation ? 'Request account deletion' : 'Delete your account?',
            widget.isEducation
                ? 'We\'ll remove your education account and learning records, and email ${widget.email} when done.'
                : 'This permanently deletes your profile, field data, costs, reminders and price reports. '
                    'Anything else linked to you is removed by our team within 30 days.',
          ),
          _Error(_error),
          if (widget.needsPassword && !widget.isEducation) ...[
            _PasswordField(_password, 'Your password'),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _confirm,
            decoration: _dec('Type DELETE to confirm', Icons.warning_amber_rounded),
            validator: (v) => (v ?? '').trim().toUpperCase() == 'DELETE' ? null : 'Type DELETE to confirm',
          ),
          if (_progress != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(_progress!, style: const TextStyle(color: kSetMuted))),
            ]),
          ],
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
            TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            CompactButton(
              icon: widget.isEducation ? Icons.send_rounded : Icons.delete_forever_rounded,
              label: widget.isEducation ? 'Send request' : 'Delete forever',
              color: kSetRed,
              busy: _busy,
              onPressed: _submit,
            ),
          ]),
        ]),
      );
}
