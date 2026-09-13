#!/bin/sh
# Xcode Cloud: materialize the gitignored Secrets.plist from the workflow's
# GIPHY_API_KEY environment variable so cloud builds ship the GIF feature.
set -e
if [ -n "$GIPHY_API_KEY" ]; then
  cat > "$CI_PRIMARY_REPOSITORY_PATH/TeamRadio/Resources/Secrets.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>GiphyAPIKey</key>
	<string>$GIPHY_API_KEY</string>
</dict>
</plist>
EOF
  echo "Secrets.plist written"
else
  echo "GIPHY_API_KEY not set — GIF search will be hidden in this build"
fi
