import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _items = [];
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  List<Transaction> get items => _items;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTransactions({
    int skip = 0,
    int limit = 20,
    String? type,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{'skip': skip, 'limit': limit};
      if (type != null) params['type'] = type;
      final res = await apiClient.dio.get('/transactions/', queryParameters: params);
      final data = TransactionListResponse.fromJson(res.data);
      _items = data.items;
      _total = data.total;
    } catch (e) {
      _error = '거래 목록을 불러오는데 실패했습니다';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTransaction({
    required String categoryId,
    required double amount,
    required String type,
    required String transactionDate,
    String? counterpartyName,
    String? memo,
    String? eventType,
  }) async {
    try {
      await apiClient.dio.post('/transactions/', data: {
        'category_id': categoryId,
        'amount': amount,
        'type': type,
        'transaction_date': transactionDate,
        if (counterpartyName != null && counterpartyName.isNotEmpty)
          'counterparty_name': counterpartyName,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
      });
      await fetchTransactions();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await apiClient.dio.delete('/transactions/$id');
      _items.removeWhere((t) => t.id == id);
      _total--;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
