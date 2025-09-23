#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔨 Building JWHTC app with ad-hoc signing...${NC}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build-adhoc
xcodebuild clean -project JWHTC.xcodeproj -scheme JWHTC -configuration Release

# Build the app with ad-hoc signing
echo -e "${YELLOW}Building Release configuration...${NC}"
xcodebuild -project JWHTC.xcodeproj \
    -scheme JWHTC \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="Vladyslav Shvedov" \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    build

# Create build-adhoc directory
echo -e "${YELLOW}Creating build-adhoc directory...${NC}"
mkdir -p build-adhoc

# Find the built app
APP_PATH="build/Build/Products/Release/JWHTC.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Built app not found at $APP_PATH${NC}"
    exit 1
fi

# Ad-hoc sign the app with hardened runtime and timestamp
echo -e "${YELLOW}Ad-hoc signing the app...${NC}"
codesign --force --deep --sign - \
    --options runtime \
    --timestamp \
    "$APP_PATH"

# Verify the signature
echo -e "${YELLOW}Verifying signature...${NC}"
codesign --verify --verbose --deep --strict "$APP_PATH"

# Check Gatekeeper acceptance
echo -e "${YELLOW}Checking Gatekeeper assessment...${NC}"
spctl -a -vv "$APP_PATH" 2>&1 || echo -e "${YELLOW}Note: App will require user override on first launch${NC}"

# Create README.txt
echo -e "${YELLOW}Creating README.txt...${NC}"
cat > build-adhoc/README.txt << 'EOF'
JWHTC - Jesse We Have To Cook
==============================
Vladyslav Shvedov (mail@vlad.codes)

A macOS menu bar app that prevents your system from sleeping and keeps you active

HOW TO RUN THE APP
------------------

Method 1 - Right-click to Open (Recommended):
1. Unzip JWHTC_latest.zip
2. Right-click on JWHTC.app
3. Select "Open" from the context menu
4. Click "Open" in the dialog that appears
5. The app will start and appear in your menu bar (look for the flask icon)

Method 2 - If the app is blocked:
1. Try to open the app normally (double-click)
2. If macOS blocks it, go to System Settings > Privacy & Security
3. Look for a message about JWHTC being blocked
4. Click "Open Anyway"
5. Confirm by clicking "Open" in the dialog

Method 3 - Remove quarantine attribute (Terminal):
1. Open Terminal
2. Navigate to where you unzipped the app
3. Run: xattr -cr JWHTC.app
4. Now double-click the app to open normally

USING THE APP
-------------
- Click the flask icon in the menu bar to access controls
- Toggle "Stay Active" to prevent sleep and stay active in Slack
- Access Settings to adjust the activity pulse interval
- To quit: Click the flask icon and select "Stop cooking, Jesse!"


EOF

# Compress the app with README
echo -e "${YELLOW}Compressing app to JWHTC_latest.zip...${NC}"
cd build/Build/Products/Release
cp ../../../../build-adhoc/README.txt .
zip -r -q "../../../../build-adhoc/JWHTC_latest.zip" JWHTC.app README.txt
rm README.txt
cd ../../../..

# Clean up build directory (optional - comment out if you want to keep it)
echo -e "${YELLOW}Cleaning up build directory...${NC}"
rm -rf build

# Print results
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}📦 App packaged at: build-adhoc/JWHTC_latest.zip${NC}"

# Show file size
SIZE=$(du -h "build-adhoc/JWHTC_latest.zip" | cut -f1)
echo -e "${GREEN}📊 File size: $SIZE${NC}"