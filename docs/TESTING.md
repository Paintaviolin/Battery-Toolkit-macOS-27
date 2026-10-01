# Version 1.9.0 release-candidate checklist

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

## Maintainer feedback on the previous build

On 2026-10-01, the maintainer reported that the requested charging-command,
adapter-reconnection, sleep/wake, and reboot tests worked. That report also
identified the inherited charging-only sleep prevention, which is changed by
the new plugged-in sleep option. These results are preliminary feedback;
repeat them on the final release candidate rather than treating the new
behavior as already validated.

## Automated sleep-policy checks

The test harness compiles the production power-state and power-event code with
simulated hardware and sleep writes. It covers all 64 combinations of backend,
adapter attachment, charge hold, plugged-in sleep preference, software-disabled
adapter, and adapter-sleep preference. It also checks repeated notifications,
overlapping sleep reasons, failed adapter writes, wake, pause/resume, daemon
update, queued callbacks, and failed notification registration.

Run from the repository root (no signing or root privileges are required):

```sh
swiftc -swift-version 6 -parse-as-library \
  -module-cache-path /tmp/Battery-Toolkit-SleepTests-cache \
  Common/BTError.swift Common/BTStateInfo.swift \
  me.mhaeuser.batterytoolkitd/BTPowerState.swift \
  me.mhaeuser.batterytoolkitd/BTPowerEvents.swift \
  Tests/SleepPolicyTests.swift -o /tmp/Battery-Toolkit-SleepPolicyTests
/tmp/Battery-Toolkit-SleepPolicyTests
```

## Required before publishing 1.9.0

- [ ] Verify charging begins below the configured lower threshold.
- [ ] Verify charging stops at the configured upper threshold.
- [ ] Verify **Charge to Limit**, **Charge to Full**, and **Stop Charging**.
- [ ] Verify disconnecting and reconnecting the power adapter.
- [ ] Verify sleep and wake below, between, and above the configured thresholds.
- [ ] With the native backend and the plugged-in sleep option off, verify sleep
  while charging and while holding at the limit, then check the charge limit
  after waking.
- [ ] With the option on, verify sleep prevention while charging and while
  charging is stopped, including with the lid closed.
- [ ] Verify switching the option off releases its block immediately.
- [ ] Verify unplugging releases its block and reconnecting reapplies it.
- [ ] Verify the option persists after reopening Settings and after a reboot.
- [ ] Verify the existing software-disabled adapter sleep setting, including
  unplugging while that setting is active.
- [ ] Verify pausing/disabling background activity restores the prior sleep
  setting and resuming reapplies the saved preference.
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
