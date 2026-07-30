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

The workflow only creates HarmonyOS invitation testing versions: `testType=3` and `onshelfSelfDetect=0`. It obtains a token, queries every invitation-test group through the paginated `/api/app-test/v1/test-group/list` API, then uploads the signed `.app` and the ACL permission-introduction video. The App object is registered once with `distributeMode=2` (testing and AppGallery listing), and that package is bound to the invitation test version. `appId` is sent as a request header for the group API.

The update request refuses to proceed without at least one group. It writes every `groupId`, a start time one hour after the current UTC time, an end time after `AGC_TEST_DURATION_DAYS`, `displayArea="1"`, and `needShareLink=0`. It sends a test notification only for the first attempt of an ArkTS `push` run; dispatches, manual runs, and retries do not notify testers.

The update attaches the SVID introduction video for `ohos.permission.INTERCEPT_INPUT_EVENT` on phone (`deviceType=4`) and tablet (`deviceType=5`). The Testing API does not define a 2-in-1 device type, so the app's 2-in-1 manifest declaration is not sent with a guessed value.

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
