import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import 'trade_field_note_config.dart';

/// Horizontally scrollable update-type chips with edge fades (Solution A).
/// Fixed height 44dp; chips visually ~36dp with 44dp min tap height.
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

  static const double _rowHeight = 44;
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

    return SizedBox(
      height: _rowHeight,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ScrollConfiguration(
              behavior: _NoScrollbarScrollBehavior(),
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: widget.tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final tag = widget.tags[i];
                  final isSelected = widget.selected == tag;
                  return _FieldNoteTagChip(
                    tag: tag,
                    selected: isSelected,
                    onTap: () => widget.onSelected(tag),
                  );
                },
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
