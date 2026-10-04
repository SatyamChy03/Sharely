part of 'protocol_message.dart';

const _allowedLinkSchemes = {'http', 'https'};

/// A web link to open on the receiver. Only http and https are allowed,
/// so a peer can never trigger file://, intent:// or javascript: URLs.
final class LinkMessage extends ProtocolMessage {
  const new _(this.url);

  /// The only way to build a link, so unsafe schemes can never be sent.
  factory parse(String raw) => LinkMessage._(parseSafeWebUrl(raw));

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'url'});
    return LinkMessage.parse(
      fields.string('url', maxLength: ProtocolLimits.maxUrlChars),
    );
  }

  final Uri url;

  @override
  MessageType get type => MessageType.link;

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'url': url.toString()};
}

/// Parses [raw] and accepts only absolute http(s) URLs with a host.
Uri parseSafeWebUrl(String raw) {
  final url = Uri.tryParse(raw.trim());
  final isSafe =
      url != null &&
      _allowedLinkSchemes.contains(url.scheme.toLowerCase()) &&
      url.host.isNotEmpty &&
      url.userInfo.isEmpty;
  if (!isSafe) throw const ProtocolException('"url" is not a safe web link');
  return url;
}
