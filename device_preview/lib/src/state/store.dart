import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../device_preview.dart';
import 'custom_device.dart';
import '../../device_preview.dart' as device_preview;

/// The store is a container for the current [state] of the device preview.
///
/// Whenever the state changes, it notifies its listener so that they can update themselves.
class DevicePreviewStore extends ChangeNotifier {
  /// Create a new store with the given [locales], [device] and [storage].
  DevicePreviewStore({
    required this.defaultDevice,
    List<Locale>? locales,
    List<DeviceInfo>? devices,
    required this.storage,
  }) {
    initialize(
      locales: locales,
      devices: devices,
    );
  }

  final DeviceInfo defaultDevice;

  DevicePreviewState _state = const DevicePreviewState.notInitialized();

  /// The storage used to persist the states's data.
  final DevicePreviewStorage storage;

  /// The curren state of the device preview.
  DevicePreviewState get state => _state;

  /// Update the state with [value] and notifies all listeners
  /// of a change.
  set state(DevicePreviewState value) {
    _state = value;
    notifyListeners();
  }

  /// The default custom device when never edited.
  static const _defaultCustomDevice = CustomDeviceInfoData(
    id: CustomDeviceIdentifier.identifier,
    name: 'Custom',
    pixelRatio: 2,
    platform: TargetPlatform.android,
    safeAreas: EdgeInsets.only(top: 20),
    rotatedSafeAreas: EdgeInsets.only(top: 20),
    screenSize: Size(512, 1024),
    type: DeviceType.tablet,
  );

  /// Initializes the state by loading data from storage (if [useStorage])
  Future<void> initialize({
    List<Locale>? locales,
    List<DeviceInfo>? devices,
  }) async {
    await state.maybeWhen(
      notInitialized: () async {
        state = const DevicePreviewState.initializing();

        final availaiableLocales = locales != null
            ? locales
                .map(
                  (available) =>
                      defaultAvailableLocales.cast<NamedLocale?>().firstWhere(
                            (all) => all!.code == available.toString(),
                            orElse: () => null,
                          ),
                )
                .where((x) => x != null)
                .toList()
            : defaultAvailableLocales;

        final defaultLocale = device_preview
            .basicLocaleListResolution(
              WidgetsBinding.instance.window.locales,
              availaiableLocales.map((x) => x!.locale).toList(),
            )
            .toString();

        devices = devices ?? Devices.all;
        DevicePreviewData? data;
        try {
          data = await storage.load();
        } catch (e) {
          // ignore: avoid_print
          print('[device_preview] Error while restoring data: $e');
        }

        data ??= DevicePreviewData(
          locale: defaultLocale,
          customDevice: _defaultCustomDevice,
        );

        if (data.customDevice == null) {
          data = data.copyWith(
            customDevice: _defaultCustomDevice,
          );
        }
        state = DevicePreviewState.initialized(
          locales: availaiableLocales.cast<NamedLocale>(),
          devices: devices!,
          data: data,
        );
      },
      orElse: () => Future.value(),
    );
  }
}

/// A set of extension to triggers updates of the state.
extension DevicePreviewStateHelperExtensions on DevicePreviewStore {
  /// Access to the current state's data.
  ///
  /// Throws an exception if not initialized.
  DevicePreviewData get data => state.maybeMap(
        initialized: (state) => state.data,
        orElse: () => throw Exception('Not initialized'),
      );

  /// Defines the current state's data.
  ///
  /// Throws an exception if not initialized.
  set data(DevicePreviewData data) {
    state = state.maybeMap(
      initialized: (state) {
        final result = state.copyWith(data: data);
        unawaited(storage.save(data));
        return result;
      },
      orElse: () => throw Exception('Not initialized'),
    );
  }

  /// Access to all available locales.
  ///
  /// Throws an exception if not initialized.
  List<NamedLocale> get locales => state.maybeMap(
        initialized: (state) => state.locales,
        orElse: () => throw Exception('Not initialized'),
      );

  /// Access to all available devices.
  ///
  /// Throws an exception if not initialized.
  List<DeviceInfo> get devices => state.maybeMap(
        initialized: (state) => state.devices,
        orElse: () => throw Exception('Not initialized'),
      );

  /// Access to device preview settings from state's data.
  ///
  /// Throws an exception if not initialized.
  DevicePreviewSettingsData get settings =>
      data.settings ?? const DevicePreviewSettingsData();

  set settings(DevicePreviewSettingsData value) {
    data = data.copyWith(settings: value);
  }

  /// The currently selected device from the [availableDevices].
  ///
  /// Throws an exception if not initialized.
  DeviceInfo get deviceInfo {
    if (data.deviceIdentifier == CustomDeviceIdentifier.identifier) {
      return CustomDeviceInfo(data.customDevice!);
    }
    return state.maybeMap(
      initialized: (state) => state.devices.firstWhere(
        (x) =>
            x.identifier.toString() ==
            (data.deviceIdentifier ?? defaultDevice.identifier.toString()),
        orElse: () => state.devices.first,
      ),
      orElse: () => throw Exception('Not initialized'),
    );
  }

