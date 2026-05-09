# Rolume — macOS Volume Control App

Rolume is a macOS menu bar app (Swift + SwiftUI, min macOS 14.0) for controlling system audio and external monitor volume via DDC/CI, plus mouse scroll reversal.

## Build & Run
```bash
open Rolume.xcodeproj  # then Cmd+R
# or
xcodebuild -project Rolume.xcodeproj -scheme Rolume -configuration Debug build
```

## Architecture

```
Rolume/
├── App/              AppDelegate, RolumeApp (menu bar only, LSUIElement)
├── Models/           Display.swift
├── Core/
│   ├── Audio/        SystemAudioManager — CoreAudio get/set volume, device monitoring
│   ├── DDC/          DDCManager (Apple Silicon IOAVService + Intel framebuffer I2C fallback)
│   │                 DDCHelper, DDCCommands, IOI2C (private IOKit function declarations)
│   ├── Events/       EventMonitor (NSEvent local+global monitors)
│   ├── EventInterceptor.swift   CGEvent tap (HID level, for scroll reversal + modifier key volume)
│   ├── LanguageManager.swift    Runtime localization (zh-Hans / en), instant switch
│   └── LaunchAtLogin.swift
└── UI/
    ├── MenuBar/      StatusBarController (NSStatusItem, NSEvent scroll handling, right-click menu)
    │                 VolumeIconGenerator (template image, wheel shape)
    ├── Settings/     SettingsView (4 tabs: General, Mouse, Trackpad, About)
    └── OSD/          OSDManager + CustomOSDWindow (HUD-style volume overlay)
```

## Two Scroll Event Paths (CRITICAL)

### Path A: NSEvent (StatusBarController, lines ~56-182)
- Local + global NSEvent monitors for `.scrollWheel`
- Always running, no permission needed
- Handles: dock area scroll, menu bar area scroll, modifier key + scroll
- Uses `event.isDirectionInvertedFromDevice` for natural scrolling compensation
- Only consumes events when device-specific "intercept" setting is ON

### Path B: CGEvent tap (EventInterceptor, `handleEvent`)
- `.cghidEventTap` at `.headInsertEventTap`, intercepts ALL scroll events system-wide
- Requires Accessibility permission (AXIsProcessTrusted)
- Started only when needed: reverseMouseScroll=true OR mouseDisableSystemScroll=true OR trackpadDisableSystemScroll=true
- Uses cached settings (CachedSettings struct) to avoid UserDefaults I/O on hot path
- Uses phase-based trackpad detection (MomentumPhase/ScrollPhase/ScrollCount, sampled every 3 calls)
- Always consumes event after adjusting volume (returns nil) to prevent double-fire with Path A

## Key Design Decisions

1. **Modifier key separation**: Mouse and trackpad have independent modifier key settings (mouseModifierKey / trackpadModifierKey)
2. **Settings cache**: EventInterceptor's CachedSettings is populated at start() and refreshed via "RefreshInterceptorSettings" notification
3. **Interpreter lifecycle**: setupEventInterceptor() in StatusBarController stops old interceptor when settings no longer need it
4. **DDC fallback**: Apple Silicon IOAVService first, Intel framebuffer I2C as fallback
5. **Language**: Runtime switching via LanguageManager (ObservableObject), not AppleLanguages
6. **OSD**: Custom window with NSVisualEffectView (.hudWindow material), fade in/out, isShowing flag to prevent flicker
7. **Window title**: Left-aligned (macOS 11+ standard, no toolbar)
8. **Window size**: minWidth: 370, minHeight: 420

## Settings (UserDefaults keys)
- showOSD, doubleClickToMute, launchAtLogin, showDockIcon
- mouseVolumeStep, mouseScrollInDock, mouseScrollInMenuBar, mouseScrollWithModifier, mouseDisableSystemScroll
- trackpadVolumeStep, trackpadScrollInDock, trackpadScrollInMenuBar, trackpadScrollWithModifier, trackpadDisableSystemScroll
- reverseMouseScroll, reversalExcludedApps (String array), isEnabled
- mouseModifierKey, trackpadModifierKey
- appLanguage (absent = follow system)

## Gotchas
- Don't use NSToolbar for settings tabs (causes SF Symbol icon drift)
- Don't animate OSD show without isShowing guard (causes flicker)
- AudioObjectRemovePropertyListener must use same closure reference as Add (fixed: stored volumeListener)
- DisplayManager has private func CoreDisplay_DisplayCreateInfoDictionary — DDCManager duplicates it
- Static variables in EventInterceptor (scrollAccumulator, lastScrollTime) must be reset in start()

## License
MIT
