import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypted;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_models.dart';
import 'dealinfo_repository.dart';

void main() {
  runApp(const DealInfoApp());
}

class DealInfoApp extends StatelessWidget {
  const DealInfoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DealInfo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFEAF2F7),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white.withValues(alpha: 0.58),
          foregroundColor: const Color(0xFF1D2A35),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.40),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w700),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const MainMenuScreen(),
    );
  }
}

Future<String?> showNameDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String initialValue = '',
  bool obscureText = false,
  String confirmLabel = 'Save',
}) async {
  String value = initialValue;
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final media = MediaQuery.of(context);
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            math.max(14, media.viewPadding.bottom + 14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: initialValue,
                autofocus: true,
                obscureText: obscureText,
                scrollPadding: const EdgeInsets.only(bottom: 180),
                decoration: InputDecoration(hintText: hint),
                onChanged: (text) => value = text,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(value.trim()),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (result == null || result.isEmpty) {
    return null;
  }
  return result;
}

String initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

const String _secureImageMagic = 'DINSEC1';

Uint8List _deriveEncryptionKey(String password) {
  final digest = sha256.convert(utf8.encode(password));
  return Uint8List.fromList(digest.bytes);
}

Uint8List _encryptImageBytes(Uint8List bytes, String password) {
  final key = encrypted.Key(_deriveEncryptionKey(password));
  final iv = encrypted.IV.fromSecureRandom(16);
  final encrypter = encrypted.Encrypter(
    encrypted.AES(key, mode: encrypted.AESMode.cbc),
  );
  final encryptedBytes = encrypter.encryptBytes(bytes, iv: iv).bytes;

  final magicBytes = utf8.encode(_secureImageMagic);
  return Uint8List.fromList([
    ...magicBytes,
    ...iv.bytes,
    ...encryptedBytes,
  ]);
}

Uint8List? _decryptImageBytes(Uint8List bytes, String password) {
  try {
    final magicBytes = utf8.encode(_secureImageMagic);
    if (bytes.length <= magicBytes.length + 16) {
      return bytes;
    }

    var startsWithMagic = true;
    for (var index = 0; index < magicBytes.length; index++) {
      if (bytes[index] != magicBytes[index]) {
        startsWithMagic = false;
        break;
      }
    }

    if (!startsWithMagic) {
      return bytes;
    }

    final ivStart = magicBytes.length;
    final ivEnd = ivStart + 16;
    final ivBytes = bytes.sublist(ivStart, ivEnd);
    final encryptedPayload = bytes.sublist(ivEnd);

    final key = encrypted.Key(_deriveEncryptionKey(password));
    final iv = encrypted.IV(ivBytes);
    final encrypter = encrypted.Encrypter(
      encrypted.AES(key, mode: encrypted.AESMode.cbc),
    );

    final decrypted = encrypter.decryptBytes(
      encrypted.Encrypted(Uint8List.fromList(encryptedPayload)),
      iv: iv,
    );
    return Uint8List.fromList(decrypted);
  } catch (_) {
    return null;
  }
}

Future<String> persistPickedImage({
  required XFile image,
  required String prefix,
  required String password,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final imageDirectory = Directory('${directory.path}/images_secure');
  if (!await imageDirectory.exists()) {
    await imageDirectory.create(recursive: true);
  }

  final filePath =
      '${imageDirectory.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.encimg';

  final originalBytes = await image.readAsBytes();
  final encryptedBytes = _encryptImageBytes(Uint8List.fromList(originalBytes), password);

  await File(filePath).writeAsBytes(encryptedBytes, flush: true);
  return filePath;
}

MemoryImage? loadSecureMemoryImage({
  required String? encryptedPath,
  required String? password,
}) {
  if (encryptedPath == null || password == null || password.isEmpty) {
    return null;
  }

  final file = File(encryptedPath);
  if (!file.existsSync()) {
    return null;
  }

  final encryptedBytes = Uint8List.fromList(file.readAsBytesSync());
  final plainBytes = _decryptImageBytes(encryptedBytes, password);
  if (plainBytes == null) {
    return null;
  }

  return MemoryImage(plainBytes);
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final DealInfoRepository _repository = DealInfoRepository();
  AppData _data = AppData.empty();
  bool _isLoading = true;
  bool _lowStockShownForThisLoad = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repository.loadData();
    if (!mounted) {
      return;
    }
    setState(() {
      _data = data;
      _isLoading = false;
      _lowStockShownForThisLoad = false;
    });
    _showLowStockNoticeIfNeeded();
  }

  int _lowStockCount() {
    final threshold = _data.settings.lowStockThreshold;
    return _data.stockItems.where((item) => item.currentCount <= threshold).length;
  }

  void _showLowStockNoticeIfNeeded() {
    if (_lowStockShownForThisLoad || !mounted) {
      return;
    }
    final count = _lowStockCount();
    if (count <= 0) {
      return;
    }
    _lowStockShownForThisLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Low stock alert: $count item(s) at or below threshold.'),
        ),
      );
    });
  }

  String _dealerLabelById(String? dealerId) {
    if (dealerId == null) {
      return 'Dealer ID: -';
    }
    for (final dealer in _data.dealers) {
      if (dealer.id == dealerId) {
        return 'Dealer ID: ${dealer.dealerNumber}';
      }
    }
    return 'Dealer ID: -';
  }

  String _dealerNameById(String? dealerId) {
    if (dealerId == null || dealerId.isEmpty) {
      return 'No dealer selected';
    }
    for (final dealer in _data.dealers) {
      if (dealer.id == dealerId) {
        return dealer.name;
      }
    }
    return 'No dealer selected';
  }

  Future<void> _openCustomers() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = _data.settings.password;
    if (password != null && password.isNotEmpty) {
      final entered = await showNameDialog(
        context: context,
        title: 'Enter password',
        hint: 'Password',
        obscureText: true,
        confirmLabel: 'Unlock',
      );
      if (entered == null || entered != password) {
        messenger.showSnackBar(const SnackBar(content: Text('Wrong password.')));
        return;
      }
    }

    await navigator.push(
      MaterialPageRoute(builder: (context) => const CustomersScreen()),
    );
    await _load();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryScreen(data: _data),
      ),
    );
  }

  Future<void> _openSettings() async {
    final previousPassword = _data.settings.password;
    final updatedSettings = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settings: _data.settings),
      ),
    );

    if (updatedSettings == null) {
      return;
    }

    final nextPassword = updatedSettings.password;
    if ((previousPassword ?? '') != (nextPassword ?? '') &&
        (previousPassword ?? '').isNotEmpty &&
        (nextPassword ?? '').isNotEmpty) {
      await _reencryptAllImages(
        oldPassword: previousPassword!,
        newPassword: nextPassword!,
      );
    }

    _data = _data.copyWith(settings: updatedSettings);
    await _repository.saveData(_data);

    if (!mounted) {
      return;
    }
    setState(() {});
    _showLowStockNoticeIfNeeded();
  }

  Future<void> _openGlobalSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GlobalSearchScreen(data: _data)),
    );
  }

  Future<void> _openBackupRestore() async {
    final restored = await Navigator.of(context).push<AppData>(
      MaterialPageRoute(
        builder: (context) => BackupRestoreScreen(
          data: _data,
          password: _data.settings.password,
        ),
      ),
    );
    if (restored == null) {
      return;
    }
    _data = restored;
    await _repository.saveData(_data);
    if (!mounted) {
      return;
    }
    setState(() {});
    _showLowStockNoticeIfNeeded();
  }

  Future<void> _openIntegrityTools() async {
    final repaired = await Navigator.of(context).push<AppData>(
      MaterialPageRoute(builder: (context) => IntegrityToolsScreen(data: _data)),
    );
    if (repaired == null) {
      return;
    }
    _data = repaired;
    await _repository.saveData(_data);
    if (!mounted) {
      return;
    }
    setState(() {});
    _showLowStockNoticeIfNeeded();
  }

  Future<void> _reencryptImageAtPath({
    required String path,
    required String oldPassword,
    required String newPassword,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }

    final encryptedBytes = await file.readAsBytes();
    final plainBytes = _decryptImageBytes(Uint8List.fromList(encryptedBytes), oldPassword);
    if (plainBytes == null) {
      return;
    }

    final reencrypted = _encryptImageBytes(plainBytes, newPassword);
    await file.writeAsBytes(reencrypted, flush: true);
  }

  Future<void> _reencryptAllImages({
    required String oldPassword,
    required String newPassword,
  }) async {
    final imagePaths = <String>{};

    final backgroundPath = _data.settings.backgroundImagePath;
    if (backgroundPath != null && backgroundPath.isNotEmpty) {
      imagePaths.add(backgroundPath);
    }

    for (final dealer in _data.dealers) {
      final path = dealer.profileImagePath;
      if (path != null && path.isNotEmpty) {
        imagePaths.add(path);
      }
    }

    for (final customer in _data.customers) {
      final path = customer.profileImagePath;
      if (path != null && path.isNotEmpty) {
        imagePaths.add(path);
      }
    }

    for (final path in imagePaths) {
      await _reencryptImageAtPath(
        path: path,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    }
  }

  DecorationImage? _backgroundImage() {
    final image = loadSecureMemoryImage(
      encryptedPath: _data.settings.backgroundImagePath,
      password: _data.settings.password,
    );
    if (image == null) {
      return null;
    }
    return DecorationImage(image: image, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final passwordSet = (_data.settings.password ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(image: _backgroundImage()),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text('Current Seller'),
                                const SizedBox(height: 4),
                                Text(_dealerLabelById(_data.currentSalesDealerId)),
                                const SizedBox(height: 4),
                                Text(_dealerNameById(_data.currentSalesDealerId)),
                                const SizedBox(height: 6),
                                Text('Current Ticker'),
                                const SizedBox(height: 4),
                                Text(_dealerLabelById(_data.currentTickDealerId)),
                                const SizedBox(height: 4),
                                Text(_dealerNameById(_data.currentTickDealerId)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      InkWell(
                        onTap: _openCustomers,
                        borderRadius: BorderRadius.circular(80),
                        child: CircleAvatar(
                          radius: 52,
                          child: Icon(
                            passwordSet ? Icons.lock : Icons.people,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(passwordSet ? 'Unlock Customers' : 'Customers'),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _openHistory,
                        icon: const Icon(Icons.history),
                        label: const Text('History'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _openGlobalSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Global Search'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _openBackupRestore,
                        icon: const Icon(Icons.backup),
                        label: const Text('Backup / Restore'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _openIntegrityTools,
                        icon: const Icon(Icons.health_and_safety),
                        label: const Text('Integrity Tools'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _GlobalSearchResult {
  _GlobalSearchResult({required this.category, required this.title, required this.detail});

  final String category;
  final String title;
  final String detail;
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, required this.data});

  final AppData data;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  String _query = '';

  String _dealerLabel(String dealerId) {
    for (final dealer in widget.data.dealers) {
      if (dealer.id == dealerId) {
        return 'ID ${dealer.dealerNumber} - ${dealer.name}';
      }
    }
    return 'Unknown dealer';
  }

  List<_GlobalSearchResult> _results() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return [];
    }

    final results = <_GlobalSearchResult>[];

    for (final customer in widget.data.customers) {
      final haystack = '${customer.name} customer'.toLowerCase();
      if (haystack.contains(query)) {
        results.add(_GlobalSearchResult(category: 'Customer', title: customer.name, detail: 'Customer profile'));
      }
    }

    for (final dealer in widget.data.dealers) {
      final label = 'ID ${dealer.dealerNumber} - ${dealer.name}';
      if (label.toLowerCase().contains(query)) {
        results.add(_GlobalSearchResult(category: 'Dealer', title: label, detail: 'Dealer profile'));
      }
    }

    for (final item in widget.data.stockItems) {
      final title = '${item.stockType} • ${item.name}';
      if (title.toLowerCase().contains(query)) {
        results.add(
          _GlobalSearchResult(
            category: 'Stock Item',
            title: title,
            detail: 'Current: ${item.currentCount} • Price: R${item.price.toStringAsFixed(2)}',
          ),
        );
      }
    }

    for (final sale in widget.data.sales) {
      final text = '${sale.itemName} ${_dealerLabel(sale.dealerId)} sale';
      if (text.toLowerCase().contains(query)) {
        results.add(
          _GlobalSearchResult(
            category: 'Sale',
            title: sale.itemName,
            detail: '${_dealerLabel(sale.dealerId)} • R${sale.itemPrice.toStringAsFixed(2)}',
          ),
        );
      }
    }

    for (final gift in widget.data.gifts) {
      final text = '${gift.stockType} ${gift.itemName} gift';
      if (text.toLowerCase().contains(query)) {
        results.add(
          _GlobalSearchResult(
            category: 'Gift',
            title: '${gift.stockType} • ${gift.itemName}',
            detail: '${_dealerLabel(gift.dealerId)} • Qty ${gift.quantity}',
          ),
        );
      }
    }

    for (final lost in widget.data.lostStock) {
      final text = '${lost.stockType} ${lost.itemName} lost';
      if (text.toLowerCase().contains(query)) {
        results.add(
          _GlobalSearchResult(
            category: 'Lost',
            title: '${lost.stockType} • ${lost.itemName}',
            detail: 'Qty ${lost.quantity} • R${lost.itemPrice.toStringAsFixed(2)}',
          ),
        );
      }
    }

    for (final take in widget.data.dealerTakes) {
      final text = '${take.stockType} ${take.itemName} dealer take ${_dealerLabel(take.dealerId)}';
      if (text.toLowerCase().contains(query)) {
        results.add(
          _GlobalSearchResult(
            category: 'Dealer Take',
            title: '${take.stockType} • ${take.itemName}',
            detail: '${_dealerLabel(take.dealerId)} • Qty ${take.quantity}',
          ),
        );
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results();
    return Scaffold(
      appBar: AppBar(title: const Text('Global Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search customers, dealers, items, events',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const Center(child: Text('Type to search.'))
                : results.isEmpty
                    ? const Center(child: Text('No matches found.'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return ListTile(
                            title: Text('${result.category}: ${result.title}'),
                            subtitle: Text(result.detail),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key, required this.data, required this.password});

  final AppData data;
  final String? password;

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<FileSystemEntity> _backupFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _loadBackups() async {
    final dir = await _backupDir();
    final files = dir.listSync().whereType<File>().where((file) => file.path.endsWith('.bakenc')).toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    if (!mounted) {
      return;
    }
    setState(() {
      _backupFiles = files;
      _loading = false;
    });
  }

  Future<void> _createBackup() async {
    final password = widget.password;
    if (password == null || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a password first to create encrypted backups.')),
      );
      return;
    }

    final json = jsonEncode(widget.data.toJson());
    final encryptedBytes = _encryptImageBytes(Uint8List.fromList(utf8.encode(json)), password);

    final dir = await _backupDir();
    final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.bakenc';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(encryptedBytes, flush: true);
    await _loadBackups();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup created: $fileName')),
    );
  }

  Future<void> _restoreBackup(File file) async {
    final password = widget.password;
    if (password == null || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a password first to restore encrypted backups.')),
      );
      return;
    }

    final encryptedBytes = await file.readAsBytes();
    final decoded = _decryptImageBytes(Uint8List.fromList(encryptedBytes), password);
    if (decoded == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decrypt backup with current password.')),
      );
      return;
    }

    try {
      final jsonText = utf8.decode(decoded);
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final data = AppData.fromJson(parsed);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(data);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file is invalid or corrupted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup / Restore'),
        actions: [
          IconButton(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup),
            tooltip: 'Create backup',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _backupFiles.isEmpty
              ? const Center(child: Text('No backups yet. Use the backup icon to create one.'))
              : ListView.builder(
                  itemCount: _backupFiles.length,
                  itemBuilder: (context, index) {
                    final file = _backupFiles[index] as File;
                    final name = file.path.split('/').last;
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(name),
                      trailing: FilledButton(
                        onPressed: () => _restoreBackup(file),
                        child: const Text('Restore'),
                      ),
                    );
                  },
                ),
    );
  }
}

class IntegrityToolsScreen extends StatefulWidget {
  const IntegrityToolsScreen({super.key, required this.data});

  final AppData data;

  @override
  State<IntegrityToolsScreen> createState() => _IntegrityToolsScreenState();
}

class _IntegrityToolsScreenState extends State<IntegrityToolsScreen> {
  late AppData _workingData;
  late List<String> _issues;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _workingData = widget.data;
    _issues = _collectIssues(_workingData);
  }

  List<String> _collectIssues(AppData data) {
    final issues = <String>[];
    final dealerNumbers = <int>{};
    for (final dealer in data.dealers) {
      if (dealer.name.trim().isEmpty) {
        issues.add('Dealer with empty name found.');
      }
      if (!dealerNumbers.add(dealer.dealerNumber)) {
        issues.add('Duplicate dealer numbers found.');
      }
    }

    for (final customer in data.customers) {
      if (customer.name.trim().isEmpty) {
        issues.add('Customer with empty name found.');
      }
    }

    for (final item in data.stockItems) {
      if (item.currentCount < 0) {
        issues.add('Stock item with negative current count found.');
      }
      if (item.initialCount < 0) {
        issues.add('Stock item with negative initial count found.');
      }
    }

    final dealerIds = data.dealers.map((entry) => entry.id).toSet();
    if (data.currentSalesDealerId != null &&
        data.currentSalesDealerId!.isNotEmpty &&
        !dealerIds.contains(data.currentSalesDealerId)) {
      issues.add('Current seller pointer is invalid.');
    }
    if (data.currentTickDealerId != null &&
        data.currentTickDealerId!.isNotEmpty &&
        !dealerIds.contains(data.currentTickDealerId)) {
      issues.add('Current ticker pointer is invalid.');
    }

    return issues;
  }

  void _repair() {
    var data = _workingData;

    final repairedDealers = [...data.dealers]
      ..sort((a, b) => a.dealerNumber.compareTo(b.dealerNumber));
    for (var i = 0; i < repairedDealers.length; i++) {
      final dealer = repairedDealers[i];
      repairedDealers[i] = dealer.copyWith(
        dealerNumber: i + 1,
        name: dealer.name.trim().isEmpty ? 'Dealer ${i + 1}' : dealer.name,
      );
    }

    final repairedCustomers = <Customer>[];
    for (var i = 0; i < data.customers.length; i++) {
      final customer = data.customers[i];
      repairedCustomers.add(
        customer.copyWith(name: customer.name.trim().isEmpty ? 'Customer ${i + 1}' : customer.name),
      );
    }

    final repairedStock = data.stockItems
        .map(
          (item) => item.copyWith(
            id: item.id.trim().isEmpty ? _uuid.v4() : item.id,
            initialCount: item.initialCount < 0 ? 0 : item.initialCount,
            currentCount: item.currentCount < 0 ? 0 : item.currentCount,
          ),
        )
        .toList();

    final allTypes = <String>{
      ...data.stockTypes,
      ...repairedStock.map((item) => item.stockType),
      ...data.gifts.map((item) => item.stockType),
      ...data.lostStock.map((item) => item.stockType),
      ...data.dealerTakes.map((item) => item.stockType),
    }.where((entry) => entry.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final validDealerIds = repairedDealers.map((entry) => entry.id).toSet();
    final defaultDealerId = repairedDealers.isEmpty ? '' : repairedDealers.first.id;

    data = data.copyWith(
      dealers: repairedDealers,
      customers: repairedCustomers,
      stockItems: repairedStock,
      stockTypes: allTypes,
      currentSalesDealerId: validDealerIds.contains(data.currentSalesDealerId) ? data.currentSalesDealerId : defaultDealerId,
      currentTickDealerId: validDealerIds.contains(data.currentTickDealerId) ? data.currentTickDealerId : defaultDealerId,
    );

    setState(() {
      _workingData = data;
      _issues = _collectIssues(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrity Tools'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_workingData),
            child: const Text('Apply'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton.icon(
            onPressed: _repair,
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Auto-repair common issues'),
          ),
          const SizedBox(height: 12),
          if (_issues.isEmpty)
            const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('No integrity issues detected.'),
            )
          else
            ..._issues.map(
              (issue) => ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(issue),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.data});

  final AppData data;

  String _dealerLabel(String dealerId) {
    for (final dealer in data.dealers) {
      if (dealer.id == dealerId) {
        return 'ID ${dealer.dealerNumber} - ${dealer.name}';
      }
    }
    return 'Unknown dealer';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekDays[local.weekday - 1]} ${local.day}/${months[local.month - 1]}/${local.year}';
  }

  String _stockTypeForSale(SaleEntry sale) {
    for (final item in data.stockItems) {
      if (item.id == sale.stockItemId) {
        return item.stockType;
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Dealers'),
              Tab(text: 'Stock Types'),
              Tab(text: 'Gifted/Lost'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CustomerHistoryTab(
              data: data,
              dealerLabel: _dealerLabel,
              formatDate: _formatDate,
            ),
            _DealerHistoryTab(
              data: data,
              dealerLabel: _dealerLabel,
              formatDate: _formatDate,
            ),
            _StockTypeHistoryTab(
              data: data,
              dealerLabel: _dealerLabel,
              formatDate: _formatDate,
              stockTypeForSale: _stockTypeForSale,
            ),
            _GiftLostHistoryTab(
              data: data,
              dealerLabel: _dealerLabel,
              formatDate: _formatDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEvent {
  _HistoryEvent({
    required this.type,
    required this.date,
    required this.detail,
  });

  final String type;
  final DateTime date;
  final String detail;
}

enum _HistorySortOrder { newest, oldest }

class DealerStatData {
  DealerStatData({
    required this.dealerId,
    required this.dealerNumber,
    required this.dealerName,
    required this.salesCount,
    required this.tickCount,
  });

  final String dealerId;
  final int dealerNumber;
  final String dealerName;
  final int salesCount;
  final int tickCount;

  String get label => 'ID $dealerNumber - $dealerName';
}

class _CustomerDayTotals {
  _CustomerDayTotals({required this.day, required this.salesCount, required this.tickCount});

  final DateTime day;
  final int salesCount;
  final int tickCount;
}

List<DealerStatData> buildDealerStats(AppData data) {
  final dealers = [...data.dealers]..sort((a, b) => a.dealerNumber.compareTo(b.dealerNumber));
  return dealers.map((dealer) {
    final salesCount = data.sales.where((sale) => sale.dealerId == dealer.id).length;
    final tickCount = data.customers
        .map((customer) => customer.ticks.where((tick) => tick.dealerId == dealer.id).length)
        .fold(0, (sum, value) => sum + value);
    return DealerStatData(
      dealerId: dealer.id,
      dealerNumber: dealer.dealerNumber,
      dealerName: dealer.name,
      salesCount: salesCount,
      tickCount: tickCount,
    );
  }).toList();
}

List<_CustomerDayTotals> _buildCustomerDayTotals(AppData data) {
  final byDay = <String, _CustomerDayTotals>{};

  for (final sale in data.sales) {
    final day = DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day);
    final key = day.toIso8601String();
    final existing = byDay[key];
    byDay[key] = _CustomerDayTotals(
      day: day,
      salesCount: (existing?.salesCount ?? 0) + 1,
      tickCount: existing?.tickCount ?? 0,
    );
  }

  for (final customer in data.customers) {
    for (final tick in customer.ticks) {
      final day = DateTime(tick.createdAt.year, tick.createdAt.month, tick.createdAt.day);
      final key = day.toIso8601String();
      final existing = byDay[key];
      byDay[key] = _CustomerDayTotals(
        day: day,
        salesCount: existing?.salesCount ?? 0,
        tickCount: (existing?.tickCount ?? 0) + 1,
      );
    }
  }

  final list = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
  return list;
}

class _CustomerHistoryCharts extends StatelessWidget {
  const _CustomerHistoryCharts({required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final dayTotals = _buildCustomerDayTotals(data);
    final totalSales = data.sales.length;
    final totalTicks = data.customers
        .map((customer) => customer.ticks.length)
        .fold(0, (sum, value) => sum + value);

    final salesSpots = <FlSpot>[];
    final tickSpots = <FlSpot>[];
    for (var index = 0; index < dayTotals.length; index++) {
      salesSpots.add(FlSpot(index.toDouble(), dayTotals[index].salesCount.toDouble()));
      tickSpots.add(FlSpot(index.toDouble(), dayTotals[index].tickCount.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Customers: Sales & Ticks'),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: dayTotals.isEmpty
                  ? const Center(child: Text('No chart data yet.'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: true),
                        lineTouchData: const LineTouchData(enabled: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: salesSpots,
                            isCurved: false,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.primary,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: tickSpots,
                            isCurved: false,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.secondary,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                        sections: [
                          PieChartSectionData(
                            value: math.max(totalSales.toDouble(), 0.0001),
                            color: Theme.of(context).colorScheme.primary,
                            title: '$totalSales',
                            radius: 55,
                          ),
                          PieChartSectionData(
                            value: math.max(totalTicks.toDouble(), 0.0001),
                            color: Theme.of(context).colorScheme.secondary,
                            title: '$totalTicks',
                            radius: 55,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sales Total: $totalSales'),
                        const SizedBox(height: 8),
                        Text('Ticks Total: $totalTicks'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealerTotalsCharts extends StatelessWidget {
  const _DealerTotalsCharts({required this.stats, this.title = 'Dealers: Totals'});

  final List<DealerStatData> stats;
  final String title;

  @override
  Widget build(BuildContext context) {
    final salesTotal = stats.fold<int>(0, (sum, stat) => sum + stat.salesCount);
    final ticksTotal = stats.fold<int>(0, (sum, stat) => sum + stat.tickCount);

    final salesSpots = stats
        .map((entry) => FlSpot(entry.dealerNumber.toDouble(), entry.salesCount.toDouble()))
        .toList();
    final tickSpots = stats
        .map((entry) => FlSpot(entry.dealerNumber.toDouble(), entry.tickCount.toDouble()))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: stats.isEmpty
                  ? const Center(child: Text('No chart data yet.'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: true),
                        lineTouchData: const LineTouchData(enabled: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: salesSpots,
                            isCurved: false,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.primary,
                            dotData: const FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: tickSpots,
                            isCurved: false,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.secondary,
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                        sections: [
                          PieChartSectionData(
                            value: math.max(salesTotal.toDouble(), 0.0001),
                            color: Theme.of(context).colorScheme.primary,
                            title: '$salesTotal',
                            radius: 55,
                          ),
                          PieChartSectionData(
                            value: math.max(ticksTotal.toDouble(), 0.0001),
                            color: Theme.of(context).colorScheme.secondary,
                            title: '$ticksTotal',
                            radius: 55,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sold Total: $salesTotal'),
                        const SizedBox(height: 8),
                        Text('Ticked Total: $ticksTotal'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHistoryTab extends StatefulWidget {
  const _CustomerHistoryTab({
    required this.data,
    required this.dealerLabel,
    required this.formatDate,
  });

  final AppData data;
  final String Function(String dealerId) dealerLabel;
  final String Function(DateTime dateTime) formatDate;

  @override
  State<_CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends State<_CustomerHistoryTab> {
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  String _filterQuery = '';

  bool _matchesFilter(Customer customer, List<_HistoryEvent> events) {
    final query = _filterQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    if (customer.name.toLowerCase().contains(query)) {
      return true;
    }

    for (final event in events) {
      if (event.type.toLowerCase().contains(query) ||
          event.detail.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  List<_HistoryEvent> _eventsForCustomer(Customer customer) {
    final events = <_HistoryEvent>[];

    final sales = widget.data.sales.where((sale) => sale.customerId == customer.id);
    for (final sale in sales) {
      events.add(
        _HistoryEvent(
          type: 'Sale',
          date: sale.createdAt,
          detail:
              '${widget.dealerLabel(sale.dealerId)} • ${sale.itemName} • R${sale.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final tick in customer.ticks) {
      events.add(
        _HistoryEvent(
          type: tick.isPaid ? 'Tick (Paid)' : 'Tick (Not paid)',
          date: tick.createdAt,
          detail:
              '${widget.dealerLabel(tick.dealerId)} • ${tick.stockType} • ${tick.itemName} • R${tick.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    final gifts = widget.data.gifts.where((gift) => gift.customerId == customer.id);
    for (final gift in gifts) {
      events.add(
        _HistoryEvent(
          type: 'Gift',
          date: gift.createdAt,
          detail:
              '${widget.dealerLabel(gift.dealerId)} • ${gift.stockType} • ${gift.itemName} • Qty ${gift.quantity} • R${gift.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    events.sort((a, b) {
      if (_sortOrder == _HistorySortOrder.newest) {
        return b.date.compareTo(a.date);
      }
      return a.date.compareTo(b.date);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.customers.isEmpty) {
      return const Center(child: Text('No customer history yet.'));
    }

    final filteredCustomers = widget.data.customers.where((customer) {
      final events = _eventsForCustomer(customer);
      return _matchesFilter(customer, events);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sortOrder == _HistorySortOrder.newest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.newest;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sortOrder == _HistorySortOrder.oldest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.oldest;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter by customer/dealer',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterQuery = value;
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _CustomerHistoryCharts(data: widget.data),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filteredCustomers.isEmpty
              ? const Center(child: Text('No matching customer history.'))
              : ListView.builder(
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = filteredCustomers[index];
        final customerSales = widget.data.sales.where((sale) => sale.customerId == customer.id).length;
        final customerTicks = customer.ticks.length;
        final customerGifts = widget.data.gifts
            .where((gift) => gift.customerId == customer.id)
            .fold<int>(0, (sum, gift) => sum + gift.quantity);
        final events = _eventsForCustomer(customer);

        return ExpansionTile(
          title: Text(customer.name),
          subtitle: Text('Sales: $customerSales • Ticks: $customerTicks • Gifted: $customerGifts'),
          children: events.isEmpty
              ? const [
                  ListTile(title: Text('No records yet.')),
                ]
              : events
                  .map(
                    (event) => ListTile(
                      title: Text(event.type),
                      subtitle: Text('${event.detail}\n${widget.formatDate(event.date)}'),
                      isThreeLine: true,
                    ),
                  )
                  .toList(),
        );
      },
    ),
        ),
      ],
    );
  }
}

class _DealerHistoryTab extends StatefulWidget {
  const _DealerHistoryTab({
    required this.data,
    required this.dealerLabel,
    required this.formatDate,
  });

  final AppData data;
  final String Function(String dealerId) dealerLabel;
  final String Function(DateTime dateTime) formatDate;

  @override
  State<_DealerHistoryTab> createState() => _DealerHistoryTabState();
}

class _DealerHistoryTabState extends State<_DealerHistoryTab> {
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  String _filterQuery = '';

  List<DealerStatData> _dealerStats() {
    return buildDealerStats(widget.data);
  }

  bool _matchesFilter(Dealer dealer, List<_HistoryEvent> events) {
    final query = _filterQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final dealerLabel = widget.dealerLabel(dealer.id).toLowerCase();
    if (dealerLabel.contains(query) || dealer.name.toLowerCase().contains(query)) {
      return true;
    }

    for (final event in events) {
      if (event.type.toLowerCase().contains(query) ||
          event.detail.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  List<_HistoryEvent> _eventsForDealer(Dealer dealer) {
    final events = <_HistoryEvent>[];

    for (final sale in widget.data.sales.where((entry) => entry.dealerId == dealer.id)) {
      final customer = widget.data.customers.where((entry) => entry.id == sale.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Sale',
          date: sale.createdAt,
          detail: '$customerName • ${sale.itemName} • R${sale.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final customer in widget.data.customers) {
      for (final tick in customer.ticks.where((entry) => entry.dealerId == dealer.id)) {
        events.add(
          _HistoryEvent(
            type: tick.isPaid ? 'Tick (Paid)' : 'Tick (Not paid)',
            date: tick.createdAt,
            detail:
                '${customer.name} • ${tick.stockType} • ${tick.itemName} • R${tick.itemPrice.toStringAsFixed(2)}',
          ),
        );
      }
    }

    for (final gift in widget.data.gifts.where((entry) => entry.dealerId == dealer.id)) {
      final customer = widget.data.customers.where((entry) => entry.id == gift.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Gift',
          date: gift.createdAt,
          detail:
              '$customerName • ${gift.stockType} • ${gift.itemName} • Qty ${gift.quantity} • R${gift.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final take in widget.data.dealerTakes.where((entry) => entry.dealerId == dealer.id)) {
      events.add(
        _HistoryEvent(
          type: 'Dealer Take',
          date: take.createdAt,
          detail:
              '${take.stockType} • ${take.itemName} • Qty ${take.quantity} • R${take.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    events.sort((a, b) {
      if (_sortOrder == _HistorySortOrder.newest) {
        return b.date.compareTo(a.date);
      }
      return a.date.compareTo(b.date);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.dealers.isEmpty) {
      return const Center(child: Text('No dealer history yet.'));
    }

    final dealers = [...widget.data.dealers]..sort((a, b) => a.dealerNumber.compareTo(b.dealerNumber));
    final filteredDealers = dealers.where((dealer) {
      final events = _eventsForDealer(dealer);
      return _matchesFilter(dealer, events);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sortOrder == _HistorySortOrder.newest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.newest;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sortOrder == _HistorySortOrder.oldest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.oldest;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter by dealer/customer',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterQuery = value;
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _DealerTotalsCharts(stats: _dealerStats()),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filteredDealers.isEmpty
              ? const Center(child: Text('No matching dealer history.'))
              : ListView.builder(
      itemCount: filteredDealers.length,
      itemBuilder: (context, index) {
        final dealer = filteredDealers[index];
        final dealerStat = _dealerStats().firstWhere(
          (entry) => entry.dealerId == dealer.id,
          orElse: () => DealerStatData(
            dealerId: dealer.id,
            dealerNumber: dealer.dealerNumber,
            dealerName: dealer.name,
            salesCount: 0,
            tickCount: 0,
          ),
        );
        final events = _eventsForDealer(dealer);

        return ExpansionTile(
          title: Text(widget.dealerLabel(dealer.id)),
          subtitle: Text('Sales: ${dealerStat.salesCount} • Ticks: ${dealerStat.tickCount}'),
          children: events.isEmpty
              ? const [
                  ListTile(title: Text('No records yet.')),
                ]
              : events
                  .map(
                    (event) => ListTile(
                      title: Text(event.type),
                      subtitle: Text('${event.detail}\n${widget.formatDate(event.date)}'),
                      isThreeLine: true,
                    ),
                  )
                  .toList(),
        );
      },
    ),
        ),
      ],
    );
  }
}

class _StockTypeHistoryTab extends StatefulWidget {
  const _StockTypeHistoryTab({
    required this.data,
    required this.dealerLabel,
    required this.formatDate,
    required this.stockTypeForSale,
  });

  final AppData data;
  final String Function(String dealerId) dealerLabel;
  final String Function(DateTime dateTime) formatDate;
  final String Function(SaleEntry sale) stockTypeForSale;

  @override
  State<_StockTypeHistoryTab> createState() => _StockTypeHistoryTabState();
}

class _StockTypeHistoryTabState extends State<_StockTypeHistoryTab> {
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  String _filterQuery = '';

  bool _matchesFilter(String stockType, List<_HistoryEvent> events) {
    final query = _filterQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    if (stockType.toLowerCase().contains(query)) {
      return true;
    }

    for (final event in events) {
      if (event.type.toLowerCase().contains(query) ||
          event.detail.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  List<String> _types() {
    final fromSettings = widget.data.stockTypes;
    final fromItems = widget.data.stockItems.map((item) => item.stockType);
    final fromTicks = widget.data.customers.expand((customer) => customer.ticks.map((tick) => tick.stockType));
    final fromSales = widget.data.sales.map(widget.stockTypeForSale);
    final fromGifts = widget.data.gifts.map((gift) => gift.stockType);
    final fromLost = widget.data.lostStock.map((entry) => entry.stockType);
    final fromDealerTake = widget.data.dealerTakes.map((entry) => entry.stockType);

    final all = <String>{
      ...fromSettings,
      ...fromItems,
      ...fromTicks,
      ...fromSales,
      ...fromGifts,
      ...fromLost,
      ...fromDealerTake,
    };

    final cleaned = all.where((type) => type.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cleaned;
  }

  List<_HistoryEvent> _eventsForType(String stockType) {
    final events = <_HistoryEvent>[];

    for (final sale in widget.data.sales) {
      if (widget.stockTypeForSale(sale) != stockType) {
        continue;
      }
      final customer = widget.data.customers.where((entry) => entry.id == sale.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Sale',
          date: sale.createdAt,
          detail:
              '$customerName • ${widget.dealerLabel(sale.dealerId)} • ${sale.itemName} • R${sale.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final customer in widget.data.customers) {
      for (final tick in customer.ticks.where((entry) => entry.stockType == stockType)) {
        events.add(
          _HistoryEvent(
            type: tick.isPaid ? 'Tick (Paid)' : 'Tick (Not paid)',
            date: tick.createdAt,
            detail:
                '${customer.name} • ${widget.dealerLabel(tick.dealerId)} • ${tick.itemName} • R${tick.itemPrice.toStringAsFixed(2)}',
          ),
        );
      }
    }

    for (final gift in widget.data.gifts.where((entry) => entry.stockType == stockType)) {
      final customer = widget.data.customers.where((entry) => entry.id == gift.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Gift',
          date: gift.createdAt,
          detail:
              '$customerName • ${widget.dealerLabel(gift.dealerId)} • ${gift.itemName} • Qty ${gift.quantity} • R${gift.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final lost in widget.data.lostStock.where((entry) => entry.stockType == stockType)) {
      events.add(
        _HistoryEvent(
          type: 'Lost',
          date: lost.createdAt,
          detail: '${lost.itemName} • Qty ${lost.quantity} • R${lost.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final take in widget.data.dealerTakes.where((entry) => entry.stockType == stockType)) {
      events.add(
        _HistoryEvent(
          type: 'Dealer Take',
          date: take.createdAt,
          detail:
              '${widget.dealerLabel(take.dealerId)} • ${take.itemName} • Qty ${take.quantity} • R${take.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    events.sort((a, b) {
      if (_sortOrder == _HistorySortOrder.newest) {
        return b.date.compareTo(a.date);
      }
      return a.date.compareTo(b.date);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final types = _types();
    if (types.isEmpty) {
      return const Center(child: Text('No stock type history yet.'));
    }

    final filteredTypes = types.where((type) {
      final events = _eventsForType(type);
      return _matchesFilter(type, events);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sortOrder == _HistorySortOrder.newest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.newest;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sortOrder == _HistorySortOrder.oldest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.oldest;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter by type/dealer/customer',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterQuery = value;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredTypes.isEmpty
              ? const Center(child: Text('No matching stock type history.'))
              : ListView.builder(
            itemCount: filteredTypes.length,
            itemBuilder: (context, index) {
              final type = filteredTypes[index];
              final saleCount = widget.data.sales.where((sale) => widget.stockTypeForSale(sale) == type).length;
              final tickCount = widget.data.customers
                  .map((customer) => customer.ticks.where((tick) => tick.stockType == type).length)
                  .fold(0, (sum, value) => sum + value);
              final saleValue = widget.data.sales
                  .where((sale) => widget.stockTypeForSale(sale) == type)
                  .fold<double>(0, (sum, sale) => sum + sale.itemPrice);
              final tickValue = widget.data.customers
                  .expand((customer) => customer.ticks)
                  .where((tick) => tick.stockType == type)
                  .fold<double>(0, (sum, tick) => sum + tick.itemPrice);
                final giftCount = widget.data.gifts
                  .where((gift) => gift.stockType == type)
                  .fold<int>(0, (sum, gift) => sum + gift.quantity);
                final giftValue = widget.data.gifts
                  .where((gift) => gift.stockType == type)
                  .fold<double>(0, (sum, gift) => sum + (gift.itemPrice * gift.quantity));
                final lostCount = widget.data.lostStock
                  .where((entry) => entry.stockType == type)
                  .fold<int>(0, (sum, entry) => sum + entry.quantity);
                final lostValue = widget.data.lostStock
                  .where((entry) => entry.stockType == type)
                  .fold<double>(0, (sum, entry) => sum + (entry.itemPrice * entry.quantity));
              final dealerTakeCount = widget.data.dealerTakes
                  .where((entry) => entry.stockType == type)
                  .fold<int>(0, (sum, entry) => sum + entry.quantity);
              final dealerTakeValue = widget.data.dealerTakes
                  .where((entry) => entry.stockType == type)
                  .fold<double>(0, (sum, entry) => sum + (entry.itemPrice * entry.quantity));
              final events = _eventsForType(type);

              return ExpansionTile(
                title: Text(type),
                subtitle: Text(
                  'Sales: $saleCount (R${saleValue.toStringAsFixed(2)}) • Ticks: $tickCount (R${tickValue.toStringAsFixed(2)}) • Gifts: $giftCount (R${giftValue.toStringAsFixed(2)}) • Lost: $lostCount (R${lostValue.toStringAsFixed(2)}) • Dealer-taken: $dealerTakeCount (R${dealerTakeValue.toStringAsFixed(2)})',
                ),
                children: events.isEmpty
                    ? const [
                        ListTile(title: Text('No records yet.')),
                      ]
                    : events
                        .map(
                          (event) => ListTile(
                            title: Text(event.type),
                            subtitle: Text('${event.detail}\n${widget.formatDate(event.date)}'),
                            isThreeLine: true,
                          ),
                        )
                        .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GiftLostHistoryTab extends StatefulWidget {
  const _GiftLostHistoryTab({
    required this.data,
    required this.dealerLabel,
    required this.formatDate,
  });

  final AppData data;
  final String Function(String dealerId) dealerLabel;
  final String Function(DateTime dateTime) formatDate;

  @override
  State<_GiftLostHistoryTab> createState() => _GiftLostHistoryTabState();
}

class _GiftLostHistoryTabState extends State<_GiftLostHistoryTab> {
  _HistorySortOrder _sortOrder = _HistorySortOrder.newest;
  String _filterQuery = '';

  List<_HistoryEvent> _events() {
    final events = <_HistoryEvent>[];

    for (final gift in widget.data.gifts) {
      final customer = widget.data.customers.where((entry) => entry.id == gift.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Gift',
          date: gift.createdAt,
          detail:
              '$customerName • ${widget.dealerLabel(gift.dealerId)} • ${gift.stockType} • ${gift.itemName} • Qty ${gift.quantity} • R${gift.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final lost in widget.data.lostStock) {
      events.add(
        _HistoryEvent(
          type: 'Lost',
          date: lost.createdAt,
          detail:
              '${lost.stockType} • ${lost.itemName} • Qty ${lost.quantity} • R${lost.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    for (final take in widget.data.dealerTakes) {
      events.add(
        _HistoryEvent(
          type: 'Dealer Take',
          date: take.createdAt,
          detail:
              '${widget.dealerLabel(take.dealerId)} • ${take.stockType} • ${take.itemName} • Qty ${take.quantity} • R${take.itemPrice.toStringAsFixed(2)}',
        ),
      );
    }

    events.sort((a, b) {
      if (_sortOrder == _HistorySortOrder.newest) {
        return b.date.compareTo(a.date);
      }
      return a.date.compareTo(b.date);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _events();
    if (events.isEmpty) {
      return const Center(child: Text('No gift or lost history yet.'));
    }

    final query = _filterQuery.trim().toLowerCase();
    final filtered = events.where((event) {
      if (query.isEmpty) {
        return true;
      }
      return event.type.toLowerCase().contains(query) ||
          event.detail.toLowerCase().contains(query);
    }).toList();

    final giftedCount = widget.data.gifts.fold<int>(0, (sum, gift) => sum + gift.quantity);
    final giftedValue = widget.data.gifts
        .fold<double>(0, (sum, gift) => sum + (gift.itemPrice * gift.quantity));
    final lostCount = widget.data.lostStock.fold<int>(0, (sum, entry) => sum + entry.quantity);
    final lostValue = widget.data.lostStock
        .fold<double>(0, (sum, entry) => sum + (entry.itemPrice * entry.quantity));
    final dealerTakeCount = widget.data.dealerTakes.fold<int>(0, (sum, entry) => sum + entry.quantity);
    final dealerTakeValue = widget.data.dealerTakes
        .fold<double>(0, (sum, entry) => sum + (entry.itemPrice * entry.quantity));

    final byDay = <String, ({DateTime day, int gifted, int lost, int dealerTake})>{};
    for (final gift in widget.data.gifts) {
      final day = DateTime(gift.createdAt.year, gift.createdAt.month, gift.createdAt.day);
      final key = day.toIso8601String();
      final existing = byDay[key];
      byDay[key] = (
        day: day,
        gifted: (existing?.gifted ?? 0) + gift.quantity,
        lost: existing?.lost ?? 0,
        dealerTake: existing?.dealerTake ?? 0,
      );
    }
    for (final lost in widget.data.lostStock) {
      final day = DateTime(lost.createdAt.year, lost.createdAt.month, lost.createdAt.day);
      final key = day.toIso8601String();
      final existing = byDay[key];
      byDay[key] = (
        day: day,
        gifted: existing?.gifted ?? 0,
        lost: (existing?.lost ?? 0) + lost.quantity,
        dealerTake: existing?.dealerTake ?? 0,
      );
    }
    for (final take in widget.data.dealerTakes) {
      final day = DateTime(take.createdAt.year, take.createdAt.month, take.createdAt.day);
      final key = day.toIso8601String();
      final existing = byDay[key];
      byDay[key] = (
        day: day,
        gifted: existing?.gifted ?? 0,
        lost: existing?.lost ?? 0,
        dealerTake: (existing?.dealerTake ?? 0) + take.quantity,
      );
    }
    final dayTotals = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    final giftSpots = <FlSpot>[];
    final lostSpots = <FlSpot>[];
    final dealerTakeSpots = <FlSpot>[];
    for (var index = 0; index < dayTotals.length; index++) {
      giftSpots.add(FlSpot(index.toDouble(), dayTotals[index].gifted.toDouble()));
      lostSpots.add(FlSpot(index.toDouble(), dayTotals[index].lost.toDouble()));
      dealerTakeSpots.add(FlSpot(index.toDouble(), dayTotals[index].dealerTake.toDouble()));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sortOrder == _HistorySortOrder.newest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.newest;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sortOrder == _HistorySortOrder.oldest,
                    onSelected: (_) {
                      setState(() {
                        _sortOrder = _HistorySortOrder.oldest;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter by item/type/customer/dealer',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterQuery = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gifted: $giftedCount (R${giftedValue.toStringAsFixed(2)}) • Lost: $lostCount (R${lostValue.toStringAsFixed(2)}) • Dealer-taken: $dealerTakeCount (R${dealerTakeValue.toStringAsFixed(2)})',
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gifted vs Lost Overview'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: dayTotals.isEmpty
                            ? const Center(child: Text('No chart data yet.'))
                            : LineChart(
                                LineChartData(
                                  minY: 0,
                                  gridData: const FlGridData(show: true),
                                  lineTouchData: const LineTouchData(enabled: false),
                                  titlesData: const FlTitlesData(
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: giftSpots,
                                      isCurved: false,
                                      barWidth: 3,
                                      color: Theme.of(context).colorScheme.primary,
                                      dotData: const FlDotData(show: false),
                                    ),
                                    LineChartBarData(
                                      spots: lostSpots,
                                      isCurved: false,
                                      barWidth: 3,
                                      color: Theme.of(context).colorScheme.error,
                                      dotData: const FlDotData(show: false),
                                    ),
                                    LineChartBarData(
                                      spots: dealerTakeSpots,
                                      isCurved: false,
                                      barWidth: 3,
                                      color: Theme.of(context).colorScheme.tertiary,
                                      dotData: const FlDotData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  centerSpaceRadius: 28,
                                  sectionsSpace: 2,
                                  sections: [
                                    PieChartSectionData(
                                      value: math.max(giftedCount.toDouble(), 0.0001),
                                      color: Theme.of(context).colorScheme.primary,
                                      title: '$giftedCount',
                                      radius: 50,
                                    ),
                                    PieChartSectionData(
                                      value: math.max(lostCount.toDouble(), 0.0001),
                                      color: Theme.of(context).colorScheme.error,
                                      title: '$lostCount',
                                      radius: 50,
                                    ),
                                    PieChartSectionData(
                                      value: math.max(dealerTakeCount.toDouble(), 0.0001),
                                      color: Theme.of(context).colorScheme.tertiary,
                                      title: '$dealerTakeCount',
                                      radius: 50,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Gifted qty: $giftedCount'),
                                  const SizedBox(height: 6),
                                  Text('Lost qty: $lostCount'),
                                  const SizedBox(height: 6),
                                  Text('Dealer-taken qty: $dealerTakeCount'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching gift/lost history.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    return ListTile(
                      title: Text(event.type),
                      subtitle: Text('${event.detail}\n${widget.formatDate(event.date)}'),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _pickBackgroundImage() async {
    final password = _settings.password;
    if (password == null || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a password first to encrypt images.')),
      );
      return;
    }

    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) {
      return;
    }

    final stablePath = await persistPickedImage(
      image: image,
      prefix: 'menu_bg',
      password: password,
    );
    setState(() {
      _settings = _settings.copyWith(backgroundImagePath: stablePath);
    });
  }

  Future<void> _setPassword() async {
    final password = await showNameDialog(
      context: context,
      title: 'Set Password',
      hint: 'Enter password',
      obscureText: true,
    );
    if (password == null) {
      return;
    }
    setState(() {
      _settings = _settings.copyWith(password: password);
    });
  }

  void _clearPassword() {
    setState(() {
      _settings = _settings.copyWith(password: '');
    });
  }

  Future<void> _setLowStockThreshold() async {
    final input = await showNameDialog(
      context: context,
      title: 'Low stock alert threshold',
      hint: 'Enter minimum stock count',
      initialValue: _settings.lowStockThreshold.toString(),
    );
    if (input == null) {
      return;
    }
    final threshold = int.tryParse(input.trim());
    if (threshold == null || threshold < 1) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number greater than 0.')),
      );
      return;
    }
    setState(() {
      _settings = _settings.copyWith(lowStockThreshold: threshold);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_settings),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Change main menu background'),
            onTap: _pickBackgroundImage,
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Set or change password'),
            onTap: _setPassword,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open),
            title: const Text('Clear password'),
            onTap: _clearPassword,
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: const Text('Set low stock alert threshold'),
            subtitle: Text('Current: ${_settings.lowStockThreshold}'),
            onTap: _setLowStockThreshold,
          ),
        ],
      ),
    );
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final DealInfoRepository _repository = DealInfoRepository();
  final Uuid _uuid = const Uuid();
  final ImagePicker _imagePicker = ImagePicker();

  AppData _data = AppData.empty();
  bool _isLoading = true;
  AppData? _undoSnapshot;
  String? _undoMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var data = await _repository.loadData();
    data = _normalizePointers(data);
    if (!mounted) {
      return;
    }
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  AppData _normalizePointers(AppData data) {
    final dealers = _sortedDealers(data.dealers);
    if (dealers.isEmpty) {
      return data.copyWith(currentSalesDealerId: '', currentTickDealerId: '');
    }

    final firstId = dealers.first.id;
    final salesValid = dealers.any((dealer) => dealer.id == data.currentSalesDealerId);
    final ticksValid = dealers.any((dealer) => dealer.id == data.currentTickDealerId);

    return data.copyWith(
      currentSalesDealerId: salesValid ? data.currentSalesDealerId : firstId,
      currentTickDealerId: ticksValid ? data.currentTickDealerId : firstId,
    );
  }

  List<Dealer> _sortedDealers(List<Dealer> dealers) {
    final sorted = [...dealers]..sort((a, b) => a.dealerNumber.compareTo(b.dealerNumber));
    return sorted;
  }

  Future<void> _save() async {
    await _repository.saveData(_data);
  }

  void _captureUndo(String message) {
    _undoSnapshot = _data;
    _undoMessage = message;
  }

  bool _canUndoStockAction() => _undoSnapshot != null;

  Future<void> _undoLastStockAction() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) {
      return;
    }
    setState(() {
      _data = snapshot;
      _undoSnapshot = null;
      _undoMessage = null;
    });
    await _save();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Last stock action was undone.')),
    );
  }

  List<StockItem> _sortedStockItems(List<StockItem> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final typeCompare = a.stockType.toLowerCase().compareTo(b.stockType.toLowerCase());
        if (typeCompare != 0) {
          return typeCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  StockItem? _stockItemById(String stockItemId) {
    for (final item in _data.stockItems) {
      if (item.id == stockItemId) {
        return item;
      }
    }
    return null;
  }

  List<String> _stockTypes() {
    final types = {
      ..._data.stockTypes,
      ..._data.stockItems.map((item) => item.stockType.trim()),
    }.where((type) => type.isNotEmpty).toList();
    types.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return types;
  }

  Future<void> _addStockType(String stockType) async {
    final cleaned = stockType.trim();
    if (cleaned.isEmpty) {
      return;
    }

    final exists = _stockTypes().any((type) => type.toLowerCase() == cleaned.toLowerCase());
    if (exists) {
      return;
    }

    setState(() {
      _data = _data.copyWith(stockTypes: [..._data.stockTypes, cleaned]);
    });
    await _save();
  }

  Future<void> _addStockItem({
    required String stockType,
    required String name,
    required double price,
    required int initialCount,
  }) async {
    final item = StockItem(
      id: _uuid.v4(),
      stockType: stockType.trim(),
      name: name.trim(),
      price: price,
      initialCount: initialCount,
      currentCount: initialCount,
    );

    _captureUndo('Added stock item');
    setState(() {
      final nextTypes = {..._data.stockTypes, stockType.trim()}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _data = _data.copyWith(
        stockTypes: nextTypes,
        stockItems: [..._data.stockItems, item],
        stockAdditions: [
          ..._data.stockAdditions,
          StockAdditionEntry(
            id: _uuid.v4(),
            stockItemId: item.id,
            stockType: item.stockType,
            itemName: item.name,
            quantityAdded: initialCount,
            addedAt: DateTime.now(),
          ),
        ],
      );
    });
    await _save();
  }

  Future<void> _increaseStockCount({
    required String stockItemId,
    required int addCount,
  }) async {
    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null) {
      return;
    }

    _captureUndo('Increased stock count');
    setState(() {
      _data = _data.copyWith(
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItemId
                  ? item.copyWith(
                      initialCount: item.initialCount + addCount,
                      currentCount: item.currentCount + addCount,
                    )
                  : item,
            )
            .toList(),
        stockAdditions: [
          ..._data.stockAdditions,
          StockAdditionEntry(
            id: _uuid.v4(),
            stockItemId: stockItem.id,
            stockType: stockItem.stockType,
            itemName: stockItem.name,
            quantityAdded: addCount,
            addedAt: DateTime.now(),
          ),
        ],
      );
    });
    await _save();
  }

  Future<void> _openStockScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StockScreen(
          getStockItems: () => _sortedStockItems(_data.stockItems),
          getStockTypes: _stockTypes,
          getStockAdditions: () => _data.stockAdditions,
          getGiftEntries: () => _data.gifts,
          getLostStockEntries: () => _data.lostStock,
          getDealerTakeEntries: () => _data.dealerTakes,
          getDealers: () => _sortedDealers(_data.dealers),
          lowStockThreshold: _data.settings.lowStockThreshold,
          canUndoStockAction: _canUndoStockAction,
          onUndoStockAction: _undoLastStockAction,
          onAddStockType: _addStockType,
          onAddStockItem: _addStockItem,
          onIncreaseStockCount: _increaseStockCount,
          onRecordLostStock: _recordLostStock,
          onRecordDealerTake: _recordDealerTake,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Dealer? _dealerById(String? dealerId) {
    if (dealerId == null || dealerId.isEmpty) {
      return null;
    }
    for (final dealer in _data.dealers) {
      if (dealer.id == dealerId) {
        return dealer;
      }
    }
    return null;
  }

  String _dealerLabelById(String dealerId) {
    final dealer = _dealerById(dealerId);
    if (dealer == null) {
      return 'Unknown dealer';
    }
    return 'ID ${dealer.dealerNumber} - ${dealer.name}';
  }

  String _currentSalesDealerLabel() {
    final dealer = _dealerById(_data.currentSalesDealerId);
    if (dealer == null) {
      return 'No dealer';
    }
    return 'ID ${dealer.dealerNumber} - ${dealer.name}';
  }

  String _currentTickDealerLabel() {
    final dealer = _dealerById(_data.currentTickDealerId);
    if (dealer == null) {
      return 'No dealer';
    }
    return 'ID ${dealer.dealerNumber} - ${dealer.name}';
  }

  String? _nextDealerIdAfter(String currentDealerId) {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
      return null;
    }
    final index = dealers.indexWhere((dealer) => dealer.id == currentDealerId);
    if (index == -1) {
      return dealers.first.id;
    }
    final nextIndex = (index + 1) % dealers.length;
    return dealers[nextIndex].id;
  }

  Future<void> _addDealer(String name) async {
    final maxNumber = _data.dealers.isEmpty
        ? 0
        : _data.dealers
            .map((dealer) => dealer.dealerNumber)
            .reduce((left, right) => left > right ? left : right);

    final dealer = Dealer(
      id: _uuid.v4(),
      dealerNumber: maxNumber + 1,
      name: name.trim(),
    );

    var updated = _data.copyWith(dealers: [..._data.dealers, dealer]);
    updated = _normalizePointers(updated);

    setState(() {
      _data = updated;
    });
    await _save();
  }

  Future<void> _editDealerName({required String dealerId, required String name}) async {
    setState(() {
      _data = _data.copyWith(
        dealers: _data.dealers
            .map((dealer) => dealer.id == dealerId ? dealer.copyWith(name: name.trim()) : dealer)
            .toList(),
      );
    });
    await _save();
  }

  Future<void> _captureDealerPhoto(String dealerId) async {
    final password = _data.settings.password;
    if (password == null || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a password in Settings before adding profile photos.')),
      );
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) {
      return;
    }

    final stablePath = await persistPickedImage(
      image: image,
      prefix: 'dealer_$dealerId',
      password: password,
    );

    setState(() {
      _data = _data.copyWith(
        dealers: _data.dealers
            .map(
              (dealer) =>
                  dealer.id == dealerId ? dealer.copyWith(profileImagePath: stablePath) : dealer,
            )
            .toList(),
      );
    });
    await _save();
  }

  Future<bool> _removeDealer(String dealerId) async {
    final usedInTicks = _data.customers.any(
      (customer) => customer.ticks.any((tick) => tick.dealerId == dealerId),
    );
    final usedInSales = _data.sales.any((sale) => sale.dealerId == dealerId);
    final usedInGifts = _data.gifts.any((gift) => gift.dealerId == dealerId);
    final usedInDealerTakes = _data.dealerTakes.any((entry) => entry.dealerId == dealerId);
    if (usedInTicks || usedInSales || usedInGifts || usedInDealerTakes) {
      return false;
    }

    var updated = _data.copyWith(
      dealers: _data.dealers.where((dealer) => dealer.id != dealerId).toList(),
    );
    updated = _normalizePointers(updated);
    setState(() {
      _data = updated;
    });
    await _save();
    return true;
  }

  Future<void> _addCustomer(String name) async {
    final customer = Customer(id: _uuid.v4(), name: name.trim(), ticks: []);
    setState(() {
      _data = _data.copyWith(customers: [..._data.customers, customer]);
    });
    await _save();
  }

  Future<void> _editCustomerName({required String customerId, required String name}) async {
    setState(() {
      _data = _data.copyWith(
        customers: _data.customers
            .map((customer) => customer.id == customerId ? customer.copyWith(name: name.trim()) : customer)
            .toList(),
      );
    });
    await _save();
  }

  Future<void> _removeCustomer(String customerId) async {
    setState(() {
      _data = _data.copyWith(
        customers: _data.customers.where((customer) => customer.id != customerId).toList(),
      );
    });
    await _save();
  }

  Future<String?> _captureCustomerPhoto(String customerId) async {
    final password = _data.settings.password;
    if (password == null || password.isEmpty) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a password in Settings before adding profile photos.')),
      );
      return null;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) {
      return null;
    }

    final stablePath = await persistPickedImage(
      image: image,
      prefix: 'customer_$customerId',
      password: password,
    );

    setState(() {
      _data = _data.copyWith(
        customers: _data.customers
            .map(
              (customer) => customer.id == customerId
                  ? customer.copyWith(profileImagePath: stablePath)
                  : customer,
            )
            .toList(),
      );
    });
    await _save();
    return stablePath;
  }

  bool _canEditTickStatus(TickEntry tick) {
    final changedAt = tick.paidStatusEditedAt;
    if (changedAt == null) {
      return true;
    }
    return DateTime.now().isBefore(changedAt.add(const Duration(hours: 1)));
  }

  Future<bool> _updateTickPaidStatus({
    required String customerId,
    required String tickId,
    required bool isPaid,
  }) async {
    final customerIndex = _data.customers.indexWhere((customer) => customer.id == customerId);
    if (customerIndex == -1) {
      return false;
    }

    final currentCustomer = _data.customers[customerIndex];
    final tickIndex = currentCustomer.ticks.indexWhere((tick) => tick.id == tickId);
    if (tickIndex == -1) {
      return false;
    }

    final currentTick = currentCustomer.ticks[tickIndex];
    if (!isPaid) {
      final updatedTick = currentTick.copyWith(
        isPaid: false,
        paidStatusEditedAt: null,
      );

      final updatedTicks = [...currentCustomer.ticks];
      updatedTicks[tickIndex] = updatedTick;

      final updatedCustomers = [..._data.customers];
      updatedCustomers[customerIndex] = currentCustomer.copyWith(ticks: updatedTicks);

      setState(() {
        _data = _data.copyWith(customers: updatedCustomers);
      });
      await _save();
      return true;
    }

    if (currentTick.isPaid == isPaid) {
      return true;
    }
    if (!_canEditTickStatus(currentTick)) {
      return false;
    }

    final updatedTick = currentTick.copyWith(
      isPaid: isPaid,
      paidStatusEditedAt: currentTick.paidStatusEditedAt ?? DateTime.now(),
    );
    final updatedTicks = [...currentCustomer.ticks];
    updatedTicks[tickIndex] = updatedTick;

    final updatedCustomers = [..._data.customers];
    updatedCustomers[customerIndex] = currentCustomer.copyWith(ticks: updatedTicks);

    setState(() {
      _data = _data.copyWith(customers: updatedCustomers);
    });
    await _save();
    return true;
  }

  Future<String?> _recordSale(String customerId, String stockItemId) async {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
      return null;
    }

    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null || stockItem.currentCount <= 0) {
      return null;
    }

    final activeDealer = _dealerById(_data.currentSalesDealerId) ?? dealers.first;
    final nextId = _nextDealerIdAfter(activeDealer.id) ?? activeDealer.id;

    final sale = SaleEntry(
      id: _uuid.v4(),
      customerId: customerId,
      dealerId: activeDealer.id,
      stockItemId: stockItem.id,
      itemName: stockItem.name,
      itemPrice: stockItem.price,
      createdAt: DateTime.now(),
    );

    _captureUndo('Recorded sale');
    setState(() {
      _data = _data.copyWith(
        sales: [..._data.sales, sale],
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItem.id
                  ? item.copyWith(currentCount: item.currentCount - 1)
                  : item,
            )
            .toList(),
        currentSalesDealerId: nextId,
      );
    });
    await _save();
    return _dealerLabelById(activeDealer.id);
  }

  Future<String?> _recordGift(String customerId, String stockItemId) async {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
      return null;
    }

    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null || stockItem.currentCount <= 0) {
      return null;
    }

    final activeDealer = _dealerById(_data.currentSalesDealerId) ?? dealers.first;
    final nextId = _nextDealerIdAfter(activeDealer.id) ?? activeDealer.id;

    final gift = GiftEntry(
      id: _uuid.v4(),
      customerId: customerId,
      dealerId: activeDealer.id,
      stockItemId: stockItem.id,
      itemName: stockItem.name,
      stockType: stockItem.stockType,
      itemPrice: stockItem.price,
      quantity: 1,
      createdAt: DateTime.now(),
    );

    _captureUndo('Recorded gift');
    setState(() {
      _data = _data.copyWith(
        gifts: [..._data.gifts, gift],
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItem.id
                  ? item.copyWith(currentCount: item.currentCount - 1)
                  : item,
            )
            .toList(),
        currentSalesDealerId: nextId,
      );
    });
    await _save();
    return _dealerLabelById(activeDealer.id);
  }

  Future<bool> _recordLostStock({
    required String stockItemId,
    required int quantityLost,
  }) async {
    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null || quantityLost <= 0 || stockItem.currentCount < quantityLost) {
      return false;
    }

    final lost = LostStockEntry(
      id: _uuid.v4(),
      stockItemId: stockItem.id,
      itemName: stockItem.name,
      stockType: stockItem.stockType,
      itemPrice: stockItem.price,
      quantity: quantityLost,
      createdAt: DateTime.now(),
    );

    _captureUndo('Recorded lost stock');
    setState(() {
      _data = _data.copyWith(
        lostStock: [..._data.lostStock, lost],
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItem.id
                  ? item.copyWith(currentCount: item.currentCount - quantityLost)
                  : item,
            )
            .toList(),
      );
    });
    await _save();
    return true;
  }

  Future<bool> _recordDealerTake({
    required String dealerId,
    required String stockItemId,
    required int quantityTaken,
  }) async {
    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null || quantityTaken <= 0 || stockItem.currentCount < quantityTaken) {
      return false;
    }

    final dealerExists = _data.dealers.any((dealer) => dealer.id == dealerId);
    if (!dealerExists) {
      return false;
    }

    final take = DealerTakeEntry(
      id: _uuid.v4(),
      dealerId: dealerId,
      stockItemId: stockItem.id,
      itemName: stockItem.name,
      stockType: stockItem.stockType,
      itemPrice: stockItem.price,
      quantity: quantityTaken,
      createdAt: DateTime.now(),
    );

    _captureUndo('Recorded dealer take');
    setState(() {
      _data = _data.copyWith(
        dealerTakes: [..._data.dealerTakes, take],
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItem.id
                  ? item.copyWith(currentCount: item.currentCount - quantityTaken)
                  : item,
            )
            .toList(),
      );
    });
    await _save();
    return true;
  }

  Future<String?> _recordTick(String customerId, bool isPaid, String stockItemId) async {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
      return null;
    }

    final stockItem = _stockItemById(stockItemId);
    if (stockItem == null || stockItem.currentCount <= 0) {
      return null;
    }

    final activeDealer = _dealerById(_data.currentTickDealerId) ?? dealers.first;
    final nextId = _nextDealerIdAfter(activeDealer.id) ?? activeDealer.id;

    final customerIndex = _data.customers.indexWhere((customer) => customer.id == customerId);
    if (customerIndex == -1) {
      return null;
    }

    final currentCustomer = _data.customers[customerIndex];
    final updatedCustomer = currentCustomer.copyWith(
      ticks: [
        ...currentCustomer.ticks,
        TickEntry(
          id: _uuid.v4(),
          dealerId: activeDealer.id,
          stockItemId: stockItem.id,
          itemName: stockItem.name,
          itemPrice: stockItem.price,
          stockType: stockItem.stockType,
          createdAt: DateTime.now(),
          isPaid: isPaid,
        ),
      ],
    );

    final updatedCustomers = [..._data.customers];
    updatedCustomers[customerIndex] = updatedCustomer;

    _captureUndo('Recorded tick');
    setState(() {
      _data = _data.copyWith(
        customers: updatedCustomers,
        stockItems: _data.stockItems
            .map(
              (item) => item.id == stockItem.id
                  ? item.copyWith(currentCount: item.currentCount - 1)
                  : item,
            )
            .toList(),
        currentTickDealerId: nextId,
      );
    });
    await _save();
    return _dealerLabelById(activeDealer.id);
  }

  Future<void> _openDealersScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DealersScreen(
          getDealers: () => _sortedDealers(_data.dealers),
          getDealerStats: () => buildDealerStats(_data),
          imagePassword: _data.settings.password,
          onAddDealer: _addDealer,
          onEditDealer: _editDealerName,
          onCaptureDealerPhoto: _captureDealerPhoto,
          onRemoveDealer: _removeDealer,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<SaleEntry> _salesForCustomer(String customerId) {
    return _data.sales.where((sale) => sale.customerId == customerId).toList();
  }

  List<GiftEntry> _giftsForCustomer(String customerId) {
    return _data.gifts.where((gift) => gift.customerId == customerId).toList();
  }

  Widget _buildCustomerAvatar(Customer customer) {
    final image = loadSecureMemoryImage(
      encryptedPath: customer.profileImagePath,
      password: _data.settings.password,
    );
    if (image != null) {
      return CircleAvatar(backgroundImage: image);
    }
    return CircleAvatar(child: Text(initialsForName(customer.name)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            onPressed: _canUndoStockAction() ? _undoLastStockAction : null,
            icon: const Icon(Icons.undo),
            tooltip: _undoMessage == null ? 'Undo' : 'Undo: $_undoMessage',
          ),
          IconButton(
            onPressed: _openStockScreen,
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Stock',
          ),
          IconButton(
            onPressed: _openDealersScreen,
            icon: const Icon(Icons.groups),
            tooltip: 'Dealers',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.customers.isEmpty
              ? const Center(child: Text('No customers yet. Add one with +'))
              : ListView.builder(
                  itemCount: _data.customers.length,
                  itemBuilder: (context, index) {
                    final customer = _data.customers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: _buildCustomerAvatar(customer),
                        title: Text(customer.name),
                        subtitle: Text('Tickz count: ${customer.tickCount}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final name = await showNameDialog(
                                  context: context,
                                  title: 'Edit customer',
                                  hint: 'Customer name',
                                  initialValue: customer.name,
                                );
                                if (name != null) {
                                  await _editCustomerName(customerId: customer.id, name: name);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeCustomer(customer.id),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CustomerDetailsScreen(
                                customerId: customer.id,
                                getCustomer: () => _data.customers.firstWhere((entry) => entry.id == customer.id),
                                getSalesForCustomer: () => _salesForCustomer(customer.id),
                                getGiftsForCustomer: () => _giftsForCustomer(customer.id),
                                imagePassword: _data.settings.password,
                                dealerLabelById: _dealerLabelById,
                                getStockItems: () => _sortedStockItems(_data.stockItems),
                                getCurrentSalesDealerLabel: _currentSalesDealerLabel,
                                getCurrentTickDealerLabel: _currentTickDealerLabel,
                                canEditTickStatus: _canEditTickStatus,
                                onAddTick: (isPaid, stockItemId) =>
                                  _recordTick(customer.id, isPaid, stockItemId),
                                onRecordSale: (stockItemId) =>
                                  _recordSale(customer.id, stockItemId),
                                onRecordGift: (stockItemId) =>
                                  _recordGift(customer.id, stockItemId),
                                onUpdateTickPaidStatus: ({required tickId, required isPaid}) =>
                                    _updateTickPaidStatus(
                                  customerId: customer.id,
                                  tickId: tickId,
                                  isPaid: isPaid,
                                ),
                                onCapturePhoto: () => _captureCustomerPhoto(customer.id),
                                onRenameCustomer: (name) =>
                                    _editCustomerName(customerId: customer.id, name: name),
                              ),
                            ),
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showNameDialog(
            context: context,
            title: 'Add customer',
            hint: 'Customer name',
          );
          if (name != null) {
            await _addCustomer(name);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DealersScreen extends StatefulWidget {
  const DealersScreen({
    super.key,
    required this.getDealers,
    required this.getDealerStats,
    required this.imagePassword,
    required this.onAddDealer,
    required this.onEditDealer,
    required this.onCaptureDealerPhoto,
    required this.onRemoveDealer,
  });

  final List<Dealer> Function() getDealers;
  final List<DealerStatData> Function() getDealerStats;
  final String? imagePassword;
  final Future<void> Function(String name) onAddDealer;
  final Future<void> Function({required String dealerId, required String name}) onEditDealer;
  final Future<void> Function(String dealerId) onCaptureDealerPhoto;
  final Future<bool> Function(String dealerId) onRemoveDealer;

  @override
  State<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends State<DealersScreen> {
  Widget _buildDealerAvatar(Dealer dealer) {
    final image = loadSecureMemoryImage(
      encryptedPath: dealer.profileImagePath,
      password: widget.imagePassword,
    );
    if (image != null) {
      return CircleAvatar(backgroundImage: image);
    }
    return CircleAvatar(child: Text(initialsForName(dealer.name)));
  }

  @override
  Widget build(BuildContext context) {
    final dealers = widget.getDealers();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dealers'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DealerStatsScreen(stats: widget.getDealerStats()),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Dealer stats',
          ),
        ],
      ),
      body: dealers.isEmpty
          ? const Center(child: Text('No dealers yet. Add one with +'))
          : ListView.builder(
              itemCount: dealers.length,
              itemBuilder: (context, index) {
                final dealer = dealers[index];
                return ListTile(
                  leading: _buildDealerAvatar(dealer),
                  title: Text(dealer.name),
                  subtitle: Text('Dealer ID ${dealer.dealerNumber}'),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_camera),
                        onPressed: () async {
                          await widget.onCaptureDealerPhoto(dealer.id);
                          if (context.mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final name = await showNameDialog(
                            context: context,
                            title: 'Edit dealer',
                            hint: 'Dealer name',
                            initialValue: dealer.name,
                          );
                          if (name != null) {
                            await widget.onEditDealer(dealerId: dealer.id, name: name);
                            if (context.mounted) {
                              setState(() {});
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final removed = await widget.onRemoveDealer(dealer.id);
                          if (!context.mounted) {
                            return;
                          }
                          if (!removed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dealer cannot be removed if sales/ticks/gifts/dealer-take records exist.'),
                              ),
                            );
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showNameDialog(
            context: context,
            title: 'Add dealer',
            hint: 'Dealer name',
          );
          if (name != null) {
            await widget.onAddDealer(name);
            if (mounted) {
              setState(() {});
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DealerStatsScreen extends StatelessWidget {
  const DealerStatsScreen({super.key, required this.stats});

  final List<DealerStatData> stats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dealer Stats')),
      body: stats.isEmpty
          ? const Center(child: Text('No dealer stats yet.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _DealerTotalsCharts(stats: stats, title: 'Dealer Stats: Sold vs Ticked'),
                const SizedBox(height: 8),
                ...stats.map(
                  (entry) => Card(
                    child: ListTile(
                      title: Text(entry.label),
                      subtitle: Text('Sold: ${entry.salesCount} • Ticked: ${entry.tickCount}'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class StockScreen extends StatefulWidget {
  const StockScreen({
    super.key,
    required this.getStockItems,
    required this.getStockTypes,
    required this.getStockAdditions,
    required this.getGiftEntries,
    required this.getLostStockEntries,
    required this.getDealerTakeEntries,
    required this.getDealers,
    required this.lowStockThreshold,
    required this.canUndoStockAction,
    required this.onUndoStockAction,
    required this.onAddStockType,
    required this.onAddStockItem,
    required this.onIncreaseStockCount,
    required this.onRecordLostStock,
    required this.onRecordDealerTake,
  });

  final List<StockItem> Function() getStockItems;
  final List<String> Function() getStockTypes;
  final List<StockAdditionEntry> Function() getStockAdditions;
  final List<GiftEntry> Function() getGiftEntries;
  final List<LostStockEntry> Function() getLostStockEntries;
  final List<DealerTakeEntry> Function() getDealerTakeEntries;
  final List<Dealer> Function() getDealers;
  final int lowStockThreshold;
  final bool Function() canUndoStockAction;
  final Future<void> Function() onUndoStockAction;
  final Future<void> Function(String stockType) onAddStockType;
  final Future<void> Function({
    required String stockType,
    required String name,
    required double price,
    required int initialCount,
  }) onAddStockItem;
  final Future<void> Function({
    required String stockItemId,
    required int addCount,
  }) onIncreaseStockCount;
  final Future<bool> Function({
    required String stockItemId,
    required int quantityLost,
  }) onRecordLostStock;
  final Future<bool> Function({
    required String dealerId,
    required String stockItemId,
    required int quantityTaken,
  }) onRecordDealerTake;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Future<void> _showAddStockTypeDialog() async {
    final type = await showNameDialog(
      context: context,
      title: 'Add stock type',
      hint: 'Stock type (e.g. Tobacco)',
    );
    if (type == null) {
      return;
    }

    await widget.onAddStockType(type);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showAddStockDialog() async {
    final stockTypes = widget.getStockTypes();
    if (stockTypes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a stock type first.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final countController = TextEditingController();
    String selectedStockType = stockTypes.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    math.max(14, media.viewPadding.bottom + 14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add stock item', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStockType,
                        decoration: const InputDecoration(labelText: 'Stock type'),
                        items: stockTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedStockType = value;
                          });
                        },
                      ),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        scrollPadding: const EdgeInsets.only(bottom: 240),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Item name'),
                      ),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        scrollPadding: const EdgeInsets.only(bottom: 240),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                      TextField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        scrollPadding: const EdgeInsets.only(bottom: 240),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Initial count'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    final count = int.tryParse(countController.text.trim());

    if (name.isEmpty || price == null || count == null || count <= 0 || price < 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid item name, price, and count.')),
      );
      return;
    }

    await widget.onAddStockItem(
      stockType: selectedStockType,
      name: name,
      price: price,
      initialCount: count,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showIncreaseStockDialog(StockItem item) async {
    final countController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              math.max(14, media.viewPadding.bottom + 14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add count to ${item.name}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: countController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.only(bottom: 180),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Add count'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final addCount = int.tryParse(countController.text.trim());
    if (addCount == null || addCount <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid count greater than 0.')),
      );
      return;
    }

    await widget.onIncreaseStockCount(stockItemId: item.id, addCount: addCount);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _showLostStockDialog() async {
    final stockItems = widget.getStockItems().where((item) => item.currentCount > 0).toList();
    if (stockItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stock available to mark as lost.')),
      );
      return;
    }

    String selectedStockItemId = stockItems.first.id;
    final quantityController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  math.max(14, media.viewPadding.bottom + 14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Record lost stock', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStockItemId,
                      decoration: const InputDecoration(labelText: 'Stock item'),
                      items: stockItems
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                '${item.stockType} • ${item.name} (Qty: ${item.currentCount})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedStockItemId = value;
                        });
                      },
                    ),
                    TextField(
                      controller: quantityController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      scrollPadding: const EdgeInsets.only(bottom: 220),
                      decoration: const InputDecoration(labelText: 'Quantity lost'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final quantityLost = int.tryParse(quantityController.text.trim());
    if (quantityLost == null || quantityLost <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity greater than 0.')),
      );
      return;
    }

    final success = await widget.onRecordLostStock(
      stockItemId: selectedStockItemId,
      quantityLost: quantityLost,
    );

    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stock to mark that quantity as lost.')),
      );
      return;
    }
    setState(() {});
  }

  Future<void> _showDealerTakeDialog() async {
    final stockItems = widget.getStockItems().where((item) => item.currentCount > 0).toList();
    final dealers = widget.getDealers();
    if (stockItems.isEmpty || dealers.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need available stock and at least one dealer.')),
      );
      return;
    }

    String selectedStockItemId = stockItems.first.id;
    String selectedDealerId = dealers.first.id;
    final quantityController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  math.max(14, media.viewPadding.bottom + 14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Record dealer stock take', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDealerId,
                      decoration: const InputDecoration(labelText: 'Dealer'),
                      items: dealers
                          .map(
                            (dealer) => DropdownMenuItem<String>(
                              value: dealer.id,
                              child: Text('ID ${dealer.dealerNumber} - ${dealer.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDealerId = value;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStockItemId,
                      decoration: const InputDecoration(labelText: 'Stock item'),
                      items: stockItems
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                '${item.stockType} • ${item.name} (Qty: ${item.currentCount})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedStockItemId = value;
                        });
                      },
                    ),
                    TextField(
                      controller: quantityController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      scrollPadding: const EdgeInsets.only(bottom: 220),
                      decoration: const InputDecoration(labelText: 'Quantity taken'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final quantityTaken = int.tryParse(quantityController.text.trim());
    if (quantityTaken == null || quantityTaken <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity greater than 0.')),
      );
      return;
    }

    final success = await widget.onRecordDealerTake(
      dealerId: selectedDealerId,
      stockItemId: selectedStockItemId,
      quantityTaken: quantityTaken,
    );

    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record dealer take for that quantity.')),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stockItems = widget.getStockItems();
    final gifts = widget.getGiftEntries();
    final lostEntries = widget.getLostStockEntries();
    final dealerTakes = widget.getDealerTakeEntries();
    final lowItems = stockItems
        .where((item) => item.currentCount <= widget.lowStockThreshold)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            onPressed: widget.canUndoStockAction() ? widget.onUndoStockAction : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last stock action',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StockAdditionGraphsScreen(
                    additions: widget.getStockAdditions(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.show_chart),
            tooltip: 'Stock addition graphs',
          ),
          IconButton(
            onPressed: _showAddStockTypeDialog,
            icon: const Icon(Icons.category),
            tooltip: 'Add stock type',
          ),
          IconButton(
            onPressed: _showDealerTakeDialog,
            icon: const Icon(Icons.person_remove_alt_1),
            tooltip: 'Record dealer take',
          ),
        ],
      ),
      body: stockItems.isEmpty
          ? const Center(child: Text('No stock items yet. Add one with +'))
          : ListView(
              children: [
                if (lowItems.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded),
                      title: Text('Low stock alert (${lowItems.length})'),
                      subtitle: Text('Threshold: ${widget.lowStockThreshold}'),
                    ),
                  ),
                ...stockItems.map((item) {
                  final giftedCount = gifts
                      .where((gift) => gift.stockItemId == item.id)
                      .fold<int>(0, (sum, gift) => sum + gift.quantity);
                  final lostCount = lostEntries
                      .where((entry) => entry.stockItemId == item.id)
                      .fold<int>(0, (sum, entry) => sum + entry.quantity);
                  final dealerTakeCount = dealerTakes
                      .where((entry) => entry.stockItemId == item.id)
                      .fold<int>(0, (sum, entry) => sum + entry.quantity);
                  final isLow = item.currentCount <= widget.lowStockThreshold;
                  return ListTile(
                    leading: isLow ? const Icon(Icons.error_outline) : null,
                    title: Text('${item.stockType} • ${item.name} - R${item.price.toStringAsFixed(2)}'),
                    subtitle: Text(
                      'Initial: ${item.initialCount} • Current: ${item.currentCount} • Used: ${item.soldCount} • Gifted: $giftedCount • Lost: $lostCount • Dealer-taken: $dealerTakeCount${isLow ? ' • LOW' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_box_outlined),
                      tooltip: 'Add stock count',
                      onPressed: () => _showIncreaseStockDialog(item),
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLostStockDialog,
        tooltip: 'Record lost stock',
        child: const Icon(Icons.remove),
      ),
      persistentFooterButtons: [
        FilledButton.icon(
          onPressed: _showAddStockDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Stock Item'),
        ),
      ],
    );
  }
}

class StockAdditionGraphsScreen extends StatefulWidget {
  const StockAdditionGraphsScreen({super.key, required this.additions});

  final List<StockAdditionEntry> additions;

  @override
  State<StockAdditionGraphsScreen> createState() => _StockAdditionGraphsScreenState();
}

class _StockAdditionGraphsScreenState extends State<StockAdditionGraphsScreen> {
  String? _highlightedSectionId;

  String? _selectedItemForType(String stockType) {
    final sectionId = _highlightedSectionId;
    if (sectionId == null) {
      return null;
    }
    final prefix = '$stockType::';
    if (!sectionId.startsWith(prefix)) {
      return null;
    }
    return sectionId.substring(prefix.length);
  }

  void _scrollToItem(GlobalKey targetKey) {
    final targetContext = targetKey.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _highlightSection(String sectionId) {
    setState(() {
      _highlightedSectionId = sectionId;
    });

    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || _highlightedSectionId != sectionId) {
        return;
      }
      setState(() {
        _highlightedSectionId = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final byType = <String, List<StockAdditionEntry>>{};
    for (final entry in widget.additions) {
      byType.putIfAbsent(entry.stockType, () => []).add(entry);
    }

    final sortedTypes = byType.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Addition Graphs')),
      body: sortedTypes.isEmpty
          ? const Center(child: Text('No stock additions recorded yet.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: sortedTypes.map((stockType) {
                final typeEntries = byType[stockType]!..sort((a, b) => a.addedAt.compareTo(b.addedAt));
                final itemMap = <String, List<StockAdditionEntry>>{};
                for (final entry in typeEntries) {
                  itemMap.putIfAbsent(entry.itemName, () => []).add(entry);
                }

                final sortedItems = itemMap.keys.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                final itemSectionKeys = <String, GlobalKey>{
                  for (final itemName in sortedItems) itemName: GlobalKey(),
                };
                final itemTotals = <String, int>{};
                for (final itemName in sortedItems) {
                  final itemEntries = itemMap[itemName]!;
                  final total = itemEntries.fold<int>(0, (sum, entry) => sum + entry.quantityAdded);
                  itemTotals[itemName] = total;
                }

                final totalByType = itemTotals.values.fold<int>(0, (sum, value) => sum + value);
                final palette = [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.tertiary,
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                  Theme.of(context).colorScheme.tertiaryContainer,
                  Theme.of(context).colorScheme.errorContainer,
                ];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stockType),
                        if (_selectedItemForType(stockType) != null) ...[
                          const SizedBox(height: 4),
                          Text('Selected: ${_selectedItemForType(stockType)}'),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 190,
                          child: Row(
                            children: [
                              Expanded(
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {
                                        final touched = response?.touchedSection;
                                        if (touched == null) {
                                          return;
                                        }
                                        final index = touched.touchedSectionIndex;
                                        if (index < 0 || index >= sortedItems.length) {
                                          return;
                                        }
                                        final itemName = sortedItems[index];
                                        final targetKey = itemSectionKeys[itemName];
                                        if (targetKey == null) {
                                          return;
                                        }
                                        _highlightSection('$stockType::$itemName');
                                        _scrollToItem(targetKey);
                                      },
                                    ),
                                    centerSpaceRadius: 30,
                                    sectionsSpace: 2,
                                    sections: sortedItems.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final itemName = entry.value;
                                      final value = itemTotals[itemName]!.toDouble();
                                      final percentage = totalByType == 0
                                          ? 0
                                          : ((value / totalByType) * 100).round();

                                      return PieChartSectionData(
                                        value: math.max(value, 0.0001),
                                        color: palette[index % palette.length],
                                        title: '$percentage%',
                                        radius: 55,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Added: $totalByType'),
                                    const SizedBox(height: 8),
                                    ...sortedItems.map(
                                      (itemName) => Text('$itemName: ${itemTotals[itemName]}'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...sortedItems.map((itemName) {
                          final itemEntries = itemMap[itemName]!..sort((a, b) => a.addedAt.compareTo(b.addedAt));
                          final points = <FlSpot>[];
                          var cumulative = 0;
                          for (var index = 0; index < itemEntries.length; index++) {
                            cumulative += itemEntries[index].quantityAdded;
                            points.add(FlSpot(index.toDouble(), cumulative.toDouble()));
                          }
                          final totalAdded = itemEntries.fold<int>(0, (sum, entry) => sum + entry.quantityAdded);

                          return Padding(
                            key: itemSectionKeys[itemName],
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _highlightedSectionId == '$stockType::$itemName'
                                    ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.6)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$itemName • Total Added: $totalAdded'),
                                  Text('Addition events: ${itemEntries.length}'),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 140,
                                    child: LineChart(
                                      LineChartData(
                                        minY: 0,
                                        gridData: const FlGridData(show: true),
                                        lineTouchData: const LineTouchData(enabled: false),
                                        titlesData: const FlTitlesData(
                                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: points,
                                            isCurved: false,
                                            barWidth: 3,
                                            color: Theme.of(context).colorScheme.primary,
                                            dotData: const FlDotData(show: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.getCustomer,
    required this.getSalesForCustomer,
    required this.getGiftsForCustomer,
    required this.imagePassword,
    required this.dealerLabelById,
    required this.getStockItems,
    required this.getCurrentSalesDealerLabel,
    required this.getCurrentTickDealerLabel,
    required this.canEditTickStatus,
    required this.onAddTick,
    required this.onRecordSale,
    required this.onRecordGift,
    required this.onUpdateTickPaidStatus,
    required this.onCapturePhoto,
    required this.onRenameCustomer,
  });

  final String customerId;
  final Customer Function() getCustomer;
  final List<SaleEntry> Function() getSalesForCustomer;
  final List<GiftEntry> Function() getGiftsForCustomer;
  final String? imagePassword;
  final String Function(String dealerId) dealerLabelById;
  final List<StockItem> Function() getStockItems;
  final String Function() getCurrentSalesDealerLabel;
  final String Function() getCurrentTickDealerLabel;
  final bool Function(TickEntry tick) canEditTickStatus;
  final Future<String?> Function(bool isPaid, String stockItemId) onAddTick;
  final Future<String?> Function(String stockItemId) onRecordSale;
  final Future<String?> Function(String stockItemId) onRecordGift;
  final Future<bool> Function({required String tickId, required bool isPaid}) onUpdateTickPaidStatus;
  final Future<String?> Function() onCapturePhoto;
  final Future<void> Function(String name) onRenameCustomer;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late Customer _customer;
  late List<SaleEntry> _sales;
  late List<GiftEntry> _gifts;
  late String _currentSalesDealerLabel;
  late String _currentTickDealerLabel;
  Timer? _countdownTicker;
  MemoryImage? _cachedAvatarImage;
  String? _cachedAvatarPath;
  String? _cachedAvatarPassword;

  @override
  void initState() {
    super.initState();
    _customer = widget.getCustomer();
    _sales = widget.getSalesForCustomer();
    _gifts = widget.getGiftsForCustomer();
    _currentSalesDealerLabel = widget.getCurrentSalesDealerLabel();
    _currentTickDealerLabel = widget.getCurrentTickDealerLabel();
    _refreshAvatarCacheIfNeeded(force: true);
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  void _refreshData() {
    _customer = widget.getCustomer();
    _sales = widget.getSalesForCustomer();
    _gifts = widget.getGiftsForCustomer();
    _currentSalesDealerLabel = widget.getCurrentSalesDealerLabel();
    _currentTickDealerLabel = widget.getCurrentTickDealerLabel();
    _refreshAvatarCacheIfNeeded();
  }

  void _refreshAvatarCacheIfNeeded({bool force = false}) {
    final path = _customer.profileImagePath;
    final password = widget.imagePassword;
    final shouldRefresh = force || path != _cachedAvatarPath || password != _cachedAvatarPassword;
    if (!shouldRefresh) {
      return;
    }

    _cachedAvatarPath = path;
    _cachedAvatarPassword = password;
    _cachedAvatarImage = loadSecureMemoryImage(
      encryptedPath: path,
      password: password,
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekDays[local.weekday - 1]} ${local.day}/${months[local.month - 1]}/${local.year}';
  }

  Future<bool?> _showPaidPrompt({required bool initialPaid}) async {
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            math.max(14, media.viewPadding.bottom + 14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paid?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(initialPaid ? 'Current status is paid. Keep as paid?' : 'Mark this as paid?'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTickUsingCurrentDealer() async {
    final stockItems = widget.getStockItems().where((item) => item.currentCount > 0).toList();
    if (stockItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stock available. Add stock first.')),
      );
      return;
    }

    String selectedStockItemId = stockItems.first.id;
    final chosenItemId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                math.max(14, media.viewPadding.bottom + 14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select item to tick', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStockItemId,
                    decoration: const InputDecoration(labelText: 'Stock item'),
                    items: stockItems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              '${item.stockType} • ${item.name} - R${item.price.toStringAsFixed(2)} (Qty: ${item.currentCount})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedStockItemId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(selectedStockItemId),
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosenItemId == null) {
      return;
    }

    final isPaid = await _showPaidPrompt(initialPaid: false);
    if (isPaid == null) {
      return;
    }

    final dealerLabel = await widget.onAddTick(isPaid, chosenItemId);
    if (!mounted) {
      return;
    }
    if (dealerLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dealer and stock item first.')),
      );
      return;
    }

    setState(() {
      _refreshData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tick recorded for $dealerLabel')),
    );
  }

  Future<void> _recordSale() async {
    final stockItems = widget.getStockItems().where((item) => item.currentCount > 0).toList();
    if (stockItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stock available. Add stock first.')),
      );
      return;
    }

    String selectedStockItemId = stockItems.first.id;
    final chosenItemId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                math.max(14, media.viewPadding.bottom + 14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select item to sell', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStockItemId,
                    decoration: const InputDecoration(labelText: 'Stock item'),
                    items: stockItems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              '${item.name} - R${item.price.toStringAsFixed(2)} (Qty: ${item.currentCount})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedStockItemId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(selectedStockItemId),
                          child: const Text('Sell'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosenItemId == null) {
      return;
    }

    final dealerLabel = await widget.onRecordSale(chosenItemId);
    if (!mounted) {
      return;
    }
    if (dealerLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dealer and stock item first.')),
      );
      return;
    }

    setState(() {
      _refreshData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale recorded for $dealerLabel')),
    );
  }

  Future<void> _recordGift() async {
    final stockItems = widget.getStockItems().where((item) => item.currentCount > 0).toList();
    if (stockItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stock available. Add stock first.')),
      );
      return;
    }

    String selectedStockItemId = stockItems.first.id;
    final chosenItemId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                math.max(14, media.viewPadding.bottom + 14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select item to gift', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStockItemId,
                    decoration: const InputDecoration(labelText: 'Stock item'),
                    items: stockItems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              '${item.stockType} • ${item.name} - R${item.price.toStringAsFixed(2)} (Qty: ${item.currentCount})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedStockItemId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(selectedStockItemId),
                          child: const Text('Gift'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosenItemId == null) {
      return;
    }

    final dealerLabel = await widget.onRecordGift(chosenItemId);
    if (!mounted) {
      return;
    }
    if (dealerLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dealer and stock item first.')),
      );
      return;
    }

    setState(() {
      _refreshData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gift recorded for $dealerLabel')),
    );
  }

  Future<void> _renameCustomer() async {
    final name = await showNameDialog(
      context: context,
      title: 'Edit customer',
      hint: 'Customer name',
      initialValue: _customer.name,
    );
    if (name == null) {
      return;
    }
    await widget.onRenameCustomer(name);
    if (!mounted) {
      return;
    }
    setState(_refreshData);
  }

  Future<void> _onTickTap(TickEntry tick) async {
    final selectedPaid = await _showPaidPrompt(initialPaid: tick.isPaid);
    if (selectedPaid == null) {
      return;
    }

    final updated = await widget.onUpdateTickPaidStatus(tickId: tick.id, isPaid: selectedPaid);
    if (!mounted) {
      return;
    }
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tick status is permanent after 1 hour from first change.')),
      );
      return;
    }
    setState(_refreshData);
  }

  Duration _remainingEditDuration(TickEntry tick) {
    final changedAt = tick.paidStatusEditedAt;
    if (changedAt == null) {
      return const Duration(hours: 1);
    }
    final remaining = changedAt.add(const Duration(hours: 1)).difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildTickCountdown(TickEntry tick) {
    final remaining = _remainingEditDuration(tick);
    final progress = (remaining.inMilliseconds / const Duration(hours: 1).inMilliseconds).clamp(0.0, 1.0);
    final started = tick.paidStatusEditedAt != null;
    final caption = !started
        ? '1:00:00 available (starts after first status change)'
        : '${_formatCountdown(remaining)} remaining';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 4),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAvatar() {
    if (_cachedAvatarImage != null) {
      return CircleAvatar(radius: 32, backgroundImage: _cachedAvatarImage);
    }
    return CircleAvatar(radius: 32, child: Text(initialsForName(_customer.name)));
  }

  @override
  Widget build(BuildContext context) {
    final sortedTicks = [..._customer.ticks]
      ..sort((a, b) {
        if (a.isPaid != b.isPaid) {
          return a.isPaid ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    final soldItemsCount = _sales.length;
    final giftedItemsCount = _gifts.fold<int>(0, (sum, gift) => sum + gift.quantity);
    final tickedItemsCount = _customer.ticks.length;
    final soldValue = _sales.fold<double>(0, (sum, sale) => sum + sale.itemPrice);
    final giftedValue = _gifts.fold<double>(0, (sum, gift) => sum + (gift.itemPrice * gift.quantity));
    final tickedValue = _customer.ticks.fold<double>(0, (sum, tick) => sum + tick.itemPrice);

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [IconButton(onPressed: _renameCustomer, icon: const Icon(Icons.edit_outlined))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tickz count: ${_customer.tickCount}'),
                      Text('Sales count: ${_sales.length}'),
                      Text('Items sold: $soldItemsCount (R${soldValue.toStringAsFixed(2)})'),
                      Text('Items gifted: $giftedItemsCount (R${giftedValue.toStringAsFixed(2)})'),
                      Text('Items ticked: $tickedItemsCount (R${tickedValue.toStringAsFixed(2)})'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final newImagePath = await widget.onCapturePhoto();
                    if (!mounted) {
                      return;
                    }
                    if (newImagePath != null) {
                      setState(() {
                        _customer = _customer.copyWith(profileImagePath: newImagePath);
                        _sales = widget.getSalesForCustomer();
                        _refreshAvatarCacheIfNeeded(force: true);
                      });
                      return;
                    }
                    setState(_refreshData);
                  },
                  icon: const Icon(Icons.photo_camera),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Seller: $_currentSalesDealerLabel'),
                const SizedBox(height: 4),
                Text('Current Ticker: $_currentTickDealerLabel'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _recordSale,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Sell'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _recordGift,
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Gift'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 18),
          Expanded(
            child: sortedTicks.isEmpty
                ? const Center(child: Text('No ticks for this customer yet.'))
                : ListView.builder(
                    itemCount: sortedTicks.length,
                    itemBuilder: (context, index) {
                      final tick = sortedTicks[index];
                      final tickEditable = widget.canEditTickStatus(tick);
                      return ListTile(
                        title: Text('${tick.stockType} • ${tick.itemName}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${widget.dealerLabelById(tick.dealerId)} • R${tick.itemPrice.toStringAsFixed(2)}'),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.bold),
                                text: _formatDate(tick.createdAt),
                              ),
                            ),
                            _buildTickCountdown(tick),
                          ],
                        ),
                        isThreeLine: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(tick.isPaid ? 'Paid' : 'Not paid'),
                            Text(
                              tickEditable ? 'Editable' : 'Permanent',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () => _onTickTap(tick),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTickUsingCurrentDealer,
        child: const Icon(Icons.add),
      ),
    );
  }
}
