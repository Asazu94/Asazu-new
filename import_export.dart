import 'dart:convert';
import 'dart:io';

import 'scene_builder.dart';

class MediaImportResult {
  final String path;
  final String extension;
  final int bytes;
  const MediaImportResult({required this.path, required this.extension, required this.bytes});
}

class MediaImporter {
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const videoExtensions = {'mp4', 'mov', 'mkv', 'webm'};
  static const audioExtensions = {'mp3', 'wav', 'm4a', 'aac', 'ogg'};

  Future<MediaImportResult> copyIntoMedia(File source, Directory mediaDirectory) async {
    if (!await source.exists()) throw FileSystemException('Media file not found', source.path);
    final extension = _extension(source.path);
    final allowed = {...imageExtensions, ...videoExtensions, ...audioExtensions};
    if (!allowed.contains(extension)) throw FormatException('Unsupported media type: .$extension');
    await mediaDirectory.create(recursive: true);
    final safeName = _safeName(source.uri.pathSegments.last);
    var destination = File('${mediaDirectory.path}${Platform.pathSeparator}$safeName');
    var counter = 1;
    final dot = safeName.lastIndexOf('.');
    final stem = dot > 0 ? safeName.substring(0, dot) : safeName;
    final suffix = dot > 0 ? safeName.substring(dot) : '';
    while (await destination.exists()) {
      destination = File('${mediaDirectory.path}${Platform.pathSeparator}$stem-$counter$suffix');
      counter++;
    }
    await source.copy(destination.path);
    return MediaImportResult(path: destination.path, extension: extension, bytes: await destination.length());
  }

  String _extension(String path) => path.split('.').last.toLowerCase();
  String _safeName(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

class ProjectJsonCodec {
  const ProjectJsonCodec();

  String encode(SceneProject project) => const JsonEncoder.withIndent('  ').convert({
    'id': project.id,
    'title': project.title,
    'width': project.width,
    'height': project.height,
    'fps': project.fps,
    'scenes': project.scenes.map((s) => {
      'id': s.id,
      'index': s.index,
      'kind': s.kind.name,
      'duration': s.duration,
      'narration': s.narration,
      'onScreenText': s.onScreenText,
      'visualType': s.visualType.name,
      'assets': s.assets.map((a) => {'id': a.id, 'type': a.type, 'source': a.source}).toList(),
      'avatar': {
        'enabled': s.avatar.enabled,
        'action': s.avatar.action.name,
        'emotion': s.avatar.emotion,
      },
      'captions': {
        'enabled': s.captions.enabled,
        'fontSize': s.captions.fontSize,
        'position': s.captions.position,
        'highlightKeywords': s.captions.highlightKeywords,
      },
      'animation': {
        'camera': s.animation.camera,
        'intensity': s.animation.intensity,
      },
      'transitionIn': s.transitionIn.name,
      'transitionOut': s.transitionOut.name,
      'effects': s.effects.map((e) => {
        'id': e.id,
        'type': e.type.name,
        'intensity': e.intensity,
        'start': e.start,
        'duration': e.duration,
        'enabled': e.enabled,
      }).toList(),
      'background': {
        'type': s.background.type.name,
        'value': s.background.value,
        'opacity': s.background.opacity,
      },
      'captionAnimation': {
        'animation': s.captionAnimation.animation.name,
        'speed': s.captionAnimation.speed,
        'highlightKeywords': s.captionAnimation.highlightKeywords,
      },
    }).toList(),
  });

  Future<void> write(SceneProject project, File file) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(encode(project), flush: true);
  }
}
