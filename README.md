# Jesse, We Have To Cook! 🧪

Keep your Mac awake and stay active in Slack, Teams, and other apps. A simple menu bar utility inspired by everyone's favorite chemistry teacher.

## What It Does

JWHTC sits in your menu bar (look for the flask icon ⚗️) and helps you:

- **Stay Awake** - Prevents your Mac from sleeping or starting the screensaver
- **Stay Active** - Keeps your status as "active" in communication apps
- **Stay in Control** - Customize how often it sends activity signals (5 seconds to 3 minutes)

Perfect for those long video calls, presentations, or when you just need to step away without going "idle."

## Download & Install

### Option 1: Download Pre-built App
Check the [Releases](https://github.com/vshvedov/JesseWeHaveToCook/releases) page for the latest version.

**First time opening:**
1. Unpack and copy to "Applications"
2. Right-click the app and select "Open"
3. Click "Open" when macOS warns about an unidentified developer
4. That's it! The app will appear in your menu bar

### Option 2: Build From Source
Requires Xcode 16.0+. See [BUILDING.md](BUILDING.md) for detailed instructions.

## How to Use

1. **Look for the flask icon** in your menu bar
   - Filled flask (⚗️) = Active (keeping awake or sending activity)
   - Empty flask = Inactive

2. **Click the icon** to see options:
   - **Keep Awake** - Toggle to prevent sleep/screensaver
   - **Keep Active** - Toggle to maintain active presence
   - **Settings** - Adjust activity pulse interval
   - **Stop cooking, Jesse!** - Quit the app

3. **Auto-start** (optional):
   - Open Settings
   - Toggle "Launch at login"

## System Requirements

- macOS 15.6 or later
- About 10 MB of disk space
- Minimal CPU and memory usage (around 37MB of RAM)

## FAQ

**Q: Is this safe to use?**
A: Yes! The app uses official macOS APIs and doesn't fake mouse movements or keystrokes. It simply tells the system you're active.

**Q: Does it drain battery?**
A: Minimal impact. The app uses very little CPU (< 0.1%) and memory (< 40MB).

**Q: Will this work with [specific app]?**
A: It works with any app that respects macOS activity signals, including Slack, Teams, Discord, and most communication tools.

## Privacy & Security

- No data collection
- No network requests
- No file system access beyond preferences
- Fully sandboxed for your security
- [View source code](https://github.com/vshvedov/JesseWeHaveToCook)

## Support

Having issues? Found a bug?
- [Open an issue](https://github.com/vshvedov/JesseWeHaveToCook/issues)
- Email: mail@vlad.codes

## Author

Made with 🍵 by [Vladyslav Shvedov](https://vlad.codes)

## License

MIT License - feel free to modify and share!
