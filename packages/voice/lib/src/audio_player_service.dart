import 'package:just_audio/just_audio.dart';

/// Real, offline audio playback (spec 2.5 VoiceService's fourth box).
///
/// [TextToSpeechService] speaks directly through the OS TTS engine with no
/// intermediate audio, so this wasn't previously needed. It becomes real
/// once a synthesis backend produces a standalone audio file to play back
/// (Piper/Kokoro via `sherpa_onnx`, THE-41/THE-42) — those write a WAV file
/// and hand the path to [playFile] rather than speaking in one step.
///
/// Playback happens entirely from a local file path — no network call is
/// made, matching spec 8.2's offline hard rule.
class AudioPlayerService {
  final AudioPlayer _player;

  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  /// Whether audio is currently playing.
  Stream<bool> get isPlayingStream => _player.playerStateStream.map((state) => state.playing);

  Future<AudioPlaybackResult> playFile(String filePath) async {
    if (filePath.trim().isEmpty) return AudioPlaybackResult.error;
    try {
      await _player.setFilePath(filePath);
      await _player.play();
      return AudioPlaybackResult.played;
    } catch (_) {
      return AudioPlaybackResult.error;
    }
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}

enum AudioPlaybackResult { played, error }
