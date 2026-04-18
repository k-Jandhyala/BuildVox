// File: frontend/lib/screens/worker/field_note_tag_chip_row.dart
// Component: FieldNoteTagChipRow — shared Update-screen chips (Electrician / Plumber / GC / Manager)
// via lib/screens/electrician/electrician_record_screen.dart

import 'package:flutter/material.dart';

import 'trade_field_note_config.dart';

/// Single-row update type chips (compact sizing so all fit on one line).
class FieldNoteTagChipRow extends StatelessWidget {
  final List<FieldNoteTagDefinition> tags;
  final FieldNoteTagDefinition selected;
  final ValueChanged<FieldNoteTagDefinition> onSelected;

  const FieldNoteTagChipRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.onSelected,
  });

  static const double _chipHeight = 30;
  static const double _chipRadius = 15;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _chipHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _FieldNoteTagChip(
                tag: tags[i],
                selected: selected == tags[i],
                onTap: () => onSelected(tags[i]),
              ),
            ],
          ],
        ),
      ),
    );
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

  static const double _h = 30;
  static const double _radius = 15;
  static const double _iconSize = 11;
  static const double _iconLabelGap = 3;
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 0);

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
        height: _h,
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
                  height: _h,
                  padding: _padding,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.tag.chipIcon, size: _iconSize, color: fg),
                      const SizedBox(width: _iconLabelGap),
                      Text(
                        widget.tag.chipLabel,
                        softWrap: false,
                        maxLines: 1,
                        style: TextStyle(
                          color: fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
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
