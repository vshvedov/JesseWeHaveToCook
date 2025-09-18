# Building JWHTC from Source

## Prerequisites

- macOS 15.6 or later
- Xcode 16.0 or later
- Git

## Quick Build

```bash
# Clone the repository
git clone https://github.com/vshvedov/JesseWeHaveToCook.git
cd JesseWeHaveToCook

# Build release version
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC -configuration Release build

# Find the app in:
# ~/Library/Developer/Xcode/DerivedData/JWHTC-*/Build/Products/Release/JWHTC.app
```

## Build for Distribution

To create a version that works on other computers:

```bash
# Build with ad-hoc signature
xcodebuild -project JWHTC.xcodeproj \
  -scheme JWHTC \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  clean build

# Remove quarantine attributes
xattr -cr ./build/Build/Products/Release/JWHTC.app

# Create ZIP for distribution
cd ./build/Build/Products/Release/
zip -r JWHTC.zip JWHTC.app
```

Note: Recipients will need to right-click and select "Open" on first launch.

## Development

### Open in Xcode
```bash
open JWHTC.xcodeproj
```

### Build Debug Version
```bash
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC -configuration Debug build
```

### Clean Build
```bash
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC clean
```

## Troubleshooting

### Build Errors
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/JWHTC-*

# Reset and rebuild
xcodebuild -project JWHTC.xcodeproj -scheme JWHTC clean build
```

### App Won't Launch
```bash
# Remove quarantine flag
xattr -cr /path/to/JWHTC.app

# Check signature
codesign -dv --verbose=4 /path/to/JWHTC.app
```
