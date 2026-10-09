import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

const int _chunkBytes = 1 << 20;

// Enough read-ahead to keep Wi-Fi busy, bounded so a slow network can't
// pull a whole video into memory.
const _chunksInFlight = 4;

const _eintr = 4;
const _seekFromStart = 0;

/// Streams the bytes behind [fd], an Android descriptor from the picker.
///
/// Reads block, and a cloud document can block for a long time, so they run
/// on their own isolate instead of stalling the UI. Every call starts from
/// the first byte again, which is what resuming a broken send needs.
Stream<Uint8List> readFileDescriptor(int fd) async* {
  final replies = ReceivePort();
  final iterator = StreamIterator<Object?>(replies);
  Isolate? reader;
  SendPort? requests;
  try {
    reader = await Isolate.spawn(_serveChunks, (
      fd: fd,
      replies: replies.sendPort,
    ));
    if (!await iterator.moveNext()) return;
    final handshake = iterator.current;
    if (handshake is! SendPort) return;
    requests = handshake;
    for (var i = 0; i < _chunksInFlight; i++) {
      requests.send(true);
    }
    while (await iterator.moveNext()) {
      final reply = iterator.current;
      if (reply == null) return;
      if (reply is int) {
        throw FileSystemException('Read failed', '', OSError('', reply));
      }
      if (reply is! TransferableTypedData) return;
      requests.send(true);
      yield reply.materialize().asUint8List();
    }
  } finally {
    // Before the handshake the reader holds nothing, so stopping it is safe.
    if (requests == null) reader?.kill();
    requests?.send(false);
    await iterator.cancel();
  }
}

/// Closes a descriptor the picker handed over; safe to call once per fd.
void closeFileDescriptor(int fd) => _Libc.instance.close(fd);

typedef _Read = int Function(int fd, Pointer<Uint8> buffer, int count);
typedef _Close = int Function(int fd);
typedef _Seek = int Function(int fd, int offset, int whence);
typedef _Malloc = Pointer<Uint8> Function(int bytes);
typedef _Free = void Function(Pointer<Uint8> buffer);
typedef _ErrnoLocation = Pointer<Int32> Function();

// Linux is supported too so the reader can be tested on a desktop.
final class _Libc {
  new _()
    : _library = DynamicLibrary.open(
        Platform.isAndroid ? 'libc.so' : 'libc.so.6',
      );

  static final _Libc instance = _Libc._();

  final DynamicLibrary _library;

  late final _Read read = _library
      .lookupFunction<IntPtr Function(Int32, Pointer<Uint8>, Size), _Read>(
        'read',
      );
  late final _Close close = _library
      .lookupFunction<Int32 Function(Int32), _Close>('close');
  // The 64-bit variant: plain lseek takes a 32-bit offset on 32-bit phones.
  late final _Seek seek = _library
      .lookupFunction<Int64 Function(Int32, Int64, Int32), _Seek>('lseek64');
  late final _Malloc malloc = _library
      .lookupFunction<Pointer<Uint8> Function(Size), _Malloc>('malloc');
  late final _Free free = _library
      .lookupFunction<Void Function(Pointer<Uint8>), _Free>('free');
  late final _ErrnoLocation _errno = _library
      .lookupFunction<Pointer<Int32> Function(), _ErrnoLocation>(
        Platform.isAndroid ? '__errno' : '__errno_location',
      );

  int get errno => _errno().value;
}

/// Reader isolate: one chunk per `true` request, until EOF, error or `false`.
void _serveChunks(({int fd, SendPort replies}) job) {
  final libc = _Libc.instance;
  final requests = ReceivePort();
  Pointer<Uint8>? allocated;
  // Rewinds for a repeat read. A source that can't seek fails here on its
  // first read too, harmlessly: it is still at its start then.
  libc.seek(job.fd, 0, _seekFromStart);
  job.replies.send(requests.sendPort);

  void finish(Object? lastReply) {
    if (lastReply != false) job.replies.send(lastReply);
    requests.close();
    final buffer = allocated;
    if (buffer != null) libc.free(buffer);
  }

  requests.listen((request) {
    if (request != true) return finish(false);
    final buffer = allocated ??= libc.malloc(_chunkBytes);
    final count = _readOnce(libc, job.fd, buffer);
    if (count < 0) return finish(-count);
    if (count == 0) return finish(null);
    job.replies.send(
      TransferableTypedData.fromList([buffer.asTypedList(count)]),
    );
  });
}

/// Bytes read, 0 at end of file, or minus the errno on failure.
int _readOnce(_Libc libc, int fd, Pointer<Uint8> buffer) {
  while (true) {
    final count = libc.read(fd, buffer, _chunkBytes);
    if (count >= 0) return count;
    final errno = libc.errno;
    if (errno != _eintr) return -errno;
  }
}
