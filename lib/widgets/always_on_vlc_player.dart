import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

/// A VLC player widget that always mounts the underlying platform view.
///
/// The upstream `VlcPlayer` widget hides the platform view behind an `Offstage`
/// until the controller is initialized. On some Android devices this can prevent
/// the platform view from being created, which in turn prevents
/// `onPlatformViewCreated` from firing and the controller from initializing.
class AlwaysOnVlcPlayer extends StatefulWidget {
  final VlcPlayerController controller;
  final double aspectRatio;
  final Widget? placeholder;
  final bool virtualDisplay;

  const AlwaysOnVlcPlayer({
    required this.controller,
    required this.aspectRatio,
    this.placeholder,
    this.virtualDisplay = false,
    super.key,
  });

  @override
  State<AlwaysOnVlcPlayer> createState() => _AlwaysOnVlcPlayerState();
}

class _AlwaysOnVlcPlayerState extends State<AlwaysOnVlcPlayer> {
  late VoidCallback _listener;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _isInitialized = widget.controller.value.isInitialized;
    _listener = () {
      if (!mounted) return;
      final next = widget.controller.value.isInitialized;
      if (next != _isInitialized) {
        // ignore: avoid_print
        if (next) print('✅ VLC player initialized');
        setState(() => _isInitialized = next);
      }
    };
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant AlwaysOnVlcPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      _isInitialized = widget.controller.value.isInitialized;
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: avoid_print
    print(
      '🎬 AlwaysOnVlcPlayer build: isInitialized=$_isInitialized virtualDisplay=${widget.virtualDisplay}',
    );
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: [
          // Always render VlcPlayer (not Offstage)
          VlcPlayer(
            controller: widget.controller,
            aspectRatio: widget.aspectRatio,
            virtualDisplay: widget.virtualDisplay,
          ),
          if (!_isInitialized)
            Positioned.fill(child: widget.placeholder ?? const SizedBox()),
        ],
      ),
    );
  }
}

