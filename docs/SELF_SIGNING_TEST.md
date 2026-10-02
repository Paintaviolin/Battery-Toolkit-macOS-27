# Independent signing experiment — 2026-10-02

This records the isolated experiment and subsequent live installation test.
It is not a complete fresh-installation test on a second Mac.

## Environment and scope

- Mac model: `Mac15,6` (Apple Silicon).
- macOS: `27.0`, build `26A428`.
- Base source commit: `7177d92`, plus the uncommitted certificate-pin changes.
- Configuration: Release, Hardened Runtime enabled.
- Certificate subject and issuer: `Paintaviolin Battery Toolkit Test` only.
  No real name, email address, Apple Team ID, or Apple-issued signing certificate
  was included in this experimental identity.
- The identity was kept in a separate temporary keychain. It was not added to
  system certificate trust. No global Gatekeeper settings were changed.

## Verified

- The complete experimental app bundle and its nested daemon, XPC service,
  and login helper pass strict code-signature validation.
- The experimental app passes a requirement for the exact certificate and
  fails a requirement for a different certificate fingerprint.
- An isolated XPC test compiles the production `BTXPCValidation.swift` and
  uses real, independently signed processes (not mocked security APIs).
- The correctly signed client receives an authenticated reply.
- A client with the wrong bundle identifier, and an ad-hoc-signed client
  without the expected certificate, are rejected. macOS terminates these
  intentionally invalid clients with SIGTRAP on the requirement violation.
- A separate test app registers a daemon through `SMAppService`. Registration
  initially requires the user's normal background-activity approval.
- After the maintainer grants approval, the daemon starts in the system domain
  as UID `0` and answers the authenticated XPC client.
- Both invalid-client tests are also rejected by this root daemon.
- The test app successfully unregisters the daemon afterwards. Its service
  status becomes `notRegistered`, and launchd no longer contains the job.
- The default Apple-signed build configuration still compiles with an empty
  certificate pin.
- All 469 sleep-policy/lifecycle checks still pass (64 state combinations).

The isolated test daemon does not include power-control code. The currently
installed Battery Toolkit app was not replaced or stopped during this test.

## Not yet verified

- First launch of a downloaded, quarantined self-signed app through Gatekeeper.
  The default `spctl` assessment rejects the experimental app; a valid code
  signature is not equivalent to Apple notarization or Gatekeeper approval.
- Registration and normal operation of the complete Battery Toolkit app with
  the new identity, including its authorization XPC service and login helper.
- Migration from the Apple Development-signed installed app to the new identity.
- Restart, update, uninstall, and recovery using this identity.
- Installation on a second Mac without the test identity or keychain present.
- Final archive privacy checks and distribution packaging.

## Security properties

An optional build setting, `BT_CODESIGN_CERT_SHA1`, selects the independently
signed configuration. It pins an exact signing certificate, not a freely
chosen display name. SHA-1 here is the fingerprint syntax of Apple's code
requirement language, not the certificate's signature algorithm (SHA-256).
Malformed pins fail closed. An empty pin retains the existing Apple-issued
certificate and signing-team requirements.

Both configurations retain the bundle-identifier checks, disallowed-entitlement
checks, and dynamic Hardened Runtime/signature-status checks. This experiment
does not remove daemon client authentication.

The generated test certificate, private key, keychain, and passwords are not
repository assets and must not be committed or uploaded. A release identity
and its private-key backup need a separate preparation step.

## Application-name follow-up

The app now builds as `Battery Toolkit 1.9.0.app` and displays
`Battery Toolkit 1.9.0`. Its fork-owned bundle identifier remains unchanged;
the Swift module name is explicitly preserved so storyboard connections still
resolve. The settings storyboard/navigation/layout/save smoke tests pass with
the renamed app.

A separate certificate with subject/issuer `Battery Toolkit` only signs the
renamed experimental build. The complete bundle passes strict nested signature
validation and the exact-certificate requirement. This certificate has no
version in its display name, so a release identity can remain stable across
application updates. It is a different certificate from the one used for the
root-daemon experiment above; a full installation test is still outstanding.

Neither the installed app nor the public GitHub branch was changed during
the naming follow-up. The temporary signing keychain was locked after signing.

## Full-app migration attempt

The Apple Development-signed fork was subsequently backed up, its GUI stopped,
and its daemon unregistered using a temporary migration utility signed with
the existing identity. This avoided the normal uninstall operation, which
deletes preferences. The daemon reported a saved lower/upper threshold of
60/80 and the plugged-in sleep preference enabled before the migration.

The self-signed `Battery Toolkit 1.9.0.app` was installed in `/Applications`
and launched. Registration reported `enabled`, but the production daemon
failed to spawn with `Launch Constraint Violation` / `EX_CONFIG`. Inspection
showed launchd retaining a lightweight code requirement for the previous
Apple Development signing team, despite the installed app and daemon both
being signed by the independent certificate.

The maintainer then toggled only **Battery Toolkit 1.9.0** background activity
off and on in System Settings. launchd replaced the cached Apple-team constraint
with the current daemon's code hash. The production daemon now runs as root;
an independently signed client with the production app identifier reads its
settings and state over authenticated XPC. The 60/80 thresholds and all three
boolean preferences were preserved. The GUI was restarted afterwards.

No global background-item database reset or security-policy change was
performed. The previous app bundle remains available for local rollback.
The complete current identity was also imported into the maintainer's login
keychain so it is not stored solely in an ephemeral test keychain.

This passes service recovery and read-only live communication, not every test
listed above. The first public distribution is a pre-release; fresh downloaded
installation, login-helper startup, reboot, upgrade, and uninstall checks remain
open for the independent identity.
