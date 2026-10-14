import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:salahly/features/calls/domain/services/call_ringer.dart';

/// Rings with the phone's own sounds.
class DeviceCallRinger implements CallRinger {
  final _player = FlutterRingtonePlayer();

  @override
  Future<void> start({required bool incoming}) async {
    try {
      if (incoming) {
        await _player.playRingtone(volume: 1);
      } else {
        await _player.play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
          looping: true,
          volume: 0.5,
        );
      }
    } on Object {
      // A phone that can't ring still takes the call.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // Nothing was playing.
    }
  }
}
