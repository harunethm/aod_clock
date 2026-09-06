import 'dart:async';

import 'package:aod_clock/core/platform/now_playing_channel.dart';
import 'package:aod_clock/features/now_playing/data/datasources/now_playing_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNowPlayingChannel implements NowPlayingChannel {
  final _controller = StreamController<Map<Object?, Object?>?>();

  @override
  Stream<Map<Object?, Object?>?> get trackStream => _controller.stream;

  void emit(Map<Object?, Object?>? event) => _controller.add(event);

  var playCalled = false;
  var pauseCalled = false;

  @override
  Future<void> play() async => playCalled = true;

  @override
  Future<void> pause() async => pauseCalled = true;

  @override
  Future<void> skipNext() async {}

  @override
  Future<void> skipPrevious() async {}
}

void main() {
  test('parses a full event into a NowPlayingTrack', () async {
    final channel = _FakeNowPlayingChannel();
    final datasource = NowPlayingDatasource(channel);

    final future = datasource.trackStream.first;
    channel.emit({
      'title': 'Song',
      'artist': 'Artist',
      'isPlaying': true,
      'positionMs': 1000,
      'durationMs': 200000,
    });

    final track = await future;
    expect(track!.title, 'Song');
    expect(track.artist, 'Artist');
    expect(track.isPlaying, true);
    expect(track.positionMs, 1000);
    expect(track.durationMs, 200000);
  });

  test('null event maps to null track (nothing playing)', () async {
    final channel = _FakeNowPlayingChannel();
    final datasource = NowPlayingDatasource(channel);

    final future = datasource.trackStream.first;
    channel.emit(null);

    expect(await future, isNull);
  });

  test('control calls forward to the channel', () async {
    final channel = _FakeNowPlayingChannel();
    final datasource = NowPlayingDatasource(channel);

    await datasource.play();
    expect(channel.playCalled, true);

    await datasource.pause();
    expect(channel.pauseCalled, true);
  });
}
