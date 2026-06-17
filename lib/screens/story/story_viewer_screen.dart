import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class StoryViewerScreen extends StatefulWidget {
  final String userId;
  final bool   isOwnStory;
  const StoryViewerScreen({super.key, required this.userId, this.isOwnStory = false});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {

  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Map<String, dynamic>> _stories = [];
  int     _index     = 0;
  bool    _loading   = true;
  bool    _paused    = false;
  String  _username  = '';
  String  _avatarUrl = '';

  late AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this);
    _progressCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    _load();
  }

  Future<void> _load() async {
    // Load user info
    final userDoc = await _db.collection('users').doc(widget.userId).get();
    _username  = userDoc.data()?['username'] as String? ?? 'User';
    _avatarUrl = userDoc.data()?['profileImageUrl'] as String? ?? '';

    // Load active stories
    final now  = Timestamp.now();
    final snap = await _db
        .collection('stories')
        .doc(widget.userId)
        .collection('items')
        .get();

    if (!mounted) return;

    final stories = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((s) {
          final exp = s['expiresAt'];
          if (exp is Timestamp) return exp.toDate().isAfter(now.toDate());
          return true;
        })
        .toList()
      ..sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          final da = ta is Timestamp ? ta.toDate() : DateTime(0);
          final db = tb is Timestamp ? tb.toDate() : DateTime(0);
          return da.compareTo(db);
        });

    if (stories.isEmpty) {
      context.pop();
      return;
    }

    setState(() {
      _stories = stories;
      _loading = false;
    });

    _showStory(0);
  }

  void _showStory(int index) {
    _progressCtrl.stop();
    _progressCtrl.reset();
    setState(() => _index = index);

    final story    = _stories[index];
    final durationMs = (story['duration'] as num?)?.toInt() ?? 5000;
    _progressCtrl.duration = Duration(milliseconds: durationMs);
    _progressCtrl.forward();

    // Mark as viewed if not own story
    if (!widget.isOwnStory && _uid.isNotEmpty) {
      _db.collection('stories')
          .doc(widget.userId)
          .collection('items')
          .doc(story['id'] as String)
          .update({'viewedBy': FieldValue.arrayUnion([_uid])});
    }
  }

  void _next() {
    if (_index + 1 < _stories.length) {
      _showStory(_index + 1);
    } else {
      context.pop();
    }
  }

  void _prev() {
    if (_index - 1 >= 0) {
      _showStory(_index - 1);
    }
  }

  void _pause()  { _paused = true;  _progressCtrl.stop(); }
  void _resume() { _paused = false; _progressCtrl.forward(); }

  Future<void> _delete() async {
    _pause();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) { _resume(); return; }

    final storyId = _stories[_index]['id'] as String;
    await _db.collection('stories').doc(widget.userId).collection('items').doc(storyId).delete();

    setState(() => _stories.removeAt(_index));
    if (_stories.isEmpty) {
      await _db.collection('users').doc(widget.userId).update({'hasActiveStory': false});
      if (mounted) context.pop();
    } else {
      _showStory(_index >= _stories.length ? _stories.length - 1 : _index);
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: UbuntuColors.primary)),
      );
    }

    final story    = _stories[_index];
    final imageUrl = story['imageUrl'] as String?;
    final ts       = story['createdAt'];
    DateTime? createdAt;
    if (ts is Timestamp) createdAt = ts.toDate();

    final viewedBy  = List<String>.from(story['viewedBy'] as List? ?? []);
    final viewCount = viewedBy.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Story image ──
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl:    imageUrl,
                fit:         BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: UbuntuColors.primary)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              )
            else
              const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64)),

            // ── Progress bars ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8, right: 8,
              child: Row(
                children: List.generate(_stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _index
                            ? Container(height: 3, color: Colors.white)
                            : i == _index
                                ? AnimatedBuilder(
                                    animation: _progressCtrl,
                                    builder: (_, __) => LinearProgressIndicator(
                                      value:            _progressCtrl.value,
                                      backgroundColor:  Colors.white38,
                                      valueColor:       const AlwaysStoppedAnimation(Colors.white),
                                      minHeight:        3,
                                    ),
                                  )
                                : Container(height: 3, color: Colors.white38),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Header: avatar + username + time + close ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12, right: 12,
              child: Row(
                children: [
                  UbuntuAvatar(url: _avatarUrl, name: _username, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_username,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        if (createdAt != null)
                          Text(formatTimestamp(createdAt),
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (widget.isOwnStory)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

            // ── View count for own stories ──
            if (widget.isOwnStory)
              Positioned(
                bottom: 32,
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text('$viewCount ${viewCount == 1 ? 'view' : 'views'}',
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
