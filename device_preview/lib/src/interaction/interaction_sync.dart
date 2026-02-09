import 'package:flutter/widgets.dart';

/// The type of a normalized pointer event.
enum NormalizedPointerEventType {
  down,
  move,
  up,
  scroll,
}

/// A pointer event with coordinates normalized to the 0.0-1.0 range
/// relative to the device screen size.
class NormalizedPointerEvent {
  const NormalizedPointerEvent({
    required this.type,
    required this.normalizedX,
    required this.normalizedY,
    this.scrollDeltaNormalizedY,
    required this.pointer,
    required this.buttons,
  });

  final NormalizedPointerEventType type;

  /// X coordinate in 0.0-1.0 range relative to the device screen.
  final double normalizedX;

  /// Y coordinate in 0.0-1.0 range relative to the device screen.
  final double normalizedY;

  /// Scroll delta Y normalized relative to the device screen height.
  final double? scrollDeltaNormalizedY;

  /// The original pointer ID.
  final int pointer;

  /// The button state.
  final int buttons;
}

/// Controller that manages interaction synchronization between
/// multiple device preview instances.
///
/// When a pointer event occurs on one device, it is normalized and
/// dispatched to all other devices which de-normalize and replay it.
class InteractionSyncController extends ChangeNotifier {
  /// The entry ID of the device that is currently the source of events.
  String? _sourceEntryId;

  /// The last normalized pointer event dispatched.
  NormalizedPointerEvent? _lastEvent;

  /// Flag to prevent re-entrancy when replaying synthetic events.
  bool _isSynthetic = false;

  /// Get the source entry ID.
  String? get sourceEntryId => _sourceEntryId;

  /// Get the last dispatched event.
  NormalizedPointerEvent? get lastEvent => _lastEvent;

  /// Whether we are currently replaying a synthetic event.
  bool get isSynthetic => _isSynthetic;

  /// Mark the start of synthetic event processing.
  void beginSynthetic() => _isSynthetic = true;

  /// Mark the end of synthetic event processing.
  void endSynthetic() => _isSynthetic = false;

  /// Dispatch a normalized pointer event from a source device.
  void dispatchEvent(String entryId, NormalizedPointerEvent event) {
    if (_isSynthetic) return;
    _sourceEntryId = entryId;
    _lastEvent = event;
    notifyListeners();
  }

  /// Clear the current source.
  void clearSource() {
    _sourceEntryId = null;
    _lastEvent = null;
  }
}
