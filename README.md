<p align="center">
 <img alt="Battery Toolkit logo" src="Resources/LogoCaption.png" width=500 align="center">
</p>

<p align="center">Control the platform power state of your Apple Silicon Mac.</p>

<p align="center"><a href="#project-status">Status</a> &bull; <a href="#features">Features</a> &bull; <a href="#compatibility">Compatibility</a> &bull; <a href="#install">Install</a> &bull; <a href="#usage">Usage</a> &bull; <a href="#uninstall">Uninstall</a> &bull; <a href="#limitations">Limitations</a> &bull; <a href="#technical-details">Technical Details</a></p>

-----

> [!NOTE]
> This is a community-maintained fork of
> [mhaeuser/Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit),
> focused on restoring compatibility with macOS 27. Version 1.9 is currently
> under development and should be tested before it is used as a daily driver.

# Project status

The `macos-27` branch contains the version 1.9 development work. It currently:

* builds with Xcode 27 and Swift 6;
* runs its app, privileged daemon, login item, and XPC service under fork-owned
  identifiers;
* uses the native Manual Charge Limit backend on recent macOS firmware;
* preserves the legacy SMC backend for older supported firmware;
* adds an optional **Prevent sleep while the power adapter is connected**
  setting, independent of whether the battery is charging; and
* has been manually verified on macOS 27 for app startup, daemon communication,
  settings changes, and charge-threshold persistence.

The initial build's charging commands, adapter reconnection, sleep/wake, and
reboot tests were reported as working by the maintainer. The new sleep option
and uninstall recovery still need release-candidate testing. See the
[testing checklist](docs/TESTING.md) for the current validation status.

# Features

## Limits battery charge to an upper limit

Modern batteries deteriorate more when always kept at full charge. For this reason, Apple introduced the “Optimized Charging“ feature for all their portable devices, including Macs. However, its limit cannot be changed, and you cannot force charging to be put on hold. Battery Toolkit allows specifying a hard limit past which battery charging will be turned off. For safety reasons, this limit cannot be lower than 50&nbsp;%.

## Allows battery charge to drain to a lower limit

Even when connected to power, your Mac's battery may slowly lose battery charge for various reasons. Short battery charging bursts can further deteriorate batteries. For this reason, Battery Toolkit allows specifying a limit only below which battery charging will be turned on. For safety reasons, this limit cannot be lower than 20&nbsp;%.

**Note:** This setting is not honoured for cold boots or reboots, because Apple Silicon Macs reset their platform state in these cases. As battery charging will already be ongoing when Battery Toolkit starts, it lets charging proceed to the upper limit to not cause further short bursts across reboots.

## Allows you to disable the power adapter

If you want to discharge the battery of your Mac, e.g., to recalibrate it, you can turn off the power adapter without actually unplugging it. You can also have Battery Toolkit disable sleeping when the power adapter is disabled.

**Note:** Your Mac may go to sleep immediately after enabling the power adapter again. This is a software bug in macOS and cannot easily be worked around.

|<img alt="Power Settings" src="Resources/PowerSettings.png" width=607>|
|:--:| 
| **Fig. 1**. *Power Settings* |

## Lets you choose whether your Mac stays awake while plugged in

Version 1.9.0 adds **Prevent sleep while the power adapter is connected** to
Power settings. It is off by default. Turn it on to keep the Mac awake while
the adapter is attached, including when charging is stopped at the upper limit.
Unplugging the adapter, pausing background activity, or disabling the service
releases the app's sleep prevention. Closing the GUI alone does not pause it.

With the native charge-limit backend, leaving the option off allows normal
system sleep while charging. Other apps and macOS settings can still affect
sleep and closed-display operation. Display dimming and screen locking remain
controlled by macOS.

The existing **Prevent sleep when the power adapter is disabled** setting
applies separately to the adapter's software-disabled state while the cable is
attached. On older firmware, Battery Toolkit must still prevent sleep during
charging to monitor and enforce the upper limit.

## Grants you manual control

The Battery Toolkit "Commands" menu and its menu bar extra allow you to issue various commands related to the power state of your Mac. These include:
* Enabling and disabling the power adapter
* Requesting a full charge
* Requesting a charge to the specified upper limit
* Stopping charging immediately
* Pausing all background activity

|<img alt="Menu Bar Extra" src="Resources/MenuBarExtra.png" width=283>|
|:----------|
| **Fig. 2**. *Menu Bar Extra* |

# Compatibility

| macOS version | Charge-control backend | Status |
| --- | --- | --- |
| 27 | Native Manual Charge Limit | Development build manually verified on Apple Silicon |
| 26.4–26.x | Native Manual Charge Limit | Implemented, not yet manually verified by this fork |
| 13–26.3 | Legacy SMC controls | Inherited from version 1.8; not regression-tested by this fork yet |

Battery Toolkit supports Apple Silicon Macs only. Firmware capabilities can
also differ between Mac models, so an operating-system version alone does not
guarantee support.

# Install

