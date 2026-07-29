# AGC API CI

The `ohos` workflow uploads the signed `publish/release` App and submits an AGC test version through the AppGallery Connect API Client flow.

Configure these repository Secrets:

- `AGC_CLIENT_ID`
- `AGC_CLIENT_SECRET`
- `AGC_APP_ID`

The API Client must be a team-level client (`N/A` project) with permission to upload packages and manage testing versions. The default China endpoint is `connect-api.cloud.huawei.com`; override it with the repository variable `AGC_API_DOMAIN` only when the AGC data-processing region requires another endpoint.

Optional repository variables:

- `AGC_API_DOMAIN`: defaults to `connect-api.cloud.huawei.com`.
- `AGC_TEST_DURATION_DAYS`: invitation-test lifetime in days; defaults to `14`.

The workflow only creates HarmonyOS invitation testing versions: `testType=3` and `onshelfSelfDetect=0`. It obtains a token, requests a short-lived upload URL, uploads the `.app`, creates a test version, adds the package, waits for package compilation, then queries every invitation-test group through the paginated `/api/app-test/v1/test-group/list` API. `appId` is sent as a request header for that API.

The update request refuses to proceed without at least one group. It writes every `groupId`, a start time one hour after the current UTC time, an end time after `AGC_TEST_DURATION_DAYS`, `displayArea="1"`, and `needShareLink=0`. It sends a test notification only for the first attempt of an ArkTS `push` run; dispatches, manual runs, and retries do not notify testers.

The test description is truncated to the API's 50-character limit: `同步上游 <HAR version>` for a Core dispatch, the push commit message for a push, and the current SHA for a manual run. The script does not print the Client Secret or access token. When the three required Secrets are absent, the AGC step is skipped and the signed GitHub artifact is still produced.

Official API references:

- [AppGallery Connect API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-0000002236015554)
- [API Client authentication](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-obtain-server-auth-0000002271134661)
- [Upload Management API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-upload-api-reference-0000002236041486)
- [Testing API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-reference-0000002271000709)
