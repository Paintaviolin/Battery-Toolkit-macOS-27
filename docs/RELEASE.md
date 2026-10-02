# Battery Toolkit 1.9.0 community pre-release

This is a community-maintained fork, not an official release from the original
author. The public app is named `Battery Toolkit 1.9.0.app`. All four embedded
components report version `1.9.0`.

## Independent signing

The certificate's subject and issuer are **Battery Toolkit** only. It contains
no maintainer name, email address, or Apple Team ID. The app, daemon, XPC service,
and login helper use the same certificate. XPC clients and services still
require their exact bundle identifier and certificate, plus the existing
Hardened Runtime and entitlement checks. A matching display name is not enough.

- Certificate SHA-1 pin: `6a5cac50121ad4c34ed4e26bb725348b463cf8be`.
- Public certificate: [ReleaseCertificate.pem](../signing/ReleaseCertificate.pem).
- Certificate signature algorithm: SHA-256 with RSA.
- Certificate validity ends: **2027-10-01 22:42:37 UTC**. This first identity
  needs renewal planning before then; it is not an indefinite signing solution.
- Apple notarization: **none**. Normal Gatekeeper assessment does not accept
  this certificate automatically. Never globally disable Gatekeeper or trust
  this certificate as a system root to install the app.

The SHA-1 pin is Apple's code-requirement fingerprint syntax, not the
certificate's signature algorithm. Private keys, signing keychains, and
passwords are not part of the repository or release archive. The maintainer
has imported the identity into their login keychain; a secure, independent
backup is still recommended before rebuilding future releases.

## Build and package

The release archive is generated from a clean commit with
[build-independent-release.sh](../scripts/build-independent-release.sh).
It uses the public certificate pin, disables automatic Apple signing, signs
each component explicitly, and verifies the extracted archive. A matching
private key is required to reproduce this signature. Other developers should
use their own Apple Development team for a local build or their own independent
identity and update the certificate pin accordingly.

```sh
scripts/build-independent-release.sh /absolute/path/to/signing.keychain-db
```

The keychain must already contain the matching identity and permit `codesign`
to use it. The script does not change certificate trust or keychain permissions.
It excludes dSYM bundles and creates `SHA256SUMS.txt` next to the ZIP archive.

## Scope and remaining tests

Live app/daemon operation and preference preservation after signing migration
have been checked on one Apple Silicon `Mac15,6` running macOS `27.0` build
`26A428`. See [the signing test record](SELF_SIGNING_TEST.md) and
[the release checklist](TESTING.md). Earlier charging and sleep/wake feedback
was obtained with a previous signing identity; it does not establish complete
coverage for this independently signed build.

Fresh installation of a downloaded/quarantined app on another Mac, reboot,
login-helper autostart, update, and uninstall recovery still need verification
with this identity. Other macOS families are source compatibility targets,
not a promise that this binary has been tested there.

If migrating from an earlier locally Apple-signed build of this fork and the
daemon fails despite background activity being enabled, see
[the migration troubleshooting steps](MIGRATION.md#changing-signing-identity).
