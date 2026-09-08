import 'dart:ui';

import '../../design/tokens/db_dimens.dart';
import 'island_state.dart';

/// The target shape of the island for a given state.
///
/// Pure data with no Flutter dependency, which keeps the geometry rules
/// testable on their own and stops layout maths from leaking into widgets.
class IslandGeometry {
  const IslandGeometry({
    required this.width,
    required this.height,
    required this.topRadius,
    required this.bottomRadius,
    required this.expansion,
    required this.shadow,
  });

  final double width;
  final double height;
  final double topRadius;
  final double bottomRadius;

  /// 0 collapsed, 1 fully expanded. Content cross-fades on this, so it is part
  /// of the geometry rather than a separate animation.
  final double expansion;

  /// Shadow strength: the island lifts off the bezel as it opens.
  final double shadow;

  Size get size => Size(width, height);

  @override
  String toString() =>
      'IslandGeometry(${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)}'
      ', r=${bottomRadius.toStringAsFixed(1)}, e=$expansion)';
}

/// Resolves state into geometry.
///
/// Size is a function of *content*, not of a fixed layout: a media session
/// needs more room than a clock, a notification needs a line of text, and a
/// download needs a progress rail. Each mode declares what it needs here, in
/// one table, so the stage can be sized from a single known maximum.
class IslandMetrics {
  const IslandMetrics._();

  /// How much the island grows under the cursor. Enough to acknowledge the
  /// pointer, not enough to be mistaken for opening.
  static const Size _peekGrowth = Size(28, 6);

  /// The settings surface. Far larger than any island face, which is why it
  /// gets a stage of its own rather than stretching the island's.
  static const Size settingsSize = Size(880, 596);

  /// The expanded island. One size for every page, deliberately: a pager whose
  /// viewport resized as you swiped would make the shape the loudest thing on
  /// screen. Transient faces (a notification, a recording notice) keep their
  /// own smaller sizes because they are not part of the pager.
  static const Size pagerSize = Size(486, 322);

  /// Extra collapsed width per Live Activity shown beside the clock.
  static const double activityWidth = 62;

  /// The resting pill, widened by one step per Live Activity flanking the
  /// clock. Computed rather than measured so the spring always has a definite
  /// target to travel towards.
  static Size collapsedSizeFor(IslandMode mode, {int activities = 0}) {
    final int extra = activities.clamp(0, 2);
    switch (mode) {
      case IslandMode.notification:
        return const Size(300, 40);
      case IslandMode.privacy:
        return const Size(168, 32);
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
      case IslandMode.settings:
        return Size(
          DbSize.collapsedWidth + extra * activityWidth,
          DbSize.collapsedHeight,
        );
    }
  }

  static Size expandedSizeFor(IslandMode mode) {
    switch (mode) {
      case IslandMode.notification:
        return const Size(404, 152);
      case IslandMode.privacy:
        return const Size(376, 148);
      case IslandMode.settings:
        return settingsSize;
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
        // Everything else opens into the pager.
        return pagerSize;
    }
  }

  static IslandGeometry resolve({
    required IslandIntent intent,
    required IslandMode mode,
    required bool hovered,
    double scale = 1.0,
    double cornerScale = 1.0,
    int activities = 0,
  }) {
    switch (intent) {
      case IslandIntent.hidden:
        // Retracts upward into the bezel rather than fading in place: the
        // island should look like it is withdrawing into the edge of the
        // screen, which is where it lives.
        return IslandGeometry(
          width:
              collapsedSizeFor(mode, activities: activities).width *
              scale *
              0.72,
          height: 0,
          topRadius: DbRadius.islandTop,
          bottomRadius: DbRadius.islandCollapsedBottom * cornerScale,
          expansion: 0,
          shadow: 0,
        );

      case IslandIntent.collapsed:
        final Size base = collapsedSizeFor(mode, activities: activities);
        if (hovered) {
          return IslandGeometry(
            width: (base.width + _peekGrowth.width) * scale,
            height: (base.height + _peekGrowth.height) * scale,
            topRadius: DbRadius.islandTop,
            bottomRadius: DbRadius.islandPeekBottom * cornerScale,
            expansion: 0,
            shadow: 0.45,
          );
        }
        return IslandGeometry(
          width: base.width * scale,
          height: base.height * scale,
          topRadius: DbRadius.islandTop,
          bottomRadius: DbRadius.islandCollapsedBottom * cornerScale,
          expansion: 0,
          shadow: 0.2,
        );

      case IslandIntent.expanded:
        final Size expanded = expandedSizeFor(mode);
        return IslandGeometry(
          width: expanded.width * scale,
          height: expanded.height * scale,
          topRadius: DbRadius.islandTop,
          bottomRadius: DbRadius.islandExpandedBottom * cornerScale,
          expansion: 1,
          shadow: 1,
        );
    }
  }

  /// The island rectangle inside the stage, given a live geometry.
  ///
  /// The island is centred horizontally and anchored to the very top of the
  /// stage, which sits at the top edge of the monitor.
  static Rect islandRect(Size stage, double width, double height) {
    final double left = ((stage.width - width) / 2).clamp(0.0, stage.width);
    return Rect.fromLTWH(left, 0, width, height);
  }

  /// The rectangle that should receive mouse input, slightly larger than the
  /// island so the cursor is caught just before it touches the shape.
  static Rect hitRect(Rect island) {
    return Rect.fromLTRB(
      island.left - DbSize.hoverPaddingX,
      island.top,
      island.right + DbSize.hoverPaddingX,
      island.bottom + DbSize.hoverPaddingY,
    );
  }

  /// How far outside the resting pill the cursor counts as "approaching".
  ///
  /// Generous sideways, tight downward: the pointer usually arrives along the
  /// top edge of the screen rather than from below, and a tall zone would keep
  /// waking the island while someone works in the top of a window.
  static const double revealMarginX = 130;
  static const double revealMarginY = 20;

  /// The area a hidden island watches for the cursor.
  ///
  /// Deliberately computed from the idle pill rather than from the current
  /// mode: the island is not on screen when this matters, so a zone that moved
  /// with a live activity would move for a reason the user cannot see.
  static Rect revealZone(Size stage, {double scale = 1.0}) {
    final Size pill = collapsedSizeFor(IslandMode.idle);
    final double width = pill.width * scale + revealMarginX * 2;
    final double height = pill.height * scale + revealMarginY;
    final double left = ((stage.width - width) / 2).clamp(0.0, stage.width);
    return Rect.fromLTWH(left, 0, width, height);
  }

  /// Stage size needed to hold every island state plus room for shadow.
  ///
  /// Derived from the declared maxima rather than from any particular mode, so
  /// adding a larger module cannot silently start clipping the shadow.
  static Size stageSize({double scale = 1.0, bool panel = false}) {
    if (panel) {
      return Size(
        settingsSize.width * scale + DbSize.stagePadding,
        settingsSize.height * scale + DbSize.stagePadding,
      );
    }
    return Size(
      DbSize.maxWidth * scale + DbSize.stagePadding * 2,
      DbSize.maxHeight * scale + DbSize.stagePadding,
    );
  }

  /// Every mode must fit inside the declared maximum; asserted by the tests so
  /// a new module cannot quietly outgrow the stage.
  static bool fitsInStage(IslandMode mode) {
    final Size expanded = expandedSizeFor(mode);
    final Size stage = stageSize(panel: mode.needsPanelStage);
    return expanded.width <= stage.width && expanded.height <= stage.height;
  }
}
