import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_models.dart';

class DealInfoRepository {
  static const String _fileName = 'dealer_customer.dat';

  Future<File> _getDataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AppData> loadData() async {
    final file = await _getDataFile();
    if (!await file.exists()) {
      return AppData.empty();
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return AppData.empty();
    }

    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return AppData.fromJson(decoded);
  }

  Future<void> saveData(AppData data) async {
    final file = await _getDataFile();
    final encoded = jsonEncode(data.toJson());
    await file.writeAsString(encoded, flush: true);
  }
}