  /// Get the currently selected locale from state's data.
  ///
  /// Throws an exception if not initialized.
  Locale get locale => state.maybeMap(
        initialized: (state) => state.locales
            .firstWhere(
              (x) => x.locale.toString() == data.locale,
              orElse: () => state.locales.first,
            )
            .locale,
        orElse: () => throw Exception('Not initialized'),
      );

  /// Activate the custom device mode.
  void enableCustomDevice() {
    data = data.copyWith(
      deviceIdentifier: CustomDeviceIdentifier.identifier,
    );
  }

  /// Hide or show the current device frame.
  void toggleFrame() {
    data = data.copyWith(
      isFrameVisible: !data.isFrameVisible,
    );
  }

  /// Hide or show the virtual keyboard.
  void toggleVirtualKeyboard() {
    data = data.copyWith(
      isVirtualKeyboardVisible: !data.isVirtualKeyboardVisible,
    );
  }

  /// Switch from light to dark mode.
  void toggleDarkMode() {
    data = data.copyWith(
      isDarkMode: !data.isDarkMode,
    );
  }

  /// Change the simulated device orientation between portrait and landscape.
  void rotate() {
    final index = (data.orientation.index + 1) % Orientation.values.length;
    data = data.copyWith(
      orientation: Orientation.values[index],
    );
  }

  /// Select the current device.
  void selectDevice(DeviceIdentifier id) {
    data = data.copyWith(
      deviceIdentifier: id.toString(),
    );
  }

  /// Indicate whether the current device is a custom one.
  bool get isCustomDevice {
    return deviceInfo.identifier is CustomDeviceIdentifier;
  }

  /// Updates the custom device configuration.
  void updateCustomDevice(CustomDeviceInfoData data) =>
      this.data = this.data.copyWith(customDevice: data);

  // --- Multi-device mode methods ---

  /// Toggle between single-device and multi-device mode.
  void toggleMultiDeviceMode() {
    if (!data.isMultiDeviceMode) {
      // Entering multi-device: seed with current single device
      final currentId =
          data.deviceIdentifier ?? defaultDevice.identifier.toString();
      data = data.copyWith(
        isMultiDeviceMode: true,
        multiDeviceEntries: [
          MultiDeviceEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            deviceIdentifier: currentId,
            orientation: data.orientation,
          ),
        ],
      );
    } else {
      // Exiting multi-device: use first entry as the single device
      final first = data.multiDeviceEntries.firstOrNull;
      data = data.copyWith(
        isMultiDeviceMode: false,
        deviceIdentifier: first?.deviceIdentifier ?? data.deviceIdentifier,
        orientation: first?.orientation ?? data.orientation,
      );
    }
  }

  /// Add a device to the multi-device view.
  void addDeviceToMultiView(DeviceIdentifier id) {
    final entries = List<MultiDeviceEntry>.from(data.multiDeviceEntries);
    entries.add(MultiDeviceEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceIdentifier: id.toString(),
    ));
    data = data.copyWith(multiDeviceEntries: entries);
  }

  /// Remove a device from the multi-device view by its entry ID.
  void removeDeviceFromMultiView(String entryId) {
    final entries =
        data.multiDeviceEntries.where((e) => e.id != entryId).toList();
    if (entries.isEmpty) {
      toggleMultiDeviceMode();
      return;
    }
    data = data.copyWith(multiDeviceEntries: entries);
  }

  /// Rotate a specific device entry in multi-device mode.
  void rotateMultiDeviceEntry(String entryId) {
    final entries = data.multiDeviceEntries.map((e) {
      if (e.id == entryId) {
        final index = (e.orientation.index + 1) % Orientation.values.length;
        return e.copyWith(orientation: Orientation.values[index]);
      }
      return e;
    }).toList();
    data = data.copyWith(multiDeviceEntries: entries);
  }

  /// Toggle interaction sync on/off.
  void toggleInteractionSync() {
    data = data.copyWith(
      isInteractionSyncEnabled: !data.isInteractionSyncEnabled,
    );
  }

  /// Set the multi-device layout mode.
  void setMultiDeviceLayout(MultiDeviceLayout layout) {
    data = data.copyWith(multiDeviceLayout: layout);
  }

  /// Set the global scale for multi-device preview.
  void setMultiDeviceScale(double scale) {
    data = data.copyWith(multiDeviceScale: scale.clamp(0.25, 3.0));
  }

  /// Resolve a device identifier string to a [DeviceInfo].
  DeviceInfo resolveDeviceInfo(String deviceIdentifier) {
    if (deviceIdentifier == CustomDeviceIdentifier.identifier) {
      return CustomDeviceInfo(data.customDevice!);
    }
    return devices.firstWhere(
      (x) => x.identifier.toString() == deviceIdentifier,
      orElse: () => devices.first,
    );
  }
}
