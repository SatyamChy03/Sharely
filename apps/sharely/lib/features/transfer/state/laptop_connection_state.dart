import 'package:sharely_core/sharely_core.dart';

/// The phone's live link to its paired laptop.
sealed class LaptopConnectionState {
  const new();
}

final class LaptopNotPaired extends LaptopConnectionState {
  const new();
}

/// Paired before addresses were remembered; scanning again fixes it.
final class LaptopNeedsRepairing extends LaptopConnectionState {
  const new(this.laptop);

  final PairedDevice laptop;
}

final class LaptopConnecting extends LaptopConnectionState {
  const new(this.laptop);

  final PairedDevice laptop;
}

final class LaptopConnected extends LaptopConnectionState {
  const new(this.laptop, this.connection);

  final PairedDevice laptop;
  final ControlConnection connection;
}

/// The user chose Disconnect; nothing connects until they choose Connect.
final class LaptopDisconnected extends LaptopConnectionState {
  const new(this.laptop);

  final PairedDevice laptop;
}

final class LaptopUnreachable extends LaptopConnectionState {
  const new(this.laptop);

  final PairedDevice laptop;
}
