import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../components/animated_equalizer.dart';
import '../../data/api/audio_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioService(),
      builder: (context, _) {
        final audioService = AudioService();
        final queue = audioService.queueList;
        final currentIndex = audioService.currentIndex;
        final isAutoplayEnabled = audioService.isAutoplayEnabled;
        final isAudioPlaying = audioService.isPlaying;
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Playing Next',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                audioService.clearQueue();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.7),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                              ),
                              child: const Text('Clear', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Autoplay toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.all_inclusive_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Autoplay similar music',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
                                ),
                              ],
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: CupertinoSwitch(
                                value: isAutoplayEnabled,
                                activeColor: const Color(0xFFFF5C5C),
                                trackColor: Colors.white.withValues(alpha: 0.2),
                                thumbColor: Colors.white,
                                onChanged: (val) {
                                  audioService.toggleAutoplay();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // List
                  Expanded(
                    child: queue.isEmpty
                        ? Center(
                            child: Text(
                              'Queue is empty',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                          )
                        : Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: Colors.transparent,
                            ),
                            child: ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: const EdgeInsets.only(bottom: 24, top: 8),
                              itemCount: queue.length,
                              onReorder: (oldIndex, newIndex) {
                                audioService.reorderQueue(oldIndex, newIndex);
                              },
                              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                return Material(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.5),
                                  child: child,
                                );
                              },
                              itemBuilder: (context, index) {
                                final track = queue[index];
                                final isPlaying = index == currentIndex;
                                final isPast = index < currentIndex;
                                
                                return QueueItem(
                                  key: ValueKey('${track['id']}_$index'),
                                  track: track,
                                  index: index,
                                  isPlaying: isPlaying,
                                  isPast: isPast,
                                  audioService: audioService,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class QueueItem extends StatefulWidget {
  final Map<String, String> track;
  final int index;
  final bool isPlaying;
  final bool isPast;
  final AudioService audioService;

  const QueueItem({
    super.key,
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isPast,
    required this.audioService,
  });

  @override
  State<QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends State<QueueItem> with SingleTickerProviderStateMixin {
  late AnimationController _deleteController;

  @override
  void initState() {
    super.initState();
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _deleteController.dispose();
    super.dispose();
  }

  void _triggerDelete() {
    _deleteController.forward().then((_) {
      if (mounted) {
        widget.audioService.removeTrack(widget.index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
          CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
        ),
        child: Dismissible(
          key: ValueKey('${widget.track['id']}_${widget.index}'),
      direction: widget.isPlaying ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withOpacity(0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
      ),
      onDismissed: (_) {
        widget.audioService.removeTrack(widget.index);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.track['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white.withOpacity(0.1),
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
                if (widget.isPlaying)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: widget.audioService.isPlaying
                          ? AnimatedEqualizer(isAudioPlaying: true)
                          : const Icon(Icons.pause, color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Text(
          widget.track['title'] ?? 'Unknown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.isPlaying ? Colors.white : Colors.white.withOpacity(widget.isPast ? 0.5 : 1.0),
            fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          widget.track['subtitle'] ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(widget.isPast ? 0.3 : 0.6),
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isPlaying)
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8.0),
                icon: Icon(Icons.remove_circle_outline, color: Colors.white.withValues(alpha: 0.5), size: 20),
                onPressed: _triggerDelete,
              ),
            const SizedBox(width: 12),
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          if (!widget.isPlaying) {
            widget.audioService.playTrack(widget.track);
          } else {
            widget.audioService.togglePlayPause();
          }
        },
      ),
        ),
      ),
    );
  }
}
