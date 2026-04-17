import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ElectricianSessionService {
  static const _fileName = 'electrician_session.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<String?> loadSelectedSiteId(String userId) async {
    final f = await _file();
    if (!await f.exists()) return null;
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) return null;
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return json[userId] as String?;
  }

  static Future<void> saveSelectedSiteId(String userId, String siteId) async {
    final f = await _file();
    Map<String, dynamic> json = {};
    if (await f.exists()) {
      final raw = await f.readAsString();
      if (raw.trim().isNotEmpty) {
        json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    }
    json[userId] = siteId;
    await f.writeAsString(jsonEncode(json));
  }
}
