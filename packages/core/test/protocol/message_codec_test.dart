import 'dart:convert';

import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

const _transferId = 'tr_0123456789abcdef';
const _deviceId = 'dev_0123456789abcdef';

void main() {
  group('round trip', _roundTripTests);
  group('rejects malformed frames', _malformedFrameTests);
  group('rejects invalid fields', _invalidFieldTests);
  group('links', _linkTests);
}

void _expectRoundTrip(ProtocolMessage message) {
  final decoded = MessageCodec.decode(MessageCodec.encode(message));
  expect(decoded.runtimeType, message.runtimeType);
  expect(decoded.toJson(), message.toJson());
}

void _expectRejected(Map<String, Object?> json) {
  expect(
    () => MessageCodec.decode(jsonEncode(json)),
    throwsA(isA<ProtocolException>()),
  );
}

void _roundTripTests() {
  test('every message type survives encode then decode', () {
    <ProtocolMessage>[
      const HelloMessage(
        deviceId: _deviceId,
        deviceName: "Satyam's Phone",
        platform: DevicePlatform.android,
      ),
      const OfferMessage(
        transferId: _transferId,
        files: [
          OfferedFile(
            name: 'a.jpg',
            sizeBytes: 1024,
            mimeType: 'image/jpeg',
            sha256: _sha256,
          ),
        ],
      ),
      const TransferDecisionMessage.accept(_transferId),
      const TransferDecisionMessage.reject(_transferId),
      const TransferDecisionMessage.cancel(_transferId),
      const ProgressMessage(transferId: _transferId, bytes: 512),
      const TextContentMessage.text('Hello\nthere\twith tabs'),
      const TextContentMessage.clipboard('482913'),
      LinkMessage.parse('https://example.com/path?q=1'),
    ].forEach(_expectRoundTrip);
  });

  test('offer reports the total size of its files', () {
    const offer = OfferMessage(
      transferId: _transferId,
      files: [
        OfferedFile(
          name: 'a',
          sizeBytes: 10,
          mimeType: 'text/plain',
          sha256: _sha256,
        ),
        OfferedFile(
          name: 'b',
          sizeBytes: 32,
          mimeType: 'text/plain',
          sha256: _sha256,
        ),
      ],
    );
    expect(offer.totalBytes, 42);
  });
}

void _malformedFrameTests() {
  final frames = {
    'not JSON': '{type: hello',
    'a JSON array': '["hello"]',
    'a JSON string': '"hello"',
    'an unknown type': '{"type":"delete_everything"}',
    'a missing type': '{"body":"hi"}',
    'an oversized frame': '{"type":"text","body":"${'a' * 300000}"}',
  };
  for (final MapEntry(key: description, value: frame) in frames.entries) {
    test(description, () {
      expect(
        () => MessageCodec.decode(frame),
        throwsA(isA<ProtocolException>()),
      );
    });
  }
}

void _invalidFieldTests() {
  for (final MapEntry(key: description, value: json)
      in _invalidFieldCases.entries) {
    test(description, () => _expectRejected(json));
  }
}

void _linkTests() {
  final unsafeUrls = [
    'javascript:alert(1)',
    'file:///etc/passwd',
    'intent://scan#Intent;scheme=zxing;end',
    'ftp://example.com',
    'https://',
    'https://user:pass@example.com',
    'not a url',
  ];
  for (final url in unsafeUrls) {
    test('rejects $url', () => _expectRejected({'type': 'link', 'url': url}));
  }

  test('LinkMessage.parse refuses unsafe schemes for outgoing links', () {
    expect(
      () => LinkMessage.parse('javascript:alert(1)'),
      throwsA(isA<ProtocolException>()),
    );
  });
}

const _sha256 =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

const Map<String, Object?> _validFile = {
  'name': 'a.jpg',
  'size': 1,
  'mime': 'image/jpeg',
  'sha256': _sha256,
};

// Attack and malformed inputs, each of which must be rejected.
final _invalidFieldCases = <String, Map<String, Object?>>{
  'an unexpected extra field': {
    'type': 'accept',
    'transferId': _transferId,
    'admin': true,
  },
  'a too-short id': {'type': 'accept', 'transferId': 'short'},
  'an id with path characters': {
    'type': 'accept',
    'transferId': '../../etc/passwd_x',
  },
  'a size given as a string': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'size': '1'},
    ],
  },
  'a negative size': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'size': -1},
    ],
  },
  'an offer with no files': {
    'type': 'offer',
    'transferId': _transferId,
    'files': <Object?>[],
  },
  'a file name with a NUL byte': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'name': 'a\u0000.jpg'},
    ],
  },
  'a malformed MIME type': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'mime': 'image jpeg'},
    ],
  },
  'a missing checksum': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile}..remove('sha256'),
    ],
  },
  'an uppercase checksum': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'sha256': 'AB' * 32},
    ],
  },
  'a short checksum': {
    'type': 'offer',
    'transferId': _transferId,
    'files': [
      {..._validFile, 'sha256': 'ab' * 31},
    ],
  },
  'too many files': {
    'type': 'offer',
    'transferId': _transferId,
    'files': List.filled(1001, _validFile),
  },
  'a negative progress': {
    'type': 'progress',
    'transferId': _transferId,
    'bytes': -5,
  },
  'an unknown platform': {
    'type': 'hello',
    'deviceId': _deviceId,
    'name': 'X',
    'platform': 'toaster',
    'protocolVersion': 1,
  },
  'a device name with control characters': {
    'type': 'hello',
    'deviceId': _deviceId,
    'name': 'Evil\u001b[31m',
    'platform': 'linux',
    'protocolVersion': 1,
  },
  'a text body with a NUL byte': {'type': 'text', 'body': 'hi\u0000'},
};
