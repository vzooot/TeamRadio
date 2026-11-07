#!/bin/zsh
# Send a notification to every Team Radio user.
#
#   scripts/push/announce.sh "Title" "Text" [teamradio://tab] [--media https://…] [--at "2026-11-04 18:07"] [--test]
#   scripts/push/announce.sh --scheduled        the ones waiting to go out
#   scripts/push/announce.sh --cancel ID        cancels one of them
#
# --test sends only to development builds (your own phone from Xcode) first.
# --media attaches a short video or image (apps from 1.3.3; older ones show the text),
#   e.g. https://teamradio-push.eam-adio.workers.dev/media/champion.mp4
# --at sends it at that local time instead of now: the server keeps it and its
#   5-minute check sends it (up to 5 minutes after), nothing needs to stay open here.
# Tabs: teamradio://countdown | results | standings | games | paddock | news
# The key lives in server/.secrets/admin-key (not in git).
set -e
cd "$(dirname "$0")/../.."
api=https://teamradio-push.eam-adio.workers.dev
key=$(cat server/.secrets/admin-key)
case $1 in
  --scheduled) curl -sS "$api/scheduled" -H "x-admin-key: $key"; echo; exit ;;
  --cancel) curl -sS -X DELETE "$api/scheduled?id=$2" -H "x-admin-key: $key"; echo; exit ;;
esac
[[ -n "$1" && -n "$2" ]] || { sed -n 2,14p "$0"; exit 1; }
title=$1; text=$2; link=""; only=""; media=""; at=""
args=("${@:3}")
for (( i = 1; i <= ${#args}; i++ )); do
  case ${args[i]} in
    --test) only=sandbox ;;
    --media) media=${args[i+1]}; (( i++ )) ;;
    --at) at=$(python3 -c 'import sys, datetime; print(datetime.datetime.strptime(sys.argv[1], "%Y-%m-%d %H:%M").astimezone().isoformat())' "${args[i+1]}"); (( i++ )) ;;
    *) link=${args[i]} ;;
  esac
done
body=$(python3 -c 'import json,sys; t,b,l,o,m,a=sys.argv[1:7]; d={"title":t,"body":b}; d.update({"link":l} if l else {}); d.update({"onlyEnv":o} if o else {}); d.update({"media":m} if m else {}); d.update({"at":a} if a else {}); print(json.dumps(d))' "$title" "$text" "$link" "$only" "$media" "$at")
echo "${at:+Scheduling for }${at:-Sending}: $title — $text ${link:+($link)} ${media:+[media]} ${only:+[test only]}"
curl -sS -X POST "$api/announce" \
  -H "x-admin-key: $key" -H "content-type: application/json" -d "$body"
echo
