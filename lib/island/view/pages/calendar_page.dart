import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/clock_service.dart';
import '../../../design/components/db_text_field.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/calendar/calendar_controller.dart';
import '../../../modules/calendar/calendar_entry.dart';
import 'page_scaffold.dart';

/// The month, and what you have written on the day you picked.
///
/// Two sections side by side: the grid on the left to move around in, the
/// chosen day on the right to read and write. A note with a time on it is a
/// reminder and a note without one is just a note - they are the same thing in
/// the same list, because "remember this on Thursday" and "tell me at nine on
/// Thursday" differ only by whether a time was given, and making the user
/// choose between two features before typing would be the wrong question.
///
/// Reading the machine's own appointment store needs package identity, which
/// arrives with the MSIX build. Until then everything here is either arithmetic
/// on the date or something the user typed, so nothing on this page is
/// invented.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// Width reserved for the month. The grid needs seven readable columns and
  /// nothing more; every remaining pixel is better spent on the day panel,
  /// which has to hold text.
  static const double _gridWidth = 196;

  DateTime? _month;
  DateTime? _selected;

  /// Which way the last month change went, so the grid slides the way the
  /// calendar is being read rather than always from the same side.
  int _direction = 1;

  DateTime _today(BuildContext context) {
    final DateTime now = AppScope.read(context).clock.now;
    return DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int by) {
    final DateTime current = _month ?? _today(context);
    setState(() {
      _direction = by.sign;
      _month = DateTime(current.year, current.month + by, 1);
    });
  }

  void _goToToday() {
    final DateTime today = _today(context);
    final DateTime current = _month ?? today;
    setState(() {
      _direction = today.isBefore(current) ? -1 : 1;
      _month = DateTime(today.year, today.month, 1);
      _selected = today;
    });
  }

  /// Slides a replaced child in from [_direction] and the old one out the
  /// other side.
  Widget _slide(Widget child, Animation<double> animation, {double travel = 1}) {
    final bool incoming = animation.status != AnimationStatus.reverse;
    final double from = (incoming ? _direction : -_direction) * travel;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(from, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalendarController calendar = AppScope.read(context).calendar;
    final DateTime today = _today(context);
    final DateTime month = _month ?? DateTime(today.year, today.month, 1);
    final DateTime selected = _selected ?? today;
    final bool onCurrentMonth =
        month.year == today.year && month.month == today.month;
    final IslandThemeData theme = IslandTheme.of(context);

    return AnimatedBuilder(
      animation: calendar,
      builder: (BuildContext context, _) => PageScaffold(
        title: ClockFormat.monthYear(month),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!onCurrentMonth) ...<Widget>[
              IslandButton(
                icon: DbIcons.today,
                tooltip: 'Back to today',
                size: DbSize.controlSm,
                onPressed: _goToToday,
              ),
              const SizedBox(width: DbSpace.xs),
            ],
            IslandButton(
              icon: DbIcons.chevronLeft,
              tooltip: 'Previous month',
              size: DbSize.controlSm,
              onPressed: () => _shiftMonth(-1),
            ),
            const SizedBox(width: DbSpace.xs),
            IslandButton(
              icon: DbIcons.chevronRight,
              tooltip: 'Next month',
              size: DbSize.controlSm,
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: _gridWidth,
              child: Reveal(
                order: 1,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: theme.motion.scale(DbDuration.standard),
                    switchInCurve: DbCurve.emphasized,
                    switchOutCurve: DbCurve.exit,
                    layoutBuilder:
                        (Widget? current, List<Widget> previous) => Stack(
                          fit: StackFit.expand,
                          children: <Widget>[...previous, ?current],
                        ),
                    transitionBuilder: (Widget child, Animation<double> a) =>
                        _slide(child, a, travel: 0.35),
                    child: _MonthGrid(
                      key: ValueKey<String>('${month.year}-${month.month}'),
                      month: month,
                      today: today,
                      selected: selected,
                      calendar: calendar,
                      onSelect: (DateTime day) =>
                          setState(() => _selected = day),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DbSpace.lg),
            Expanded(
              child: Reveal(
                order: 2,
                scaleFrom: 0.96,
                child: _DayPanel(
                  key: ValueKey<String>(CalendarEntry.dayKey(selected)),
                  day: selected,
                  today: today,
                  calendar: calendar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six rows of seven, always. A grid that changed height between months would
/// make the page jump as you paged through it.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.calendar,
    required this.onSelect,
    super.key,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final CalendarController calendar;
  final ValueChanged<DateTime> onSelect;

  static const int _rows = 6;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    // DateTime.weekday counts Monday as 1, and the grid starts on Monday, so
    // the offset is simply how far into the week the first lands.
    final int leading = DateTime(month.year, month.month, 1).weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String initial in ClockFormat.weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: DbType.overline.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: DbSpace.xs),
        for (int row = 0; row < _rows; row++)
          Expanded(
            child: Row(
              children: <Widget>[
                for (int column = 0; column < 7; column++)
                  Expanded(
                    child: Builder(
                      builder: (BuildContext context) {
                        // Day numbers outside 1..length roll into the
                        // neighbouring month on their own, which is exactly
                        // the leading and trailing greyed-out days a calendar
                        // wants.
                        final DateTime day = DateTime(
                          month.year,
                          month.month,
                          row * 7 + column + 1 - leading,
                        );
                        return _DayCell(
                          day: day,
                          inMonth: month,
                          today: today,
                          selected: selected,
                          marked: calendar.hasEntriesOn(day),
                          onSelect: onSelect,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.marked,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime inMonth;
  final DateTime today;
  final DateTime selected;

  /// Whether anything is written on this day.
  final bool marked;

  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final bool outside = day.month != inMonth.month;
    final bool isToday = CalendarEntry.sameDay(day, today);
    final bool isSelected = CalendarEntry.sameDay(day, selected);

    final Color text = isSelected
        ? palette.textPrimary
        : (outside
              ? palette.textTertiary.withValues(alpha: 0.45)
              : (isToday ? palette.accent : palette.textSecondary));

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(day),
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.quick),
            curve: DbCurve.emphasized,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.accent.withValues(alpha: 0.22)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: isToday && !isSelected
                  ? Border.all(color: palette.accent.withValues(alpha: 0.55))
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Text(
                  '${day.day}',
                  style: DbType.caption.copyWith(
                    color: text,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                // A day carrying a note says so without the number moving.
                if (marked)
                  Positioned(
                    bottom: 1,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: outside ? palette.textTertiary : palette.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-hand section: one day, what is on it, and a way to add to it.
class _DayPanel extends StatefulWidget {
  const _DayPanel({
    required this.day,
    required this.today,
    required this.calendar,
    super.key,
  });

  final DateTime day;
  final DateTime today;
  final CalendarController calendar;

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'Calendar note');

  bool _timed = false;
  int _minute = 9 * 60;
  String? _editing;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _relative {
    final int days = widget.day.difference(widget.today).inDays;
    if (days == 0) {
      return 'Today';
    }
    if (days == 1) {
      return 'Tomorrow';
    }
    if (days == -1) {
      return 'Yesterday';
    }
    if (days > 0) {
      return days < 14 ? 'In $days days' : 'In ${days ~/ 7} weeks';
    }
    final int ago = -days;
    return ago < 14 ? '$ago days ago' : '${ago ~/ 7} weeks ago';
  }

  void _step(int minutes) {
    setState(() {
      // Wraps within the day rather than spilling into the next one: the day
      // is chosen in the grid, and a time control that silently changed it
      // would be a trap.
      _minute = (_minute + minutes + 1440) % 1440;
      _timed = true;
    });
  }

  void _startEditing(CalendarEntry entry) {
    setState(() {
      _editing = entry.id;
      _text.text = entry.text;
      _timed = entry.hasTime;
      _minute = entry.minuteOfDay ?? _minute;
    });
    _focus.requestFocus();
  }

  void _commit() {
    final String value = _text.text.trim();
    if (value.isEmpty) {
      return;
    }
    final String? editing = _editing;
    if (editing != null) {
      for (final CalendarEntry existing in widget.calendar.entries) {
        if (existing.id != editing) {
          continue;
        }
        widget.calendar.update(
          existing.copyWith(
            text: value,
            minuteOfDay: _timed ? _minute : null,
            clearTime: !_timed,
            // Changing a reminder re-arms it; otherwise editing one that had
            // already fired would leave it silent for ever.
            notified: false,
          ),
        );
        break;
      }
    } else {
      widget.calendar.add(
        day: widget.day,
        text: value,
        minuteOfDay: _timed ? _minute : null,
      );
    }
    setState(() {
      _editing = null;
      _text.clear();
    });
    _focus.requestFocus();
  }

  String get _timeLabel {
    final String hh = (_minute ~/ 60).toString().padLeft(2, '0');
    final String mm = (_minute % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final List<CalendarEntry> entries = widget.calendar.forDay(widget.day);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.card),
        border: Border.all(color: palette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DbSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '${widget.day.day}',
                  style: DbType.title.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(width: DbSpace.sm),
                Text(
                  ClockFormat.weekdayShort(widget.day).toUpperCase(),
                  style: DbType.overline.copyWith(color: palette.textTertiary),
                ),
                const Spacer(),
                Text(
                  _relative,
                  style: DbType.caption.copyWith(color: palette.accent),
                ),
              ],
            ),
            const SizedBox(height: DbSpace.sm),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing on this day',
                        style: DbType.caption.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: entries.length,
                      itemBuilder: (BuildContext context, int index) => _Entry(
                        entry: entries[index],
                        editing: entries[index].id == _editing,
                        onTap: () => _startEditing(entries[index]),
                        onRemove: () {
                          if (_editing == entries[index].id) {
                            setState(() {
                              _editing = null;
                              _text.clear();
                            });
                          }
                          widget.calendar.remove(entries[index].id);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: DbSpace.sm),
            DbTextField(
              controller: _text,
              focusNode: _focus,
              placeholder: _editing == null ? 'Add a note…' : 'Edit the note…',
              textStyle: DbType.caption,
              onSubmitted: (_) => _commit(),
            ),
            const SizedBox(height: DbSpace.sm),
            Row(
              children: <Widget>[
                _TimeToggle(
                  on: _timed,
                  label: _timed ? _timeLabel : 'No time',
                  onToggle: () => setState(() => _timed = !_timed),
                  onEarlier: () => _step(-15),
                  onLater: () => _step(15),
                ),
                const Spacer(),
                IslandButton(
                  icon: _editing == null ? DbIcons.add : DbIcons.check,
                  tooltip: _editing == null ? 'Add' : 'Save',
                  tone: IslandButtonTone.accent,
                  size: DbSize.controlSm,
                  onPressed: _commit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The time control: a switch, and a value only when it is on.
///
/// Stepping the time turns it on, because reaching for the arrows *is* the
/// statement that a time is wanted.
class _TimeToggle extends StatelessWidget {
  const _TimeToggle({
    required this.on,
    required this.label,
    required this.onToggle,
    required this.onEarlier,
    required this.onLater,
  });

  final bool on;
  final String label;
  final VoidCallback onToggle;
  final VoidCallback onEarlier;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = on ? palette.accent : palette.textTertiary;

    return AnimatedContainer(
      duration: theme.motion.scale(DbDuration.micro),
      curve: DbCurve.standard,
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.xs),
      height: DbSize.controlSm,
      decoration: BoxDecoration(
        color: on
            ? palette.accent.withValues(alpha: 0.14)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(DbRadius.pill),
        border: Border.all(
          color: on ? palette.accent.withValues(alpha: 0.34) : palette.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DbSpace.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(DbIcons.timer, size: 11, color: tint),
                    const SizedBox(width: DbSpace.xs),
                    Text(label, style: DbType.caption.copyWith(color: tint)),
                  ],
                ),
              ),
            ),
          ),
          if (on) ...<Widget>[
            const SizedBox(width: DbSpace.xs),
            _Step(icon: DbIcons.collapse, onPressed: onLater),
            _Step(icon: DbIcons.expand, onPressed: onEarlier),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 16,
          height: DbSize.controlSm,
          child: Icon(icon, size: 14, color: palette.textSecondary),
        ),
      ),
    );
  }
}

/// One line in the day's list.
class _Entry extends StatefulWidget {
  const _Entry({
    required this.entry,
    required this.editing,
    required this.onTap,
    required this.onRemove,
  });

  final CalendarEntry entry;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final CalendarEntry entry = widget.entry;

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
            color: widget.editing
                ? palette.accent.withValues(alpha: 0.14)
                : (_hovered ? palette.surfaceRaised : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(DbRadius.control),
          ),
          child: Row(
            children: <Widget>[
              if (entry.hasTime) ...<Widget>[
                Icon(
                  entry.notified ? DbIcons.check : DbIcons.bell,
                  size: 10,
                  color: entry.notified ? palette.textTertiary : palette.accent,
                ),
                const SizedBox(width: DbSpace.xxs),
                Text(
                  entry.timeLabel,
                  style: DbType.caption.copyWith(
                    color: entry.notified
                        ? palette.textTertiary
                        : palette.accent,
                  ),
                ),
                const SizedBox(width: DbSpace.xs),
              ],
              Expanded(
                child: Text(
                  entry.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(color: palette.textSecondary),
                ),
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: theme.motion.scale(DbDuration.micro),
                curve: DbCurve.standard,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(left: DbSpace.xs),
                    child: Icon(
                      DbIcons.close,
                      size: 12,
                      color: palette.textTertiary,
                    ),
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
