import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../data/local_store.dart';
import '../models/analytics.dart';

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsSummary? _summary;
  List<TrendPoint> _trends = [];
  List<CategoryStat> _categoryStats = [];
  double _categoryTotal = 0;
  bool _isLoading = false;
  bool _isTrendLoading = false;
  bool _isCatLoading = false;
  String? _summaryError;
  String? _trendError;
  String? _categoryError;
  int _summaryRequest = 0;
  int _trendRequest = 0;
  int _categoryRequest = 0;

  AnalyticsSummary? get summary => _summary;
  List<TrendPoint> get trends => _trends;
  List<CategoryStat> get categoryStats => _categoryStats;
  double get categoryTotal => _categoryTotal;
  bool get isLoading => _isLoading;
  bool get isTrendLoading => _isTrendLoading;
  bool get isCatLoading => _isCatLoading;
  String? get summaryError => _summaryError;
  String? get trendError => _trendError;
  String? get categoryError => _categoryError;

  @override
  void dispose() {
    // Invalidate outstanding reads before their completions can notify.
    _summaryRequest++;
    _trendRequest++;
    _categoryRequest++;
    super.dispose();
  }

  Future<void> fetchSummary({int? year, int? month}) async {
    final request = ++_summaryRequest;
    _isLoading = true;
    _summary = null;
    _summaryError = null;
    notifyListeners();
    try {
      final Map<String, dynamic> raw;
      if (AppConfig.isLocal) {
        raw = await LocalStore.instance.summary(year: year, month: month);
      } else {
        final params = <String, dynamic>{};
        if (year != null) params['year'] = year;
        if (month != null) params['month'] = month;
        final res =
            await apiClient.dio.get('/analytics/summary', queryParameters: params);
        raw = res.data;
      }
      if (request != _summaryRequest) return;
      _summary = AnalyticsSummary.fromJson(raw);
    } catch (_) {
      if (request == _summaryRequest) {
        _summaryError = '이 달의 기록을 불러오지 못했어요. 다시 시도해 주세요.';
      }
    } finally {
      if (request == _summaryRequest) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchTrends({int months = 6}) async {
    final request = ++_trendRequest;
    _isTrendLoading = true;
    _trends = [];
    _trendError = null;
    notifyListeners();
    try {
      final Map<String, dynamic> raw;
      if (AppConfig.isLocal) {
        raw = await LocalStore.instance.trends(months: months);
      } else {
        final res = await apiClient.dio
            .get('/analytics/trends', queryParameters: {'months': months});
        raw = res.data;
      }
      if (request != _trendRequest) return;
      _trends =
          (raw['trends'] as List).map((e) => TrendPoint.fromJson(e)).toList();
    } catch (_) {
      if (request == _trendRequest) {
        _trendError = '선택한 기간의 흐름을 불러오지 못했어요. 다시 시도해 주세요.';
      }
    } finally {
      if (request == _trendRequest) {
        _isTrendLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchByCategory({int? year, int? month, String type = 'expense'}) async {
    final request = ++_categoryRequest;
    _isCatLoading = true;
    _categoryStats = [];
    _categoryTotal = 0;
    _categoryError = null;
    notifyListeners();
    try {
      final Map<String, dynamic> raw;
      if (AppConfig.isLocal) {
        raw = await LocalStore.instance
            .byCategory(year: year, month: month, type: type);
      } else {
        final params = <String, dynamic>{'type': type};
        if (year != null) params['year'] = year;
        if (month != null) params['month'] = month;
        final res = await apiClient.dio
            .get('/analytics/by-category', queryParameters: params);
        raw = res.data;
      }
      if (request != _categoryRequest) return;
      final stats = (raw['categories'] as List)
          .map((e) => CategoryStat.fromJson(e))
          .toList();
      _categoryTotal = (raw['total'] as num).toDouble();
      _categoryStats = stats;
    } catch (_) {
      if (request == _categoryRequest) {
        _categoryError = '분류별 기록을 불러오지 못했어요. 다시 시도해 주세요.';
      }
    } finally {
      if (request == _categoryRequest) {
        _isCatLoading = false;
        notifyListeners();
      }
    }
  }
}
