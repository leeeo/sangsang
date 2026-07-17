import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/relationship.dart';

class RelationshipProvider extends ChangeNotifier {
  List<Relationship> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Relationship> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRelationships() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await apiClient.dio.get('/relationships/', queryParameters: {'limit': 50});
      _items = (res.data as List).map((e) => Relationship.fromJson(e)).toList();
    } catch (_) {
      _error = '관계 목록을 불러오는데 실패했습니다';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRelationship({
    required String counterpartyName,
    String? relationshipType,
    String? notes,
  }) async {
    try {
      final res = await apiClient.dio.post('/relationships/', data: {
        'counterparty_name': counterpartyName,
        if (relationshipType != null && relationshipType.isNotEmpty)
          'relationship_type': relationshipType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      _items.insert(0, Relationship.fromJson(res.data));
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateRelationship(String id, {String? relationshipType, String? notes}) async {
    try {
      final res = await apiClient.dio.patch('/relationships/$id', data: {
        'relationship_type': relationshipType,
        'notes': notes,
      });
      final updated = Relationship.fromJson(res.data);
      final idx = _items.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
