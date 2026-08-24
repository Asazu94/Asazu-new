import 'dart:io';

import 'package:test/test.dart';
import '../lib/final_hardening.dart';
import '../lib/import_export.dart';
import '../lib/storage_manager.dart';
import '../lib/scene_builder.dart';

void main() {
  test('project ids cannot escape the projects directory', () async {
    final root = await Directory.systemTemp.createTemp('asazu-storage-hardening-');
    final layout = await StorageLayout.create(root.path);
    final manager = StorageManager(layout);
    final file = await manager.saveProject('../outside/evil', '{"ok":true}');
    expect(file.parent.path, layout.projects.path);
    expect(await file.exists(), isTrue);
    expect(await manager.readProject('../outside/evil'), contains('ok'));
    await root.delete(recursive: true);
  });

  test('media imports do not overwrite an existing filename', () async {
    final root = await Directory.systemTemp.createTemp('asazu-media-hardening-');
    final source = File('${root.path}/product.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final media = Directory('${root.path}/media');
    final importer = MediaImporter();
    final first = await importer.copyIntoMedia(source, media);
    final second = await importer.copyIntoMedia(source, media);
    expect(first.path, isNot(second.path));
    expect(await File(first.path).length(), 3);
    expect(await File(second.path).length(), 3);
    await root.delete(recursive: true);
  });

  test('backup filenames remain unique within the same second', () async {
    final root = await Directory.systemTemp.createTemp('asazu-backup-hardening-');
    const project = SceneProject(id: 'demo', title: 'Demo', width: 1080, height: 1920, scenes: []);
    final manager = const ProjectBackupManager();
    final first = await manager.backup(project, root);
    final second = await manager.backup(project, root);
    expect(first.path, isNot(second.path));
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
    await root.delete(recursive: true);
  });
}