> [!IMPORTANT]
> Battery Toolkit currently only supports Apple Silicon Macs [#15](https://github.com/mhaeuser/Battery-Toolkit/issues/15)

> [!WARNING]
> There is no public version 1.9 binary release yet. Do not download a binary
> claiming to be this fork from another source. Until the release checklist is
> complete, build the `macos-27` branch locally with Xcode.

### Build the development version

1. Install Xcode 27 or newer.
2. Clone this repository and check out the `macos-27` branch.
3. Open `Battery Toolkit.xcodeproj` in Xcode.
4. Select your Apple Development team for local signing. A free Personal Team
   is sufficient for testing on your own Mac.
5. Build the `Battery Toolkit` scheme using the Release configuration.
6. Copy the resulting `Battery Toolkit.app` to `/Applications` before enabling
   its background service.

If version 1.8 is already installed, follow the
[migration guide](docs/MIGRATION.md). The original and forked background
services use different identifiers and must not control charging at the same
time.

There is no Homebrew formula for the macOS 27 fork yet. The formula for the
archived upstream project installs the older, incompatible build.

### Opening an unnotarized build

> [!IMPORTANT]
> This step is necessary, because the app has not been notarized by Apple due to the membership fees of the Apple Developer Program. "Apple could not verify 'Battery Toolkit.app' is free of malware" refers to the [lack of notarization](https://support.apple.com/en-us/102445), not to any anomalies detected.

On macOS 14 Sonoma or below:
1. Right click `Battery Toolkit.app`
2. Click "Open"
3. Click "Open" in the dialog box

On macOS 15 Sequoia or above:
1. Try to open the app, it will tell you it's blocked
2. Go to `System Settings > Privacy & Security` and scroll to the bottom
3. Click "Open Anyway" to allow Battery Toolkit to open
4. Click "Open Anyway" on the next dialog box and authenticate
5. Open Battery Toolkit again from Applications folder

# Usage

> [!CAUTION]
> To ensure there is no chance of interference, please turn “Optimized Charging” **off** when Battery Toolkit is in use. <br>
>  Go to macOS System Settings > Battery > the (i) next to Battery Health > Optimized Battery Charging > toggle off

1. Open Battery Toolkit from your Applications folder
2. The menu bar will change to show the app menus, and a menu bar extra should be visible
3. Configure the settings through either method (see **Fig. 2, 3, 4**)

|<img alt="Menu Bar Main" src="Resources/MenuBarMain.png" width=316>|<img alt="Menu Bar Extra" src="Resources/MenuBarCommands.png" width=248>|
|:----------|:----------|
| **Fig. 3**. *Main Menu* | **Fig. 4**. *Menu Bar Commands* |

If you prefer, you can quit the GUI to hide the menu bar extra and Battery Toolkit will keep running in the background.
If you want to change any settings, simply re-open the app.

# Uninstall

1. Focus Battery Toolkit
2. Open the main Battery Toolkit menu in the menu bar (see **Fig. 3**)
3. Choose "Disable Background Activity"
4. Wait until Battery Toolkit closes
5. Move the app to the Trash

Disabling background activity first gives the daemon an opportunity to restore
the system charging state. Do not remove the app bundle while its background
service is still enabled. See the [migration guide](docs/MIGRATION.md) for
rollback instructions.

# Limitations

On the legacy SMC backend, Battery Toolkit prevents sleep while charging to
actively stop charging at the upper limit. The native Manual Charge Limit
backend delegates this limit to macOS and does not require this charging-only
sleep block. The plugged-in sleep preference applies to both backends.

While the daemon is asleep, the native system limit controls charging; the
app's lower-threshold logic runs again when it wakes. Apple's native Charge
Limit can stop within a few percentage points of its target and may
occasionally charge to full to maintain its battery estimates. See
[Apple's description of Charge Limit](https://support.apple.com/en-gb/102338).

Apps, including Battery Toolkit, cannot control the charge state when the machine is shut down. If the charger remains plugged in while the Mac is off, the battery will charge to 100&nbsp;%.

The macOS 27 backend depends on an undocumented PowerUI interface. Apple may
change it in a future macOS update. Re-test the release checklist after every
major or beta operating-system update.

Note that sleep should usually be disabled when the power adapter is disabled, as this will exit Clamshell mode and the machine will sleep immediately if the lid is closed. Refer to the toggle in the Settings dialog (see **Fig. 1**).

# Technical Details

* Based on IOPowerManagement events to minimize resource usage, especially when not connected to power
* Support for macOS Ventura daemons and login items for a more reliable experience
* Uses the legacy CHTE/CH0C SMC controls on firmware that still exposes them
* On macOS 27, uses macOS's firmware-backed Manual Charge Limit through
  PowerUIAgent preferences because the replacement SMC keys require an Apple
  private entitlement
* Saves the user's previous system charge-limit setting before taking control
  and restores it when the daemon is stopped normally

## Security
* Privileged operations are authenticated by the daemon
* Privileged daemon exposes only a minimal protocol via XPC
* XPC communication uses the latest macOS codesign features

# Credits
* Icon based on [reference icon by Streamline](https://seekicon.com/free-icon/rechargable-battery_1)
* README overhauled by [rogue](https://github.com/realrogue)
* macOS 27 charge-limit research and portions of the implementation from
  [Ampere](https://github.com/az-code-lab/ampere), used under the MIT License
