#!/bin/zsh
# Uploads the circuit guides to the Worker's KV (guide:<circuitId>).
#   scripts/guide/upload.sh            # all of server/guides
set -e
ROOT=${0:A:h:h:h}
cd $ROOT/server
for f in guides/*.json; do
  id=${f:t:r}
  npx --yes wrangler kv key put --binding TOKENS --remote "guide:$id" --path "$f" >/dev/null
  echo "✓ guide:$id"
done
