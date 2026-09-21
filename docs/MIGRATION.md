# Migrating from Battery Toolkit 1.8

Version 1.9 is a community-maintained fork. It deliberately uses different app,
daemon, login-item, and XPC identifiers from the archived upstream release.
This prevents an experimental build from silently replacing the original
developer's services, but it also means macOS can run both versions at once.

Do not leave both background services enabled. Two independent processes
trying to control charging can produce unpredictable results.

## Move from 1.8 to the 1.9 development build

1. Open Battery Toolkit 1.8.
2. Choose **Disable Background Activity** from its application menu.
3. Confirm in **System Settings → General → Login Items & Extensions** that the
   old Battery Toolkit background item is disabled.
4. Quit Battery Toolkit 1.8.
5. Keep the old app as a temporary backup instead of deleting it immediately.
6. Copy the locally built version 1.9 app to `/Applications`.
7. Open version 1.9 and approve its new background item if macOS asks.
8. Re-enter and save the lower and upper charge thresholds. Settings are not
   imported automatically because the fork uses its own preferences domain.
9. Reopen Settings and confirm that both thresholds were saved.

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
