import 'package:meta/meta.dart';
import 'package:sharely_core/src/protocol/json_fields.dart';
import 'package:sharely_core/src/protocol/protocol_exception.dart';
import 'package:sharely_core/src/protocol/protocol_limits.dart';

part 'device_platform.dart';
part 'hello_message.dart';
part 'link_message.dart';
part 'message_type.dart';
part 'offer_message.dart';
part 'offered_file.dart';
part 'progress_message.dart';
part 'text_content_message.dart';
part 'transfer_decision_message.dart';

/// A control-channel message. Construct incoming ones only via the codec.
@immutable
sealed class ProtocolMessage {
  const new();

  MessageType get type;

  Map<String, Object?> toJson();
}
