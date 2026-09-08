import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/clock_service.dart';
import '../../../core/time/seconds_scope.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/rolling_text.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/calendar/calendar_controller.dart';
import '../../../modules/calendar/calendar_entry.dart';
import '../../../modules/system/system_controller.dart';
import '../../../modules/timers/island_timer.dart';
import '../../../modules/timers/timer_controller.dart';
import '../../../native/system_bridge.dart';
import '../../state/island_controller.dart';
import '../../state/island_page.dart';
import '../../state/island_state.dart';
import 'intro_banner.dart';
import 'page_scaffold.dart';

/// The home page: the time, what is on today, and the few actions worth
/// reaching without going anywhere else.
///
/// The middle of this page used to be empty, which was defensible when it was
/// only a clock and indefensible once there was something true to put there.
/// What it carries now is the answer to the question people actually open a
/// clock for - *what is next* - assembled from the notes on today's date and
/// any timer that is running, and from nothing else.
class NowPage extends StatelessWidget {
  const NowPage({required this.controller, super.key});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool use24Hour = services.settings.settings.use24HourClock;

    return SecondsScope(
      child: PageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Reveal(
              order: 0,
              child: AnimatedBuilder(
                animation: services.clock,
                builder: (BuildContext context, _) {
                  final DateTime now = services.clock.now;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          // The hero. Light rather than bold, tracked tight,
                          // and rolling only the digits that changed.
                          RollingText(
                            ClockFormat.time(now, use24Hour: use24Hour),
                            style: DbType.display.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: DbSpace.sm),
                          // Seconds are deliberately not rolled: a digit
                          // animating once a second at the top of the screen
                          // is the ambient motion this design exists to avoid.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              use24Hour
                                  ? ClockFormat.seconds(now)
                                  : ClockFormat.meridiem(now),
                              style: DbType.numeric.copyWith(
                                color: palette.accent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _WeekChip(now: now),
                        ],
                      ),
                      const SizedBox(height: DbSpace.sm),
                      // The date as one wide-tracked line, with the weekday
                      // carried in the accent so the eye lands on the word that
                      // answers "which day is it" before the number does.
                      _Dateline(now: now),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: DbSpace.md),
            Expanded(
              child: Reveal(
                order: 1,
                scaleFrom: 0.97,
                child: _Today(controller: controller),
              ),
            ),
            const SizedBox(height: DbSpace.md),
            const IntroBanner(),
            Reveal(order: 2, child: const _StatusLine()),
            const SizedBox(height: DbSpace.md),
            Reveal(
              order: 3,
              scaleFrom: 0.95,
              child: _Actions(controller: controller, services: services),
            ),
          ],
        ),
      ),
    );
  }
}

/// `TUESDAY · 8 SEPTEMBER`, hairline-separated.
///
/// Small caps at this size read as a label rather than as a sentence, which is
/// what lets the clock above it stay the only loud thing on the page.
class _Dateline extends StatelessWidget {
  const _Dateline({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    // `longDate` is "Tuesday, 8 September"; the weekday is everything before
    // the comma, and the rest is the day and month.
    final String full = ClockFormat.longDate(now);
    final int comma = full.indexOf(',');
    final String weekday = comma < 0 ? full : full.substring(0, comma);
    final String rest = comma < 0 ? '' : full.substring(comma + 2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          weekday.toUpperCase(),
          style: DbType.dateline.copyWith(color: palette.accent),
        ),
        if (rest.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm),
            child: Container(
              width: 1,
              height: 9,
              color: palette.separator,
            ),
          ),
          Flexible(
            child: Text(
              rest.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.dateline.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// The ISO week number, which is the one piece of calendar arithmetic people
/// routinely need and no clock ever shows them.
class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.pill),
        border: Border.all(color: palette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DbSpace.sm,
          vertical: DbSpace.xxs,
        ),
        child: Text(
          'Week ${ClockFormat.isoWeek(now)}',
          style: DbType.caption.copyWith(color: palette.textTertiary),
        ),
      ),
    );
  }
}

/// What is on today: notes with a time first, then untimed ones, then any
/// timer that is running. Three lines at most, because this is a glance.
class _Today extends StatelessWidget {
  const _Today({required this.controller});

