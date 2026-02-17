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
    required this.createdAt,
    required this.isPaid,
    this.paidStatusEditedAt,
  });

  final String id;
  final String dealerId;
  final DateTime createdAt;
  final bool isPaid;
  final DateTime? paidStatusEditedAt;

  TickEntry copyWith({
    String? id,
    String? dealerId,
    DateTime? createdAt,
    bool? isPaid,
    DateTime? paidStatusEditedAt,
  }) {
    return TickEntry(
      id: id ?? this.id,
      dealerId: dealerId ?? this.dealerId,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      paidStatusEditedAt: paidStatusEditedAt ?? this.paidStatusEditedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dealerId': dealerId,
        'createdAt': createdAt.toIso8601String(),
        'isPaid': isPaid,
        'paidStatusEditedAt': paidStatusEditedAt?.toIso8601String(),
      };

  factory TickEntry.fromJson(Map<String, dynamic> json) {
    return TickEntry(
      id: json['id'] as String,
      dealerId: json['dealerId'] as String,
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
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String dealerId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'dealerId': dealerId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SaleEntry.fromJson(Map<String, dynamic> json) {
    return SaleEntry(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      dealerId: json['dealerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
  });

  final String? backgroundImagePath;
  final String? password;

  AppSettings copyWith({
    String? backgroundImagePath,
    String? password,
  }) {
    return AppSettings(
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'backgroundImagePath': backgroundImagePath,
        'password': password,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backgroundImagePath: json['backgroundImagePath'] as String?,
      password: json['password'] as String?,
    );
  }
}

class AppData {
  AppData({
    required this.dealers,
    required this.customers,
    required this.sales,
    required this.settings,
    this.currentSalesDealerId,
    this.currentTickDealerId,
  });

  final List<Dealer> dealers;
  final List<Customer> customers;
  final List<SaleEntry> sales;
  final AppSettings settings;
  final String? currentSalesDealerId;
  final String? currentTickDealerId;

  factory AppData.empty() => AppData(
        dealers: [],
        customers: [],
        sales: [],
        settings: AppSettings(),
      );

  AppData copyWith({
    List<Dealer>? dealers,
    List<Customer>? customers,
    List<SaleEntry>? sales,
    AppSettings? settings,
    String? currentSalesDealerId,
    String? currentTickDealerId,
  }) {
    return AppData(
      dealers: dealers ?? this.dealers,
      customers: customers ?? this.customers,
      sales: sales ?? this.sales,
      settings: settings ?? this.settings,
      currentSalesDealerId: currentSalesDealerId ?? this.currentSalesDealerId,
      currentTickDealerId: currentTickDealerId ?? this.currentTickDealerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'dealers': dealers.map((dealer) => dealer.toJson()).toList(),
        'customers': customers.map((customer) => customer.toJson()).toList(),
        'sales': sales.map((sale) => sale.toJson()).toList(),
        'settings': settings.toJson(),
        'currentSalesDealerId': currentSalesDealerId,
        'currentTickDealerId': currentTickDealerId,
      };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final rawDealers = (json['dealers'] as List<dynamic>? ?? []);
    final rawCustomers = (json['customers'] as List<dynamic>? ?? []);
    final rawSales = (json['sales'] as List<dynamic>? ?? []);
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

    return AppData(
      dealers: normalizedDealers,
      customers: rawCustomers
          .map((customerJson) =>
              Customer.fromJson(customerJson as Map<String, dynamic>))
          .toList(),
      sales: rawSales
          .map((saleJson) => SaleEntry.fromJson(saleJson as Map<String, dynamic>))
          .toList(),
      settings:
          rawSettings == null ? AppSettings() : AppSettings.fromJson(rawSettings),
      currentSalesDealerId: json['currentSalesDealerId'] as String?,
      currentTickDealerId: json['currentTickDealerId'] as String?,
    );
  }
}
