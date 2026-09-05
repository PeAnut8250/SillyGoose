import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_router/audio_router.dart';

class AudioDeviceDropdown extends StatefulWidget {
  const AudioDeviceDropdown({super.key});

  @override
  State<AudioDeviceDropdown> createState() => _AudioDeviceDropdownState();
}

class _AudioDeviceDropdownState extends State<AudioDeviceDropdown> {
  final AudioRouter _audioRouter = AudioRouter();

  IconData _getIconForDeviceType(AudioSourceType type) {
    switch (type) {
      case AudioSourceType.bluetooth:
        return Icons.bluetooth_audio;
      case AudioSourceType.wiredHeadset:
        return Icons.headphones;
      case AudioSourceType.builtinSpeaker:
        return Icons.speaker;
      case AudioSourceType.builtinReceiver:
        return Icons.phone_android;
      default:
        return Icons.volume_up;
    }
  }

  String _getNameForDeviceType(AudioSourceType type) {
    switch (type) {
      case AudioSourceType.bluetooth:
        return 'Bluetooth';
      case AudioSourceType.wiredHeadset:
        return 'Wired Headset';
      case AudioSourceType.builtinSpeaker:
        return 'Speaker';
      case AudioSourceType.builtinReceiver:
        return 'Phone';
      default:
        return 'Audio Output';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please use Windows System Settings to change audio output.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.speaker,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'System Audio',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return StreamBuilder<AudioDevice?>(
      stream: _audioRouter.currentDeviceStream,
      builder: (context, snapshot) {
        final device = snapshot.data;
        final icon = _getIconForDeviceType(device?.type ?? AudioSourceType.unknown);
        final name = _getNameForDeviceType(device?.type ?? AudioSourceType.unknown);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                      _audioRouter.tryChangeAudioRoute(
                        context,
                        androidOptions: const AndroidAudioOptions.media(),
                        dialogTitle: 'Select Audio Output',
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
      },
    );
  }
}
