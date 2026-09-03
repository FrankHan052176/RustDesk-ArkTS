# AGC API CI

The `Build ArkTS HarmonyOS App` workflow uploads the signed `publish/release` App and submits an AGC test version through the AppGallery Connect API Client flow.

Configure these repository Secrets:

- `AGC_CLIENT_ID`
- `AGC_CLIENT_SECRET`
- `AGC_APP_ID`

The API Client must be a team-level client (`N/A` project) with permission to upload packages and manage testing versions. The default China endpoint is `connect-api.cloud.huawei.com`; override it with the repository variable `AGC_API_DOMAIN` only when the AGC data-processing region requires another endpoint.

Optional repository variables:

- `AGC_API_DOMAIN`: defaults to `connect-api.cloud.huawei.com`.
- `AGC_TEST_DURATION_DAYS`: invitation-test lifetime in days; defaults to `14`.

The workflow only creates HarmonyOS invitation testing versions: `testType=3` and `onshelfSelfDetect=0`. It obtains a token, queries every invitation-test group through the paginated `/api/app-test/v1/test-group/list` API, then uploads the signed `.app` and the ACL permission-introduction video. The App object is registered once with `distributeMode=2` (testing and AppGallery listing), and that package is bound to the invitation test version. `appId` is sent as a request header for the group API.

The update request refuses to proceed without at least one group. It writes every `groupId`, a start time one hour after the current UTC time, an end time after `AGC_TEST_DURATION_DAYS`, `displayArea="1"`, and `needShareLink=0`. It sends a test notification only for the first attempt of an ArkTS `push` run; dispatches, manual runs, and retries do not notify testers.

After AGC finishes processing the uploaded package, the workflow updates the app file information and attaches the SVID introduction video for `ohos.permission.INTERCEPT_INPUT_EVENT` on phone (`deviceType=4`), tablet (`deviceType=5`), and PC/2-in-1 (`deviceType=19`). It passes the same three records to the invitation-test version. The PC/2-in-1 value follows the Publishing API's `PackagePermissionIntroVideo` contract and matches the app manifest's supported device types.

Before the signed `publish/release` App is built, CI counts Action build attempts since the commit that introduced the current base version and counts Action build attempts created on the current UTC date. It rewrites only the runner checkout using these formulas:

```text
versionName = <base major.minor.patch>.<current-version build count>
versionCode = 100000000 + (<UTC days since 2020-01-01> × 100) + <UTC daily build count>
```

The fixed epoch keeps `versionCode` monotonic across year boundaries, and the offset keeps the new scheme above every previously published `10xxxxxx` code. A rerun increments both counters through `run_attempt`, and the UTC daily count supports `01..99`. Local builds continue to use the static committed `AppScope/app.json5` baseline.

Repository and manual release dispatches must supply an exact HAR package version plus the full Core and HAR commit SHAs. Push validation reads the same immutable values from `.github/native-har-lock.json`; it never relies on the private registry's eventually consistent `@latest` tag. The workflow verifies the package-internal provenance and installed integrity, then uploads `release-provenance.json` beside the signed App with the ArkTS/Core/HAR revisions, exact signing-repository revision, package version/integrity, dynamic App version, App SHA-256, embedded HAP SHA-256, and CI run identity.

The same web-configurable test description is used when creating and updating a test version, and is truncated to 30 characters: `同步上游 <HAR version>` for a Core dispatch, the push commit message for a push, and the current SHA for a manual run. The script does not print the Client Secret or access token. When the three required Secrets are absent, the AGC step is skipped and the signed GitHub artifact is still produced.

The workflow also retains a non-sensitive `*-agc-ids` artifact containing the created version, package, and upload-object IDs. It intentionally does not delete AGC objects: the final CI run is the retained release record, and the public Testing API documents deletion of a test version but not deletion by package ID.

For a disposable local proof only, set `AGC_LOCAL_CLEANUP_AFTER_SUBMIT=1`. After a successful submit, the script follows the documented lifecycle for that exact generated test version: stop it, then delete it. This flag is not set by the workflow, and it never deletes package records.

Official API references:

- [AppGallery Connect API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-0000002236015554)
- [API Client authentication](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-obtain-server-auth-0000002271134661)
- [Upload Management API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-upload-api-reference-0000002236041486)
- [Testing API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-reference-0000002271000709)
- [Add test package](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-add-test-package-0000002236201330)
- [Modify test version](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-modify-test-version-0000002271160657)
- [Package permission introduction video](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-data-packagepermissionintrovideo-0000002237496316)
- [Update application file information](https://developer.huawei.com/consumer/cn/doc/app/agc-help-publish-api-app-file-info-update-0000002236041430)
