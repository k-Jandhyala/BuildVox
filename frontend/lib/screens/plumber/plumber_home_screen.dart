import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../worker/trade_worker_home_screen.dart';

/// Plumber home — same structure as Electrician with plumber-specific quick actions.
class PlumberHomeScreen extends ConsumerWidget {
  const PlumberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TradeWorkerHomeScreen(isPlumber: true);
  }
}
