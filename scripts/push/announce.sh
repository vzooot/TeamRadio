#!/bin/zsh
# Send a notification to every Team Radio user.
#
#   scripts/push/announce.sh "Title" "Text" [teamradio://tab] [--media https://…] [--test]
#
# --test sends only to development builds (your own phone from Xcode) first.
# --media attaches a short video or image (apps from 1.3.3; older ones show the text),
#   e.g. https://teamradio-push.eam-adio.workers.dev/media/champion.mp4
# Tabs: teamradio://countdown | results | standings | games | paddock | news
# The key lives in server/.secrets/admin-key (not in git).
set -e
cd "$(dirname "$0")/../.."
[[ -n "$1" && -n "$2" ]] || { sed -n 2,11p "$0"; exit 1; }
key=$(cat server/.secrets/admin-key)
title=$1; text=$2; link=""; only=""; media=""
args=("${@:3}")
for (( i = 1; i <= ${#args}; i++ )); do
  case ${args[i]} in
    --test) only=sandbox ;;
    --media) media=${args[i+1]}; (( i++ )) ;;
    *) link=${args[i]} ;;
  esac
done
body=$(python3 -c 'import json,sys; t,b,l,o,m=sys.argv[1:6]; d={"title":t,"body":b}; d.update({"link":l} if l else {}); d.update({"onlyEnv":o} if o else {}); d.update({"media":m} if m else {}); print(json.dumps(d))' "$title" "$text" "$link" "$only" "$media")
echo "Sending: $title — $text ${link:+($link)} ${media:+[media]} ${only:+[test only]}"
curl -sS -X POST https://teamradio-push.eam-adio.workers.dev/announce \
  -H "x-admin-key: $key" -H "content-type: application/json" -d "$body"
echo
