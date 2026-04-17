import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/electrician_models.dart';

class OfflineQueueService {
  static const _fileName = 'electrician_queue.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<QueuedSubmission>> loadAll() async {
    final f = await _file();
    if (!await f.exists()) return const [];
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) return const [];
    final list = (jsonDecode(raw) as List)
        .map((e) => QueuedSubmission.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static Future<void> saveAll(List<QueuedSubmission> items) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
