import 'package:craft_kit/craft_kit.dart';
import 'package:flutter/foundation.dart';

/// What a direction does in the swipe lab. `off` means no behavior at all.
/// The look of the drag overlay: the classic framed stamps, or a colour wash
/// with an icon badge.
enum OverlayStyle { badge, stamps }

enum DirectionAction { off, dismiss, consume, springBack, sendToBack, undo }

/// A label for a [DirectionAction].
extension DirectionActionLabel on DirectionAction {
  /// Shown in the control center.
  String get label => switch (this) {
    DirectionAction.off => 'off (blocked)',
    DirectionAction.dismiss => 'dismiss',
    DirectionAction.consume => 'consume into button',
    DirectionAction.springBack => 'spring back (task)',
    DirectionAction.sendToBack => 'send to back',
    DirectionAction.undo => 'undo (bring back previous)',
  };
}

/// Every setting the control center can change, live.
///
/// The demo listens to it and rebuilds the stack with new parameters, so a
/// change is visible on the next touch without restarting anything.
class SwipeLabSettings extends ChangeNotifier {
  /// Creates the settings with the defaults.
  SwipeLabSettings() {
    _load(SwipePhysics.smooth);
  }

  // ---- physics ----
  String preset = 'smooth';
  double commitThreshold = 0.3;
  double projectionTime = 0.18;
  double minCommitDistance = 8;
  double maxAngle = 0.25;
  double rubberBandLimit = 36;
  double programmaticSpeed = 1400;
  double triggerKick = 900;
  bool grabTilt = true;
  late SwipeSpring settle;
  late SwipeSpring fling;
  late SwipeSpring consume;
  late SwipeSpring undo;
  late SwipeSpring promote;

  // ---- layout ----
  int visibleCards = 3;
  double stackOffset = 14;
  double scaleStep = 0.06;
  double tilt = 0;

  // ---- directions ----
  final Map<SwipeDirection, DirectionAction> actions =
      <SwipeDirection, DirectionAction>{
        SwipeDirection.left: DirectionAction.dismiss,
        SwipeDirection.right: DirectionAction.consume,
        SwipeDirection.up: DirectionAction.springBack,
        SwipeDirection.down: DirectionAction.undo,
      };

  /// Directions whose swipes are refused for the card named Coral (a guard).
  final Set<SwipeDirection> refusing = <SwipeDirection>{};
  double consumeEndScale = 0.08;
  double consumeArc = 0.2;
  bool consumeFade = true;
  SwipeConsumeEffect consumeEffect = SwipeConsumeEffect.genie;
  double genieLag = 0.45;

  // ---- input and feedback ----
  bool enabled = true;
  bool keyboard = true;
  bool reduceMotion = false;
  bool hapticThreshold = true;
  bool hapticCommit = true;
  bool showStamps = true;
  OverlayStyle overlayStyle = OverlayStyle.badge;

  // ---- deck ----
  int deckSize = 8;
  int historyLimit = 20;
  bool infinite = false;
  int needMoreThreshold = 3;
  int preloadCount = 2;

  /// Pause, in milliseconds, between cards of a rewind.
  int rewindStagger = 90;

  /// Bumped to make the demo rebuild its deck.
  int deckVersion = 0;

  /// The newest events first, for the event log.
  final List<String> events = <String>[];

  /// Ticks whenever [events] changes. The log has its own notifier so that
  /// logging never rebuilds the demo (and with it, every card).
  final ValueNotifier<int> logVersion = ValueNotifier<int>(0);

  /// Applies a change and notifies.
  void change(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Applies a physics change, which makes the preset "custom".
  void changePhysics(VoidCallback fn) {
    fn();
    preset = 'custom';
    notifyListeners();
  }

  /// Loads one of the built-in physics presets.
  void loadPreset(String name) {
    _load(switch (name) {
      'snappy' => SwipePhysics.snappy,
      'bouncy' => SwipePhysics.bouncy,
      _ => SwipePhysics.smooth,
    });
    preset = name;
    notifyListeners();
  }

  void _load(SwipePhysics p) {
    commitThreshold = p.commitThreshold;
    projectionTime = p.projectionTime;
    minCommitDistance = p.minCommitDistance;
    maxAngle = p.maxAngle;
    rubberBandLimit = p.rubberBandLimit;
    programmaticSpeed = p.programmaticSpeed;
    triggerKick = p.triggerKick;
    grabTilt = p.grabTilt;
    settle = p.settle;
    fling = p.fling;
    consume = p.consume;
    undo = p.undo;
    promote = p.promote;
  }

  /// Starts a fresh deck.
  void regenerate() {
    deckVersion++;
    notifyListeners();
  }

  /// Puts every setting back to its default.
  void resetAll() {
    _load(SwipePhysics.smooth);
    preset = 'smooth';
    visibleCards = 3;
    stackOffset = 14;
    scaleStep = 0.06;
    tilt = 0;
    actions
      ..[SwipeDirection.left] = DirectionAction.dismiss
      ..[SwipeDirection.right] = DirectionAction.consume
      ..[SwipeDirection.up] = DirectionAction.springBack
      ..[SwipeDirection.down] = DirectionAction.undo;
    refusing.clear();
    consumeEndScale = 0.08;
    consumeArc = 0.2;
    consumeFade = true;
    consumeEffect = SwipeConsumeEffect.genie;
    genieLag = 0.45;
    rewindStagger = 90;
    enabled = true;
    keyboard = true;
    reduceMotion = false;
    hapticThreshold = true;
    hapticCommit = true;
    showStamps = true;
    overlayStyle = OverlayStyle.badge;
    deckSize = 8;
    historyLimit = 20;
    infinite = false;
    needMoreThreshold = 3;
    preloadCount = 2;
    deckVersion++;
    notifyListeners();
  }

  /// Adds a line to the event log.
  void log(String line) {
    events.insert(0, line);
    if (events.length > 40) events.removeLast();
    logVersion.value++;
  }

  @override
  void dispose() {
    logVersion.dispose();
    super.dispose();
  }

  /// The physics described by the current settings.
  SwipePhysics get physics => SwipePhysics(
    commitThreshold: commitThreshold,
    projectionTime: projectionTime,
    minCommitDistance: minCommitDistance,
    maxAngle: maxAngle,
    grabTilt: grabTilt,
    rubberBandLimit: rubberBandLimit,
    programmaticSpeed: programmaticSpeed,
    triggerKick: triggerKick,
    settle: settle,
    fling: fling,
    consume: consume,
    undo: undo,
    promote: promote,
  );

  /// The layout described by the current settings.
  CascadeLayout get layout => CascadeLayout(
    visibleCards: visibleCards,
    offset: stackOffset,
    scaleStep: scaleStep,
    tilt: tilt,
  );

  /// The haptics described by the current settings.
  SwipeHaptics get haptics => SwipeHaptics(
    thresholdCrossed: hapticThreshold ? SwipeHapticType.selectionClick : null,
    commit: hapticCommit ? SwipeHapticType.lightImpact : null,
  );
}
