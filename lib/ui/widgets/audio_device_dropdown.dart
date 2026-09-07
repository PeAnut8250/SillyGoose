import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_router/audio_router.dart';
import 'package:audio_router/audio_router_platform_interface.dart';
import '../components/liquid_glass.dart';
import '../components/app_toast.dart';
import '../../data/settings_service.dart';

class AudioDeviceDropdown extends StatefulWidget {
  const AudioDeviceDropdown({super.key});

  @override
  State<AudioDeviceDropdown> createState() => _AudioDeviceDropdownState();
}

class _AudioDeviceDropdownState extends State<AudioDeviceDropdown> {
  final AudioRouter _audioRouter = const AudioRouter();

  IconData _getIconForDeviceType(AudioSourceType type) {
    switch (type) {
      case AudioSourceType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioSourceType.wiredHeadset:
        return Icons.headphones_rounded;
      case AudioSourceType.builtinSpeaker:
        return Icons.volume_up_rounded;
      case AudioSourceType.builtinReceiver:
        return Icons.phone_android_rounded;
      case AudioSourceType.carAudio:
        return Icons.directions_car_rounded;
      case AudioSourceType.airplay:
        return Icons.airplay_rounded;
      default:
        return Icons.speaker_rounded;
    }
  }

  String _getNameForDevice(AudioDevice device) {
    switch (device.type) {
      case AudioSourceType.bluetooth:
        return 'Bluetooth Audio';
      case AudioSourceType.wiredHeadset:
        return 'Headphones';
      case AudioSourceType.builtinSpeaker:
        return 'Speaker';
      case AudioSourceType.builtinReceiver:
        return 'Phone';
      case AudioSourceType.carAudio:
        return 'Car Audio';
      case AudioSourceType.airplay:
        return 'AirPlay';
      default:
        return 'Audio Output';
    }
  }

  Future<void> _openGlassAudioOutputDialog(BuildContext context) async {
    List<AudioDevice> devices = [];
    AudioDevice? currentDevice;

    try {
      devices = await AudioRouterPlatform.instance.getAvailableDevices(
        androidAudioOptions: const AndroidAudioOptions.media(),
      );
      currentDevice = await AudioRouterPlatform.instance.getCurrentDevice();
    } catch (e) {
      debugPrint('Error getting audio devices: $e');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LiquidGlass(
              forceOpaque: !SettingsService().liquidGlass,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Audio Output',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'No audio devices found',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: devices.map((device) {
                              final isSelected = currentDevice?.id == device.id ||
                                  (currentDevice != null && currentDevice.type == device.type);
                              final iconData = _getIconForDeviceType(device.type);
                              final name = _getNameForDevice(device);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  leading: Icon(iconData, color: isSelected ? Colors.white : Colors.white70),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
                                      : null,
                                  onTap: () async {
                                    Navigator.pop(context);
                                    try {
                                      await AudioRouterPlatform.instance.setAudioDevice(device.id);
                                      if (context.mounted) {
                                        showAppToast(context, 'Audio output set to $name');
                                      }
                                    } catch (e) {
                                      debugPrint('Error setting audio device: $e');
                                      if (context.mounted) {
                                        showAppToast(context, 'Failed to switch to $name');
                                      }
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
                showAppToast(context, 'Use Windows System Settings to change audio output');
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
                          Icons.speaker_rounded,
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
        final name = device != null ? _getNameForDevice(device) : 'Audio Output';

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openGlassAudioOutputDialog(context),
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
