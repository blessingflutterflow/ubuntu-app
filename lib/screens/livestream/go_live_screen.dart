import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../../models/livestream_model.dart';
import '../../services/livestream_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

const _kAgoraAppId = String.fromEnvironment('AGORA_APP_ID');
const _kStreamCapSeconds = 60 * 60;

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _livestreamService = LivestreamService();
  final _titleCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  RtcEngine? _engine;
  bool _engineReady = false;
  String? _streamId;
  bool _isStarting = false;
  int _secondsRemaining = _kStreamCapSeconds;
  Timer? _countdownTimer;

  StreamSubscription<int>? _viewerCountSub;
  StreamSubscription<List<LiveCommentModel>>? _commentsSub;
  int _viewerCount = 0;
  List<LiveCommentModel> _comments = [];

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _kAgoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    await engine.enableVideo();
    await engine.startPreview();
    if (mounted) setState(() { _engine = engine; _engineReady = true; });
  }

  Future<void> _goLive() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _isStarting = true);

    final streamId = await _livestreamService.createLivestream(_titleCtrl.text.trim());
    if (streamId == null) {
      if (mounted) setState(() => _isStarting = false);
      return;
    }

    try {
      final auth = await _livestreamService.fetchAgoraToken(streamId, 'publisher');
      await engine.joinChannel(
        token: auth.token,
        channelId: streamId,
        uid: auth.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      if (!mounted) return;
      setState(() { _streamId = streamId; _isStarting = false; });
      _startCountdown();
      _viewerCountSub = _livestreamService.observeViewerCount(streamId).listen((c) {
        if (mounted) setState(() => _viewerCount = c);
      });
      _commentsSub = _livestreamService.observeLiveComments(streamId).listen((c) {
        if (mounted) setState(() => _comments = c);
      });
    } catch (_) {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _endStream();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  Future<void> _endStream() async {
    final id = _streamId;
    if (id != null) await _livestreamService.endLivestream(id);
    await _engine?.leaveChannel();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _sendComment() async {
    final id = _streamId;
    final text = _commentCtrl.text.trim();
    if (id == null || text.isEmpty) return;
    _commentCtrl.clear();
    await _livestreamService.sendLiveComment(id, text);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _viewerCountSub?.cancel();
    _commentsSub?.cancel();
    // Defensive cleanup if the screen is torn down unexpectedly while still
    // live — the scheduled Cloud Function is the real backstop regardless.
    final id = _streamId;
    if (id != null) _livestreamService.endLivestream(id);
    _engine?.leaveChannel();
    _engine?.release();
    _titleCtrl.dispose();
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
          if (_engineReady && _engine != null)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: _streamId != null ? _endStream : () => Navigator.of(context).maybePop(),
                      ),
                      if (_streamId != null)
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
                              Text(' · ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
                const Spacer(),
                if (_streamId != null) ...[
                  SizedBox(
                    height: 200,
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
                        TextButton(
                          onPressed: _endStream,
                          child: const Text('End', style: TextStyle(color: UbuntuColors.liked, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Add a title…', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none, isDense: true),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: (_engineReady && !_isStarting) ? _goLive : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UbuntuColors.liked,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: _isStarting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Go Live', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
