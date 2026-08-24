import 'dart:async';

import 'package:test/test.dart';
import '../lib/platform_optimization.dart';
import '../lib/render_engine.dart';
import '../lib/scene_builder.dart';

class _QueueRenderer implements RenderEngine {
  final Duration delay;
  int active = 0;
  int maxActive = 0;

  _QueueRenderer([this.delay = const Duration(milliseconds: 10)]);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<RenderResult> render(RenderRequest request, {void Function(RenderProgress progress)? onProgress}) async {
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(delay);
    active--;
    return RenderResult(status: RenderStatus.completed, outputPath: request.outputPath);
  }
}

RenderRequest _request(String name) => RenderRequest(
      project: const SceneProject(
        id: 'queue-test',
        title: 'Queue test',
        width: 1080,
        height: 1920,
        scenes: [EditableAdScene(
          id: 's1', index: 1, kind: SceneKind.hook, duration: 1,
          narration: '', onScreenText: '', visualType: VisualType.productHero,
        )],
      ),
      outputPath: name,
    );

void main() {
  test('each queued job future completes with its own state', () async {
    final engine = _QueueRenderer();
    final queue = RenderQueue(engine: engine, maxConcurrent: 1);
    final first = queue.enqueue(RenderJob(id: 'one', request: _request('one')));
    final second = queue.enqueue(RenderJob(id: 'two', request: _request('two')));

    final states = await Future.wait([first, second]);
    expect(states.map((s) => s.id), containsAllInOrder(['one', 'two']));
    expect(states.every((s) => s.status == RenderStatus.completed), isTrue);
    expect(engine.maxActive, 1);
    await queue.close();
  });

  test('duplicate ids are rejected', () async {
    final queue = RenderQueue(engine: _QueueRenderer());
    await queue.enqueue(RenderJob(id: 'same', request: _request('same'))).then((_) {});
    await expectLater(
      queue.enqueue(RenderJob(id: 'same', request: _request('same'))),
      throwsStateError,
    );
    await queue.close();
  });

  test('close resolves pending jobs as cancelled', () async {
    final engine = _QueueRenderer(const Duration(milliseconds: 50));
    final queue = RenderQueue(engine: engine, maxConcurrent: 1);
    final first = queue.enqueue(RenderJob(id: 'running', request: _request('running')));
    final second = queue.enqueue(RenderJob(id: 'pending', request: _request('pending')));
    await queue.close();

    final pending = await second;
    expect(pending.status, RenderStatus.cancelled);
    expect((await first).status, RenderStatus.completed);
  });
}
