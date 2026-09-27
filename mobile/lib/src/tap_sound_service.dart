import 'package:audioplayers/audioplayers.dart';

class TapSoundService {
  static const labels = <String, String>{
    'soft_click': 'Soft Click',
    'wooden_bead': 'Wooden Bead',
    'temple_bell': 'Temple Bell',
  };

  static const _assets = <String, String>{
    'soft_click': 'sounds/soft_click.wav',
    'wooden_bead': 'sounds/wooden_bead.wav',
    'temple_bell': 'sounds/temple_bell.wav',
  };

  AudioPool? _pool;
  String? _preparedSound;
  int _generation = 0;

  Future<void> prepare(String sound) async {
    if (_preparedSound == sound && _pool != null) return;
    final asset = _assets[sound] ?? _assets['soft_click']!;
    final generation = ++_generation;
    final oldPool = _pool;
    _pool = null;
    _preparedSound = sound;
    await oldPool?.dispose();

    try {
      final nextPool = await AudioPool.createFromAsset(
        path: asset,
        minPlayers: 2,
        maxPlayers: 5,
        playerMode: PlayerMode.lowLatency,
      );
      if (generation == _generation) {
        _pool = nextPool;
      } else {
        await nextPool.dispose();
      }
    } catch (_) {
      // Counting must continue even when a device cannot initialize audio.
    }
  }

  Future<void> play(String sound) async {
    if (_preparedSound != sound || _pool == null) await prepare(sound);
    try {
      final stop = await _pool?.start(volume: .8);
      if (stop != null) {
        Future<void>.delayed(const Duration(milliseconds: 650), stop);
      }
    } catch (_) {
      // Audio is optional and must never interrupt a count.
    }
  }

  Future<void> dispose() async {
    _generation++;
    await _pool?.dispose();
    _pool = null;
  }
}
