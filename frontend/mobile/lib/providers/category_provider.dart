import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../data/local_store.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();

  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();

  String nameById(String id) =>
      _categories.firstWhere((c) => c.id == id, orElse: () => Category(id: '', name: '-', type: '', isSystem: false)).name;

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return; // 캐시 활용
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> raw;
      if (AppConfig.isLocal) {
        raw = await LocalStore.instance.listCategories();
      } else {
        final res = await apiClient.dio.get('/categories/');
        raw = res.data as List;
      }
      _categories = raw.map((e) => Category.fromJson(e)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
