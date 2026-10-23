import 'package:sharely_core/sharely_core.dart';
import 'package:test/test.dart';

OfferMessage _offerOf(List<int> sizes) => OfferMessage(
  transferId: 'transfer_0123456789',
  files: [
    for (final size in sizes)
      OfferedFile(name: 'a.bin', sizeBytes: size, mimeType: 'video/mp4'),
  ],
);

void main() {
  test('an ordinary offer may skip the prompt', () {
    expect(canAcceptWithoutAsking(_offerOf([maxAutoAcceptBytes])), isTrue);
  });

  test('a huge file always asks', () {
    expect(canAcceptWithoutAsking(_offerOf([maxAutoAcceptBytes + 1])), isFalse);
  });

  test('many files that add up to too much always ask', () {
    final sizes = List.filled(5, maxAutoAcceptBytes ~/ 4);

    expect(canAcceptWithoutAsking(_offerOf(sizes)), isFalse);
  });
}
