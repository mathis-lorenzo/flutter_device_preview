import 'package:device_preview/src/state/state.dart';
import 'package:device_preview/src/state/store.dart';
import 'package:device_preview/src/views/tool_panel/sections/subsections/device_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'section.dart';

/// Toolbar section for managing multi-device mode.
class MultiDeviceSection extends StatelessWidget {
  const MultiDeviceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMultiDeviceMode = context.select(
      (DevicePreviewStore store) => store.data.isMultiDeviceMode,
    );
    final entries = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceEntries,
    );
    final isSyncEnabled = context.select(
      (DevicePreviewStore store) => store.data.isInteractionSyncEnabled,
    );
    final layout = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceLayout,
    );

    return ToolPanelSection(
      title: 'Multi-Device',
      children: [
        SwitchListTile(
          title: const Text('Multi-Device Mode'),
          subtitle: Text(isMultiDeviceMode
              ? '${entries.length} device(s)'
              : 'Disabled'),
          value: isMultiDeviceMode,
          onChanged: (_) {
            context.read<DevicePreviewStore>().toggleMultiDeviceMode();
          },
        ),
        if (isMultiDeviceMode) ...[
          _ScaleSlider(),
          SwitchListTile(
            title: const Text('Sync Interactions'),
            subtitle: Text(isSyncEnabled ? 'Enabled' : 'Disabled'),
            value: isSyncEnabled,
            onChanged: (_) {
              context.read<DevicePreviewStore>().toggleInteractionSync();
            },
          ),
          ListTile(
            title: const Text('Layout'),
            subtitle: Text(
              layout == MultiDeviceLayout.row ? 'Horizontal row' : 'Grid',
            ),
            trailing: Icon(
              layout == MultiDeviceLayout.row
                  ? Icons.view_column_rounded
                  : Icons.grid_view_rounded,
            ),
            onTap: () {
              final store = context.read<DevicePreviewStore>();
              store.setMultiDeviceLayout(
                layout == MultiDeviceLayout.row
                    ? MultiDeviceLayout.grid
                    : MultiDeviceLayout.row,
              );
            },
          ),
          const Divider(),
          ...entries.map(
            (entry) => _MultiDeviceEntryTile(entry: entry),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add device'),
            onTap: () {
              final theme = Theme.of(context);
              final store = context.read<DevicePreviewStore>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: store,
                    child: Theme(
                      data: theme,
                      child: DeviceModelPicker(
                        onDeviceSelected: (device) {
                          store.addDeviceToMultiView(device.identifier);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scale = context.select(
      (DevicePreviewStore store) => store.data.multiDeviceScale,
    );
    return ListTile(
      title: Row(
        children: [
          const Text('Scale'),
          const Spacer(),
          Text(
            '${(scale * 100).round()}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      subtitle: Slider(
        value: scale,
        min: 0.25,
        max: 3.0,
        divisions: 55,
        onChanged: (value) {
          context.read<DevicePreviewStore>().setMultiDeviceScale(value);
        },
      ),
      trailing: IconButton(
        icon: const Icon(Icons.restart_alt, size: 20),
        onPressed: () {
          context.read<DevicePreviewStore>().setMultiDeviceScale(1.0);
        },
        tooltip: 'Reset to 100%',
      ),
    );
  }
}

class _MultiDeviceEntryTile extends StatelessWidget {
  const _MultiDeviceEntryTile({required this.entry});

  final MultiDeviceEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = context.read<DevicePreviewStore>();
    final device = store.resolveDeviceInfo(entry.deviceIdentifier);

    return ListTile(
      title: Text(device.name),
      subtitle: Text(
        '${device.screenSize.width.toInt()}x${device.screenSize.height.toInt()} '
        '${entry.orientation == Orientation.portrait ? "Portrait" : "Landscape"}',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (device.rotatedSafeAreas != null)
            IconButton(
              icon: const Icon(Icons.screen_rotation, size: 20),
              onPressed: () {
                store.rotateMultiDeviceEntry(entry.id);
              },
              tooltip: 'Rotate',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              store.removeDeviceFromMultiView(entry.id);
            },
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
