//
// Copyright (C) 2022 - 2024 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import Foundation
import os.log

@MainActor
internal enum BTPowerState {
    private static var chargingDisabled = false
    private static var powerDisabled = false
    private static var sleepPrevented = false

    static func initState() {
        let (percent, _, _) = self.getPercentRemaining()
        self.chargingDisabled = SMCComm.Power.isChargingDisabled(at: percent)
        self.powerDisabled = SMCComm.Power.isPowerAdapterDisabled()
        self.updateSleepPrevention()

        SMCComm.MagSafe.prepare()

        if BTSettings.magSafeSync {
            self.syncMagSafeState()
        }
    }

    static func refreshState() {
        //
        // Refresh platform stated when waking from sleep, as events might not
        // fire.
        //
        let (percent, _, _) = self.getPercentRemaining()
        self.chargingDisabled = SMCComm.Power.isChargingDisabled(at: percent)
        self.powerDisabled = SMCComm.Power.isPowerAdapterDisabled()
        self.updateSleepPrevention()

        if BTSettings.magSafeSync {
            self.syncMagSafeState()
        }
    }

    static func getPercentRemaining() -> (UInt8, Bool, Bool) {
        return IOPSPrivate.GetPercentRemaining() ?? (100, false, false)
    }

    static func updateSleepPrevention() {
        // Native limits are enforced by the system even while the daemon
        // sleeps. Legacy SMC charging still requires active monitoring.
        let chargingNeedsMonitoring = !SMCComm.Power.usesNativeChargeLimit &&
            !self.chargingDisabled && !self.powerDisabled
        let disabledAdapterNeedsAwake = self.powerDisabled &&
            !BTSettings.adapterSleep
        let preventSleep = IOPSPrivate.ExternalPowerConnected() &&
            (BTSettings.preventSleepOnPower || chargingNeedsMonitoring ||
                disabledAdapterNeedsAwake)

        // Hold one sleep block for the combined policy. Repeated power events
        // or overlapping reasons must not leave an extra block behind.
        guard self.sleepPrevented != preventSleep else {
            return
        }

        self.sleepPrevented = preventSleep
        os_log("Sleep prevention: %{public}@", preventSleep ? "on" : "off")

        if preventSleep {
            GlobalSleep.disable()
        } else {
            GlobalSleep.restore()
        }
    }

    static func releaseSleepPrevention() {
        guard self.sleepPrevented else {
            return
        }

        self.sleepPrevented = false
        GlobalSleep.restore()
    }

    static func syncMagSafeStatePowerEnabled(percent: UInt8) {
        assert(BTSettings.magSafeSync)
        assert(!self.powerDisabled)

        if percent == 100 {
            _ = SMCComm.MagSafe.setGreen()
        } else if self.chargingDisabled {
            _ = SMCComm.MagSafe.setOrange()
        } else {
            _ = SMCComm.MagSafe.setOrangeSlowBlink()
        }
    }

    static func syncMagSafeState() {
        assert(BTSettings.magSafeSync)

        if self.powerDisabled {
            _ = SMCComm.MagSafe.setOff()
        } else {
            let (percent, _, _) = self.getPercentRemaining()
            self.syncMagSafeStatePowerEnabled(percent: percent)
        }
    }

    static func magSafeSyncSettingToggled() {
        if BTSettings.magSafeSync {
            self.syncMagSafeState()
        } else {
            _ = SMCComm.MagSafe.setSystem()
        }
    }

    static func disableCharging(percent: UInt8) -> Bool {
        guard !self.chargingDisabled || SMCComm.Power.usesNativeChargeLimit
        else {
            return true
        }

        let wasDisabled = self.chargingDisabled
        let success = SMCComm.Power.disableCharging(at: percent)
        guard success else {
            os_log("Failed to disable charging")
            return false
        }

        self.chargingDisabled = true
        self.updateSleepPrevention()

        if !wasDisabled && BTSettings.magSafeSync {
            BTPowerState.syncMagSafeStatePowerEnabled(percent: percent)
        }

        return true
    }

    static func enableCharging(percent: UInt8, target: UInt8) -> Bool {
        guard self.chargingDisabled || SMCComm.Power.usesNativeChargeLimit
        else {
            return true
        }

        let wasDisabled = self.chargingDisabled
        let success = SMCComm.Power.enableCharging(target: target)
        if !success {
            os_log("Failed to enable charging")
            return false
        }

        self.chargingDisabled = false
        self.updateSleepPrevention()

        if wasDisabled && BTSettings.magSafeSync {
            BTPowerState.syncMagSafeStatePowerEnabled(percent: percent)
        }

        return true
    }

    static func restoreCharging(percent: UInt8) -> Bool {
        let success = SMCComm.Power.restoreCharging()
        guard success else {
            os_log("Failed to restore charging")
            return false
        }

        if self.chargingDisabled {
            self.chargingDisabled = false

            if BTSettings.magSafeSync {
                BTPowerState.syncMagSafeStatePowerEnabled(percent: percent)
            }
        }

        self.updateSleepPrevention()

        return true
    }

    static func disablePowerAdapter() -> Bool {
        guard !self.powerDisabled else {
            return true
        }

        // Prevent an immediate clamshell sleep during the state transition.
        GlobalSleep.disable()
        defer { GlobalSleep.restore() }

        let success = SMCComm.Power.disablePowerAdapter()
        guard success else {
            os_log("Failed to disable power adapter")
            return false
        }

        if BTSettings.magSafeSync {
            _ = SMCComm.MagSafe.setOff()
        }

        self.powerDisabled = true
        self.updateSleepPrevention()
        return true
    }

    static func enablePowerAdapter() -> Bool {
        guard self.powerDisabled else {
            return true
        }

        let success = SMCComm.Power.enablePowerAdapter()
        guard success else {
            os_log("Failed to enable power adapter")
            return false
        }

        self.powerDisabled = false

        if BTSettings.magSafeSync {
            let (percent, _, _) = self.getPercentRemaining()
            BTPowerState.syncMagSafeStatePowerEnabled(percent: percent)
        }

        self.updateSleepPrevention()

        return true
    }

    static func isChargingDisabled() -> Bool {
        return self.chargingDisabled
    }

    static func isPowerAdapterDisabled() -> Bool {
        return self.powerDisabled
    }
}
