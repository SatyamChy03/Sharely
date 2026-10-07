import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/typography.dart';
import 'package:sharely/features/laptop/widgets/activity_row.dart';
import 'package:sharely/features/transfer/state/recent_transfer.dart';
import 'package:sharely/features/transfer/state/transfers_by_day.dart';

/// Transfers under Today, Yesterday and Earlier headings.
class ActivityDayGroups extends StatelessWidget {
  const new({required this.transfers, this.showsTime = false, super.key});

  final List<RecentTransfer> transfers;
  final bool showsTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (final day in groupTransfersByDay(transfers)) ...[
          Text(
            day.label,
            style: sharelyMonoStyle(
              size: 11,
              color: SharelyColors.slate,
            ).copyWith(letterSpacing: 1.5),
          ),
          for (final transfer in day.transfers)
            ActivityRow(transfer: transfer, showsTime: showsTime),
        ],
      ],
    );
  }
}
