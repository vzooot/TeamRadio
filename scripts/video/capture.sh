#!/bin/zsh
# Records one demo pass of the app in the Simulator.
#   scripts/video/capture.sh countdown
# Output: Marketing/videos/raw/<pass>-<date>.mov + .json (the app's step log,
# with the recording's start time added so the renderer can cut exactly).
# Debug build only: the demo director doesn't exist in release builds.
set -e
PASS=${1:-countdown}
DEVICE=${DEVICE:-4C11EA7D-A524-4089-BDF5-B94196092D52}   # iPhone 18 Pro
BUNDLE=com.woqomoqo.OneF
ROOT=${0:A:h:h:h}
OUT=$ROOT/Marketing/videos/raw
STAMP=$(date +%Y-%m-%d)
mkdir -p $OUT

echo "› building"
xcodebuild -project $ROOT/TeamRadio.xcodeproj -scheme TeamRadio -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath $ROOT/build/DerivedData build -quiet
xcrun simctl boot $DEVICE 2>/dev/null || true
xcrun simctl install $DEVICE $ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/TeamRadio.app
xcrun simctl status_bar $DEVICE override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl terminate $DEVICE $BUNDLE 2>/dev/null || true

LOG=$(xcrun simctl get_app_container $DEVICE $BUNDLE data)/Documents/demo-log.json; echo "log: $LOG"
rm -f $LOG $OUT/$PASS-$STAMP.mov

echo "› recording pass '$PASS'"
xcrun simctl io $DEVICE recordVideo --codec=h264 --force $OUT/$PASS-$STAMP.mov 2>/dev/null &
REC=$!
sleep 1.5
REC_START=$(python3 -c 'import time; print(time.time() - 1.5)')
xcrun simctl launch $DEVICE $BUNDLE -Demo $PASS

for i in {1..180}; do
  grep -q '"end"' $LOG 2>/dev/null && break
  sleep 1
done
sleep 1
kill -INT $REC; wait $REC 2>/dev/null || true
grep -q '"end"' $LOG || { echo "✗ demo never finished"; exit 1; }

python3 - "$LOG" "$REC_START" "$OUT/$PASS-$STAMP.json" <<'EOF'
import json, sys
log = json.load(open(sys.argv[1]))
start = next(e for e in log if e['event'] == 'start')
json.dump({'offset': start['epoch'] - float(sys.argv[2]), 'events': log}, open(sys.argv[3], 'w'), indent=1)
EOF
xcrun simctl status_bar $DEVICE clear 2>/dev/null || true
echo "✓ $OUT/$PASS-$STAMP.mov"
