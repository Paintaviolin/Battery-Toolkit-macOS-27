// SPDX-License-Identifier: BSD-3-Clause
// Compile with the production BTPowerState, BTPowerEvents and BTStateInfo.
// Hardware and sleep writes are replaced below; this never changes Mac power.

import Foundation

@MainActor
enum BTSettings {
    static var preventSleepOnPower = false
    static var adapterSleep = true
    static var magSafeSync = false
    static var minCharge: UInt8 = 75
    static var maxCharge: UInt8 = 80
}

@MainActor
enum GlobalSleep {
    static var blocks = 0
    static func disable() { blocks += 1 }
    static func restore() {
        precondition(blocks > 0, "Unbalanced sleep restoration")
        blocks -= 1
    }
    static func forceRestore() { blocks = 0 }
}

@MainActor
enum IOPSPrivate {
    static var connected = true
    static var percent: UInt8 = 80
    static func GetPercentRemaining() -> (UInt8, Bool, Bool)? {
        (percent, !SMCComm.Power.chargingDisabled, percent == 100)
    }
    static func DrawingUnlimitedPower() -> Bool { connected }
    static func ExternalPowerConnected() -> Bool { connected }
}

@MainActor
enum SMCComm {
    static func start() -> Bool { true }
    static func stop() {}
    @MainActor
    enum Power {
        static var usesNativeChargeLimit = true
        static var chargingDisabled = true
        static var adapterDisabled = false
        static var writesSucceed = true
        static func supported() -> Bool { true }
        static func isChargingDisabled(at _: UInt8) -> Bool { chargingDisabled }
        static func isPowerAdapterDisabled() -> Bool { adapterDisabled }
        static func disableCharging(at _: UInt8) -> Bool {
            if writesSucceed { chargingDisabled = true }
            return writesSucceed
        }
        static func enableCharging(target _: UInt8) -> Bool {
            if writesSucceed { chargingDisabled = false }
            return writesSucceed
        }
        static func restoreCharging() -> Bool { enableCharging(target: 100) }
        static func disablePowerAdapter() -> Bool {
            if writesSucceed { adapterDisabled = true }
            return writesSucceed
        }
        static func enablePowerAdapter() -> Bool {
            if writesSucceed { adapterDisabled = false }
            return writesSucceed
        }
    }
    @MainActor
    enum MagSafe {
        static func prepare() {}
        static func setGreen() -> Bool { true }
        static func setOrange() -> Bool { true }
        static func setOrangeSlowBlink() -> Bool { true }
        static func setOff() -> Bool { true }
        static func setSystem() -> Bool { true }
    }
}

@MainActor
enum BTDispatcher {
    static var registrationSucceeds = true
    static var connectionRegistrationSucceeds = true
    static var powerHandler: (@MainActor (Int32) -> Void)?
    static var connectionHandler: (@MainActor (Int32) -> Void)?
    static var percentHandler: (@MainActor (Int32) -> Void)?
    static func registerLimitedPowerNotification(
        _ handler: @MainActor @escaping (Int32) -> Void
    ) -> Bool {
        if registrationSucceeds { powerHandler = handler }
        return registrationSucceeds
    }
    static func registerPowerConnectionNotification(
        _ handler: @MainActor @escaping (Int32) -> Void
    ) -> Bool {
        if connectionRegistrationSucceeds { connectionHandler = handler }
        return connectionRegistrationSucceeds
    }
    static func registerPercentChangeNotification(
        _ handler: @MainActor @escaping (Int32) -> Void
    ) -> Bool {
        percentHandler = handler
        return true
    }
    static func unregisterLimitedPowerNotification() { powerHandler = nil }
    static func unregisterPowerConnectionNotification() { connectionHandler = nil }
    static func unregisterPercentChangeNotification() { percentHandler = nil }
}

@main
@MainActor
struct SleepPolicyTests {
    static var checks = 0

    static func expect(_ blocks: Int, _ message: String) {
        precondition(GlobalSleep.blocks == blocks,
                     "\(message): expected \(blocks), got \(GlobalSleep.blocks)")
        checks += 1
    }

