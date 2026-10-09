import 'package:sharely/features/transfer/state/recent_transfer.dart';

/// Which way the transfers on the Activity screen went.
enum ActivityFilter {
  all('All'),
  sent('Sent'),
  received('Received');

  new(this.label);

  final String label;

  List<RecentTransfer> apply(List<RecentTransfer> transfers) {
    final direction = switch (this) {
      ActivityFilter.all => null,
      ActivityFilter.sent => TransferDirection.sent,
      ActivityFilter.received => TransferDirection.received,
    };
    if (direction == null) return transfers;
    return [
      for (final transfer in transfers)
        if (transfer.direction == direction) transfer,
    ];
  }
}
