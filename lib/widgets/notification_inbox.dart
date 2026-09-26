// lib/widgets/notification_inbox.dart
//
// The in-app copy of every push a user received (userNotifications/{uid}/
// items, written by functions/notifications.js), styled like the Farm Alerts
// cards so a notification looks the same on the phone and in the app.
// Also lists recent verified advice, which farmers receive via crop topics.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/services/notification_service.dart';

class InboxItem {
  final String id;
  final String type;
  final KmChannel channel;
  final String title;
  final String body;
  final String? route;
  final String? severity;
  final bool read;
  final DateTime? createdAt;

  const InboxItem({
    required this.id,
    required this.type,
    required this.channel,
    required this.title,
    required this.body,
    this.route,
    this.severity,
    this.read = false,
    this.createdAt,
  });

  factory InboxItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return InboxItem(
      id: doc.id,
      type: (d['type'] as String?) ?? 'general',
      channel: KmChannel.fromId(d['channel'] as String?),
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      route: d['route'] as String?,
      severity: d['severity'] as String?,
      read: d['read'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Same colour language as the Farm Alerts tab.
  Color get color => switch (channel) {
        KmChannel.weatherAlerts =>
          severity == 'critical' ? const Color(0xFFB71C1C) : const Color(0xFFE65100),
        KmChannel.advisories => AdvisoryColors.verified,
        KmChannel.approvals => const Color(0xFF1565C0),
        KmChannel.reminders => const Color(0xFF6A1B9A),
        _ => const Color(0xFF455A64),
      };

  IconData get icon => switch (type) {
        'weather_alert' => Icons.thunderstorm_outlined,
        'advisory' => Icons.verified_rounded,
        'approval_request' => Icons.how_to_reg_outlined,
        'approval_decision' => Icons.verified_user_outlined,
        _ => Icons.notifications_none_rounded,
      };
}

class NotificationInbox extends StatelessWidget {
  /// Reports the unread count (for the tab label).
  final ValueChanged<int>? onUnreadCount;
  const NotificationInbox({super.key, this.onUnreadCount});

  CollectionReference<Map<String, dynamic>>? get _items {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('userNotifications')
        .doc(uid)
        .collection('items');
  }

  @override
  Widget build(BuildContext context) {
    final col = _items;
    if (col == null) {
      return const Center(child: Text('Sign in to see your notifications.'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load notifications.\n${snap.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!.docs.map(InboxItem.fromDoc).toList();
        final unread = items.where((i) => !i.read).length;
        WidgetsBinding.instance.addPostFrameCallback((_) => onUnreadCount?.call(unread));

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _markAllRead(col, items),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: Text('Mark $unread as read'),
                ),
              ),
            if (items.isEmpty) _empty(),
            ...items.map((i) => _InboxCard(item: i, col: col)),
            const SizedBox(height: 8),
            const _RecentVerifiedAdvice(),
          ],
        );
      },
    );
  }

  Future<void> _markAllRead(
      CollectionReference<Map<String, dynamic>> col, List<InboxItem> items) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final i in items.where((i) => !i.read)) {
      batch.update(col.doc(i.id), {'read': true});
    }
    await batch.commit();
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('No notifications yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Weather alerts for your station, verified advice and approvals '
            'will appear here and on your phone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ]),
      );
}

class _InboxCard extends StatelessWidget {
  final InboxItem item;
  final CollectionReference<Map<String, dynamic>> col;
  const _InboxCard({required this.item, required this.col});

  @override
  Widget build(BuildContext context) {
    final color = item.read ? item.color.withValues(alpha: 0.55) : item.color;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => col.doc(item.id).delete(),
      child: Card(
        elevation: item.read ? 1 : 3,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: InkWell(
          onTap: () {
            if (!item.read) col.doc(item.id).update({'read': true});
            final route = item.route;
            if (route != null) NotificationService.routeHandler?.call(route);
          },
          child: Column(children: [
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(children: [
                Icon(item.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                if (!item.read)
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.body, style: const TextStyle(fontSize: 13, height: 1.45)),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.notifications_active_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${item.channel.label} · ${formatAdvisoryDate(item.createdAt)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  if (item.route != null)
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Latest live verified advisories (farmers get these via crop-topic pushes,
/// which have no per-user inbox copy).
class _RecentVerifiedAdvice extends StatelessWidget {
  const _RecentVerifiedAdvice();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('agronomic_advisories')
          .where('status', isEqualTo: 'published')
          .where('testOnly', isEqualTo: false)
          .get(),
      builder: (context, snap) {
        final list = (snap.data?.docs ?? const [])
            .map(AgronomicAdvisory.fromDoc)
            .toList()
          ..sort((a, b) => (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Text('RECENT VERIFIED ADVICE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AdvisoryColors.verified)),
          ),
          for (final a in list.take(5)) ...[
            VerifiedAdvisoryCard.fromAdvisory(a),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}
