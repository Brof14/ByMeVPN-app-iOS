# ByMeVPN for iOS (native Swift)

A native SwiftUI port of [ByMeVPN for Android](https://github.com/Brof14/ByMeVPN-app), with the same backend endpoint, navigation structure, visual colors, and existing branded imagery.

## Implemented

- iOS 17+ native SwiftUI UI: sign in, sign up, home, server list, 3-day trial, plans, settings, advanced settings, account, account settings, devices, renewal, support, FAQ.
- Russian and English UI (system language by default).
- Email/password and Telegram authorization; secure credentials in Keychain; transparent 401 token refresh.
- Server-driven subscription/plan/device state, device removal, account deletion and logout. No locally forged entitlements or checkout prices.
- VPN manager via `NETunnelProviderManager`, Packet Tunnel Extension, native Libbox (sing-box), a server-issued `/vpn/session` config, VLESS/Reality and Hysteria2 generation, VPN stop/on-demand and user-consented VPN disclosure.
- Russian domain bypass defaults to enabled (.ru, .рф, .su); DNS selector and VPN kill-switch settings.
- Exact current Android shield and 1024×1024 app icon copied from its repository.
- CI on macOS 26 / Xcode 26: unsigned iPhone/simulator builds, model regression tests and a simulator sign-in/registration UI smoke test. Pinned sing-box is built from source.

## Important limitations (not ready to claim full parity)

1. **VPN engine:** Building and running this project requires a compatible `Libbox.xcframework` from `SagerNet/sing-box` pinned to `v1.13.14`. The GitHub workflow builds it from source. Real device tests of VLESS Reality, DNS, reconnect, IPv4/IPv6 and traffic routing are still required. iOS Simulator cannot establish a real Packet Tunnel.
2. **XHTTP:** Android supports Xray XHTTP, but sing-box's supported V2Ray transports do not provide equivalent XHTTP compatibility. Such servers are intentionally rejected; do not silently replace XHTTP with TCP. Full Android parity requires an Xray-core based iOS tunnel engine or a backend-provided supported alternate transport.
3. **StoreKit:** iOS digital subscription purchases are **not implemented**. Backend prices appear, but checkout is not enabled without the App Store payment configuration and backend receipt verification. Existing subscribers can sign in. Do not link directly to YooKassa in worldwide App Store builds without a region-specific legal review.
4. **Google Sign-In:** Needs an iOS OAuth client ID, URL callback configuration and GoogleSignIn SDK integration. Telegram and email sign-in are available.
5. **Russian bypass:** The current implementation only routes `.ru`, `.рф` and `.su` domains directly. Full geo-based bypass needs verified and maintained route rules from the backend.
6. **Release signing:** Requires an Apple Developer **organization** account (Apple's VPN App Review rule 5.4), associated App IDs, App Group, Network Extension capability, signing certificates and provisioning. Adjust bundle IDs and App Group if they differ from the final provisioned identifiers.
7. **Live backend:** The Android app itself warns that the production `/mobile/v2` plans, payments, devices, and VPN flows still need end-to-end release validation.

## Build with macOS

```sh
# Requires Xcode + XcodeGen + Go and a compatible Libbox framework.
brew install xcodegen
# Build Libbox.xcframework as in .github/workflows/ios-ci.yml
mkdir -p Frameworks
# Place Libbox.xcframework in Frameworks/Libbox.xcframework
xcodegen generate
xcodebuild build -project ByMeVPN.xcodeproj -scheme ByMeVPN \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

To run on a real iPhone, configure the organization team, the bundle IDs, App Group and Network Extension entitlements in Xcode and build to device. Approve the iOS VPN system permission prompt. **An unsigned CI build is not an installable, signed App Store release.**

## API contract

The iOS client uses Android's `https://bymevpn.duckdns.org/api/v1` base URL and its `/auth/login`, `/auth/register`, `/auth/refresh`, `/auth/telegram/*`, `/me`, `/subscription/status`, `/subscription/trial`, `/servers`, `/vpn/session`, `/devices`, and `/mobile/v2/plans?devices=...` endpoints.

Secret access/refresh tokens are saved with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. VPN session JSON is stored in a protected App Group file for the Packet Tunnel Extension. Never log or commit user credentials or raw server session configurations.

## Testing on iPhone 11 with iOS 26 (Windows-only workstation)

See [iOS 26 acceptance and release plan](docs/IOS26_TEST_PLAN.md). CI can validate Xcode 26 compilation and simulator UI without a Mac or paid account. The uploaded artifacts are **unsigned app bundles**, not installable IPAs. An Apple-provisioned Packet Tunnel and a real iPhone network traffic test remain mandatory before declaring VPN connectivity production-ready.
