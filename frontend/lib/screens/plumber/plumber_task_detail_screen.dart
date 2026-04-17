import 'package:flutter/material.dart';

import '../electrician/electrician_task_detail_screen.dart';

class PlumberTaskDetailScreen extends StatelessWidget {
  final String taskId;
  final String extractedItemId;

  const PlumberTaskDetailScreen({
    super.key,
    required this.taskId,
    required this.extractedItemId,
  });

  @override
  Widget build(BuildContext context) {
    return ElectricianTaskDetailScreen(
      taskId: taskId,
      extractedItemId: extractedItemId,
    );
  }
}
