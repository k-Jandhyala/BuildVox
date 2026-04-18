// BUILDVOX UI FIX — Update screen chip row clipping (all roles: Electrician, Plumber, GC, Manager)
// File: frontend/lib/screens/worker/field_note_tag_chip_row.dart
// Component: FieldNoteTagChipRow — shared by lib/screens/electrician/electrician_record_screen.dart
//
// Root cause addressed: ClipRect + Stack(clipBehavior: hardEdge) clipped horizontal chip
// painting; horizontal ListView is replaced with SingleChildScrollView + Row (overflow-x: auto
// equivalent), clip removed, chips given non-shrinking intrinsic width + nowrap labels.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import 'trade_field_note_config.dart';

/// Horizontally scrollable update-type chips (overflow-x: auto equivalent).
/// Full width; does not shrink. Edge fades hint at more content when scrollable.
class FieldNoteTagChipRow extends StatefulWidget {
  final List<FieldNoteTagDefinition> tags;
  final FieldNoteTagDefinition selected;
  final ValueChanged<FieldNoteTagDefinition> onSelected;

  const FieldNoteTagChipRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<FieldNoteTagChipRow> createState() => _FieldNoteTagChipRowState();
}

class _FieldNoteTagChipRowState extends State<FieldNoteTagChipRow> {
  final ScrollController _controller = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = true;

  static const double _rowViewportHeight = 52;
  static const double _fadeWidth = 20;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final off = _controller.offset;
    final showLeft = off > 4;
    final showRight = max <= 0 ? false : off < max - 4;
    if (showLeft != _showLeftFade || showRight != _showRightFade) {
      setState(() {
        _showLeftFade = showLeft;
        _showRightFade = showRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = BVColors.background;

    // width: 100%, flex-shrink: 0 equivalent — expand to parent max width
    return SizedBox(
      width: double.infinity,
      height: _rowViewportHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ScrollConfiguration(
            behavior: _NoScrollbarScrollBehavior(),
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              // Step 3: padding 4px 16px on scroll content (gap 8px via Row).
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.tags.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _FieldNoteTagChip(
                      tag: widget.tags[i],
                      selected: widget.selected == widget.tags[i],
                      onTap: () => widget.onSelected(widget.tags[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_showLeftFade)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _fadeWidth,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [bg, bg.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          if (_showRightFade)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _fadeWidth,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [bg.withValues(alpha: 0), bg],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoScrollbarScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _FieldNoteTagChip extends StatefulWidget {
  final FieldNoteTagDefinition tag;
  final bool selected;
  final VoidCallback onTap;

  const _FieldNoteTagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FieldNoteTagChip> createState() => _FieldNoteTagChipState();
}

class _FieldNoteTagChipState extends State<_FieldNoteTagChip> {
  bool _pressed = false;

  static const Color _borderInactive = Color(0xFF2A3A4A);
  static const Color _fgInactive = Color(0xFFA8B8C8);
  static const Color _bgActive = Color(0xFFF5A623);
  static const Color _fgActive = Color(0xFF0F1923);

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final fg = sel ? _fgActive : _fgInactive;
    final bg = sel ? _bgActive : Colors.transparent;
    final border = sel ? _bgActive : _borderInactive;

    // flex-shrink: 0 — intrinsic width only, no compression
    return Semantics(
      button: true,
      selected: sel,
      label: widget.tag.chipLabel,
      child: SizedBox(
        height: 44,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _pressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.tag.chipIcon, size: 15, color: fg),
                      const SizedBox(width: 4),
                      Text(
                        widget.tag.chipLabel,
                        softWrap: false,
                        maxLines: 1,
                        style: TextStyle(
                          color: fg,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
