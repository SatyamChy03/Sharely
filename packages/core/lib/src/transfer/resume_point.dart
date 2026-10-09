import 'dart:async';
import 'dart:io';

import 'package:sharely_core/src/net/bounded_body.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/transfer/transfer_exception.dart';

const _maxAnswerBytes = 256;

/// How much of a file the receiver already holds.
typedef ResumePoint = ({int bytes, bool isSaved});

/// Asks the laptop where to continue an upload.
///
/// Returns null when it could not be asked right now (worth another try).
/// Throws [TransferException] when the laptop no longer knows the transfer
/// or answers with something invalid.
Future<ResumePoint?> askResumePoint(
  Uri offsetUri, {
  required Map<String, String> authHeaders,
  required int fileSizeBytes,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(offsetUri);
    authHeaders.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode == HttpStatus.notFound) {
      throw const TransferException(TransferFailure.unreachable);
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    final answer = await readBoundedUtf8(response, _maxAnswerBytes);
    return _parseResumePoint(answer, fileSizeBytes);
  } on ProtocolException {
    throw const TransferException(TransferFailure.refused);
  } on IOException {
    return null;
  } on TimeoutException {
    return null;
  } finally {
    client.close(force: true);
  }
}

// The answer is untrusted: a count past the file's size is refused.
ResumePoint _parseResumePoint(String answer, int fileSizeBytes) {
  final fields = JsonFields(decodeJsonObject(answer))
    ..requireOnlyKeys(const {'bytes', 'saved'});
  return (
    bytes: fields.integer('bytes', min: 0, max: fileSizeBytes),
    isSaved: fields.boolean('saved'),
  );
}
