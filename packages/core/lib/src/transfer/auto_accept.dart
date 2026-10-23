import 'package:sharely_core/src/protocol/protocol_message.dart';

/// The most an offer may hold and still be accepted without a prompt.
const int maxAutoAcceptBytes = 4 * 1024 * 1024 * 1024;

/// Whether [offer] may skip the prompt for a sender set to "always accept".
///
/// Trust in a device is not trust in everything it might ever send: a
/// compromised phone must not be able to fill the disk unasked, so a very
/// large offer always goes to the person at the receiving device.
bool canAcceptWithoutAsking(OfferMessage offer) =>
    offer.totalBytes <= maxAutoAcceptBytes;
