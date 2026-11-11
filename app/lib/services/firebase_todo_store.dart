import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/todo.dart';
import 'firestore_todo_store.dart';

// 현재 계정의 Firestore 경로와 SDK의 영구 오프라인 캐시를 사용한다.
class FirebaseTodoStore implements FirestoreTodoStore {
  FirebaseTodoStore({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final Map<String, String> _failures = {};
  final Map<String, String> _operations = {};
  final _writeChanges = StreamController<void>.broadcast();

  CollectionReference<Map<String, dynamic>> get _todos =>
      _firestore.collection('users').doc(uid).collection('todos');

  // 캐시로 대체하지 않고 서버 응답을 요청해 수동 새로고침 실패를 구분한다.
  @override
  Future<List<RemoteTodoDocument>> readServer() async {
    final snapshot = await _todos
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 5));
    return snapshot.docs.map(_document).toList(growable: false);
  }

  // 문서 내용뿐 아니라 서버 전송 완료에 따른 대기 상태 변경도 전달한다.
  @override
  Stream<List<RemoteTodoDocument>> watchAll() => Stream.multi((controller) {
    List<RemoteTodoDocument>? latest;
    final snapshots = _todos.snapshots(includeMetadataChanges: true).listen((
      snapshot,
    ) {
      latest = snapshot.docs.map(_document).toList(growable: false);
      controller.add(latest!);
    }, onError: controller.addError);
    final writes = _writeChanges.stream.listen((_) {
      if (latest != null) controller.add(latest!);
    });
    controller.onCancel = () async {
      await snapshots.cancel();
      await writes.cancel();
    };
  });

  // 서버 조회가 지연되면 이미 저장된 캐시를 사용한다. 서버 권한 오류는 숨기지 않는다.
  @override
  Future<List<RemoteTodoDocument>> readAll() async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _todos.get().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      snapshot = await _todos.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
      snapshot = await _todos.get(const GetOptions(source: Source.cache));
    }
    return snapshot.docs.map(_document).toList(growable: false);
  }

  // 시간 비교에 사용할 Firestore Timestamp를 기존 모델이 읽을 수 있는 값으로 변환한다.
  RemoteTodoDocument _document(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = Map<String, Object?>.from(snapshot.data()!);
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) {
      data['updated_at'] = updatedAt.toDate().toUtc().toIso8601String();
    }
    return RemoteTodoDocument(
      id: snapshot.id,
      data: data,
      isPending: snapshot.metadata.hasPendingWrites,
    );
  }

  // 로컬 캐시에서 삭제 기록을 확인한다. 캐시가 없는 경우에는 서버 규칙이 충돌을 판정한다.
  @override
  Future<RemoteTodoDocument?> readCached(String id) async {
    try {
      final snapshot = await _todos
          .doc(id)
          .get(const GetOptions(source: Source.cache));
      return snapshot.exists ? _document(snapshot) : null;
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') return null;
      rethrow;
    }
  }

  // 로컬 반영을 확인한 뒤 반환하고, 늦게 도착한 서버 거절은 실패 상태로 보관한다.
  @override
  Future<void> enqueue(String id, Map<String, Object?> data) async {
    final operationId = data['operationId']! as String;
    final reference = _todos.doc(id);
    final localAccepted = Completer<void>();
    _operations[id] = operationId;
    _failures.remove(id);
    final subscription = reference
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (snapshot.data()?['operationId'] == operationId &&
                !localAccepted.isCompleted) {
              localAccepted.complete();
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!localAccepted.isCompleted) {
              localAccepted.completeError(error, stack);
            }
          },
        );
    final payload = Map<String, dynamic>.from(data);
    payload['updatedAt'] = Timestamp.fromDate(
      DateTime.parse(data['updated_at']! as String),
    );
    unawaited(
      reference
          .set(payload)
          .then<void>(
            (_) {
              if (!localAccepted.isCompleted) localAccepted.complete();
            },
            onError: (Object error, StackTrace stack) {
              if (_operations[id] == operationId) {
                _failures[id] = operationId;
                _writeChanges.add(null);
              }
              if (!localAccepted.isCompleted) {
                localAccepted.completeError(error, stack);
              }
            },
          ),
    );
    try {
      await localAccepted.future;
    } finally {
      await subscription.cancel();
    }
  }

  // 같은 ID의 더 최신 값과 삭제 기록은 보존하고, 서버 확인 후 이관을 완료한다.
  @override
  Future<void> importTodo(Todo todo) async {
    final reference = _todos.doc(todo.id);
    await _firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          if (existing.exists) {
            final data = existing.data()!;
            if (data['deleted'] == true) return;
            final updatedAt = data['updatedAt'];
            if (updatedAt is! Timestamp) {
              throw StateError('서버 할 일의 수정 시각을 확인할 수 없습니다.');
            }
            if (!todo.updatedAt.isAfter(updatedAt.toDate())) return;
          }
          transaction.set(reference, {
            ...todo.toMap(),
            'remote_id': todo.id,
            'sync_status': TodoSyncStatus.synced.name,
            'deleted': false,
            'updatedAt': Timestamp.fromDate(todo.updatedAt),
            'operationId': newOperationId(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  @override
  bool hasWriteFailure(String id) => _failures.containsKey(id);

  @override
  String newOperationId() => _todos.doc().id;
}
