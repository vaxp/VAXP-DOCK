import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/system_stats_model.dart';
import '../../data/repositories/system_stats_repository.dart';

abstract class SystemStatsState extends Equatable {
  @override
  List<Object> get props => [];
}

class SystemStatsInitial extends SystemStatsState {}

class SystemStatsLoading extends SystemStatsState {}

class SystemStatsLoaded extends SystemStatsState {
  final SystemStats stats;

   SystemStatsLoaded({
    required this.stats,
  });

  @override
  List<Object> get props => [stats];
}

class SystemStatsError extends SystemStatsState {
  final String message;

   SystemStatsError(this.message);

  @override
  List<Object> get props => [message];
}

/// ====== Cubit ======
class SystemStatsCubit extends Cubit<SystemStatsState> {
  final SystemStatsRepository repository;
  Timer? _timer;

  SystemStatsCubit(this.repository) : super(SystemStatsInitial()) {
    startUpdates();
  }

  void startUpdates() {
    _timer?.cancel();
    // يمكنك تغيير المدة هنا حسب رغبتك
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchStats();
    });
    // تحميل أول مرة
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      if (state is SystemStatsInitial) {
        emit(SystemStatsLoading());
      }

      final stats = await repository.getSystemStats();
      final newState = SystemStatsLoaded(stats: stats);

      if (state is SystemStatsLoaded) {
        final current = state as SystemStatsLoaded;
        if (current.stats == newState.stats) {
          return;
        }
      }

      emit(newState);
    } catch (e) {
      emit(SystemStatsError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
