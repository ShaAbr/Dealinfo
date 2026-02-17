class Dealer {
  Dealer({
    required this.id,
    required this.dealerNumber,
    required this.name,
    this.profileImagePath,
  });

  final String id;
  final int dealerNumber;
  final String name;
  final String? profileImagePath;

  Dealer copyWith({
    String? id,
    int? dealerNumber,
    String? name,
    String? profileImagePath,
  }) {
    return Dealer(
      id: id ?? this.id,
      dealerNumber: dealerNumber ?? this.dealerNumber,
      name: name ?? this.name,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealerNumber': dealerNumber,
        'name': name,
        'profileImagePath': profileImagePath,
      };

  factory Dealer.fromJson(Map<String, dynamic> json) {
    return Dealer(
      id: json['id'] as String,
      dealerNumber: json['dealerNumber'] as int? ?? 0,
      name: json['name'] as String,
      profileImagePath: json['profileImagePath'] as String?,
    );
  }
}

class TickEntry {
  TickEntry({
    required this.id,
    required this.dealerId,
    required this.stockItemId,
    required this.itemName,
    required this.itemPrice,
    required this.stockType,
    required this.createdAt,
    required this.isPaid,
    this.paidStatusEditedAt,
  });

  final String id;
  final String dealerId;
  final String stockItemId;
  final String itemName;
  final double itemPrice;
  final String stockType;
  final DateTime createdAt;
  final bool isPaid;
  final DateTime? paidStatusEditedAt;

  TickEntry copyWith({
    String? id,
    String? dealerId,
    String? stockItemId,
    String? itemName,
    double? itemPrice,
    String? stockType,
    DateTime? createdAt,
    bool? isPaid,
    DateTime? paidStatusEditedAt,
  }) {
    return TickEntry(
      id: id ?? this.id,
      dealerId: dealerId ?? this.dealerId,
      stockItemId: stockItemId ?? this.stockItemId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      stockType: stockType ?? this.stockType,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      paidStatusEditedAt: paidStatusEditedAt ?? this.paidStatusEditedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealerId': dealerId,
      'stockItemId': stockItemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'stockType': stockType,
        'createdAt': createdAt.toIso8601String(),
        'isPaid': isPaid,
        'paidStatusEditedAt': paidStatusEditedAt?.toIso8601String(),
      };

  factory TickEntry.fromJson(Map<String, dynamic> json) {
    return TickEntry(
      id: json['id'] as String,
      dealerId: json['dealerId'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
      stockType: json['stockType'] as String? ?? 'General',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPaid: json['isPaid'] as bool? ?? false,
      paidStatusEditedAt: json['paidStatusEditedAt'] == null
          ? null
          : DateTime.parse(json['paidStatusEditedAt'] as String),
    );
  }
}

class SaleEntry {
  SaleEntry({
    required this.id,
    required this.customerId,
    required this.dealerId,
    required this.stockItemId,
    required this.itemName,
    required this.itemPrice,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String dealerId;
  final String stockItemId;
  final String itemName;
  final double itemPrice;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'dealerId': dealerId,
        'stockItemId': stockItemId,
        'itemName': itemName,
        'itemPrice': itemPrice,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SaleEntry.fromJson(Map<String, dynamic> json) {
    return SaleEntry(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      dealerId: json['dealerId'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GiftEntry {
  GiftEntry({
    required this.id,
    required this.customerId,
    required this.dealerId,
    required this.stockItemId,
    required this.itemName,
    required this.stockType,
    required this.itemPrice,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String dealerId;
  final String stockItemId;
  final String itemName;
  final String stockType;
  final double itemPrice;
  final int quantity;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'dealerId': dealerId,
        'stockItemId': stockItemId,
        'itemName': itemName,
        'stockType': stockType,
        'itemPrice': itemPrice,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GiftEntry.fromJson(Map<String, dynamic> json) {
    return GiftEntry(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      dealerId: json['dealerId'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      stockType: json['stockType'] as String? ?? 'General',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class LostStockEntry {
  LostStockEntry({
    required this.id,
    required this.stockItemId,
    required this.itemName,
    required this.stockType,
    required this.itemPrice,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String stockItemId;
  final String itemName;
  final String stockType;
  final double itemPrice;
  final int quantity;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stockItemId': stockItemId,
        'itemName': itemName,
        'stockType': stockType,
        'itemPrice': itemPrice,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LostStockEntry.fromJson(Map<String, dynamic> json) {
    return LostStockEntry(
      id: json['id'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      stockType: json['stockType'] as String? ?? 'General',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DealerTakeEntry {
  DealerTakeEntry({
    required this.id,
    required this.dealerId,
    required this.stockItemId,
    required this.itemName,
    required this.stockType,
    required this.itemPrice,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String dealerId;
  final String stockItemId;
  final String itemName;
  final String stockType;
  final double itemPrice;
  final int quantity;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealerId': dealerId,
        'stockItemId': stockItemId,
        'itemName': itemName,
        'stockType': stockType,
        'itemPrice': itemPrice,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DealerTakeEntry.fromJson(Map<String, dynamic> json) {
    return DealerTakeEntry(
      id: json['id'] as String,
      dealerId: json['dealerId'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      stockType: json['stockType'] as String? ?? 'General',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class StockItem {
  StockItem({
    required this.id,
    required this.stockType,
    required this.name,
    required this.price,
    required this.initialCount,
    required this.currentCount,
  });

  final String id;
  final String stockType;
  final String name;
  final double price;
  final int initialCount;
  final int currentCount;

  int get soldCount {
    final sold = initialCount - currentCount;
    if (sold < 0) {
      return 0;
    }
    return sold;
  }

  StockItem copyWith({
    String? id,
    String? stockType,
    String? name,
    double? price,
    int? initialCount,
    int? currentCount,
  }) {
    return StockItem(
      id: id ?? this.id,
      stockType: stockType ?? this.stockType,
      name: name ?? this.name,
      price: price ?? this.price,
      initialCount: initialCount ?? this.initialCount,
      currentCount: currentCount ?? this.currentCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
      'stockType': stockType,
        'name': name,
        'price': price,
        'initialCount': initialCount,
        'currentCount': currentCount,
      };

  factory StockItem.fromJson(Map<String, dynamic> json) {
    final currentCount = json['currentCount'] as int?;
    final initialCount = json['initialCount'] as int? ?? 0;
    return StockItem(
      id: json['id'] as String,
      stockType: json['stockType'] as String? ?? 'General',
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      initialCount: initialCount,
      currentCount: currentCount ?? initialCount,
    );
  }
}

class StockAdditionEntry {
  StockAdditionEntry({
    required this.id,
    required this.stockItemId,
    required this.stockType,
    required this.itemName,
    required this.quantityAdded,
    required this.addedAt,
  });

  final String id;
  final String stockItemId;
  final String stockType;
  final String itemName;
  final int quantityAdded;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stockItemId': stockItemId,
        'stockType': stockType,
        'itemName': itemName,
        'quantityAdded': quantityAdded,
        'addedAt': addedAt.toIso8601String(),
      };

  factory StockAdditionEntry.fromJson(Map<String, dynamic> json) {
    return StockAdditionEntry(
      id: json['id'] as String,
      stockItemId: json['stockItemId'] as String? ?? '',
      stockType: json['stockType'] as String? ?? 'General',
      itemName: json['itemName'] as String? ?? 'Unknown item',
      quantityAdded: json['quantityAdded'] as int? ?? 0,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.profileImagePath,
    required this.ticks,
  });

  final String id;
  final String name;
  final String? profileImagePath;
  final List<TickEntry> ticks;

  int get tickCount => ticks.length;

  Customer copyWith({
    String? id,
    String? name,
    String? profileImagePath,
    List<TickEntry>? ticks,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      ticks: ticks ?? this.ticks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profileImagePath': profileImagePath,
        'ticks': ticks.map((tick) => tick.toJson()).toList(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final rawTicks = (json['ticks'] as List<dynamic>? ?? []);
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      profileImagePath: json['profileImagePath'] as String?,
      ticks: rawTicks
          .map((tickJson) => TickEntry.fromJson(tickJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AppSettings {
  AppSettings({
    this.backgroundImagePath,
    this.password,
    this.lowStockThreshold = 5,
  });

  final String? backgroundImagePath;
  final String? password;
  final int lowStockThreshold;

  AppSettings copyWith({
    String? backgroundImagePath,
    String? password,
    int? lowStockThreshold,
  }) {
    return AppSettings(
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      password: password ?? this.password,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'backgroundImagePath': backgroundImagePath,
        'password': password,
        'lowStockThreshold': lowStockThreshold,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawThreshold = json['lowStockThreshold'] as int?;
    final normalizedThreshold = rawThreshold == null || rawThreshold < 1 ? 5 : rawThreshold;
    return AppSettings(
      backgroundImagePath: json['backgroundImagePath'] as String?,
      password: json['password'] as String?,
      lowStockThreshold: normalizedThreshold,
    );
  }
}

class AppData {
  AppData({
    required this.dealers,
    required this.customers,
    required this.sales,
    required this.gifts,
    required this.lostStock,
    required this.dealerTakes,
    required this.stockTypes,
    required this.stockItems,
    required this.stockAdditions,
    required this.settings,
    this.currentSalesDealerId,
    this.currentTickDealerId,
  });

  final List<Dealer> dealers;
  final List<Customer> customers;
  final List<SaleEntry> sales;
  final List<GiftEntry> gifts;
  final List<LostStockEntry> lostStock;
  final List<DealerTakeEntry> dealerTakes;
  final List<String> stockTypes;
  final List<StockItem> stockItems;
  final List<StockAdditionEntry> stockAdditions;
  final AppSettings settings;
  final String? currentSalesDealerId;
  final String? currentTickDealerId;

  factory AppData.empty() => AppData(
        dealers: [],
        customers: [],
        sales: [],
        gifts: [],
        lostStock: [],
        dealerTakes: [],
        stockTypes: [],
        stockItems: [],
        stockAdditions: [],
        settings: AppSettings(),
      );

  AppData copyWith({
    List<Dealer>? dealers,
    List<Customer>? customers,
    List<SaleEntry>? sales,
    List<GiftEntry>? gifts,
    List<LostStockEntry>? lostStock,
    List<DealerTakeEntry>? dealerTakes,
    List<String>? stockTypes,
    List<StockItem>? stockItems,
    List<StockAdditionEntry>? stockAdditions,
    AppSettings? settings,
    String? currentSalesDealerId,
    String? currentTickDealerId,
  }) {
    return AppData(
      dealers: dealers ?? this.dealers,
      customers: customers ?? this.customers,
      sales: sales ?? this.sales,
      gifts: gifts ?? this.gifts,
      lostStock: lostStock ?? this.lostStock,
      dealerTakes: dealerTakes ?? this.dealerTakes,
      stockTypes: stockTypes ?? this.stockTypes,
      stockItems: stockItems ?? this.stockItems,
      stockAdditions: stockAdditions ?? this.stockAdditions,
      settings: settings ?? this.settings,
      currentSalesDealerId: currentSalesDealerId ?? this.currentSalesDealerId,
      currentTickDealerId: currentTickDealerId ?? this.currentTickDealerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'dealers': dealers.map((dealer) => dealer.toJson()).toList(),
        'customers': customers.map((customer) => customer.toJson()).toList(),
        'sales': sales.map((sale) => sale.toJson()).toList(),
        'gifts': gifts.map((gift) => gift.toJson()).toList(),
        'lostStock': lostStock.map((entry) => entry.toJson()).toList(),
        'dealerTakes': dealerTakes.map((entry) => entry.toJson()).toList(),
        'stockTypes': stockTypes,
        'stockItems': stockItems.map((item) => item.toJson()).toList(),
        'stockAdditions': stockAdditions.map((entry) => entry.toJson()).toList(),
        'settings': settings.toJson(),
        'currentSalesDealerId': currentSalesDealerId,
        'currentTickDealerId': currentTickDealerId,
      };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final rawDealers = (json['dealers'] as List<dynamic>? ?? []);
    final rawCustomers = (json['customers'] as List<dynamic>? ?? []);
    final rawSales = (json['sales'] as List<dynamic>? ?? []);
    final rawGifts = (json['gifts'] as List<dynamic>? ?? []);
    final rawLostStock = (json['lostStock'] as List<dynamic>? ?? []);
    final rawDealerTakes = (json['dealerTakes'] as List<dynamic>? ?? []);
    final rawStockTypes = (json['stockTypes'] as List<dynamic>? ?? []);
    final rawStockItems = (json['stockItems'] as List<dynamic>? ?? []);
    final rawStockAdditions = (json['stockAdditions'] as List<dynamic>? ?? []);
    final rawSettings = json['settings'] as Map<String, dynamic>?;

    final dealers = rawDealers
        .map((dealerJson) => Dealer.fromJson(dealerJson as Map<String, dynamic>))
        .toList();

    var normalizedDealers = dealers;
    final hasMissingDealerNumbers =
        normalizedDealers.any((dealer) => dealer.dealerNumber <= 0);
    if (hasMissingDealerNumbers) {
      normalizedDealers = [...normalizedDealers]
        ..sort((a, b) => a.name.compareTo(b.name));
      for (var index = 0; index < normalizedDealers.length; index++) {
        normalizedDealers[index] = normalizedDealers[index].copyWith(
          dealerNumber: index + 1,
        );
      }
    }

    final stockItems = rawStockItems
      .map((itemJson) => StockItem.fromJson(itemJson as Map<String, dynamic>))
      .toList();
    final gifts = rawGifts
      .map((giftJson) => GiftEntry.fromJson(giftJson as Map<String, dynamic>))
      .toList();
    final lostStock = rawLostStock
      .map((lostJson) => LostStockEntry.fromJson(lostJson as Map<String, dynamic>))
      .toList();
    final dealerTakes = rawDealerTakes
      .map((takeJson) => DealerTakeEntry.fromJson(takeJson as Map<String, dynamic>))
      .toList();

    final stockTypes = {
      ...rawStockTypes.map((entry) => entry.toString()),
      ...stockItems.map((item) => item.stockType),
      ...gifts.map((entry) => entry.stockType),
      ...lostStock.map((entry) => entry.stockType),
      ...dealerTakes.map((entry) => entry.stockType),
    }.where((entry) => entry.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return AppData(
      dealers: normalizedDealers,
      customers: rawCustomers
          .map((customerJson) =>
              Customer.fromJson(customerJson as Map<String, dynamic>))
          .toList(),
      sales: rawSales
          .map((saleJson) => SaleEntry.fromJson(saleJson as Map<String, dynamic>))
          .toList(),
        gifts: gifts,
        lostStock: lostStock,
        dealerTakes: dealerTakes,
      stockTypes: stockTypes,
      stockItems: stockItems,
        stockAdditions: rawStockAdditions
          .map((entryJson) => StockAdditionEntry.fromJson(entryJson as Map<String, dynamic>))
          .toList(),
      settings:
          rawSettings == null ? AppSettings() : AppSettings.fromJson(rawSettings),
      currentSalesDealerId: json['currentSalesDealerId'] as String?,
      currentTickDealerId: json['currentTickDealerId'] as String?,
    );
  }
}
