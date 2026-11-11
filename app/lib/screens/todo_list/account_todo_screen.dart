import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../services/account_service.dart';
import '../../services/firebase_account_service.dart';
import '../../services/firebase_todo_store.dart';
import '../../services/firestore_todo_repository.dart';
import '../../services/internet_status.dart';
import '../../services/sqlite_migration_journal.dart';
import '../../services/sqlite_todo_repository.dart';
import '../../services/todo_migration.dart';
import '../../services/todo_repository.dart';
import '../../widgets/error_retry_card.dart';
import '../../widgets/skeleton_list.dart';
import 'todo_list_screen.dart';

// 계정에 맞는 저장소를 준비한 후 기존 할 일 화면에 주입한다.
class AccountTodoScreen extends StatefulWidget {
  const AccountTodoScreen({
    super.key,
    this.accountService,
    this.session,
    this.onlineChanges,
  }) : assert((accountService == null) == (session == null));

  final AccountService? accountService;
  final TodoRepositorySession? session;
  final Stream<bool>? onlineChanges;

  @override
  State<AccountTodoScreen> createState() => _AccountTodoScreenState();
}

// 인증 변경마다 화면을 분리해 이전 계정의 목록이 새 계정에 남지 않도록 한다.
class _AccountTodoScreenState extends State<AccountTodoScreen>
    with WidgetsBindingObserver {
  AccountService? _accountService;
  TodoRepositorySession? _session;
  StreamSubscription<AccountIdentity?>? _subscription;
  Future<TodoRepository>? _repository;
  String? _uid;
  StreamSubscription<bool>? _onlineSubscription;
  bool _isOnline = true;

  // Firebase 없는 실행은 기존 SQLite 화면을 유지하고 인증이 있으면 저장소를 준비한다.
  @override
  void initState() {
    super.initState();
    _accountService =
        widget.accountService ??
        (Firebase.apps.isEmpty ? null : FirebaseAccountService());
    final service = _accountService;
    if (service == null) return;
    WidgetsBinding.instance.addObserver(this);
    _watchOnline();
    final remotes = <String, FirestoreTodoRepository>{};
    _session =
        widget.session ??
        TodoRepositorySession(
          local: SqliteTodoRepository(),
          journal: SqliteMigrationJournal(),
          remoteFor: (uid) => remotes.putIfAbsent(
            uid,
            () => FirestoreTodoRepository(FirebaseTodoStore(uid: uid)),
          ),
          currentUid: () => service.currentAccount?.uid,
        );
    _uid = service.currentAccount?.uid;
    _repository = _session!.forAccount(_uid);
    _subscription = service.accountChanges.listen((account) {
      if (!mounted || account?.uid == _uid) return;
      setState(() {
        _uid = account?.uid;
        _repository = _session!.forAccount(_uid);
      });
    });
  }

  // 인터넷 확인 결과를 목록에 전달해 배너와 복구 시 새로고침을 연결한다.
  void _watchOnline() {
    _onlineSubscription = (widget.onlineChanges ?? InternetStatus().watch())
        .listen((isOnline) {
          if (!mounted || isOnline == _isOnline) return;
          setState(() => _isOnline = isOnline);
        });
  }

  // 백그라운드에서는 주기 검사를 멈추고 앱 복귀 시 즉시 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_accountService == null || widget.onlineChanges != null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_onlineSubscription?.cancel());
      _onlineSubscription = null;
    } else if (state == AppLifecycleState.resumed &&
        _onlineSubscription == null) {
      _watchOnline();
    }
  }

  // 화면이 닫히면 인증 상태 구독을 해제한다.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_onlineSubscription?.cancel());
    super.dispose();
  }

  // 실패한 저장소 준비나 이관을 같은 계정과 같은 ID로 다시 시도한다.
  void _retry() {
    final repository = _session!.forAccount(_uid);
    setState(() {
      _repository = repository;
    });
  }

  // 이관 중에는 이전 계정 데이터를 숨기고 진행 상태 또는 재시도를 표시한다.
  @override
  Widget build(BuildContext context) {
    if (_session == null) return const TodoListScreen();
    return FutureBuilder<TodoRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return TodoListScreen(
            key: ValueKey('todos-${_uid ?? 'local'}'),
            repository: snapshot.data,
            isOnline: _isOnline,
          );
        }
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child:
                  snapshot.hasError &&
                      snapshot.connectionState == ConnectionState.done
                  ? ErrorRetryCard(
                      title: '할 일 저장소를 준비하지 못했습니다',
                      message: snapshot.error is StateError
                          ? (snapshot.error! as StateError).message.toString()
                          : '인터넷 연결과 계정을 확인하고 다시 시도해 주세요. 기존 할 일은 보존됩니다.',
                      onRetry: _retry,
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('계정의 할 일을 준비하는 중입니다'),
                        SizedBox(height: AppSpacing.md),
                        SkeletonList(),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
