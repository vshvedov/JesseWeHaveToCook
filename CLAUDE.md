# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JWHTC is a macOS menu bar application built with SwiftUI that prevents system sleep and maintains user activity presence. The app uses IOKit framework for power management and provides a simple interface to control Mac's sleep behavior and activity status.

## Architecture

### Core Components

- **JWHTCApp.swift**: Main app entry point, creates a menu bar extra with the activity status indicator
- **ActivityKeeper.swift**: Singleton managing all power and activity assertions using IOKit framework
  - Handles system and display sleep prevention via `IOPMAssertionCreateWithName`
  - Manages activity pulses to maintain "active" status for apps like Slack/Teams
  - Uses both modern `ProcessInfo` API and legacy IOKit assertions for compatibility
- **PresenceMenu.swift**: SwiftUI view for the menu bar dropdown interface
  - Toggle for keep-awake mode (prevents system and display sleep)
  - Toggle for appear-active mode (pulses activity to reset idle timers)
  - Slider to adjust pulse interval (5-180 seconds)

## Building and Running

### Build the Project
```bash
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC -configuration Debug build
```

### Run the App
```bash
open build/Debug/JWHTC.app
```

### Clean Build
```bash
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC clean
```

## Key Technical Details

- **Framework Dependencies**: IOKit.framework for power management APIs
- **Minimum macOS Version**: macOS 26.0 (as per project settings)
- **Swift Version**: 5.0
- **App Type**: Menu bar extra (LSUIElement) - runs without dock icon
- **Sandboxing**: Enabled with read-only file access

## Important Considerations

- The app uses power assertions that require proper entitlements
- Activity pulses are immediately released after creation to avoid holding unnecessary assertions
- All timer and assertion cleanup happens properly in deinit
- Thread safety is maintained for timer operations with main thread checks