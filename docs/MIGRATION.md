# Migrating from Battery Toolkit 1.8

Version 1.9 is a community-maintained fork. It deliberately uses different app,
daemon, login-item, and XPC identifiers from the archived upstream release.
This prevents an experimental build from silently replacing the original
developer's services, but it also means macOS can run both versions at once.

Do not leave both background services enabled. Two independent processes
trying to control charging can produce unpredictable results.

## Move from 1.8 to the 1.9.0 community pre-release

1. Open Battery Toolkit 1.8.
2. Choose **Disable Background Activity** from its application menu.
3. Confirm in **System Settings → General → Login Items & Extensions** that the
   old Battery Toolkit background item is disabled.
4. Quit Battery Toolkit 1.8.
5. Keep the old app as a temporary backup instead of deleting it immediately.
6. Copy `Battery Toolkit 1.9.0.app` to `/Applications`.
7. Open version 1.9 and approve its new background item if macOS asks.
8. Re-enter and save the lower and upper charge thresholds. Settings are not
   imported automatically because the fork uses its own preferences domain.
9. Reopen Settings and confirm that both thresholds were saved.

## Changing signing identity

If you previously installed a locally Apple Development-signed **fork**, macOS
may retain the old signing requirement even after replacing it with the
independently signed release. This can show as **Failed to communicate with
the background service** although the background switch is on.

1. Quit the fork's GUI.
2. Open **System Settings → General → Login Items & Extensions**.
3. Turn background activity for **Battery Toolkit 1.9.0** off, then on again.
4. Reopen the app, open Settings, and confirm that your thresholds are intact.

This recovered the cached launch constraint on the maintainer's macOS 27 Mac
without deleting the fork's preferences. Do not reset all background items,
disable system protections, or toggle unrelated applications. If it still
fails, stop using the new build and report the problem with the macOS version
and the app version; do not leave competing charging services running.

## Roll back to 1.8

1. Open the version 1.9 app.
2. Choose **Disable Background Activity** and wait until the app closes.
3. Move version 1.9 out of `/Applications`.
4. Restore the version 1.8 app to `/Applications/Battery Toolkit.app`.
5. Open version 1.8 and enable its background activity again.
6. Re-enter the desired charge thresholds and verify them after reopening
   Settings.

## Identifiers used by the fork

| Component | Identifier |
| --- | --- |
| App | `io.github.paintaviolin.BatteryToolkit` |
| Daemon | `io.github.paintaviolin.BatteryToolkit.daemon` |
| Login item | `io.github.paintaviolin.BatteryToolkit.Autostart` |
| XPC service | `io.github.paintaviolin.BatteryToolkit.Service` |

These identifiers are intentionally different from the `me.mhaeuser` names
used by version 1.8.
