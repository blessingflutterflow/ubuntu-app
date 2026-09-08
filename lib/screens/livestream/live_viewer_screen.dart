import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/livestream_model.dart';
import '../../services/livestream_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

const _kAgoraAppId = String.fromEnvironment('AGORA_APP_ID');

class LiveViewerScreen extends StatefulWidget {
  final String streamId;
  const LiveViewerScreen({super.key, required this.streamId});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final _livestreamService = LivestreamService();
  final _commentCtrl = TextEditingController();

  RtcEngine? _engine;
  int? _remoteUid;
  bool _streamEnded = false;

  StreamSubscription<int>? _viewerCountSub;
  StreamSubscription<List<LiveCommentModel>>? _commentsSub;
  StreamSubscription<String?>? _statusSub;
  int _viewerCount = 0;
  List<LiveCommentModel> _comments = [];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      final auth = await _livestreamService.fetchAgoraToken(widget.streamId, 'audience');

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(
        appId: _kAgoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await engine.enableVideo();

      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
      ));

      await engine.joinChannel(
        token: auth.token,
        channelId: widget.streamId,
        uid: auth.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      if (!mounted) return;
      setState(() => _engine = engine);

      await _livestreamService.joinViewerPresence(widget.streamId, _uid);

      _viewerCountSub = _livestreamService.observeViewerCount(widget.streamId).listen((c) {
        if (mounted) setState(() => _viewerCount = c);
      });
      _commentsSub = _livestreamService.observeLiveComments(widget.streamId).listen((c) {
        if (mounted) setState(() => _comments = c);
      });
      _statusSub = _livestreamService.observeLivestreamStatus(widget.streamId).listen((status) {
        if (status == 'ENDED' && mounted) setState(() => _streamEnded = true);
      });
    } catch (_) {
      if (mounted) setState(() => _streamEnded = true);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    await _livestreamService.sendLiveComment(widget.streamId, text);
  }

  void _leave() => Navigator.of(context).maybePop();

  @override
  void dispose() {
    _viewerCountSub?.cancel();
    _commentsSub?.cancel();
    _statusSub?.cancel();
    _livestreamService.leaveViewerPresence(widget.streamId, _uid);
    _engine?.leaveChannel();
    _engine?.release();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_engine != null && _remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.streamId),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: UbuntuColors.liked, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(' · $_viewerCount watching', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _leave,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            UbuntuAvatar(url: c.senderProfileImageUrl, name: c.senderUsername, size: 22),
                            const SizedBox(width: 6),
                            Text('${c.senderUsername}  ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            Expanded(child: Text(c.text, style: const TextStyle(color: Colors.white, fontSize: 12))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Say something…',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.send, color: UbuntuColors.primary), onPressed: _sendComment),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_streamEnded)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This live stream has ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _leave,
                      child: const Text('Go back', style: TextStyle(color: UbuntuColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
