import 'dart:io';

import 'package:test/test.dart';
import 'package:asazu_studio/studio_runtime.dart';
import 'package:asazu_studio/scene_builder.dart';

void main() {
  test('project ids that sanitize similarly do not collide', () async {
    final root = await Directory.systemTemp.createTemp('asazu-runtime-');
    final store = StudioProjectStore(config: StudioConfig(workspace: root));
    expect(store.projectFile('a/b').path, isNot(store.projectFile('a_b').path));
    await root.delete(recursive: true);
  });

  test('empty project id is rejected', () async {
    final root = await Directory.systemTemp.createTemp('asazu-runtime-');
    final store = StudioProjectStore(config: StudioConfig(workspace: root));
    expect(() => store.projectFile('   '), throwsArgumentError);
    await root.delete(recursive: true);
  });

  test('backup preserves previous on-disk version', () async {
    final root = await Directory.systemTemp.createTemp('asazu-runtime-');
    final config = StudioConfig(workspace: root);
    final store = StudioProjectStore(config: config);
    final first = const SceneProject(id: 'demo',title: 'old',width: 720,height: 1280,fps: 30,scenes: [],);
    final second = const SceneProject(id: 'demo',title: 'new',width: 720,height: 1280,fps: 30,scenes: [],);
    await store.save(first, createBackup: false);
    await store.save(second, createBackup: true);
    final backups = config.backups.listSync().whereType<File>().toList();
    expect(backups, isNotEmpty);
    expect(await backups.single.readAsString(), contains('"title": "old"'));
    await root.delete(recursive: true);
  });
}
