part of 'protocol_message.dart';

/// The phone saying whether Sharely is on its screen.
///
/// Android pauses an app that is off screen, for example while the user
/// picks a file, so it cannot answer for a while. Told this, the laptop
/// waits longer before it takes the silence for a lost link.
final class PresenceMessage extends ProtocolMessage {
  const new({required this.isOnScreen});

  factory fromFields(JsonFields fields) {
    fields.requireOnlyKeys(const {'type', 'onScreen'});
    return PresenceMessage(isOnScreen: fields.boolean('onScreen'));
  }

  final bool isOnScreen;

  @override
  MessageType get type => MessageType.presence;

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'onScreen': isOnScreen};
}
