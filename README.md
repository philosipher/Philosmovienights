# Kamyns flix 2.0 iOS

This repository contains a lightweight native iOS wrapper for Kamyns flix 2.0.

It includes:

- A native SwiftUI login screen themed for Kamyns flix 2.0
- License login through KeyAuth
- Admin login with password `gekyume`
- A `WKWebView` that loads `https://kamynsflix.edgeone.app/`
- A GitHub Actions workflow that builds and exports a signed `.ipa`
- A generated iOS app icon so binary image files do not need to be committed

## What You Still Need

Apple requires signing before an IPA can install on a real iPhone. Add these GitHub repository secrets before running the workflow:

- `APPLE_TEAM_ID`
- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_CODE_SIGN_IDENTITY` optional, defaults to `Apple Distribution`

The provisioning profile must match the bundle identifier used in the workflow. The default bundle identifier is `co.median.ios.qdlejpp`.

## Build The IPA

1. Open this repo on GitHub.
2. Go to **Settings > Secrets and variables > Actions**.
3. Add the secrets listed above.
4. Go to **Actions > Build iOS IPA**.
5. Click **Run workflow**.
6. Download the `Kamyns-flix-2.0-ipa` artifact when the build completes.

For direct iPhone installation outside TestFlight/App Store, use an `ad-hoc` or `development` provisioning profile that includes your iPhone UDID. For TestFlight, use Apple distribution signing and upload through App Store Connect after the archive is built.