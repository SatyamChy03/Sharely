@TestOn('linux')
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sharely/app/android/file_descriptor_reader.dart';

final _libc = DynamicLibrary.open('libc.so.6');
final int Function(Pointer<Uint8>, int) _open = _libc
    .lookupFunction<
      Int32 Function(Pointer<Uint8>, Int32),
      int Function(Pointer<Uint8>, int)
    >('open');
final Pointer<Uint8> Function(int) _malloc = _libc
    .lookupFunction<
      Pointer<Uint8> Function(Size),
      Pointer<Uint8> Function(int)
    >('malloc');

/// Opens [file] read-only the way Android hands the app a descriptor.
int _openDescriptor(File file) {
  final path = [...file.path.codeUnits, 0];
  final nativePath = _malloc(path.length)
    ..asTypedList(path.length).setAll(0, path);
  return _open(nativePath, 0);
}

void main() {
  late Directory folder;

  setUp(() async => folder = await Directory.systemTemp.createTemp('fd_'));
  tearDown(() => folder.delete(recursive: true));

  Future<List<int>> readAll(int fd) async {
    final bytes = BytesBuilder(copy: false);
    await readFileDescriptor(fd).forEach(bytes.add);
    return bytes.takeBytes();
  }

  test('streams every byte of a file larger than one chunk', () async {
    final bytes = Uint8List.fromList(
      List.generate((3 << 20) + 12345, (i) => i * 13 & 255),
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(bytes);
    final fd = _openDescriptor(file);
    addTearDown(() => closeFileDescriptor(fd));

    expect(await readAll(fd), bytes);
  });

  test('an empty file ends straight away', () async {
    final file = File('${folder.path}/empty')..writeAsBytesSync([]);
    final fd = _openDescriptor(file);
    addTearDown(() => closeFileDescriptor(fd));

    expect(await readAll(fd), isEmpty);
  });

  test('a closed descriptor fails as a file error', () async {
    final file = File('${folder.path}/gone')..writeAsBytesSync([1, 2, 3]);
    final fd = _openDescriptor(file);
    closeFileDescriptor(fd);

    await expectLater(readAll(fd), throwsA(isA<FileSystemException>()));
  });

  test('stopping early leaves nothing running', () async {
    final file = File('${folder.path}/big')
      ..writeAsBytesSync(Uint8List(8 << 20));
    final fd = _openDescriptor(file);
    addTearDown(() => closeFileDescriptor(fd));

    final first = await readFileDescriptor(fd).first;

    expect(first, hasLength(1 << 20));
  });
}
