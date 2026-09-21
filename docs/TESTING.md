# Version 1.9 release-candidate checklist

Run this checklist on the exact app bundle intended for release. Record the Mac
model, macOS build, app commit, signing identity type, and test date with the
results.

## Completed during initial macOS 27 development

- [x] Release configuration builds with Xcode 27 and Swift 6.
- [x] The complete app bundle passes strict nested code-signature validation.
- [x] The forked daemon registers and reports itself as enabled.
- [x] The app communicates with the daemon over XPC.
- [x] Lower and upper charge thresholds can be changed and persist after the
  Settings window is reopened.
- [x] The installed app runs from `/Applications` rather than a temporary build
  directory.

## Required before publishing 1.9.0

- [ ] Verify charging begins below the configured lower threshold.
- [ ] Verify charging stops at the configured upper threshold.
- [ ] Verify **Charge to Limit**, **Charge to Full**, and **Stop Charging**.
- [ ] Verify disconnecting and reconnecting the power adapter.
- [ ] Verify sleep and wake below, between, and above the configured thresholds.
- [ ] Verify a normal reboot with the power adapter connected.
- [ ] Verify daemon restart and app upgrade preserve or restore the previous
  system Manual Charge Limit as documented.
- [ ] Verify **Disable Background Activity** restores system charging control.
- [ ] Verify rollback to the archived version 1.8 without both daemons running.
- [ ] Re-run the checklist on every supported macOS family listed in README.

## Release packaging

- [ ] Build from a clean checkout of the release commit.
- [ ] Confirm the version is `1.9.0` in the app and every embedded component.
- [ ] Confirm the archive contains no development data or dSYM bundle.
- [ ] Verify every nested executable after copying the app out of the archive.
- [ ] Document whether the binary is notarized and which signing method was
  used.
- [ ] Publish SHA-256 checksums with the GitHub release.