  final IslandController controller;

  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.calendar,
        services.timers,
        services.clock,
      ]),
      builder: (BuildContext context, _) {
        final CalendarController calendar = services.calendar;
        final TimerController timers = services.timers;
        final DateTime now = services.clock.now;

        final List<CalendarEntry> today = calendar.forDay(now);
        final List<IslandTimer> running = <IslandTimer>[
          for (final IslandTimer timer in timers.timers)
            if (timer.isRunning) timer,
        ];
        final int total = today.length + running.length;

        final List<Widget> rows = <Widget>[];
        for (final CalendarEntry entry in today) {
          if (rows.length >= _maxRows) {
            break;
          }
          rows.add(
            _Row(
              icon: entry.hasTime ? DbIcons.bell : DbIcons.notes,
              lead: entry.hasTime ? entry.timeLabel : '',
              text: entry.text,
              // A reminder that has already been shown is history, not agenda.
              dimmed: entry.notified,
              onTap: () => controller.goToPage(IslandPage.calendar),
            ),
          );
        }
        for (final IslandTimer timer in running) {
          if (rows.length >= _maxRows) {
            break;
          }
          rows.add(
            _Row(
              icon: DbIcons.timer,
              lead: Formatters.stopwatch(
                timer.kind == TimerKind.countdown
                    ? timer.remainingAt(now)
                    : timer.elapsedAt(now),
              ),
              text: timer.displayLabel,
              onTap: () => controller.goToPage(IslandPage.timers),
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(DbRadius.card),
            border: Border.all(color: palette.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.md,
              vertical: DbSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'TODAY',
                      style: DbType.overline.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    if (total > rows.length)
                      Text(
                        '+${total - rows.length} more',
                        style: DbType.caption.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: rows.isEmpty
                      ? _Empty(controller: controller)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Nothing on today.',
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
          const SizedBox(width: DbSpace.sm),
          IslandButton(
            icon: DbIcons.calendar,
            label: 'Add a note',
            tooltip: 'Open the calendar',
            size: DbSize.controlSm,
            onPressed: () => controller.goToPage(IslandPage.calendar),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.icon,
    required this.lead,
    required this.text,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String lead;
  final String text;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = widget.dimmed ? palette.textTertiary : palette.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          margin: const EdgeInsets.only(bottom: DbSpace.xxs),
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.xs,
            vertical: DbSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceRaised : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DbRadius.control),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 11, color: tint),
              if (widget.lead.isNotEmpty) ...<Widget>[
                const SizedBox(width: DbSpace.xs),
                Text(
                  widget.lead,
                  style: DbType.numeric.copyWith(color: tint),
                ),
              ],
              const SizedBox(width: DbSpace.sm),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(
                    color: widget.dimmed
                        ? palette.textTertiary
                        : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet line of machine state. Each reading appears only when it has
/// something true to say.
class _StatusLine extends StatelessWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context) {
    final SystemController system = AppScope.read(context).system;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: system,
      builder: (BuildContext context, _) {
        if (!system.isEnabled) {
          return const SizedBox.shrink();
        }
        final PowerStatus power = system.power;
        final NetworkStatus network = system.network;
        final VolumeStatus volume = system.volume;

        return Row(
          children: <Widget>[
            if (power.hasBattery)
              _Chip(
                icon: DbIcons.battery,
                label: '${power.percent}%',
                tone: power.isCritical
                    ? palette.negative
                    : (power.isLow ? palette.warning : null),
              ),
            _Chip(
              icon: network.isWifi ? DbIcons.wifi : DbIcons.network,
              label: network.connected
                  ? (network.isWifi && network.ssid.isNotEmpty
                        ? network.ssid
                        : 'Connected')
                  : 'Offline',
              tone: network.connected ? null : palette.textTertiary,
            ),
            if (volume.available)
              _Chip(
                icon: volume.muted ? DbIcons.muted : DbIcons.volume,
                label: volume.muted ? 'Muted' : '${volume.percent}%',
                tone: volume.muted ? palette.textTertiary : null,
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color color = tone ?? palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: DbSpace.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: DbSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller, required this.services});

  final IslandController controller;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'DynamicBar',
            style: DbType.label.copyWith(color: palette.textTertiary),
          ),
        ),
        IslandButton(
          icon: DbIcons.settings,
          tooltip: 'Open settings',
          onPressed: services.router.openSettings,
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.visibilityOff,
          tooltip: 'Hide the island until it is next needed',
          onPressed: () => controller.hide(trigger: IslandTrigger.user),
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.pause,
          tooltip: 'Pause DynamicBar',
          onPressed: () => controller.setPaused(true),
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.power,
          tone: IslandButtonTone.danger,
          tooltip: 'Quit DynamicBar',
          onPressed: () => services.window.quit(),
        ),
      ],
    );
  }
}
