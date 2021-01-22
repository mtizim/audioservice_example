import 'package:flutter/material.dart';
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

String awfulsong =
    "https://commondatastorage.googleapis.com/codeskulptor-demos/DDR_assets/Kangaroo_MusiQue_-_The_Neverwritten_Role_Playing_Game.mp3";
void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AudioServiceWidget(
          child: MyHomePage(title: 'Flutter Demo Home Page')),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool _started = false;

  void _play() async {
    if (!_started) {
      await AudioService.start(
          backgroundTaskEntrypoint: backgroundTaskEntrypoint);
      await AudioService.playMediaItem(
          MediaItem(id: "123", album: "456", title: "789"));
      _started = true;
    }
    AudioService.play();
  }

  void _pause() async {
    if (!_started) {
      await AudioService.start(
          backgroundTaskEntrypoint: backgroundTaskEntrypoint);
      _started = true;
    }
    AudioService.pause();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: StreamBuilder<PlaybackState>(
            stream: AudioService.playbackStateStream,
            builder: (context, snapshot) {
              bool _playing = snapshot.hasData ? snapshot.data.playing : false;
              return TextButton(
                onPressed: () => !_playing ? _play() : _pause(),
                child: Text(_playing ? "playing" : "paused"),
              );
            }),
      ),
    );
  }
}

void backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  final _player = AudioPlayer();

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    _player
      ..positionStream.listen((position) {
        AudioServiceBackground.setState(position: position);
      })
      ..processingStateStream.listen((s) {
        switch (s) {
          case ProcessingState.buffering:
            AudioServiceBackground.setState(
                processingState: AudioProcessingState.buffering);
            break;
          case ProcessingState.idle:
            AudioServiceBackground.setState(
                processingState: AudioProcessingState.none);
            break;
          case ProcessingState.loading:
            AudioServiceBackground.setState(
                processingState: AudioProcessingState.buffering);
            break;
          case ProcessingState.ready:
            AudioServiceBackground.setState(
                processingState: AudioProcessingState.ready);
            break;
          case ProcessingState.completed:
            AudioServiceBackground.setState(
                processingState: AudioProcessingState.completed);
            break;
        }
      });
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!AudioServiceBackground.state.playing) {
      await onStop();
    }
  }

  @override
  Future<void> onPlayMediaItem(MediaItem mediaItem) async {
    AudioServiceBackground.setMediaItem(mediaItem);
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {
    await _player.setUrl(mediaId);
  }

  @override
  Future onCustomAction(String name, dynamic arguments) async {
    if (name == 'getDurationMillis') {
      return _player.duration.inMilliseconds;
    }
  }

  @override
  Future<void> onPlay() async {
    if (((_player.duration ?? const Duration()) - _player.position).abs() <
        const Duration(milliseconds: 100)) {
      await _player.seek(const Duration());
    }
    AudioServiceBackground.setState(
        controls: [MediaControl.pause],
        androidCompactActions: [0],
        systemActions: [MediaAction.pause],
        playing: true);
    _player.play();
  }

  @override
  Future<void> onPause() async {
    AudioServiceBackground.setState(
        controls: [MediaControl.play],
        androidCompactActions: [0],
        systemActions: [MediaAction.play],
        playing: false);
    _player.pause();
  }

  @override
  Future<void> onSeekTo(Duration duration) => _player.seek(duration);
  @override
  Future<void> onStop() async {
    await _player.dispose();
    await super.onStop();
  }
}
