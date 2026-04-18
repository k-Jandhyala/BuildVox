import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../worker/trade_worker_home_screen.dart';

/// Electrician home — trade worker dashboard (shared layout with Plumber).
class ElectricianHomeScreen extends ConsumerWidget {
  const ElectricianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TradeWorkerHomeScreen(isPlumber: false);
  }
}
