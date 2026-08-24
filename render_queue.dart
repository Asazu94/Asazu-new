import 'dart:async';

import 'platform_optimization.dart';
import 'render_engine.dart';

class RenderJob {
  final String id;
  final RenderRequest request;
  final RenderPriority priority;
  const RenderJob({required this.id, required this.request, this.priority = RenderPriority.normal});
}

class RenderJobState {
  final String id;
  final RenderStatus status;
  final RenderResult? result;
  const RenderJobState({required this.id, required this.status, this.result});
}

class RenderQueue {
  final RenderEngine engine;
  final int maxConcurrent;
  final List<RenderJob> _pending = [];
  final Map<String, RenderJobState> _states = {};
  final Map<String, Completer<RenderJobState>> _completers = {};
  int _running = 0;
  bool _closed = false;

  RenderQueue({required this.engine, int? maxConcurrent, PlatformOptimizationProfile? profile})
      : maxConcurrent = maxConcurrent ?? (profile ?? PlatformOptimizationProfile.detect()).maxConcurrentRenders {
    if (this.maxConcurrent < 1) throw ArgumentError.value(this.maxConcurrent, 'maxConcurrent', 'must be at least 1');
  }

  List<RenderJobState> get states => List.unmodifiable(_states.values);

  Future<RenderJobState> enqueue(RenderJob job) {
    if (_closed) return Future.error(StateError('Render queue is closed'));
    if (job.id.trim().isEmpty) return Future.error(ArgumentError.value(job.id, 'job.id', 'must not be empty'));
    if (_states.containsKey(job.id)) return Future.error(StateError('Render job already exists: ${job.id}'));

    final completer = Completer<RenderJobState>();
    _completers[job.id] = completer;
    _states[job.id] = RenderJobState(id: job.id, status: RenderStatus.queued);
    _pending.add(job);
    _pending.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _pump();
    return completer.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final cancelled = List<RenderJob>.from(_pending);
    _pending.clear();
    for (final job in cancelled) {
      final state = RenderJobState(
        id: job.id,
        status: RenderStatus.cancelled,
        result: RenderResult(status: RenderStatus.cancelled, outputPath: job.request.outputPath),
      );
      _states[job.id] = state;
      _complete(job.id, state);
    }
  }

  void _pump() {
    while (!_closed && _running < maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _running++;
      _run(job).then((state) {
        _states[job.id] = state;
        _complete(job.id, state);
      }).catchError((Object error, StackTrace stack) {
        final state = RenderJobState(
          id: job.id,
          status: RenderStatus.failed,
          result: RenderResult(status: RenderStatus.failed, outputPath: job.request.outputPath, error: '$error'),
        );
        _states[job.id] = state;
        _complete(job.id, state);
      }).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  void _complete(String id, RenderJobState state) {
    final completer = _completers.remove(id);
    if (completer != null && !completer.isCompleted) completer.complete(state);
  }

  Future<RenderJobState> _run(RenderJob job) async {
    _states[job.id] = RenderJobState(id: job.id, status: RenderStatus.rendering);
    final result = await engine.render(job.request);
    return RenderJobState(id: job.id, status: result.status, result: result);
  }
}
