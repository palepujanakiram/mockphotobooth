import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays an RTSP video stream using native LibVLC player.
/// 
/// This widget uses a platform-specific view to render RTSP streams efficiently
/// with hardware acceleration and native performance.
class RtspPlayer extends StatelessWidget {
  /// The RTSP URL to stream (including credentials if needed).
  /// Example: rtsp://username:password@192.168.1.100:554/stream1
  final String url;

  const RtspPlayer({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    // Only works on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Center(
        child: Text(
          'RTSP streaming is only supported on Android',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: AndroidView(
        viewType: 'rtsp_player_view',
        creationParams: {'url': url},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) {
          print('📺 Native RTSP player view created: $id');
        },
      ),
    );
  }
}
