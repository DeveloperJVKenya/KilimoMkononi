// lib/widgets/offline_sync_banner.dart
//
// A persistent banner shown at the top of:
//   • FieldDataInputHomePage
//   • PestManagementHome
//   • DiseaseManagementHome
//
// Shows count of pending offline records and a "Sync now" button.
// Disappears automatically when queue is empty.
//
// Usage:
//   OfflineSyncBanner()   ← drop anywhere in a Column above the main content

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';

class OfflineSyncBanner extends StatefulWidget {
  const OfflineSyncBanner({super.key});

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends State<OfflineSyncBanner> {
  int  _pendingCount = 0;
  bool _syncing      = false;
  bool _loaded       = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await OfflineQueueService.pendingCount();
    if (mounted) setState(() { _pendingCount = count; _loaded = true; });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final synced = await OfflineQueueService.trySync();
    await _refresh();
    if (mounted) {
      setState(() => _syncing = false);
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF2A6B2A),
          behavior: SnackBarBehavior.floating,
          content: Row(children: [
            const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('$synced record${synced == 1 ? '' : 's'} synced ✓',
                style: const TextStyle(color: Colors.white)),
          ]),
        ));
      } else if (_pendingCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No connection — records will sync automatically.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _pendingCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6A817).withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFB97000)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$_pendingCount record${_pendingCount == 1 ? '' : 's'} saved offline — waiting to sync.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A4F00)),
          ),
        ),
        const SizedBox(width: 8),
        _syncing
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFFB97000)))
            : TextButton(
                onPressed: _sync,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFFB97000),
                ),
                child: const Text('Sync now',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
      ]),
    );
  }
}