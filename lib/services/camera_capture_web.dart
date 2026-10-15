// Browser-only camera adapter. Tracks stop on capture, back navigation and dispose.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

Future<Uint8List?> captureCamera(BuildContext context) => Navigator.of(
  context,
).push<Uint8List>(MaterialPageRoute(builder: (_) => const _Camera()));

class _Camera extends StatefulWidget {
  const _Camera();
  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> {
  final _video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true');
  late final String _view =
      'sanad-camera-${DateTime.now().microsecondsSinceEpoch}';
  html.MediaStream? _stream;
  String? _error;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain';
    ui.platformViewRegistry.registerViewFactory(_view, (_) => _video);
    _open();
  }

  Future<void> _open() async {
    try {
      if (html.window.navigator.mediaDevices == null)
        throw StateError('unsupported');
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 800},
          'height': {'ideal': 800},
        },
        'audio': false,
      });
      if (!mounted) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }
      _stream = stream;
      _video.srcObject = stream;
      await _video.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e.toString().contains('NotAllowed')
              ? 'Camera permission was denied. Allow camera access or upload a photo.'
              : 'Camera is unavailable. Use Upload photo instead.',
        );
    }
  }

  void _capture() {
    if (_video.videoWidth == 0 || _video.videoHeight == 0) return;
    final scale = _video.videoWidth > _video.videoHeight
        ? 800 / _video.videoWidth
        : 800 / _video.videoHeight;
    final canvas = html.CanvasElement(
      width: (_video.videoWidth * scale).round(),
      height: (_video.videoHeight * scale).round(),
    );
    canvas.context2D.drawImageScaled(
      _video,
      0,
      0,
      canvas.width!,
      canvas.height!,
    );
    Navigator.pop(
      context,
      base64Decode(canvas.toDataUrl('image/jpeg', 0.75).split(',').last),
    );
  }

  @override
  void dispose() {
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Take a picture')),
    body: Column(
      children: [
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppText(_error!, textAlign: TextAlign.center),
                  ),
                )
              : HtmlElementView(viewType: _view),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _ready ? _capture : null,
                icon: const Icon(Icons.camera_alt),
                label: const AppText('Capture'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Back'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
