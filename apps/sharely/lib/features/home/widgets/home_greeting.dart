import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Top of Home: today's date over a greeting for the time of day.
class HomeGreeting extends StatelessWidget {
  const new({super.key, this.now});

  /// Fixed in tests; the current time otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final moment = now ?? DateTime.now();
    final date =
        '${_weekdays[moment.weekday - 1]}, ${moment.day} '
        '${_months[moment.month - 1]}';
    final greeting = switch (moment.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          date,
          style: textTheme.bodySmall?.copyWith(
            color: SharelyColors.textSecondary,
          ),
        ),
        Text(greeting, style: textTheme.headlineMedium),
      ],
    );
  }
}
