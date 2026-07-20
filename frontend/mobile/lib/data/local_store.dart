import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 로컬 우선 모드(APP_MODE=local)의 데이터 저장소 (기기 내 SQLite).
///
/// 모든 메서드는 **백엔드 API 응답과 동일한 JSON 형태(Map)** 를 반환한다.
/// 덕분에:
/// - 프로바이더/모델/화면 코드가 서버 모드와 완전히 동일하게 동작하고,
/// - 향후 서버 도입 시 이 DB 내용을 그대로 API로 업로드(마이그레이션)할 수 있다.
///
/// 스키마도 백엔드 모델(User/Transaction/Category/Relationship)과 필드 호환.
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String _dbName = 'sangbusangjo_local.db';
  static const String localUserId = 'local-user';

  /// 테스트에서 인메모리 DB 경로로 교체하기 위한 후크.
  static String? overridePathForTest;

  static final Random _rand = Random();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  /// 테스트 전용: 연결을 닫아 다음 접근 시 새 DB를 열게 한다.
  Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path = overridePathForTest ?? p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        icon TEXT,
        color TEXT,
        is_system INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        transaction_date TEXT NOT NULL,
        counterparty_name TEXT,
        memo TEXT,
        event_type TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute(
        'CREATE INDEX idx_tx_date ON transactions(transaction_date)');
    await db.execute(
        'CREATE INDEX idx_tx_counterparty ON transactions(counterparty_name)');
    await db.execute('''
      CREATE TABLE relationships (
        id TEXT PRIMARY KEY,
        counterparty_name TEXT NOT NULL UNIQUE,
        relationship_type TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )''');
    await _seedCategories(db);
  }

  /// 백엔드 `app/db/seed.py` 의 시스템 카테고리 15개와 동일 (이름/유형/아이콘/색).
  Future<void> _seedCategories(Database db) async {
    const seeds = [
      ['sys-01', '결혼 축의금', 'expense', '💍', '#FF6B9D'],
      ['sys-02', '장례 조의금', 'expense', '🕯️', '#6B7280'],
      ['sys-03', '돌잔치', 'expense', '🎂', '#F59E0B'],
      ['sys-04', '생일 선물', 'expense', '🎁', '#8B5CF6'],
      ['sys-05', '집들이 선물', 'expense', '🏠', '#10B981'],
      ['sys-06', '계모임', 'expense', '🤝', '#3B82F6'],
      ['sys-07', '동창회비', 'expense', '🎓', '#6366F1'],
      ['sys-08', '회식', 'expense', '🍽️', '#EF4444'],
      ['sys-09', '빌려준 돈', 'expense', '💸', '#F97316'],
      ['sys-10', '결혼 축의금 수령', 'income', '💍', '#FF6B9D'],
      ['sys-11', '생일 용돈', 'income', '🎂', '#F59E0B'],
      ['sys-12', '계모임 수령', 'income', '🤝', '#3B82F6'],
      ['sys-13', '빌려준 돈 회수', 'income', '💰', '#10B981'],
      ['sys-14', '기타 지출', 'expense', '📦', '#9CA3AF'],
      ['sys-15', '기타 수입', 'income', '📦', '#9CA3AF'],
    ];
    final batch = db.batch();
    for (final s in seeds) {
      batch.insert('categories', {
        'id': s[0],
        'name': s[1],
        'type': s[2],
        'icon': s[3],
        'color': s[4],
        'is_system': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  static String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(1 << 20).toRadixString(36);
    return '$t-$r';
  }

  static String _nowIso() => DateTime.now().toIso8601String();

  static String? _emptyToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  // ── 프로필 (로컬 "계정") ────────────────────────────────────────────────

  Future<bool> hasProfile() async => (await getProfile()) != null;

  /// User 모델 JSON 형태로 반환. 없으면 null.
  Future<Map<String, dynamic>?> getProfile() async {
    final db = await _database;
    final rows = await db.query('profile', limit: 1);
    if (rows.isEmpty) return null;
    return _profileJson(rows.first);
  }

  Future<Map<String, dynamic>> createProfile(String name) async {
    final db = await _database;
    final row = {
      'id': localUserId,
      'name': name.trim(),
      'created_at': _nowIso(),
    };
    await db.insert('profile', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return _profileJson(row);
  }

  Map<String, dynamic> _profileJson(Map<String, Object?> row) => {
        'id': row['id'],
        'email': 'local@device',
        'username': row['name'],
        'full_name': row['name'],
        'phone': null,
        'is_active': true,
        'created_at': row['created_at'],
      };

  // ── 카테고리 ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCategories() async {
    final db = await _database;
    final rows = await db.query('categories', orderBy: 'rowid');
    return rows
        .map((r) => <String, dynamic>{
              'id': r['id'],
              'name': r['name'],
              'type': r['type'],
              'icon': r['icon'],
              'color': r['color'],
              'is_system': (r['is_system'] as int) == 1,
            })
        .toList();
  }

  // ── 거래 ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> listTransactions({
    int skip = 0,
    int limit = 20,
    String? type,
  }) async {
    final db = await _database;
    final where = type != null ? 'WHERE type = ?' : '';
    final args = type != null ? [type] : <Object>[];
    final rows = await db.rawQuery(
      'SELECT * FROM transactions $where '
      'ORDER BY transaction_date DESC, created_at DESC LIMIT ? OFFSET ?',
      [...args, limit, skip],
    );
    final total = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM transactions $where', args)) ??
        0;
    return {
      'items': rows.map(_transactionJson).toList(),
      'total': total,
    };
  }

  Future<Map<String, dynamic>> createTransaction({
    required String categoryId,
    required double amount,
    required String type,
    required String transactionDate,
    String? counterpartyName,
    String? memo,
    String? eventType,
  }) async {
    final db = await _database;
    final cp = _emptyToNull(counterpartyName);
    final row = {
      'id': _newId(),
      'category_id': categoryId,
      'amount': amount,
      'type': type,
      'transaction_date': transactionDate,
      'counterparty_name': cp,
      'memo': _emptyToNull(memo),
      'event_type': _emptyToNull(eventType),
      'created_at': _nowIso(),
    };
    await db.transaction((txn) async {
      await txn.insert('transactions', row);
      // 백엔드와 동일: 상대방이 있으면 관계를 자동 생성 (집계는 조회 시 계산)
      if (cp != null) {
        await txn.rawInsert(
          'INSERT OR IGNORE INTO relationships (id, counterparty_name, created_at) VALUES (?, ?, ?)',
          [_newId(), cp, _nowIso()],
        );
      }
    });
    return _transactionJson(row);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _transactionJson(Map<String, Object?> r) => {
        'id': r['id'],
        'user_id': localUserId,
        'category_id': r['category_id'],
        'amount': r['amount'],
        'type': r['type'],
        'transaction_date': r['transaction_date'],
        'counterparty_name': r['counterparty_name'],
        'memo': r['memo'],
        'event_type': r['event_type'],
        'created_at': r['created_at'],
      };

  // ── 관계 (상대방별 집계) ──────────────────────────────────────────────

  static const String _relationshipSelect = '''
    SELECT r.id, r.counterparty_name, r.relationship_type, r.notes, r.created_at,
           COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount END), 0) AS total_given,
           COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount END), 0) AS total_received,
           MAX(t.transaction_date) AS last_transaction_date
    FROM relationships r
    LEFT JOIN transactions t ON t.counterparty_name = r.counterparty_name
  ''';

  Future<List<Map<String, dynamic>>> listRelationships({int limit = 50}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '$_relationshipSelect GROUP BY r.id '
      'ORDER BY last_transaction_date IS NULL, last_transaction_date DESC, r.created_at DESC '
      'LIMIT ?',
      [limit],
    );
    return rows.map(_relationshipJson).toList();
  }

  Future<Map<String, dynamic>> createRelationship({
    required String counterpartyName,
    String? relationshipType,
    String? notes,
  }) async {
    final db = await _database;
    final id = _newId();
    // 중복 이름이면 UNIQUE 제약으로 예외 발생 → 프로바이더가 실패 처리 (백엔드 400과 동일한 효과)
    await db.insert('relationships', {
      'id': id,
      'counterparty_name': counterpartyName.trim(),
      'relationship_type': _emptyToNull(relationshipType),
      'notes': _emptyToNull(notes),
      'created_at': _nowIso(),
    });
    return (await _getRelationship(id))!;
  }

  Future<Map<String, dynamic>> updateRelationship(
    String id, {
    String? relationshipType,
    String? notes,
  }) async {
    final db = await _database;
    await db.update(
      'relationships',
      {'relationship_type': relationshipType, 'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await _getRelationship(id))!;
  }

  Future<Map<String, dynamic>?> _getRelationship(String id) async {
    final db = await _database;
    final rows = await db.rawQuery(
        '$_relationshipSelect WHERE r.id = ? GROUP BY r.id', [id]);
    if (rows.isEmpty) return null;
    return _relationshipJson(rows.first);
  }

  Map<String, dynamic> _relationshipJson(Map<String, Object?> r) {
    final given = (r['total_given'] as num).toDouble();
    final received = (r['total_received'] as num).toDouble();
    return {
      'id': r['id'],
      'user_id': localUserId,
      'counterparty_name': r['counterparty_name'],
      'counterparty_id': null,
      'relationship_type': r['relationship_type'],
      'notes': r['notes'],
      'total_given': given,
      'total_received': received,
      'balance': given - received,
      'last_transaction_date': r['last_transaction_date'],
      'created_at': r['created_at'],
    };
  }

  // ── 분석 ─────────────────────────────────────────────────────────────

  /// 월별 요약. 백엔드 `/analytics/summary` 응답과 동일한 형태.
  Future<Map<String, dynamic>> summary({int? year, int? month}) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final ym = '$y-${m.toString().padLeft(2, '0')}';
    final db = await _database;
    final row = (await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount END), 0) AS expense,
        COALESCE(SUM(CASE WHEN type = 'income' THEN 1 ELSE 0 END), 0) AS income_count,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN 1 ELSE 0 END), 0) AS expense_count
      FROM transactions
      WHERE substr(transaction_date, 1, 7) = ?
    ''', [ym]))
        .first;
    final income = (row['income'] as num).toDouble();
    final expense = (row['expense'] as num).toDouble();
    return {
      'year': y,
      'month': m,
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'income_count': (row['income_count'] as num).toInt(),
      'expense_count': (row['expense_count'] as num).toInt(),
    };
  }

  /// 최근 N개월 트렌드 (과거→현재 순). `/analytics/trends` 형태.
  Future<Map<String, dynamic>> trends({int months = 6}) async {
    final now = DateTime.now();
    final monthKeys = List.generate(months, (i) {
      final d = DateTime(now.year, now.month - (months - 1 - i));
      return (
        year: d.year,
        month: d.month,
        ym: '${d.year}-${d.month.toString().padLeft(2, '0')}'
      );
    });
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT substr(transaction_date, 1, 7) AS ym,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount END), 0) AS expense
      FROM transactions
      WHERE substr(transaction_date, 1, 7) >= ?
      GROUP BY ym
    ''', [monthKeys.first.ym]);
    final byYm = {for (final r in rows) r['ym'] as String: r};
    return {
      'trends': monthKeys.map((k) {
        final r = byYm[k.ym];
        return {
          'year': k.year,
          'month': k.month,
          'income': r == null ? 0.0 : (r['income'] as num).toDouble(),
          'expense': r == null ? 0.0 : (r['expense'] as num).toDouble(),
        };
      }).toList(),
    };
  }

  /// 카테고리별 통계. `/analytics/by-category` 형태.
  Future<Map<String, dynamic>> byCategory({
    int? year,
    int? month,
    String type = 'expense',
  }) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final ym = month != null
        ? '$y-${month.toString().padLeft(2, '0')}'
        : null;
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT c.id, c.name, c.color,
             COALESCE(SUM(t.amount), 0) AS "total",
             COUNT(t.id) AS "count"
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.type = ?
        AND substr(t.transaction_date, 1, ?) = ?
      GROUP BY c.id
      ORDER BY "total" DESC
    ''', [type, ym != null ? 7 : 4, ym ?? '$y']);
    final grand = rows.fold<double>(
        0, (acc, r) => acc + (r['total'] as num).toDouble());
    return {
      'categories': rows.map((r) {
        final total = (r['total'] as num).toDouble();
        return {
          'id': r['id'],
          'name': r['name'],
          'color': r['color'],
          'total': total,
          'count': (r['count'] as num).toInt(),
          'ratio': grand == 0 ? 0.0 : total / grand,
        };
      }).toList(),
      'total': grand,
    };
  }
}
