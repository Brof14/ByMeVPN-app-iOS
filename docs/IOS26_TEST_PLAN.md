# iOS 26 test and release gate — ByMeVPN

Target device: **iPhone 11 running iOS 26**. Developer workstation: **Windows only**.

## Automated checks (no Apple Developer enrollment)

Run **iOS Build & Tests** in GitHub Actions. It runs on macOS 26 with Xcode 26, builds the pinned Libbox XCFramework, generates Xcode project with XcodeGen, compiles the unsigned iOS Simulator and device targets, then executes model/config regression tests and a sign-in/registration XCUITest on an iOS 26 simulator.

The uploaded `bymevpn-ios26-unsigned-builds` artifact is **unsigned**, not an installable IPA and not evidence that Packet Tunnel traffic works on a real iPhone.

## Prerequisites for physical iPhone VPN tests

- A paid Apple Developer Program membership meeting Apple's VPN app enrollment requirements (for public VPN distribution, organization enrollment under App Review guideline 5.4).
- Provisioned App IDs for `com.bymevpn.ios` and `com.bymevpn.ios.PacketTunnel`.
- Network Extension Packet Tunnel entitlement on both targets and matching App Group `group.com.bymevpn.ios`.
- Valid signing certificates, provisioning profiles and signed build, installed through a supported Apple distribution/development workflow.
- Access to a working ByMeVPN backend account with a **legitimate** trial or active plan and a server that uses supported VLESS Reality / WebSocket or Hysteria2. XHTTP is not yet supported on iOS.

Do not assume AltStore's free Apple Account signing provides the Packet Tunnel capability. Do not treat unsigned build artifacts as ready-to-install `.ipa` files.

## Manual real-device acceptance matrix

| Area | Pass criterion |
| --- | --- |
| Launch | iPhone 11 iOS 26 launches without terminating or a blank screen |
| Auth | Email login/logout and Telegram login/cancel are repeatable; no cross-account state |
| Subscription | Real plan status, expiry, trial availability and device limits match the backend |
| Server switching | Switch only while disconnected; selected server survives catalog refresh |
| First VPN prompt | System presents VPN permission request; cancellation leaves no active session |
| VLESS Reality | Packet Tunnel starts; HTTPS requests actually transfer data and use intended exit route |
| Hysteria2 | Same as VLESS for a backend-supported Hysteria2 server |
| Wi-Fi / cellular | Test each separately and test switching from Wi-Fi to cellular while connected |
| DNS | Domain names resolve in both IPv4 and IPv6; check for leaks and no captive traffic blackholes |
| Bypass | Only .ru, .рф and .su domain rules are currently implemented; confirm the UI says so |
| Kill switch / on-demand | Toggle setting then reconnect; test shutdown, reasserting, and intentional disconnect |
| Errors | Invalid credentials, no internet, denied VPN permission and unsupported XHTTP show useful errors |
| Session cleanup | Failed tunnel start releases server session; logout and account deletion disconnect tunnel |
| UI | All available screens, scroll areas, action buttons, language changes, dynamic type and small-screen layouts |
| Payments | Must remain visibly unavailable until StoreKit plus server-side receipt verification is implemented |

**Do not mark VPN as verified merely because iOS displays “Connected” or Libbox accepts the JSON.** Some iOS Packet Tunnel + Libbox integrations report a connected status while `packetFlow` delivers no packets through the selected tunnel file descriptor. Validate real outbound traffic before release.

## Blockers before claiming Android feature parity

1. Implement/test an Xray-compatible **XHTTP** transport, or provide an explicitly supported backend alternative.
2. Configure the Google **iOS** OAuth client and complete Google Sign-In callback/nonce flow.
3. Implement StoreKit subscriptions and server-side transaction validation, with appropriate regional compliance.
4. Add the full Russian-site/IP split-tunnel routing if marketing promises it.
5. Confirm published, reachable privacy policy and terms URLs and legal entity for App Review.
6. Complete signed physical-device packet flow, DNS and network switching acceptance runs.

## Reporting defects

Record iOS version/build, commit SHA, network type, server/protocol **name only**, reproduction steps, timestamp, user-visible error, VPN system status and observed traffic result. **Never attach access tokens, refresh tokens, VPN UUIDs, Reality keys, subscription links or unredacted tunnel configs.**
