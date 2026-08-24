import 'dart:io';

import 'package:test/test.dart';
import '../lib/studio_runtime.dart';

void main() {
  test('project ids that sanitize similarly do not collide', () async {
    final root =
        await Directory.systemTemp.createTemp('asazu-runtime-');

    final store = StudioProjectStore(
      config: StudioConfig(workspace: root),
    );

    expect(
      store.projectFile('a/b').path,
      isNot(store.projectFile('a_b').path),
    );

    await root.delete(recursive: true);
  });

  test('empty project id is rejected', () async {
    final root =
        await Directory.systemTemp.createTemp('asazu-runtime-');

    final store = StudioProjectStore(
      config: StudioConfig(workspace: root),
    );

    expect(
      () => store.projectFile('   '),
      throwsArgumentError,
    );

    await root.delete(recursive: true);
  });
}