    static func main() throws {
        // Every combination of backend, attachment, charge hold, preference,
        // disabled adapter and the existing adapter-sleep preference.
        for native in [false, true] {
            for connected in [false, true] {
                for held in [false, true] {
                    for keepAwake in [false, true] {
                        for disabled in [false, true] {
                            for allowAdapterSleep in [false, true] {
                                SMCComm.Power.usesNativeChargeLimit = native
                                SMCComm.Power.chargingDisabled = held
                                SMCComm.Power.adapterDisabled = disabled
                                IOPSPrivate.connected = connected
                                BTSettings.preventSleepOnPower = keepAwake
                                BTSettings.adapterSleep = allowAdapterSleep
                                BTPowerState.initState()

                                let expected: Int
                                if !connected { expected = 0 }
                                else if keepAwake { expected = 1 }
                                else if disabled { expected = allowAdapterSleep ? 0 : 1 }
                                else if native { expected = 0 }
                                else { expected = held ? 0 : 1 }

                                expect(expected, "Policy matrix")
                                for _ in 0..<5 {
                                    BTPowerState.refreshState()
                                    BTPowerState.updateSleepPrevention()
                                    expect(expected, "Repeated notifications must not stack blocks")
                                }
                                BTPowerState.releaseSleepPrevention()
                                BTPowerState.releaseSleepPrevention()
                                expect(0, "Stopping restores sleep exactly once")
                            }
                        }
                    }
                }
            }
        }

        SMCComm.Power.usesNativeChargeLimit = true
        SMCComm.Power.adapterDisabled = false
        SMCComm.Power.chargingDisabled = true
        IOPSPrivate.connected = true
        BTSettings.adapterSleep = true
        BTSettings.preventSleepOnPower = true
        BTPowerState.initState()
        _ = BTPowerState.enableCharging(percent: 70, target: 80)
        expect(1, "Starting charging preserves plugged-in preference")
        _ = BTPowerState.disableCharging(percent: 80)
        expect(1, "Reaching charge limit preserves plugged-in preference")
        _ = BTPowerState.disablePowerAdapter()
        expect(1, "Disabling adapter does not stack a second block")
        BTSettings.preventSleepOnPower = false
        BTSettings.adapterSleep = false
        BTPowerState.updateSleepPrevention()
        expect(1, "Existing disabled-adapter preference remains active")
        IOPSPrivate.connected = false
        BTPowerState.updateSleepPrevention()
        expect(0, "Unplugging releases every power-related reason")
        IOPSPrivate.connected = true
        BTPowerState.updateSleepPrevention()
        expect(1, "Reconnecting reevaluates the preference")
        BTSettings.adapterSleep = true
        BTPowerState.updateSleepPrevention()
        expect(0, "Turning off the last reason allows sleep immediately")
        _ = BTPowerState.enablePowerAdapter()
        _ = BTPowerState.enableCharging(percent: 70, target: 80)
        expect(0, "Native charging with preference off allows sleep")
        SMCComm.Power.writesSucceed = false
        _ = BTPowerState.disablePowerAdapter()
        expect(0, "Failed adapter write releases temporary protection")
        SMCComm.Power.writesSucceed = true
        BTPowerState.releaseSleepPrevention()

        // Releasing our block must not release another operation's block.
        GlobalSleep.disable()
        BTSettings.preventSleepOnPower = true
        BTPowerState.initState()
        expect(2, "Caller protection and policy are independent")
        BTPowerState.releaseSleepPrevention()
        expect(1, "Policy release preserves caller protection")
        GlobalSleep.restore()

        // Exercise production event lifecycle with simulated power callbacks.
        try BTPowerEvents.start()
        expect(1, "Service start applies saved preference")
        IOPSPrivate.connected = false
        BTDispatcher.connectionHandler?(0)
        expect(0, "Attachment callback releases block on battery")
        IOPSPrivate.connected = true
        BTDispatcher.powerHandler?(0)
        expect(1, "Power source callback reapplies block")
        BTPowerEvents.wakeFromSleep()
        expect(1, "Wake does not leak temporary sleep protection")
        let queuedCallback = BTDispatcher.connectionHandler
        BTPowerEvents.stop()
        expect(0, "Pausing service releases its sleep block")
        queuedCallback?(0)
        BTPowerEvents.sleepSettingsChanged()
        expect(0, "Queued notifications and settings do not block sleep while paused")
        try BTPowerEvents.start()
        expect(1, "Resuming service reapplies the preference")
        BTPowerEvents.updating = true
        BTPowerEvents.stop()
        expect(0, "Daemon update releases sleep prevention")
        BTPowerEvents.updating = false
        BTDispatcher.connectionRegistrationSucceeds = false
        do {
            try BTPowerEvents.start()
            preconditionFailure("Registration failure should prevent service start")
        } catch {
            expect(0, "Registration failure must not leave sleep disabled")
            precondition(BTDispatcher.powerHandler == nil)
        }
        BTDispatcher.connectionRegistrationSucceeds = true
        try BTPowerEvents.start()
        BTPowerEvents.stop()
        expect(0, "Service can start again after a registration failure")
        print("Passed \(checks) sleep-policy and lifecycle checks (64 state combinations).")
    }
}
