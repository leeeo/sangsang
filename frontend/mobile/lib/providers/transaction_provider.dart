import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../data/local_store.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _items = [];
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _type;
  int _pageSize = 20;
  int _requestId = 0;

  List<Transaction> get items => _items;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _items.length < _total;
  String? get error => _error;

  Future<void> fetchTransactions({
    int skip = 0,
    int limit = 20,
    String? type,
    bool append = false,
  }) async {
    final requestId = ++_requestId;
    _type = type;
    _pageSize = limit;
    _isLoading = !append;
    _isLoadingMore = append;
    _error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> raw;
      if (AppConfig.isLocal) {
        raw = await LocalStore.instance
            .listTransactions(skip: skip, limit: limit, type: type);
      } else {
        final params = <String, dynamic>{'skip': skip, 'limit': limit};
        if (type != null) params['type'] = type;
        final res =
            await apiClient.dio.get('/transactions/', queryParameters: params);
        raw = res.data;
      }
      final data = TransactionListResponse.fromJson(raw);
      if (requestId != _requestId) return;
      _items = append ? [..._items, ...data.items] : data.items;
      _total = data.total;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = '주고받은 기록을 불러오지 못했어요. 다시 시도해 주세요.';
      if (!append) _items = [];
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => fetchTransactions(type: _type, limit: _pageSize);

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;
    await fetchTransactions(skip: _items.length, limit: _pageSize, type: _type, append: true);
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
      if (AppConfig.isLocal) {
        await LocalStore.instance.createTransaction(
          categoryId: categoryId,
          amount: amount,
          type: type,
          transactionDate: transactionDate,
          counterpartyName: counterpartyName,
          memo: memo,
          eventType: eventType,
        );
      } else {
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
      }
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      if (AppConfig.isLocal) {
        await LocalStore.instance.deleteTransaction(id);
      } else {
        await apiClient.dio.delete('/transactions/$id');
      }
      _items.removeWhere((t) => t.id == id);
      _total--;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
