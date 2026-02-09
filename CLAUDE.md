# Device Preview - Guide Projet

## Vue d'ensemble

Librairie Flutter permettant de previsualiser une application dans des cadres de telephone/tablette/desktop avec simulation de MediaQuery, safe areas, pixel ratio, etc. Supporte l'affichage multi-device simultane avec synchronisation des interactions.

## Structure du monorepo

```
device_preview/          # Package principal - widget DevicePreview, state, toolbar, multi-device
device_frame/            # Package de rendu - DeviceFrame, DeviceInfo, CustomPainter des cadres
plugins/                 # Plugins (screenshot, etc.)
devtools_device_preview/  # Extension DevTools Flutter
docs/                    # Documentation
```

## Commandes essentielles

```bash
# Depuis device_preview/example/
flutter pub get
flutter run -d macos          # ou chrome, android, etc.

# Regenerer le code Freezed (depuis device_preview/)
dart run build_runner build --delete-conflicting-outputs

# Analyse statique
flutter analyze

# Tests (depuis device_frame/)
flutter test
```

## SDK requis

- Dart: `>=3.8.0 <4.0.0`
- Flutter: `>=3.32.0`

## Architecture technique

### State management
- **Provider** + **Freezed** (ChangeNotifier pattern)
- `DevicePreviewStore` (ChangeNotifier) gere `DevicePreviewData` (Freezed immutable)
- `DevicePreviewState` : union type (notInitialized | initializing | initialized)
- Persistence via `DevicePreviewStorage` (SharedPreferences par defaut)

### Fichiers cles

| Fichier | Role |
|---------|------|
| `device_preview/lib/src/device_preview.dart` | Widget principal, build layout, MediaQuery override |
| `device_preview/lib/src/state/state.dart` | Modeles Freezed (DevicePreviewData, MultiDeviceEntry, etc.) |
| `device_preview/lib/src/state/store.dart` | Store + extension avec toutes les methodes de mutation |
| `device_preview/lib/src/views/multi_device_preview.dart` | Vue multi-device (row/grid) + sync interactions |
| `device_preview/lib/src/interaction/interaction_sync.dart` | Controller de synchronisation des pointer events |
| `device_preview/lib/src/views/tool_panel/sections/` | Sections de la toolbar (Device, MultiDevice, System, etc.) |
| `device_frame/lib/src/frame.dart` | Widget DeviceFrame - rendu du cadre + clipping ecran |
| `device_frame/lib/src/devices/` | Catalogue de devices (iOS, Android, macOS, etc.) par platform |

### Rendu des cadres
- Chaque device a un `CustomPainter` (framePainter) et un `Path` (screenPath)
- Devices reels : painters generes depuis des vecteurs SVG (ex: `frame.g.dart`)
- Devices generiques : `GenericPhoneFramePainter`, `GenericTabletFramePainter`
- `DeviceFrame.mediaQuery()` cree le MediaQueryData simule

### Toolbar / Plugins
- Chaque section toolbar est un `Sliver` (extends `ToolPanelSection`)
- Les plugins sont passes via `DevicePreview(tools: [...])`
- Layout responsive : sidebar (>700px) ou bottom sheet (<700px)

## Feature Multi-Device

### Principe
- Mode activable depuis la toolbar "Multi-Device"
- Affiche N appareils simultanement, chacun avec sa propre instance de l'app
- Deux layouts : ligne horizontale scrollable (`row`) ou grille adaptative (`grid`)
- Synchronisation optionnelle des interactions entre tous les appareils

### Synchronisation des interactions
- `InteractionSyncController` (ChangeNotifier) fourni via Provider
- Chaque ecran de device est wrappe dans un `Listener`
- Les pointer events sont normalises en coordonnees 0.0-1.0 relatives a l'ecran
- Les events normalises sont de-normalises et rejoues sur les autres devices via `GestureBinding.instance.handlePointerEvent()`
- Protection anti-reentrance via flag `isSynthetic`
- Pointer IDs synthetiques : `100000 + entryIndex * 1000` pour eviter les collisions

### Modele de donnees multi-device
```dart
// Champs ajoutes a DevicePreviewData :
bool isMultiDeviceMode           // Active/desactive le mode multi
List<MultiDeviceEntry> multiDeviceEntries  // Liste des appareils affiches
bool isInteractionSyncEnabled    // Active/desactive la sync
MultiDeviceLayout multiDeviceLayout       // row | grid

// MultiDeviceEntry :
String id                        // ID unique (timestamp)
String deviceIdentifier          // Meme format que DevicePreviewData.deviceIdentifier
Orientation orientation          // Orientation par appareil
```

### Methodes du store
- `toggleMultiDeviceMode()` - bascule single/multi
- `addDeviceToMultiView(DeviceIdentifier)` - ajoute un appareil
- `removeDeviceFromMultiView(String entryId)` - retire un appareil
- `rotateMultiDeviceEntry(String entryId)` - rotation par appareil
- `toggleInteractionSync()` - active/desactive sync
- `setMultiDeviceLayout(MultiDeviceLayout)` - change le layout
- `resolveDeviceInfo(String deviceIdentifier)` - resout un identifier en DeviceInfo

## Points d'attention Freezed 3.x

- Les classes avec champs DOIVENT etre `abstract class` (pas `class`) quand elles utilisent `with _$ClassName`
- Les union types sans champs au niveau de base (comme `DevicePreviewState`) n'ont pas besoin d'`abstract`
- Supprimer les fichiers `.freezed.dart` avant de regenerer si le build_runner ne detecte pas les changements
- `freezed: ^3.0.0` dans dev_dependencies (etait commente dans le projet original)

## Dependances principales

- `provider: ^6.1.2` - State management
- `device_frame: ^1.4.0` - Rendu des cadres (package local)
- `freezed_annotation: ^3.0.0` + `freezed: ^3.0.0` - Code generation
- `json_annotation` + `json_serializable` - Serialisation JSON
- `shared_preferences: ^2.2.3` - Persistence des settings
