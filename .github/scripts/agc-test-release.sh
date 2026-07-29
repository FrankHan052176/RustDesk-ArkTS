#!/usr/bin/env bash
set -euo pipefail

: "${AGC_CLIENT_ID:?AGC_CLIENT_ID is required}"
: "${AGC_CLIENT_SECRET:?AGC_CLIENT_SECRET is required}"
: "${AGC_APP_ID:?AGC_APP_ID is required}"

AGC_API_DOMAIN="${AGC_API_DOMAIN:-connect-api.cloud.huawei.com}"
AGC_APP_FILE="${1:-${AGC_APP_FILE:-}}"
if [[ -z "$AGC_APP_FILE" || ! -f "$AGC_APP_FILE" ]]; then
  echo "Signed App file is missing." >&2
  exit 1
fi

api_base="https://${AGC_API_DOMAIN}/api"
app_id_q=$(jq -rn --arg value "$AGC_APP_ID" '$value | @uri')
app_name=$(basename "$AGC_APP_FILE")
app_size=$(wc -c < "$AGC_APP_FILE" | tr -d ' ')
if command -v sha256sum >/dev/null 2>&1; then
  app_sha256=$(sha256sum "$AGC_APP_FILE" | awk '{print $1}')
else
  app_sha256=$(shasum -a 256 "$AGC_APP_FILE" | awk '{print $1}')
fi

check_ret() {
  local response="$1"
  if ! jq -e '((.ret.code // "") | tostring) == "0"' >/dev/null <<<"$response"; then
    local message
    message=$(jq -r '.ret.msg // .message // "AGC API request failed"' <<<"$response")
    echo "AGC API request failed: $message" >&2
    exit 1
  fi
}

token_response=$(curl --silent --show-error --fail-with-body \
  --request POST "$api_base/oauth2/v1/token" \
  --header 'Content-Type: application/json' \
  --data "$(jq -cn \
    --arg client_id "$AGC_CLIENT_ID" \
    --arg client_secret "$AGC_CLIENT_SECRET" \
    '{grant_type: "client_credentials", client_id: $client_id, client_secret: $client_secret}')")
access_token=$(jq -er '.access_token // empty' <<<"$token_response") || {
  echo "AGC token response did not contain access_token." >&2
  exit 1
}

api_headers=(
  --header "Authorization: Bearer $access_token"
  --header "client_id: $AGC_CLIENT_ID"
  --header 'Content-Type: application/json'
)

upload_url_response=$(curl --silent --show-error --fail-with-body \
  --get "$api_base/publish/v2/upload-url/for-obs" \
  "${api_headers[@]}" \
  --data-urlencode "appId=$AGC_APP_ID" \
  --data-urlencode "fileName=$app_name" \
  --data-urlencode "sha256=$app_sha256" \
  --data-urlencode "contentLength=$app_size")
check_ret "$upload_url_response"
upload_url=$(jq -er '.urlInfo.url // empty' <<<"$upload_url_response")
upload_method=$(jq -er '.urlInfo.method // "PUT"' <<<"$upload_url_response")
object_id=$(jq -er '.urlInfo.objectId // empty' <<<"$upload_url_response")
upload_headers=()
while IFS= read -r header_json; do
  header_name=$(jq -r '.key' <<<"$header_json")
  header_value=$(jq -r '.value' <<<"$header_json")
  upload_headers+=(--header "$header_name: $header_value")
done < <(jq -c '.urlInfo.headers // {} | to_entries[]' <<<"$upload_url_response")

curl --silent --show-error --fail-with-body \
  --request "$upload_method" \
  "${upload_headers[@]}" \
  --data-binary "@$AGC_APP_FILE" \
  "$upload_url" >/dev/null

test_desc="${AGC_TEST_DESC:-CI ${GITHUB_REPOSITORY:-local} ${GITHUB_SHA:-local}}"
test_desc="${test_desc:0:50}"
test_type="${AGC_TEST_TYPE:-3}"
onshelf_self_detect="${AGC_ONSHELF_SELF_DETECT:-0}"
release_type="${AGC_RELEASE_TYPE:-6}"
create_response=$(curl --silent --show-error --fail-with-body \
  --request POST "$api_base/publish/v2/test/app/version?appId=$app_id_q" \
  "${api_headers[@]}" \
  --data "$(jq -cn \
    --arg desc "$test_desc" \
    --argjson release_type "$release_type" \
    --argjson test_type "$test_type" \
    --argjson onshelf_self_detect "$onshelf_self_detect" \
    '{releaseType: $release_type, testType: $test_type, testDesc: $desc, onshelfSelfDetect: $onshelf_self_detect}')")
check_ret "$create_response"
version_id=$(jq -er '.versionId // empty' <<<"$create_response")

package_response=$(curl --silent --show-error --fail-with-body \
  --request POST "$api_base/publish/v2/test/version/pkg?appId=$app_id_q" \
  "${api_headers[@]}" \
  --data "$(jq -cn \
    --arg file_name "$app_name" \
    --arg object_id "$object_id" \
    --argjson distribute_mode "${AGC_DISTRIBUTE_MODE:-1}" \
    '{distributeMode: $distribute_mode, file: {fileName: $file_name, objectId: $object_id}}')")
check_ret "$package_response"
package_id=$(jq -er '.pkgVersion[0] // empty' <<<"$package_response")

poll_attempts="${AGC_POLL_ATTEMPTS:-30}"
poll_seconds="${AGC_POLL_SECONDS:-20}"
package_ready=false
for ((attempt = 1; attempt <= poll_attempts; attempt++)); do
  status_response=$(curl --silent --show-error --fail-with-body \
    --get "$api_base/publish/v3/package/compile/status" \
    "${api_headers[@]}" \
    --data-urlencode "appId=$AGC_APP_ID" \
    --data-urlencode "pkgIds=$package_id")
  check_ret "$status_response"
  success_status=$(jq -r '.pkgStateList[0].successStatus // empty' <<<"$status_response")
  if [[ "$success_status" == "0" ]]; then
    package_ready=true
    break
  fi
  if (( attempt < poll_attempts )); then
    sleep "$poll_seconds"
  fi
done
if [[ "$package_ready" != true ]]; then
  echo "AGC package did not reach success status within the polling window." >&2
  exit 1
fi

update_response=$(curl --silent --show-error --fail-with-body \
  --request PUT "$api_base/publish/v2/test/app/version?appId=$app_id_q" \
  "${api_headers[@]}" \
  --data "$(jq -cn --arg version_id "$version_id" --arg package_id "$package_id" \
    '{versionId: $version_id, pkgId: $package_id}')")
check_ret "$update_response"

submit_response=$(curl --silent --show-error --fail-with-body \
  --request POST "$api_base/publish/v2/test/app/version/submit?appId=$app_id_q" \
  "${api_headers[@]}" \
  --data "$(jq -cn --arg version_id "$version_id" '{versionId: $version_id}')")
check_ret "$submit_response"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'agc_version_id=%s\n' "$version_id"
    printf 'agc_package_id=%s\n' "$package_id"
    printf 'agc_object_id=%s\n' "$object_id"
  } >> "$GITHUB_OUTPUT"
fi
echo "AGC test version submitted: $version_id"
