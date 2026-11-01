#!/usr/bin/env bash
# Consume only rd-engine's owning NAPI build. Never rebuild or hand-edit a HAR here.
set -euo pipefail

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
engine_root="${RD_ENGINE_ROOT:-$app_root/../rd-engine}"
ohos_cli_home="${OHOS_CLI_HOME:-$HOME/command-line-tools}"
ohpm_bin="${OHPM:-$ohos_cli_home/bin/ohpm}"
verifier="$app_root/scripts/verify-native-har.py"
target_har="$app_root/rustdesk-ohrs.har"
# build-har.sh stages these outputs here, independently of Cargo's cache/target settings.
source_har="${NATIVE_HAR_PATH:-$engine_root/native/ohos_napi/target/package.har}"
source_provenance="${NATIVE_PROVENANCE_PATH:-$(dirname "$source_har")/release-provenance.json}"

if [[ ! -x "$ohpm_bin" ]]; then
  printf 'OHPM executable not found: %s; set OHPM or OHOS_CLI_HOME.\n' "$ohpm_bin" >&2
  exit 1
fi

# A refresh must update the dependency the application actually consumes.
if ! grep -Eq '"rustdesk-ohrs"[[:space:]]*:[[:space:]]*"file:\./rustdesk-ohrs\.har"' \
  "$app_root/oh-package.json5"; then
  printf 'oh-package.json5 must depend on "rustdesk-ohrs": "file:./rustdesk-ohrs.har".\n' >&2
  exit 1
fi
if [[ ! -f "$source_har" ]]; then
  cat >&2 <<EOF
Missing native HAR: $source_har

Build it first:
  cd "$engine_root"
  bash native/ohos_napi/build-har.sh
EOF
  exit 1
fi

verify_args=(--har "$source_har" --sidecar "$source_provenance")
if [[ -n "${RD_ENGINE_SHA:-}" ]]; then
  verify_args+=(--expected-engine-sha "$RD_ENGINE_SHA")
fi
if [[ -n "${RD_ENGINE_HAR_VERSION:-}" ]]; then
  verify_args+=(--expected-package-version "$RD_ENGINE_HAR_VERSION")
fi
# Schema 2 records the commit and dirty flag, not a working-tree freshness receipt.
# This checks the real sidecar and native bytes; it does not claim current-source or ABI parity.
python3 "$verifier" "${verify_args[@]}"

cp "$source_har" "$target_har"
cd "$app_root"
rm -rf oh_modules entry/oh_modules
"$ohpm_bin" install
(
  cd entry
  "$ohpm_bin" install
)

printf 'Refreshed %s from %s\n' "$target_har" "$source_har"
