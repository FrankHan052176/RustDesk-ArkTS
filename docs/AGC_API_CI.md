# AGC API CI

The `ohos` workflow uploads the signed `publish/release` App and submits an AGC test version through the AppGallery Connect API Client flow.

Configure these repository Secrets:

- `AGC_CLIENT_ID`
- `AGC_CLIENT_SECRET`
- `AGC_APP_ID`

The API Client must be a team-level client (`N/A` project) with permission to upload packages and manage testing versions. The default China endpoint is `connect-api.cloud.huawei.com`; override it with the repository variable `AGC_API_DOMAIN` only when the AGC data-processing region requires another endpoint.

Optional repository variables:

- `AGC_TEST_TYPE`: `3` for invitation testing (default), `4` for public testing.
- `AGC_TEST_DESC`: test description; the API limit is 50 characters.

The script obtains a token, requests a short-lived upload URL, uploads the `.app`, creates a test version, adds the package, waits for package compilation, binds the package, and submits the test version. It does not print the Client Secret or access token. When any required Secret is absent, the AGC step is skipped and the signed GitHub artifact is still produced.

Official API references:

- [AppGallery Connect API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-0000002236015554)
- [API Client authentication](https://developer.huawei.com/consumer/cn/doc/app/agc-help-connect-api-obtain-server-auth-0000002271134661)
- [Upload Management API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-upload-api-reference-0000002236041486)
- [Testing API](https://developer.huawei.com/consumer/cn/doc/app/agc-help-test-api-reference-0000002271000709)
