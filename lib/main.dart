import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypted;
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.bold),
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
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          obscureText: obscureText,
          decoration: InputDecoration(hintText: hint),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(value.trim()),
            child: Text(confirmLabel),
          ),
        ],
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Dealers'),
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

  List<_HistoryEvent> _eventsForCustomer(Customer customer) {
    final events = <_HistoryEvent>[];

    final sales = widget.data.sales.where((sale) => sale.customerId == customer.id);
    for (final sale in sales) {
      events.add(
        _HistoryEvent(
          type: 'Sale',
          date: sale.createdAt,
          detail: widget.dealerLabel(sale.dealerId),
        ),
      );
    }

    for (final tick in customer.ticks) {
      events.add(
        _HistoryEvent(
          type: tick.isPaid ? 'Tick (Paid)' : 'Tick (Not paid)',
          date: tick.createdAt,
          detail: widget.dealerLabel(tick.dealerId),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
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
        ),
        Expanded(
          child: ListView.builder(
      itemCount: widget.data.customers.length,
      itemBuilder: (context, index) {
        final customer = widget.data.customers[index];
        final customerSales = widget.data.sales.where((sale) => sale.customerId == customer.id).length;
        final customerTicks = customer.ticks.length;
        final events = _eventsForCustomer(customer);

        return ExpansionTile(
          title: Text(customer.name),
          subtitle: Text('Sales: $customerSales • Ticks: $customerTicks'),
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

  List<_HistoryEvent> _eventsForDealer(Dealer dealer) {
    final events = <_HistoryEvent>[];

    for (final sale in widget.data.sales.where((entry) => entry.dealerId == dealer.id)) {
      final customer = widget.data.customers.where((entry) => entry.id == sale.customerId).toList();
      final customerName = customer.isEmpty ? 'Unknown customer' : customer.first.name;
      events.add(
        _HistoryEvent(
          type: 'Sale',
          date: sale.createdAt,
          detail: customerName,
        ),
      );
    }

    for (final customer in widget.data.customers) {
      for (final tick in customer.ticks.where((entry) => entry.dealerId == dealer.id)) {
        events.add(
          _HistoryEvent(
            type: tick.isPaid ? 'Tick (Paid)' : 'Tick (Not paid)',
            date: tick.createdAt,
            detail: customer.name,
          ),
        );
      }
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
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
        ),
        Expanded(
          child: ListView.builder(
      itemCount: dealers.length,
      itemBuilder: (context, index) {
        final dealer = dealers[index];
        final salesCount = widget.data.sales.where((sale) => sale.dealerId == dealer.id).length;
        final tickCount = widget.data.customers
            .map((customer) => customer.ticks.where((tick) => tick.dealerId == dealer.id).length)
            .fold(0, (sum, value) => sum + value);
        final events = _eventsForDealer(dealer);

        return ExpansionTile(
          title: Text(widget.dealerLabel(dealer.id)),
          subtitle: Text('Sales: $salesCount • Ticks: $tickCount'),
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
    if (usedInTicks || usedInSales) {
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

  Future<String?> _recordSale(String customerId) async {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
      return null;
    }

    final activeDealer = _dealerById(_data.currentSalesDealerId) ?? dealers.first;
    final nextId = _nextDealerIdAfter(activeDealer.id) ?? activeDealer.id;

    final sale = SaleEntry(
      id: _uuid.v4(),
      customerId: customerId,
      dealerId: activeDealer.id,
      createdAt: DateTime.now(),
    );

    setState(() {
      _data = _data.copyWith(
        sales: [..._data.sales, sale],
        currentSalesDealerId: nextId,
      );
    });
    await _save();
    return _dealerLabelById(activeDealer.id);
  }

  Future<String?> _recordTick(String customerId, bool isPaid) async {
    final dealers = _sortedDealers(_data.dealers);
    if (dealers.isEmpty) {
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
          createdAt: DateTime.now(),
          isPaid: isPaid,
        ),
      ],
    );

    final updatedCustomers = [..._data.customers];
    updatedCustomers[customerIndex] = updatedCustomer;

    setState(() {
      _data = _data.copyWith(
        customers: updatedCustomers,
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
                                imagePassword: _data.settings.password,
                                dealerLabelById: _dealerLabelById,
                                getCurrentSalesDealerLabel: _currentSalesDealerLabel,
                                getCurrentTickDealerLabel: _currentTickDealerLabel,
                                canEditTickStatus: _canEditTickStatus,
                                onAddTick: (isPaid) => _recordTick(customer.id, isPaid),
                                onRecordSale: () => _recordSale(customer.id),
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
    required this.imagePassword,
    required this.onAddDealer,
    required this.onEditDealer,
    required this.onCaptureDealerPhoto,
    required this.onRemoveDealer,
  });

  final List<Dealer> Function() getDealers;
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
      appBar: AppBar(title: const Text('Dealers')),
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
                                content: Text('Dealer cannot be removed if sales/ticks exist.'),
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

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.getCustomer,
    required this.getSalesForCustomer,
    required this.imagePassword,
    required this.dealerLabelById,
    required this.getCurrentSalesDealerLabel,
    required this.getCurrentTickDealerLabel,
    required this.canEditTickStatus,
    required this.onAddTick,
    required this.onRecordSale,
    required this.onUpdateTickPaidStatus,
    required this.onCapturePhoto,
    required this.onRenameCustomer,
  });

  final String customerId;
  final Customer Function() getCustomer;
  final List<SaleEntry> Function() getSalesForCustomer;
  final String? imagePassword;
  final String Function(String dealerId) dealerLabelById;
  final String Function() getCurrentSalesDealerLabel;
  final String Function() getCurrentTickDealerLabel;
  final bool Function(TickEntry tick) canEditTickStatus;
  final Future<String?> Function(bool isPaid) onAddTick;
  final Future<String?> Function() onRecordSale;
  final Future<bool> Function({required String tickId, required bool isPaid}) onUpdateTickPaidStatus;
  final Future<String?> Function() onCapturePhoto;
  final Future<void> Function(String name) onRenameCustomer;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late Customer _customer;
  late List<SaleEntry> _sales;
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
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paid?'),
          content: Text(initialPaid ? 'Current status is paid. Keep as paid?' : 'Mark this as paid?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
          ],
        );
      },
    );
  }

  Future<void> _addTickUsingCurrentDealer() async {
    final isPaid = await _showPaidPrompt(initialPaid: false);
    if (isPaid == null) {
      return;
    }

    final dealerLabel = await widget.onAddTick(isPaid);
    if (!mounted) {
      return;
    }
    if (dealerLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dealer first.')),
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
    final dealerLabel = await widget.onRecordSale();
    if (!mounted) {
      return;
    }
    if (dealerLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dealer first.')),
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
                        title: Text(widget.dealerLabelById(tick.dealerId)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
