import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(authService: ref.watch(authServiceProvider));
});

class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoggedIn;
  final bool isGuestMode;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.token,
    this.isLoggedIn = false,
    this.isGuestMode = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoggedIn,
    bool? isGuestMode,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearUser ? null : (token ?? this.token),
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuestMode: isGuestMode ?? this.isGuestMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    final service = ref.watch(authServiceProvider);
    return AuthState(
      user: service.currentUser,
      token: service.token,
      isLoggedIn: service.isLoggedIn,
      isGuestMode: service.isGuestMode,
      isLoading: !service.isInitialized,
    );
  }

  Future<void> _init() async {
    final service = ref.read(authServiceProvider);
    await service.init();
    state = AuthState(
      user: service.currentUser,
      token: service.token,
      isLoggedIn: service.isLoggedIn,
      isGuestMode: service.isGuestMode,
      isLoading: false,
    );
  }

  Future<AuthResult> sendOtp(String email, {String? name, String mode = 'login'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(authServiceProvider);
    final result = await service.sendOtp(email: email, name: name, mode: mode);
    state = state.copyWith(isLoading: false, errorMessage: result.success ? null : result.message);
    return result;
  }

  Future<AuthResult> verifyOtp(String email, String otp, String name) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(authServiceProvider);
    final result = await service.verifyOtp(email: email, otp: otp, name: name);
    if (result.success && result.user != null) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        isGuestMode: false,
        user: result.user,
        token: result.token,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.message);
    }
    return result;
  }

  Future<void> continueOffline() async {
    final service = ref.read(authServiceProvider);
    await service.continueOffline();
    state = state.copyWith(isGuestMode: true, isLoading: false);
  }

  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout();
    state = const AuthState(isLoggedIn: false, isGuestMode: false, isLoading: false);
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class SyncStatusState {
  final bool isSyncing;
  final String? lastSyncedAt;
  final String? lastMessage;
  final bool? lastSuccess;

  const SyncStatusState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastMessage,
    this.lastSuccess,
  });

  SyncStatusState copyWith({
    bool? isSyncing,
    String? lastSyncedAt,
    String? lastMessage,
    bool? lastSuccess,
  }) {
    return SyncStatusState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSuccess: lastSuccess ?? this.lastSuccess,
    );
  }
}

class SyncStatusNotifier extends Notifier<SyncStatusState> {
  @override
  SyncStatusState build() {
    _loadLastSyncTime();
    return const SyncStatusState();
  }

  Future<void> _loadLastSyncTime() async {
    final service = ref.read(syncServiceProvider);
    final lastTime = await service.getLastSyncedAt();
    state = state.copyWith(lastSyncedAt: lastTime);
  }

  Future<SyncResult> triggerSync() async {
    state = state.copyWith(isSyncing: true, lastMessage: null);
    final service = ref.read(syncServiceProvider);
    final result = await service.syncWithCloud();
    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: result.syncedAt ?? state.lastSyncedAt,
      lastMessage: result.message,
      lastSuccess: result.success,
    );
    return result;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatusState>(SyncStatusNotifier.new);
