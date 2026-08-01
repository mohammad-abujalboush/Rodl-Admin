import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerPhone = true;

  bool get isMuted => _isMuted;
  bool get isSpeakerPhone => _isSpeakerPhone;

  Future<void> initAgora(String appId) async {
    if (_isInitialized) return;

    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    await _engine!.enableAudio();
    await _engine!.setEnableSpeakerphone(true);
    _isInitialized = true;
  }

  Future<void> joinCall({
    required String appId,
    required String channelName,
    required String token,
    required String userAccount,
  }) async {
    await initAgora(appId);

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelName,
      userAccount: userAccount,
    );
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
  }

  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerPhone = !_isSpeakerPhone;
    await _engine!.setEnableSpeakerphone(_isSpeakerPhone);
  }

  Future<void> leaveCall() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    _isMuted = false;
  }

  Future<void> dispose() async {
    if (_engine != null) {
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
    }
  }
}
