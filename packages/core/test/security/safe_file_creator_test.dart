import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory saveDirectory;

  setUp(() async {
    saveDirectory = await Directory.systemTemp.createTemp('sharely_test_');
  });

  tearDown(() => saveDirectory.delete(recursive: true));

  test('creates the file inside the save folder', () async {
    final file = await createUniqueIncomingFile(saveDirectory, 'photo.jpg');
    expect(p.basename(file.path), 'photo.jpg');
    expect(
      p.isWithin(saveDirectory.resolveSymbolicLinksSync(), file.path),
      isTrue,
    );
  });

  test('never overwrites an existing file', () async {
    final existing = File(p.join(saveDirectory.path, 'photo.jpg'));
    await existing.writeAsString('original');

    final first = await createUniqueIncomingFile(saveDirectory, 'photo.jpg');
    final second = await createUniqueIncomingFile(saveDirectory, 'photo.jpg');

    expect(p.basename(first.path), 'photo (1).jpg');
    expect(p.basename(second.path), 'photo (2).jpg');
    expect(await existing.readAsString(), 'original');
  });

  test('a traversal name stays inside the save folder', () async {
    final file = await createUniqueIncomingFile(
      saveDirectory,
      '../../../../tmp/escaped.txt',
    );
    expect(
      file.parent.resolveSymbolicLinksSync(),
      saveDirectory.resolveSymbolicLinksSync(),
    );
    expect(p.basename(file.path), 'escaped.txt');
  });

  test('does not follow a symlink planted at the target name', () async {
    final outside = await Directory.systemTemp.createTemp('sharely_outside_');
    addTearDown(() => outside.delete(recursive: true));
    final target = File(p.join(outside.path, 'victim.txt'));
    await target.writeAsString('untouched');
    await Link(p.join(saveDirectory.path, 'victim.txt')).create(target.path);

    final file = await createUniqueIncomingFile(saveDirectory, 'victim.txt');

    expect(p.basename(file.path), 'victim (1).txt');
    expect(await target.readAsString(), 'untouched');
  });
}
