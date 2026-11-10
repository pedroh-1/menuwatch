import 'dart:math';

/// Formato do conteúdo de onde o cardápio foi lido.
enum SourceType {
  html('Site'),
  dynamicPage('Site dinâmico'),
  canva('Canva'),
  pdf('PDF'),
  image('Imagem');

  const SourceType(this.label);
  final String label;

  /// Fontes que precisam de um navegador para serem lidas e, por isso,
  /// só podem ser verificadas com o app aberto.
  bool get needsBrowser => this == dynamicPage || this == canva;
}

/// O que se sabe sobre um prato estar sendo servido agora.
enum Availability {
  /// O cardápio é do dia (ou o prato está na seção de hoje).
  confirmed('Disponível hoje'),

  /// O cardápio marca o prato como esgotado ou indisponível.
  unavailable('Indisponível'),

  /// O prato está no cardápio, mas nada indica que é servido hoje.
  unknown('Disponibilidade não identificada');

  const Availability(this.label);
  final String label;
}

enum ChangeType {
  added('Novo prato'),
  removed('Prato removido'),
  price('Preço alterado'),
  availability('Disponibilidade alterada'),
  returned('Prato voltou');

  const ChangeType(this.label);
  final String label;
}

enum NotificationKind { favorite, menuChanged, error }

enum MenuStatus { ok, error, waitingApp }

String newId() {
  final r = Random.secure();
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final s = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$t$s';
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

class Dish {
  Dish({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.category = 'Cardápio',
    this.availability = Availability.unknown,
    this.favorite = false,
    this.present = true,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) : firstSeenAt = firstSeenAt ?? DateTime.now(),
       lastSeenAt = lastSeenAt ?? DateTime.now();

  final String id;
  final String name;
  final String? description;
  final double? price;
  final String category;
  final Availability availability;

  /// Prato acompanhado: gera aviso quando aparece ou fica disponível.
  final bool favorite;

  /// Falso quando o prato saiu do cardápio. Só favoritos são mantidos
  /// nessa condição, para que a volta deles possa ser avisada.
  final bool present;

  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  bool get availableNow => present && availability == Availability.confirmed;

  Dish copyWith({
    String? name,
    String? description,
    double? price,
    bool clearPrice = false,
    String? category,
    Availability? availability,
    bool? favorite,
    bool? present,
    DateTime? lastSeenAt,
  }) => Dish(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: clearPrice ? null : (price ?? this.price),
    category: category ?? this.category,
    availability: availability ?? this.availability,
    favorite: favorite ?? this.favorite,
    present: present ?? this.present,
    firstSeenAt: firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'availability': availability.name,
    'favorite': favorite,
    'present': present,
    'firstSeenAt': firstSeenAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
  };

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    price: (j['price'] as num?)?.toDouble(),
    category: j['category'] as String? ?? 'Cardápio',
    availability: _enumByName(
      Availability.values,
      j['availability'],
      Availability.unknown,
    ),
    favorite: j['favorite'] as bool? ?? false,
    present: j['present'] as bool? ?? true,
    firstSeenAt: _date(j['firstSeenAt']),
    lastSeenAt: _date(j['lastSeenAt']),
  );
}

class Menu {
  Menu({
    required this.id,
    required this.name,
    required this.url,
    required this.sourceType,
    this.dishes = const [],
    this.favorite = false,
    this.status = MenuStatus.ok,
    this.lastError,
    this.referenceDate,
    DateTime? createdAt,
    this.lastCheckedAt,
    this.lastChangedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String url;
  final SourceType sourceType;
  final List<Dish> dishes;
  final bool favorite;
  final MenuStatus status;
  final String? lastError;

  /// Data a que o cardápio se refere, quando o próprio cardápio informa.
  final DateTime? referenceDate;

  final DateTime createdAt;
  final DateTime? lastCheckedAt;
  final DateTime? lastChangedAt;

  List<Dish> get presentDishes => dishes.where((d) => d.present).toList();

  Menu copyWith({
    String? name,
    String? url,
    SourceType? sourceType,
    List<Dish>? dishes,
    bool? favorite,
    MenuStatus? status,
    String? lastError,
    bool clearError = false,
    DateTime? referenceDate,
    bool clearReferenceDate = false,
    DateTime? lastCheckedAt,
    DateTime? lastChangedAt,
  }) => Menu(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    sourceType: sourceType ?? this.sourceType,
    dishes: dishes ?? this.dishes,
    favorite: favorite ?? this.favorite,
    status: status ?? this.status,
    lastError: clearError ? null : (lastError ?? this.lastError),
    referenceDate: clearReferenceDate
        ? null
        : (referenceDate ?? this.referenceDate),
    createdAt: createdAt,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    lastChangedAt: lastChangedAt ?? this.lastChangedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'sourceType': sourceType.name,
    'dishes': dishes.map((d) => d.toJson()).toList(),
    'favorite': favorite,
    'status': status.name,
    'lastError': lastError,
    'referenceDate': referenceDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    'lastChangedAt': lastChangedAt?.toIso8601String(),
  };

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
    id: j['id'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    sourceType: _enumByName(SourceType.values, j['sourceType'], SourceType.html),
    dishes: [
      for (final d in (j['dishes'] as List? ?? const []))
        Dish.fromJson(Map<String, dynamic>.from(d as Map)),
    ],
    favorite: j['favorite'] as bool? ?? false,
    status: _enumByName(MenuStatus.values, j['status'], MenuStatus.ok),
    lastError: j['lastError'] as String?,
    referenceDate: _date(j['referenceDate']),
    createdAt: _date(j['createdAt']),
    lastCheckedAt: _date(j['lastCheckedAt']),
    lastChangedAt: _date(j['lastChangedAt']),
  );
}

/// Uma alteração detectada entre duas leituras do mesmo cardápio.
class ChangeEntry {
  ChangeEntry({
    required this.id,
    required this.menuId,
    required this.dishName,
    required this.type,
    required this.description,
    this.dishId,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  final String id;
  final String menuId;
  final String? dishId;
  final String dishName;
  final ChangeType type;
  final String description;
  final DateTime detectedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'menuId': menuId,
    'dishId': dishId,
    'dishName': dishName,
    'type': type.name,
    'description': description,
    'detectedAt': detectedAt.toIso8601String(),
  };

  factory ChangeEntry.fromJson(Map<String, dynamic> j) => ChangeEntry(
    id: j['id'] as String,
    menuId: j['menuId'] as String,
    dishId: j['dishId'] as String?,
    dishName: j['dishName'] as String? ?? '',
    type: _enumByName(ChangeType.values, j['type'], ChangeType.added),
    description: j['description'] as String? ?? '',
    detectedAt: _date(j['detectedAt']),
  );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    this.menuId,
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String message;
  final NotificationKind kind;
  final String? menuId;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    message: message,
    kind: kind,
    menuId: menuId,
    read: read ?? this.read,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'kind': kind.name,
    'menuId': menuId,
    'read': read,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    message: j['message'] as String? ?? '',
    kind: _enumByName(
      NotificationKind.values,
      j['kind'],
      NotificationKind.menuChanged,
    ),
    menuId: j['menuId'] as String?,
    read: j['read'] as bool? ?? false,
    createdAt: _date(j['createdAt']),
  );
}

enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.userName = '',
    this.themeMode = AppThemeMode.system,
    this.frequencyMinutes = 60,
    this.notifyFavorites = true,
    this.notifyMenuChanges = true,
    this.notifyPriceChanges = true,
    this.onboarded = false,
  });

  final String userName;
  final AppThemeMode themeMode;

  /// Intervalo entre verificações automáticas. O Android não aceita menos
  /// que 15 minutos.
  final int frequencyMinutes;

  final bool notifyFavorites;
  final bool notifyMenuChanges;
  final bool notifyPriceChanges;

  /// Verdadeiro depois que a permissão de notificações já foi pedida.
  final bool onboarded;

  static const frequencyOptions = [15, 30, 60, 180, 360, 720, 1440];

  AppSettings copyWith({
    String? userName,
    AppThemeMode? themeMode,
    int? frequencyMinutes,
    bool? notifyFavorites,
    bool? notifyMenuChanges,
    bool? notifyPriceChanges,
    bool? onboarded,
  }) => AppSettings(
    userName: userName ?? this.userName,
    themeMode: themeMode ?? this.themeMode,
    frequencyMinutes: frequencyMinutes ?? this.frequencyMinutes,
    notifyFavorites: notifyFavorites ?? this.notifyFavorites,
    notifyMenuChanges: notifyMenuChanges ?? this.notifyMenuChanges,
    notifyPriceChanges: notifyPriceChanges ?? this.notifyPriceChanges,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'themeMode': themeMode.name,
    'frequencyMinutes': frequencyMinutes,
    'notifyFavorites': notifyFavorites,
    'notifyMenuChanges': notifyMenuChanges,
    'notifyPriceChanges': notifyPriceChanges,
    'onboarded': onboarded,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    userName: j['userName'] as String? ?? '',
    themeMode: _enumByName(
      AppThemeMode.values,
      j['themeMode'],
      AppThemeMode.system,
    ),
    frequencyMinutes: j['frequencyMinutes'] as int? ?? 60,
    notifyFavorites: j['notifyFavorites'] as bool? ?? true,
    notifyMenuChanges: j['notifyMenuChanges'] as bool? ?? true,
    notifyPriceChanges: j['notifyPriceChanges'] as bool? ?? true,
    onboarded: j['onboarded'] as bool? ?? false,
  );
}

