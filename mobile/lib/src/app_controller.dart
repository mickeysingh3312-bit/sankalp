import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'notification_service.dart';
import 'purchase_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.notifications, required this.purchases});

  static const freeGoals = [108, 216, 501, 1100];
  static const _storageKey = 'sankalp_state_v1';
  static const _tokenKey = 'api_token';

  final NotificationService notifications;
  final PurchaseService purchases;
  final ApiClient api = ApiClient();
  final _secure = const FlutterSecureStorage();

  late SharedPreferences _prefs;
  String date = _today();
  String mantraId = mantras.first.id;
  String customMantra = '';
  int goal = 108;
  int count = 0;
  int tapCount = 0;
  int malaCount = 0;
  int writeCount = 0;
  int streak = 0;
  int bestStreak = 0;
  String theme = 'auto';
  bool vibrate = true;
  bool tapSound = true;
  bool reminderEnabled = false;
  int reminderHour = 7;
  int reminderMinute = 0;
  DateTime? premiumUntil;
  String? userEmail;
  String? userName;
  final List<DailyRecord> history = [];
  String? message;
  bool busy = false;
  bool storeReady = false;

  bool get signedIn => api.token != null;
  bool get isPremium =>
      premiumUntil != null && premiumUntil!.toUtc().isAfter(DateTime.now().toUtc());
  Mantra get mantra => mantras.firstWhere(
        (item) => item.id == mantraId,
        orElse: () => mantras.first,
      );
  String get mantraText => mantraId == 'custom' && customMantra.trim().isNotEmpty
      ? customMantra.trim()
      : mantra.hindi;
  double get progress => goal == 0 ? 0 : min(1, count / goal);
  int get completedMalas => count ~/ 108;
  int get currentBead => count % 108;
  int get lifetime => history.fold<int>(0, (sum, row) => sum + row.total) + count;
  int get monthlyCount {
    final prefix = DateFormat('yyyy-MM').format(DateTime.now());
    return history
            .where((row) => row.date.startsWith(prefix))
            .fold<int>(0, (sum, row) => sum + row.total) +
        count;
  }

  ThemeMode get themeMode => switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLocal();
    _rollDateIfNeeded();
    try {
      api.token = await _secure
          .read(key: _tokenKey)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      api.token = null;
    }
    try {
      storeReady = await purchases
          .initialize(_verifyPurchase)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      storeReady = false;
    }
    if (signedIn) await refreshAccount(silent: true);
    notifyListeners();
  }

  void increment(JapMode mode) {
    _rollDateIfNeeded();
    count++;
    switch (mode) {
      case JapMode.tap:
        tapCount++;
      case JapMode.mala:
        malaCount++;
      case JapMode.write:
        writeCount++;
    }
    _saveLocal();
    notifyListeners();
  }

  void selectMantra(String id, {String? custom}) {
    final nextCustom = custom?.trim();
    final changed = mantraId != id ||
        (id == 'custom' && nextCustom != null && nextCustom != customMantra.trim());
    mantraId = id;
    if (nextCustom != null) customMantra = nextCustom;
    if (changed) {
      count = 0;
      tapCount = 0;
      malaCount = 0;
      writeCount = 0;
    }
    _saveAndNotify();
  }

  bool selectGoal(int value) {
    if (!isPremium && !freeGoals.contains(value)) return false;
    goal = max(1, value);
    _saveAndNotify();
    return true;
  }

  void setTheme(String value) {
    theme = value;
    _saveAndNotify();
  }

  void setVibration(bool value) {
    vibrate = value;
    _saveAndNotify();
  }

  void setTapSound(bool value) {
    tapSound = value;
    _saveAndNotify();
  }

  Future<void> setReminder(bool enabled, {int? hour, int? minute}) async {
    reminderEnabled = enabled;
    reminderHour = hour ?? reminderHour;
    reminderMinute = minute ?? reminderMinute;
    if (enabled) {
      await notifications.scheduleDaily(reminderHour, reminderMinute);
    } else {
      await notifications.cancelDaily();
    }
    _saveAndNotify();
  }

  Future<void> register(String name, String email, String password) async {
    await _accountAction('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<void> login(String email, String password) async {
    await _accountAction('/auth/login', {'email': email, 'password': password});
  }

  Future<void> _accountAction(String path, Map<String, dynamic> payload) async {
    await _run(() async {
      final response = await api.post(path, payload);
      await _acceptSession(response);
      await sync();
    });
  }

  Future<void> _acceptSession(Map<String, dynamic> response) async {
    api.token = response['token'] as String;
    await _secure.write(key: _tokenKey, value: api.token);
    final user = response['user'] as Map<String, dynamic>;
    userEmail = user['email'] as String?;
    userName = user['name'] as String?;
    _applyPremium(user['premium_until']?.toString());
    _saveLocal();
  }

  Future<void> logout() async {
    api.token = null;
    userEmail = null;
    userName = null;
    premiumUntil = null;
    await _secure.delete(key: _tokenKey);
    _saveAndNotify();
  }

  Future<void> refreshAccount({bool silent = false}) async {
    if (!signedIn || !api.configured) return;
    try {
      final response = await api.post('/me', {});
      final user = response['user'] as Map<String, dynamic>;
      userEmail = user['email'] as String?;
      userName = user['name'] as String?;
      _applyPremium(user['premium_until']?.toString());
      _saveLocal();
    } catch (error) {
      if (!silent) message = error.toString();
    }
    notifyListeners();
  }

  Future<void> sync() async {
    if (!signedIn) throw const ApiException('Sign in to sync your progress.');
    await _run(() async {
      final current = _currentRecord();
      final response = await api.post('/progress/sync', {
        'records': [...history, current].map((row) => row.toJson()).toList(),
        'settings': {
          'mantra_id': mantraId,
          'custom_mantra': customMantra,
          'goal': goal,
          'theme': theme,
          'vibrate': vibrate,
          'tap_sound': tapSound,
          'reminder_enabled': reminderEnabled,
          'reminder_hour': reminderHour,
          'reminder_minute': reminderMinute,
        },
      });
      message = response['message']?.toString() ?? 'Progress synced.';
    });
  }

  Future<void> buyPremium() async {
    if (!signedIn) throw const ApiException('Please sign in before subscribing.');
    await purchases.buy();
  }

  Future<void> restorePurchases() => purchases.restore();

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    if (!signedIn) {
      message = 'Sign in and tap Restore Purchase to activate Premium.';
      notifyListeners();
      return;
    }
    await _run(() async {
      final response = await api.post('/subscriptions/google/verify', {
        'product_id': purchase.productID,
        'purchase_id': purchase.purchaseID,
        'purchase_token': purchase.verificationData.serverVerificationData,
        'source': purchase.verificationData.source,
      });
      _applyPremium(response['premium_until']?.toString());
      _saveLocal();
      message = 'Premium is active. Thank you 🙏';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      message = error.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _applyPremium(String? value) {
    premiumUntil = value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  DailyRecord _currentRecord() => DailyRecord(
        date: date,
        goal: goal,
        total: count,
        tap: tapCount,
        mala: malaCount,
        write: writeCount,
      );

  void _rollDateIfNeeded() {
    final today = _today();
    if (date == today) return;
    final old = _currentRecord();
    if (!history.any((row) => row.date == old.date)) history.add(old);
    history.sort((a, b) => a.date.compareTo(b.date));
    final previousDay = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    streak = old.date == previousDay && old.complete ? streak + 1 : 0;
    bestStreak = max(bestStreak, streak);
    date = today;
    count = tapCount = malaCount = writeCount = 0;
    _saveLocal();
  }

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _loadLocal() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      date = json['date']?.toString() ?? _today();
      mantraId = json['mantra_id']?.toString() ?? mantras.first.id;
      customMantra = json['custom_mantra']?.toString() ?? '';
      goal = (json['goal'] as num?)?.toInt() ?? 108;
      count = (json['count'] as num?)?.toInt() ?? 0;
      tapCount = (json['tap_count'] as num?)?.toInt() ?? 0;
      malaCount = (json['mala_count'] as num?)?.toInt() ?? 0;
      writeCount = (json['write_count'] as num?)?.toInt() ?? 0;
      streak = (json['streak'] as num?)?.toInt() ?? 0;
      bestStreak = (json['best_streak'] as num?)?.toInt() ?? 0;
      theme = json['theme']?.toString() ?? 'auto';
      vibrate = json['vibrate'] as bool? ?? true;
      tapSound = json['tap_sound'] as bool? ?? true;
      reminderEnabled = json['reminder_enabled'] as bool? ?? false;
      reminderHour = (json['reminder_hour'] as num?)?.toInt() ?? 7;
      reminderMinute = (json['reminder_minute'] as num?)?.toInt() ?? 0;
      userEmail = json['user_email'] as String?;
      userName = json['user_name'] as String?;
      _applyPremium(json['premium_until'] as String?);
      history
        ..clear()
        ..addAll(((json['history'] as List?) ?? const [])
            .whereType<Map>()
            .map((row) => DailyRecord.fromJson(Map<String, dynamic>.from(row))));
    } catch (_) {
      // Safe defaults are retained if a previous local state is corrupt.
    }
  }

  Future<void> _saveLocal() => _prefs.setString(
        _storageKey,
        jsonEncode({
          'date': date,
          'mantra_id': mantraId,
          'custom_mantra': customMantra,
          'goal': goal,
          'count': count,
          'tap_count': tapCount,
          'mala_count': malaCount,
          'write_count': writeCount,
          'streak': streak,
          'best_streak': bestStreak,
          'theme': theme,
          'vibrate': vibrate,
          'tap_sound': tapSound,
          'reminder_enabled': reminderEnabled,
          'reminder_hour': reminderHour,
          'reminder_minute': reminderMinute,
          'premium_until': premiumUntil?.toUtc().toIso8601String(),
          'user_email': userEmail,
          'user_name': userName,
          'history': history.map((row) => row.toJson()).toList(),
        }),
      );

  void _saveAndNotify() {
    _saveLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    purchases.dispose();
    super.dispose();
  }
}
