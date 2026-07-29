#!/usr/bin/env bash

set -euo pipefail

: "${SIGNING_REPOSITORY_DIR:?SIGNING_REPOSITORY_DIR is required}"
: "${SIGNING_APP_DIR:?SIGNING_APP_DIR is required}"
: "${SIGNING_OUTPUT_DIR:?SIGNING_OUTPUT_DIR is required}"

source_config="$SIGNING_REPOSITORY_DIR/$SIGNING_APP_DIR/signingConfigs.json"
output_config="$SIGNING_OUTPUT_DIR/signingConfigs.json"

if [[ ! -s "$source_config" ]]; then
  echo "Missing signing configuration: $source_config" >&2
  exit 1
fi

mkdir -p "$SIGNING_OUTPUT_DIR"
umask 077
jq \
  --arg repository_root "$SIGNING_REPOSITORY_DIR" \
  --arg profile_root "$SIGNING_REPOSITORY_DIR/$SIGNING_APP_DIR" \
  'map(
    .material.storeFile = ($repository_root + "/" + (.material.storeFile | split("/") | last)) |
    .material.certpath = ($repository_root + "/" + (.material.certpath | split("/") | last)) |
    .material.profile = ($profile_root + "/" + (.material.profile | split("/") | last))
  )' \
  "$source_config" > "$output_config"
chmod 600 "$output_config"

jq -e '
  type == "array" and
  length > 0 and
  any(.[]; .name == "default") and
  any(.[]; .name == "publish")
' "$output_config" >/dev/null

while IFS= read -r material_file; do
  if [[ ! -s "$material_file" ]]; then
    echo "Missing signing material: $material_file" >&2
    exit 1
  fi
done < <(
  jq -r '.[] | .material.storeFile, .material.certpath, .material.profile' \
    "$output_config"
)

echo "Prepared signing configuration for $SIGNING_APP_DIR."
