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

  AnalyticsSummary? get summary => _summary;
  List<TrendPoint> get trends => _trends;
  List<CategoryStat> get categoryStats => _categoryStats;
  double get categoryTotal => _categoryTotal;
  bool get isLoading => _isLoading;
  bool get isTrendLoading => _isTrendLoading;
  bool get isCatLoading => _isCatLoading;

  Future<void> fetchSummary({int? year, int? month}) async {
    _isLoading = true;
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
      _summary = AnalyticsSummary.fromJson(raw);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrends({int months = 6}) async {
    _isTrendLoading = true;
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
      _trends =
          (raw['trends'] as List).map((e) => TrendPoint.fromJson(e)).toList();
    } finally {
      _isTrendLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchByCategory({int? year, int? month, String type = 'expense'}) async {
    _isCatLoading = true;
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
      _categoryStats = (raw['categories'] as List)
          .map((e) => CategoryStat.fromJson(e))
          .toList();
      _categoryTotal = (raw['total'] as num).toDouble();
    } finally {
      _isCatLoading = false;
      notifyListeners();
    }
  }
}
