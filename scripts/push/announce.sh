#!/bin/zsh
# Send a notification to every Team Radio user.
#
#   scripts/push/announce.sh "Title" "Text" [teamradio://tab] [--test]
#
# --test sends only to development builds (your own phone from Xcode) first.
# Tabs: teamradio://countdown | results | games | paddock | news
# The key lives in server/.secrets/admin-key (not in git).
set -e
cd "$(dirname "$0")/../.."
[[ -n "$1" && -n "$2" ]] || { sed -n 2,9p "$0"; exit 1; }
key=$(cat server/.secrets/admin-key)
title=$1; text=$2; link=""; only=""
for arg in "${@:3}"; do
  [[ $arg == --test ]] && only=sandbox || link=$arg
done
body=$(python3 -c 'import json,sys; t,b,l,o=sys.argv[1:5]; d={"title":t,"body":b}; d.update({"link":l} if l else {}); d.update({"onlyEnv":o} if o else {}); print(json.dumps(d))' "$title" "$text" "$link" "$only")
echo "Sending: $title — $text ${link:+($link)} ${only:+[test only]}"
curl -sS -X POST https://teamradio-push.eam-adio.workers.dev/announce \
  -H "x-admin-key: $key" -H "content-type: application/json" -d "$body"
echo
