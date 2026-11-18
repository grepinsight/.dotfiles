#!/bin/sh
# Report every workspace's id as its $id token. Idempotent, so every hook
# simply re-reports all workspaces.
set -eu
herdr="${HERDR_BIN_PATH:-herdr}"
"$herdr" workspace list | jq -r '.result.workspaces[].workspace_id' | while read -r id; do
    "$herdr" workspace report-metadata "$id" --source local.workspace-id --token "id=$id" >/dev/null
done
