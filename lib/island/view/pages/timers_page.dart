import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/island_progress.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/timers/island_timer.dart';
import '../../../modules/timers/timer_controller.dart';
import 'page_scaffold.dart';

/// Countdowns and stopwatches: start one in a click, control the running one.
class TimersPage extends StatelessWidget {
  const TimersPage({super.key});

  static const List<int> _presetMinutes = <int>[1, 5, 10, 25];

  @override
  Widget build(BuildContext context) {
    final TimerController timers = AppScope.read(context).timers;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: timers,
      builder: (BuildContext context, _) {
        final IslandTimer? primary = timers.primary;
        final DateTime now = DateTime.now();

        return PageScaffold(
          title: 'Timers',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (primary == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Nothing running',
                      style:
                          DbType.body.copyWith(color: palette.textTertiary),
                    ),
                  ),
                )
              else
                Reveal(
                  order: 1,
                  child: _PrimaryTimer(
                    timer: primary,
                    now: now,
                    timers: timers,
                  ),
                ),
              const Spacer(),
              Reveal(
                order: 2,
                child: Text(
                  'START',
                  style: DbType.overline.copyWith(color: palette.textTertiary),
                ),
              ),
              const SizedBox(height: DbSpace.sm),
              Reveal(
                order: 3,
                scaleFrom: 0.94,
                child: Row(
                  children: <Widget>[
                    for (final int minutes in _presetMinutes) ...<Widget>[
                      IslandButton(
                        icon: DbIcons.timer,
                        label: '$minutes m',
                        tooltip: 'Start a $minutes minute timer',
                        onPressed: () => timers.addCountdown(
                          Duration(minutes: minutes),
                          label: '$minutes min',
                        ),
                      ),
                      const SizedBox(width: DbSpace.sm),
                    ],
                    IslandButton(
                      icon: DbIcons.clock,
                      tooltip: 'Start a stopwatch',
                      onPressed: () => timers.addStopwatch(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryTimer extends StatelessWidget {
  const _PrimaryTimer({
    required this.timer,
    required this.now,
    required this.timers,
  });

  final IslandTimer timer;
  final DateTime now;
  final TimerController timers;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool countdown = timer.kind == TimerKind.countdown;
    final Duration value =
        countdown ? timer.remainingAt(now) : timer.elapsedAt(now);
    final double? progress = timer.progressAt(now);
    final Color valueColor =
        timer.isFinished ? palette.positive : palette.textPrimary;
    final List<IslandTimer> others = timers.timers
        .where((IslandTimer t) => t.id != timer.id)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              countdown
                  ? Formatters.duration(value)
                  : Formatters.stopwatch(value),
              style: DbType.headline.copyWith(color: valueColor),
            ),
            const SizedBox(width: DbSpace.md),
            Expanded(
              child: Text(
                timer.isFinished ? 'Finished' : timer.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DbType.body.copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
        if (progress != null) ...<Widget>[
          const SizedBox(height: DbSpace.md),
          IslandProgressBar(
            value: progress,
            color: timer.isFinished ? palette.positive : palette.accent,
          ),
        ],
        const SizedBox(height: DbSpace.md),
        Row(
          children: <Widget>[
            IslandButton(
              icon: timer.isRunning ? DbIcons.pause : DbIcons.play,
              tone: IslandButtonTone.accent,
              tooltip: timer.isRunning ? 'Pause' : 'Resume',
              onPressed:
                  timer.isFinished ? null : () => timers.toggle(timer.id),
            ),
            const SizedBox(width: DbSpace.sm),
            IslandButton(
              icon: DbIcons.restart,
              tooltip: 'Reset this timer',
              onPressed: () => timers.reset(timer.id),
            ),
            const SizedBox(width: DbSpace.sm),
            IslandButton(
              icon: DbIcons.delete,
              tone: IslandButtonTone.danger,
              tooltip: 'Remove this timer',
              onPressed: () => timers.remove(timer.id),
            ),
            const Spacer(),
            if (others.isNotEmpty)
              Text(
                '${others.length} more',
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
          ],
        ),
      ],
    );
  }
}
