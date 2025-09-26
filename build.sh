#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔨 Building JWHTC app...${NC}"

# Ask user about code signing
echo -e "${YELLOW}Do you want to sign the code with an Apple Developer certificate? (Y/N)${NC}"
read -r SIGN_CHOICE

# Initialize signing variables
CODE_SIGN_IDENTITY="-"
DEVELOPMENT_TEAM=""
USE_DEVELOPER_SIGNING=false

if [[ "$SIGN_CHOICE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Fetching available Apple Developer identities...${NC}"

    # Get available developer certificates
    # For distribution outside App Store, we need Developer ID Application certificate
    IDENTITIES=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep -v "CSSMERR_TP_CERT_REVOKED")

    # If no Developer ID certificates, fall back to showing all certificates
    if [ -z "$IDENTITIES" ]; then
        echo -e "${YELLOW}No Developer ID Application certificates found. Showing all available certificates...${NC}"
        IDENTITIES=$(security find-identity -v -p codesigning | grep "Apple Development\|Apple Distribution\|Developer ID Application" | grep -v "CSSMERR_TP_CERT_REVOKED")
    fi

    if [ -z "$IDENTITIES" ]; then
        echo -e "${RED}No valid Apple Developer certificates found in keychain.${NC}"
        echo -e "${YELLOW}Falling back to ad-hoc signing...${NC}"
    else
        echo -e "${GREEN}Available signing identities:${NC}"

        # Parse and display identities
        IFS=$'\n'
        IDENTITY_ARRAY=()
        INDEX=1

        while IFS= read -r line; do
            # Extract the identity hash and name
            HASH=$(echo "$line" | awk '{print $2}')
            NAME=$(echo "$line" | sed -n 's/.*"\(.*\)".*/\1/p')
            echo -e "  ${INDEX}) $NAME"
            IDENTITY_ARRAY+=("$HASH|$NAME")
            ((INDEX++))
        done <<< "$IDENTITIES"

        echo -e "${YELLOW}Select identity number (or press Enter to use ad-hoc signing):${NC}"
        read -r IDENTITY_CHOICE

        if [[ "$IDENTITY_CHOICE" =~ ^[0-9]+$ ]] && [ "$IDENTITY_CHOICE" -ge 1 ] && [ "$IDENTITY_CHOICE" -le "${#IDENTITY_ARRAY[@]}" ]; then
            SELECTED_IDENTITY="${IDENTITY_ARRAY[$((IDENTITY_CHOICE-1))]}"
            CODE_SIGN_IDENTITY="${SELECTED_IDENTITY%%|*}"
            IDENTITY_NAME="${SELECTED_IDENTITY##*|}"
            USE_DEVELOPER_SIGNING=true

            echo -e "${GREEN}✓ Using identity: $IDENTITY_NAME${NC}"

            # Warn if not using Developer ID certificate
            if [[ ! "$IDENTITY_NAME" =~ "Developer ID Application" ]]; then
                echo -e "${YELLOW}⚠️  Warning: '$IDENTITY_NAME' is not a Developer ID Application certificate.${NC}"
                echo -e "${YELLOW}   The app may be rejected by Gatekeeper. For distribution outside the App Store,${NC}"
                echo -e "${YELLOW}   use a 'Developer ID Application' certificate.${NC}"
            fi

            # Extract team ID from the certificate name (it's in parentheses)
            TEAM_ID=$(echo "$IDENTITY_NAME" | grep -o '([A-Z0-9]*)'| tr -d '()')
            if [ -n "$TEAM_ID" ]; then
                DEVELOPMENT_TEAM="$TEAM_ID"
                echo -e "${GREEN}✓ Team ID: $TEAM_ID${NC}"
            else
                # Fallback: try to extract from certificate details
                TEAM_ID=$(security find-certificate -c "$IDENTITY_NAME" -p | openssl x509 -subject -noout 2>/dev/null | grep -o 'OU=[^/]*' | cut -d= -f2 | head -1)
                if [ -n "$TEAM_ID" ]; then
                    DEVELOPMENT_TEAM="$TEAM_ID"
                    echo -e "${GREEN}✓ Team ID: $TEAM_ID${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}Using ad-hoc signing...${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Using ad-hoc signing...${NC}"
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build-adhoc
xcodebuild clean -project JWHTC.xcodeproj -scheme JWHTC -configuration Release

# Build the app with appropriate signing
echo -e "${YELLOW}Building Release configuration...${NC}"
if [ "$USE_DEVELOPER_SIGNING" = true ]; then
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        xcodebuild -project JWHTC.xcodeproj \
            -scheme JWHTC \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
            CODE_SIGNING_REQUIRED=YES \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGNING_STYLE=Manual \
            PROVISIONING_PROFILE_SPECIFIER="" \
            ENABLE_HARDENED_RUNTIME=YES \
            OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
            build
    else
        xcodebuild -project JWHTC.xcodeproj \
            -scheme JWHTC \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
            CODE_SIGNING_REQUIRED=YES \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGNING_STYLE=Manual \
            PROVISIONING_PROFILE_SPECIFIER="" \
            ENABLE_HARDENED_RUNTIME=YES \
            OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
            build
    fi
else
    xcodebuild -project JWHTC.xcodeproj \
        -scheme JWHTC \
        -configuration Release \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_STYLE=Manual \
        PROVISIONING_PROFILE_SPECIFIER="" \
        AD_HOC_CODE_SIGNING_ALLOWED=YES \
        build
fi

# Create build-adhoc directory
echo -e "${YELLOW}Creating build-adhoc directory...${NC}"
mkdir -p build-adhoc

# Find the built app and keep its original name
ORIGINAL_APP_PATH="build/Build/Products/Release/JWHTC.app"
APP_PATH="$ORIGINAL_APP_PATH"

if [ ! -d "$ORIGINAL_APP_PATH" ]; then
    echo -e "${RED}❌ Error: Built app not found at $ORIGINAL_APP_PATH${NC}"
    exit 1
fi

# No renaming; proceed with the original app name
echo -e "${YELLOW}Using app: $(basename "$APP_PATH")${NC}"

# Sign the app (if not already signed with developer certificate)
if [ "$USE_DEVELOPER_SIGNING" = false ]; then
    echo -e "${YELLOW}Ad-hoc signing the app...${NC}"
    codesign --force --deep --sign - \
        --options runtime \
        --timestamp \
        "$APP_PATH"
else
    echo -e "${GREEN}✓ App signed with developer certificate${NC}"
fi

# Verify the signature
echo -e "${YELLOW}Verifying signature...${NC}"
codesign --verify --verbose --deep --strict "$APP_PATH"

# Check if we should notarize (only for Developer ID certificates)
if [ "$USE_DEVELOPER_SIGNING" = true ] && [[ "$IDENTITY_NAME" =~ "Developer ID Application" ]]; then
    echo -e "${YELLOW}Would you like to notarize the app for Gatekeeper approval? (Y/N)${NC}"
    echo -e "${YELLOW}Tip: Using a notarytool keychain profile avoids 2FA prompts and is more reliable.${NC}"
    read -r NOTARIZE_CHOICE

    if [[ "$NOTARIZE_CHOICE" =~ ^[Yy]$ ]]; then
        LOG_DIR="build-adhoc"
        mkdir -p "$LOG_DIR"
        echo -e "${YELLOW}Creating ZIP for notarization...${NC}"
        ditto -c -k --keepParent "$APP_PATH" "$APP_PATH.zip"

        echo -e "${YELLOW}Do you want to use a notarytool keychain profile? (Y/N)${NC}"
        read -r USE_PROFILE

        if [[ "$USE_PROFILE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Enter keychain profile name (default: JWHTC_NOTARY):${NC}"
            read -r PROFILE_NAME
            PROFILE_NAME=${PROFILE_NAME:-JWHTC_NOTARY}

            echo -e "${YELLOW}Submitting app for notarization via profile '$PROFILE_NAME'...${NC}"
            xcrun notarytool submit "$APP_PATH.zip" \
                --keychain-profile "$PROFILE_NAME" \
                --no-wait --output-format json 2>&1 | tee "$LOG_DIR/notarization-submit.json"

            REQUEST_ID=$(grep -Eo '"id"\s*:\s*"[^"]+"' "$LOG_DIR/notarization-submit.json" | head -1 | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
            if [ -z "$REQUEST_ID" ]; then
                REQUEST_ID=$(grep -Eo 'id: [A-Fa-f0-9-]+' "$LOG_DIR/notarization-submit.json" | head -1 | awk '{print $2}')
            fi
        else
            echo -e "${YELLOW}Enter your Apple ID email:${NC}"
            read -r APPLE_ID

            echo -e "${YELLOW}Enter your app-specific password (create one at appleid.apple.com):${NC}"
            read -s -r APP_PASSWORD
            echo

            # Verify or override team ID
            if [ -n "$TEAM_ID" ]; then
                echo -e "${YELLOW}Using Team ID: $TEAM_ID (press Enter to confirm or type a different one):${NC}"
                read -r TEAM_ID_OVERRIDE
                if [ -n "$TEAM_ID_OVERRIDE" ]; then
                    TEAM_ID="$TEAM_ID_OVERRIDE"
                    echo -e "${GREEN}✓ Using Team ID: $TEAM_ID${NC}"
                fi
            else
                echo -e "${YELLOW}Enter your Team ID (found in your Apple Developer account):${NC}"
                read -r TEAM_ID
            fi

            echo -e "${YELLOW}Submitting app for notarization (no-wait)...${NC}"
            xcrun notarytool submit "$APP_PATH.zip" \
                --apple-id "$APPLE_ID" \
                --password "$APP_PASSWORD" \
                --team-id "$TEAM_ID" \
                --no-wait --output-format json 2>&1 | tee "$LOG_DIR/notarization-submit.json"

            REQUEST_ID=$(grep -Eo '"id"\s*:\s*"[^"]+"' "$LOG_DIR/notarization-submit.json" | head -1 | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
            if [ -z "$REQUEST_ID" ]; then
                REQUEST_ID=$(grep -Eo 'id: [A-Fa-f0-9-]+' "$LOG_DIR/notarization-submit.json" | head -1 | awk '{print $2}')
            fi
        fi

        if [ -z "$REQUEST_ID" ]; then
            echo -e "${RED}❌ Failed to extract notarization request ID. See $LOG_DIR/notarization-submit.json${NC}"
            rm -f "$APP_PATH.zip"
            exit 1
        fi

        echo -e "${YELLOW}Request ID: $REQUEST_ID${NC}"
        echo -e "${YELLOW}Polling notarization status (max ~30 minutes)...${NC}"

        # Poll status up to ~30 minutes (120 * 15s)
        MAX_TRIES=120
        TRY=1
        STATUS="In Progress"
        while [ $TRY -le $MAX_TRIES ]; do
            if [[ "$USE_PROFILE" =~ ^[Yy]$ ]]; then
                INFO_OUTPUT=$(xcrun notarytool info "$REQUEST_ID" --keychain-profile "$PROFILE_NAME" --output-format json 2>&1)
            else
                INFO_OUTPUT=$(xcrun notarytool info "$REQUEST_ID" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" --output-format json 2>&1)
            fi

            echo "$INFO_OUTPUT" > "$LOG_DIR/notarization-info.json"
            STATUS=$(echo "$INFO_OUTPUT" | grep -Eo '"status"\s*:\s*"[^"]+"' | sed -E 's/.*"status"\s*:\s*"([^"]+)".*/\1/')

            if [ "$STATUS" = "Accepted" ]; then
                echo -e "${GREEN}✓ Notarization accepted${NC}"
                break
            elif [ "$STATUS" = "Invalid" ] || [ "$STATUS" = "Rejected" ]; then
                echo -e "${RED}❌ Notarization $STATUS${NC}"
                break
            else
                echo -ne "\rCurrent status: $STATUS (try $TRY/$MAX_TRIES)"
                sleep 15
            fi
            TRY=$((TRY+1))
        done
        echo

        # Always fetch and save the log for debugging
        if [[ "$USE_PROFILE" =~ ^[Yy]$ ]]; then
            xcrun notarytool log "$REQUEST_ID" --keychain-profile "$PROFILE_NAME" > "$LOG_DIR/notary-log.json" 2>/dev/null || true
        else
            xcrun notarytool log "$REQUEST_ID" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" > "$LOG_DIR/notary-log.json" 2>/dev/null || true
        fi

        if [ "$STATUS" = "Accepted" ]; then
            echo -e "${YELLOW}Stapling the notarization ticket to the app...${NC}"
            xcrun stapler staple "$APP_PATH"
            echo -e "${GREEN}✓ App is now notarized and will pass Gatekeeper!${NC}"
        else
            echo -e "${RED}⚠️  Notarization not accepted. See $LOG_DIR/notarization-info.json and $LOG_DIR/notary-log.json${NC}"
        fi

        # Clean up
        rm -f "$APP_PATH.zip"
    else
        echo -e "${YELLOW}Skipping notarization. The app will require Gatekeeper override to run.${NC}"
    fi
fi

# Check Gatekeeper acceptance
echo -e "${YELLOW}Checking Gatekeeper assessment...${NC}"
spctl -a -vv "$APP_PATH" 2>&1 || echo -e "${YELLOW}Note: App will require user override on first launch${NC}"

# Create README.txt
echo -e "${YELLOW}Creating README.txt...${NC}"
cat > build-adhoc/README.txt << 'EOF'
JWHTC - Stay Active
===================
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
