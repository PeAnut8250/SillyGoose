import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/settings_service.dart';
import '../../data/scroll_service.dart';
import 'liquid_glass.dart';

class FloatingBottomBar extends StatefulWidget {
  final int selectedIndex;
  final int previousIndex;
  final Function(int) onTabSelected;
  final bool isInline;

  const FloatingBottomBar({
    super.key,
    required this.selectedIndex,
    this.previousIndex = 0,
    required this.onTabSelected,
    this.isInline = false,
  });

  @override
  State<FloatingBottomBar> createState() => _FloatingBottomBarState();
}

class _FloatingBottomBarState extends State<FloatingBottomBar> {
  double? _dragPosition;

  @override
  Widget build(BuildContext context) {
    if (widget.isInline) {
      IconData icon;
      // If we are on the Search tab (index 3), show the previous tab's icon on the left
      final displayIndex = widget.selectedIndex == 3 ? widget.previousIndex : widget.selectedIndex;
      
      switch (displayIndex) {
        case 1: icon = Icons.explore; break;
        case 2: icon = Icons.library_music; break;
        case 3: icon = Icons.search; break; // Fallback just in case previous was also search
        default: icon = Icons.home; break;
      }
      return GestureDetector(
        onTap: () {
          ScrollService().setScrolledDown(false);
        },
        child: ListenableBuilder(
          listenable: SettingsService(),
          builder: (context, _) {
            return LiquidGlass(
              forceOpaque: !SettingsService().liquidGlass,
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                height: 42,
                width: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Builder(
                  builder: (context) {
                    final isLightMode = Theme.of(context).brightness == Brightness.light;
                    final activeColor = isLightMode ? const Color(0xFFE91E63) : Theme.of(context).colorScheme.onSurface;
                    return Icon(icon, color: activeColor, size: 20);
                  }
                ),
              ),
            );
          },
        ),
      );
    }

    const double barHeight = 65.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: ListenableBuilder(
          listenable: SettingsService(),
          builder: (context, _) {
            return LiquidGlass(
              forceOpaque: !SettingsService().liquidGlass,
              borderRadius: BorderRadius.circular(100),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
              child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                  final pillWidth = MediaQuery.of(context).size.width - 88.0; // 88 = left/right padding + 48px search button + gap
                  final tabWidth = pillWidth / 3;
                  
                  setState(() {
                    _dragPosition = (details.localPosition.dx - (tabWidth / 2)).clamp(0.0, pillWidth - tabWidth);
                  });

                  final newIndex = (details.localPosition.dx / tabWidth).floor().clamp(0, 2);
                  if (newIndex != widget.selectedIndex) {
                    widget.onTabSelected(newIndex);
                  }
                },
                onHorizontalDragEnd: (_) {
                  setState(() {
                    _dragPosition = null;
                  });
                },
                onHorizontalDragCancel: () {
                  setState(() {
                    _dragPosition = null;
                  });
                },
                child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 3;
              final safeIndex = widget.selectedIndex >= 3 ? 0 : widget.selectedIndex;
              final indicatorPosition = _dragPosition ?? (safeIndex * tabWidth);
              
              return Stack(
                children: [
                  // Selected Tab Background Indicator (Material 3 style)
                  AnimatedPositioned(
                    duration: _dragPosition != null ? Duration.zero : const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    left: indicatorPosition + (tabWidth - 96) / 2, // Center the 96px pill horizontally
                    top: 4, 
                    bottom: 4,
                    width: 96,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: widget.selectedIndex == 3 ? 0.0 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15), // Translucent white works on both dark and colorful backgrounds
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                  
                  // Tab Icons and Labels
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(3, (index) {
                        final isSelected = index == widget.selectedIndex;
                        
                        IconData icon;
                        String label;
                        switch (index) {
                          case 1: 
                            icon = Icons.explore; 
                            label = 'Explore';
                            break;
                          case 2: 
                            icon = Icons.library_music_rounded; 
                            label = 'Library';
                            break;
                          default: 
                            icon = Icons.home_rounded; 
                            label = 'Home';
                            break;
                        }
                        
                        return _buildTab(context, index, icon, icon, label);
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
                  ), // GestureDetector
                ), // Container
            ); // LiquidGlass
          },
        ),
      );
  }

  Widget _buildTab(BuildContext context, int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = widget.selectedIndex == index;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    
    final activeColor = isLightMode ? const Color(0xFFE91E63) : Theme.of(context).colorScheme.onSurface;
    final color = isSelected ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: ClipRect(
            child: OverflowBox(
              maxHeight: 100,
              alignment: Alignment.center,
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.fastOutSlowIn,
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  color: color,
                  size: 18, // Reduced from 26 to better fit the nav bar
                ),
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  );
}
}