/// Tudo o que o app guarda, em um único documento.
class AppData {
  const AppData({
    this.menus = const [],
    this.history = const [],
    this.notifications = const [],
    this.settings = const AppSettings(),
  });

  final List<Menu> menus;
  final List<ChangeEntry> history;
  final List<AppNotification> notifications;
  final AppSettings settings;

  int get unreadCount => notifications.where((n) => !n.read).length;

  Menu? menuById(String id) {
    for (final m in menus) {
      if (m.id == id) return m;
    }
    return null;
  }

  AppData copyWith({
    List<Menu>? menus,
    List<ChangeEntry>? history,
    List<AppNotification>? notifications,
    AppSettings? settings,
  }) => AppData(
    menus: menus ?? this.menus,
    history: history ?? this.history,
    notifications: notifications ?? this.notifications,
    settings: settings ?? this.settings,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'menus': menus.map((m) => m.toJson()).toList(),
    'history': history.map((h) => h.toJson()).toList(),
    'notifications': notifications.map((n) => n.toJson()).toList(),
    'settings': settings.toJson(),
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    menus: [
      for (final m in (j['menus'] as List? ?? const []))
        Menu.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    history: [
      for (final h in (j['history'] as List? ?? const []))
        ChangeEntry.fromJson(Map<String, dynamic>.from(h as Map)),
    ],
    notifications: [
      for (final n in (j['notifications'] as List? ?? const []))
        AppNotification.fromJson(Map<String, dynamic>.from(n as Map)),
    ],
    settings: j['settings'] is Map
        ? AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map))
        : const AppSettings(),
  );
}
