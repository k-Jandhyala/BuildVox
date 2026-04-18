import 'package:flutter/material.dart';

import '../electrician/electrician_record_screen.dart';
import '../worker/trade_field_note_config.dart';

class PlumberRecordScreen extends StatelessWidget {
  const PlumberRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElectricianRecordScreen(layout: TradeFieldNoteLayout.plumber);
  }
}
