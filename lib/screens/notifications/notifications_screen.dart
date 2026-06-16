import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notifService = NotificationService();
  List<NotificationModel> _notifs  = [];
  bool                    _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .limit(80)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _notifs = snap.docs
              .map((d) => NotificationModel.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _loading = false;
        });
      }
    });
  }

  void _markRead(NotificationModel n) {
    if (!n.isRead) {
      _notifService.markAsRead(n.id);
      setState(() {
        final idx = _notifs.indexWhere((x) => x.id == n.id);
        if (idx != -1) _notifs[idx] = n.copyWith(isRead: true);
      });
    }
  }

  void _markAllRead() {
    _notifService.markAllAsRead();
    setState(() {
      _notifs = _notifs.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: Column(
        children: [
          _TopBar(onBack: () => context.pop(), onMarkAll: _markAllRead),
          const Divider(height: 0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: UbuntuColors.primary))
                : _notifs.isEmpty
                    ? _EmptyState()
                    : ListView.separated(
                        itemCount:     _notifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final n = _notifs[i];
                          return _NotifRow(
                            notif:   n,
                            onTap: () {
                              _markRead(n);
                              if (n.postId != null) {
                                context.push('/post/${n.postId}');
                              } else if (n.type == 'FOLLOW') {
                                context.push('/profile/${n.senderId}');
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMarkAll;
  const _TopBar({required this.onBack, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
                onPressed: onBack,
              ),
              const Expanded(
                child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
              ),
              TextButton(
                onPressed: onMarkAll,
                child: const Text('Mark all read', style: TextStyle(color: UbuntuColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback      onTap;
  const _NotifRow({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: notif.isRead ? UbuntuColors.canvas : const Color(0xFFF0FFF4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar + type badge
            SizedBox(
              width: 46, height: 46,
              child: Stack(
                children: [
                  UbuntuAvatar(url: notif.senderProfileImageUrl, name: notif.senderUsername, size: 46),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(color: _colorFor(notif.type), shape: BoxShape.circle),
                      child: Icon(_iconFor(notif.type), color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.message, style: UbuntuText.body.copyWith(color: UbuntuColors.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(formatNotifTime(notif.timestamp), style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (notif.postThumbnailUrl != null && notif.postThumbnailUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(notif.postThumbnailUrl!, width: 44, height: 44, fit: BoxFit.cover),
              )
            else if (!notif.isRead)
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: UbuntuColors.primary, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'LIKE':            return Icons.favorite;
      case 'COMMENT':
      case 'COMMENT_REPLY':  return Icons.chat_bubble;
      case 'FOLLOW':          return Icons.person_add;
      case 'NEW_POST':        return Icons.photo_library;
      default:                return Icons.notifications;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'LIKE':            return UbuntuColors.liked;
      case 'COMMENT':
      case 'COMMENT_REPLY':  return UbuntuColors.primary;
      case 'FOLLOW':          return const Color(0xFF3897F0);
      default:                return UbuntuColors.primary;
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_outlined, color: UbuntuColors.divider, size: 56),
          SizedBox(height: 12),
          Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'When someone likes or comments on your posts, you\'ll see it here.',
              style:     UbuntuText.body,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
