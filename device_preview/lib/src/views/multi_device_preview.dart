import 'package:device_frame/device_frame.dart';
import 'package:device_preview/src/interaction/interaction_sync.dart';
import 'package:device_preview/src/state/state.dart';
import 'package:device_preview/src/state/store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Displays multiple device frames simultaneously in either
/// a horizontal row or an adaptive grid layout.
class MultiDevicePreviewArea extends StatelessWidget {
  const MultiDevicePreviewArea({
    super.key,
    required this.appBuilder,
    this.backgroundColor,
    this.padding,
  });

  final WidgetBuilder appBuilder;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final entries = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceEntries,
    );
    final layout = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceLayout,
    );
    final scale = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceScale,
    );
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    final content = entries.isEmpty
        ? const Center(
            child: Text(
              'No devices added.\nUse the toolbar to add devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          )
        : layout == MultiDeviceLayout.row
            ? _buildRow(context, entries, scale)
            : _buildGrid(context, entries, scale);

    return Container(
      color: backgroundColor ?? theme.canvasColor,
      padding: padding ??
          EdgeInsets.only(
            top: 20 + mediaQuery.viewPadding.top,
            right: 20 + mediaQuery.viewPadding.right,
            left: 20 + mediaQuery.viewPadding.left,
            bottom: 20,
          ),
      child: content,
    );
  }

  Widget _buildRow(
      BuildContext context, List<MultiDeviceEntry> entries, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final itemHeight = availableHeight * scale * 0.85;

        return InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          constrained: false,
          child: SizedBox(
            height: itemHeight + 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  SizedBox(
                    height: itemHeight,
                    child: _MultiDeviceFrameItem(
                      entry: entries[i],
                      entryIndex: i,
                      appBuilder: appBuilder,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(
      BuildContext context, List<MultiDeviceEntry> entries, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final itemHeight = availableHeight * scale * 0.42;

        return InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          constrained: false,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (int i = 0; i < entries.length; i++)
                  SizedBox(
                    height: itemHeight,
                    child: _MultiDeviceFrameItem(
                      entry: entries[i],
                      entryIndex: i,
                      appBuilder: appBuilder,
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

/// A single device frame item within the multi-device view.
class _MultiDeviceFrameItem extends StatefulWidget {
  const _MultiDeviceFrameItem({
    required this.entry,
    required this.entryIndex,
    required this.appBuilder,
  });

  final MultiDeviceEntry entry;
  final int entryIndex;
  final WidgetBuilder appBuilder;

  @override
  State<_MultiDeviceFrameItem> createState() => _MultiDeviceFrameItemState();
}

class _MultiDeviceFrameItemState extends State<_MultiDeviceFrameItem> {
  final GlobalKey _screenKey = GlobalKey();
  final GlobalKey _appKey = GlobalKey();

  /// Synthetic pointer ID offset to avoid collision with real pointers.
  int get _syntheticPointerBase => 100000 + widget.entryIndex * 1000;

  /// Track active synthetic pointers to properly send up events.
  final Set<int> _activeSyntheticPointers = {};

  /// Cached reference to the sync controller, saved during didChangeDependencies
  /// so it can safely be used in dispose().
  InteractionSyncController? _syncController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = context.read<InteractionSyncController>();
    if (_syncController != newController) {
      _syncController?.removeListener(_onSyncEvent);
      _syncController = newController;
      _syncController!.addListener(_onSyncEvent);
    }
  }

  @override
  void dispose() {
    _syncController?.removeListener(_onSyncEvent);
    super.dispose();
  }

  void _handlePointerEvent(PointerEvent event) {
    final syncController = context.read<InteractionSyncController>();
    final store = context.read<DevicePreviewStore>();

    if (syncController.isSynthetic || !store.data.isInteractionSyncEnabled) {
      return;
    }

    final renderBox =
        _screenKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localPosition = renderBox.globalToLocal(event.position);
    final normalizedX = localPosition.dx / renderBox.size.width;
    final normalizedY = localPosition.dy / renderBox.size.height;

    NormalizedPointerEventType type;
    double? scrollDeltaY;

    if (event is PointerDownEvent) {
      type = NormalizedPointerEventType.down;
    } else if (event is PointerMoveEvent) {
      type = NormalizedPointerEventType.move;
    } else if (event is PointerUpEvent) {
      type = NormalizedPointerEventType.up;
    } else if (event is PointerScrollEvent) {
      type = NormalizedPointerEventType.scroll;
      scrollDeltaY = event.scrollDelta.dy / renderBox.size.height;
    } else {
      return;
    }

    syncController.dispatchEvent(
      widget.entry.id,
      NormalizedPointerEvent(
        type: type,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        scrollDeltaNormalizedY: scrollDeltaY,
        pointer: event.pointer,
        buttons: event.buttons,
      ),
    );
  }

  void _onSyncEvent() {
    final syncController = context.read<InteractionSyncController>();
    final event = syncController.lastEvent;

    if (event == null || syncController.sourceEntryId == widget.entry.id) {
      return;
    }

    final renderBox =
        _screenKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localX = event.normalizedX * renderBox.size.width;
    final localY = event.normalizedY * renderBox.size.height;
    final globalPosition = renderBox.localToGlobal(Offset(localX, localY));

    final syntheticPointer = _syntheticPointerBase + (event.pointer % 1000);

    syncController.beginSynthetic();
    try {
      PointerEvent? syntheticEvent;

      switch (event.type) {
        case NormalizedPointerEventType.down:
          _activeSyntheticPointers.add(syntheticPointer);
          syntheticEvent = PointerDownEvent(
            pointer: syntheticPointer,
            position: globalPosition,
            buttons: event.buttons,
          );
          break;
        case NormalizedPointerEventType.move:
          if (_activeSyntheticPointers.contains(syntheticPointer)) {
            syntheticEvent = PointerMoveEvent(
              pointer: syntheticPointer,
              position: globalPosition,
              buttons: event.buttons,
            );
          }
          break;
        case NormalizedPointerEventType.up:
          if (_activeSyntheticPointers.remove(syntheticPointer)) {
            syntheticEvent = PointerUpEvent(
              pointer: syntheticPointer,
              position: globalPosition,
            );
          }
          break;
        case NormalizedPointerEventType.scroll:
          final scrollDelta = Offset(
            0,
            (event.scrollDeltaNormalizedY ?? 0) * renderBox.size.height,
          );
          syntheticEvent = PointerScrollEvent(
            position: globalPosition,
            scrollDelta: scrollDelta,
          );
          break;
      }

      if (syntheticEvent != null) {
        GestureBinding.instance.handlePointerEvent(syntheticEvent);
      }
    } finally {
      syncController.endSynthetic();
    }
  }

  MediaQueryData _buildMediaQuery(
    BuildContext context,
    DeviceInfo device,
    Orientation orientation,
  ) {
    final store = context.read<DevicePreviewStore>();
    final data = store.data;

    var mediaQuery = DeviceFrame.mediaQuery(
      context: context,
      info: device,
      orientation: orientation,
    );

    if (data.isVirtualKeyboardVisible) {
      mediaQuery = VirtualKeyboard.mediaQuery(mediaQuery);
    }

    return mediaQuery.copyWith(
      platformBrightness: data.isDarkMode ? Brightness.dark : Brightness.light,
      textScaleFactor: data.textScaleFactor,
      boldText: data.boldText,
      disableAnimations: data.disableAnimations,
      accessibleNavigation: data.accessibleNavigation,
      invertColors: data.invertColors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<DevicePreviewStore>();
    final device = store.resolveDeviceInfo(widget.entry.deviceIdentifier);
    final isFrameVisible = context.select(
      (DevicePreviewStore store) => store.data.isFrameVisible,
    );
    final isVirtualKeyboardVisible = context.select(
      (DevicePreviewStore store) => store.data.isVirtualKeyboardVisible,
    );
    final isDarkMode = context.select(
      (DevicePreviewStore store) => store.data.isDarkMode,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.contain,
            child: DeviceFrame(
              device: device,
              isFrameVisible: isFrameVisible,
              orientation: widget.entry.orientation,
              screen: Listener(
                key: _screenKey,
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePointerEvent,
                onPointerMove: _handlePointerEvent,
                onPointerUp: _handlePointerEvent,
                onPointerSignal: _handlePointerEvent,
                child: VirtualKeyboard(
                  isEnabled: isVirtualKeyboardVisible,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      platform: device.identifier.platform,
                      brightness:
                          isDarkMode ? Brightness.dark : Brightness.light,
                    ),
                    child: MediaQuery(
                      data: _buildMediaQuery(
                        context,
                        device,
                        widget.entry.orientation,
                      ),
                      child: Builder(
                        key: _appKey,
                        builder: widget.appBuilder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            device.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
