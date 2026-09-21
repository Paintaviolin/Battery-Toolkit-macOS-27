//
// Native charge-limit integration for recent macOS firmware.
// Portions derived from Ampere (https://github.com/az-code-lab/ampere).
// Copyright (c) 2026 AZ Code Lab.
// SPDX-License-Identifier: MIT
//

import Foundation
import ObjectiveC
import os.log

/// Controls macOS's firmware-backed Manual Charge Limit.
///
/// New firmware no longer exposes the legacy CHTE/CH0C SMC controls. Its
/// replacement SMC keys require a private entitlement, but PowerUIAgent's
/// root preferences still accept a target and forward it to powerd.
@MainActor
internal enum NativeChargeLimit {
    private static let preferencesDomain =
        "com.apple.smartcharging.topoffprotection" as CFString
    private static let featureStateKey = "MCLFeatureState"
    private static let limitValueKey = "mclLimitValue"
    private static let reloadNotification =
        "com.apple.smartcharging.defaultschanged"

    private static let originalsKey = "NativeChargeLimitOriginals"
    private static let powerUIPath =
        "/System/Library/PrivateFrameworks/PowerUI.framework/Versions/A/PowerUI"

    private struct Originals {
        let featureState: Int?
        let limit: Int?

        var encoded: String {
            let state = self.featureState.map(String.init) ?? "-"
            let limit = self.limit.map(String.init) ?? "-"
            return "\(state) \(limit)"
        }

        init(featureState: Int?, limit: Int?) {
            self.featureState = featureState
            self.limit = limit
        }

        init?(encoded: String) {
            let tokens = encoded.split(whereSeparator: { $0.isWhitespace })
            guard tokens.count == 2 else {
                return nil
            }

            func parse(_ token: Substring) -> Int?? {
                if token == "-" {
                    return .some(nil)
                }
                guard let value = Int(token) else {
                    return nil
                }
                return .some(value)
            }

            guard
                let featureState = parse(tokens[0]),
                let limit = parse(tokens[1])
            else {
                return nil
            }

            self.init(featureState: featureState, limit: limit)
        }
    }

    static var available: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let supportedOS = version.majorVersion > 26 ||
            (version.majorVersion == 26 && version.minorVersion >= 4)
        // System frameworks can live only in the dyld shared cache, so a
        // filesystem existence check incorrectly reports them as missing.
        return supportedOS && dlopen(self.powerUIPath, RTLD_LAZY) != nil
    }

    static var engaged: Bool {
        return UserDefaults.standard.string(forKey: self.originalsKey) != nil
    }

    static func isHolding(at percent: UInt8) -> Bool {
        guard
            self.preference(self.featureStateKey) == 1,
            let limit = self.preference(self.limitValueKey)
        else {
            return false
        }

        return limit <= Int(percent)
    }

    static func engage(target: UInt8) -> Bool {
        guard (1...100).contains(target) else {
            return false
        }

        if !self.engaged {
            let originals = Originals(
                featureState: self.preference(self.featureStateKey),
                limit: self.preference(self.limitValueKey)
            )
            UserDefaults.standard.set(
                originals.encoded,
                forKey: self.originalsKey
            )
            guard CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
            else {
                UserDefaults.standard.removeObject(forKey: self.originalsKey)
                return false
            }
        }

        guard self.writePreferences(
            featureState: 1,
            limit: Int(target)
        ) else {
            os_log("Failed to write native charge-limit preferences")
            return false
        }

        guard self.postReloadNotification() else {
            os_log("Failed to notify PowerUIAgent about the charge limit")
            return false
        }

        return true
    }

    static func release() -> Bool {
        guard
            let encoded = UserDefaults.standard.string(forKey: self.originalsKey)
        else {
            return true
        }
        guard let originals = Originals(encoded: encoded) else {
            os_log("Native charge-limit recovery data is malformed")
            return false
        }

        guard self.disableViaPowerUIAgent() else {
            return false
        }

        guard self.writePreferences(
            featureState: originals.featureState,
            limit: originals.limit
        ), self.postReloadNotification() else {
            os_log("Failed to restore the original native charge limit")
            return false
        }

        UserDefaults.standard.removeObject(forKey: self.originalsKey)
        guard CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        else {
            return false
        }

        return true
    }

    private static func preference(_ key: String) -> Int? {
        let value = CFPreferencesCopyValue(
            key as CFString,
            self.preferencesDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        return (value as? NSNumber)?.intValue
    }

    private static func writePreferences(
        featureState: Int?,
        limit: Int?
    ) -> Bool {
        CFPreferencesSetValue(
            self.featureStateKey as CFString,
            featureState.map(NSNumber.init(value:)),
            self.preferencesDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSetValue(
            self.limitValueKey as CFString,
            limit.map(NSNumber.init(value:)),
            self.preferencesDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        return CFPreferencesSynchronize(
            self.preferencesDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    private static func postReloadNotification() -> Bool {
        typealias NotifyPost = @convention(c) (UnsafePointer<CChar>) -> UInt32
        guard let symbol = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2),
            "notify_post"
        ) else {
            return false
        }

        let notifyPost = unsafeBitCast(symbol, to: NotifyPost.self)
        return self.reloadNotification.withCString { name in
            notifyPost(name) == 0
        }
    }

    /// Disabling through the PowerUI client is necessary because changing the
    /// preference alone does not remove the target already registered in
    /// powerd.
    private static func disableViaPowerUIAgent() -> Bool {
        typealias AllocFn = @convention(c) (
            AnyClass,
            Selector
        ) -> Unmanaged<AnyObject>
        typealias InitFn = @convention(c) (
            AnyObject,
            Selector,
            NSString
        ) -> Unmanaged<AnyObject>?
        typealias BoolErrorFn = @convention(c) (
            AnyObject,
            Selector,
            UnsafeMutablePointer<Unmanaged<NSError>?>
        ) -> Bool
        typealias UInt64ErrorFn = @convention(c) (
            AnyObject,
            Selector,
            UnsafeMutablePointer<Unmanaged<NSError>?>
        ) -> UInt64

        guard
            let messageSend = dlsym(
                UnsafeMutableRawPointer(bitPattern: -2),
                "objc_msgSend"
            ),
            dlopen(self.powerUIPath, RTLD_NOW) != nil,
            let clientClass: AnyClass = NSClassFromString(
                "PowerUISmartChargeClient"
            )
        else {
            os_log("PowerUI charge-limit client is unavailable")
            return false
        }

        let allocation = unsafeBitCast(messageSend, to: AllocFn.self)(
            clientClass,
            sel_registerName("alloc")
        ).takeUnretainedValue()
        let initialize = unsafeBitCast(messageSend, to: InitFn.self)
        guard
            let client = initialize(
                allocation,
                sel_registerName("initWithClientName:"),
                "battery-toolkit" as NSString
            )?.takeUnretainedValue(),
            let object = client as? NSObjectProtocol,
            object.responds(to: NSSelectorFromString("isMCLCurrentlyEnabled:")),
            object.responds(to: NSSelectorFromString("enableMCL:")),
            object.responds(to: NSSelectorFromString("disableMCL:"))
        else {
            os_log("PowerUI charge-limit client has an unexpected interface")
            return false
        }

        var error: Unmanaged<NSError>? = nil
        return withUnsafeMutablePointer(to: &error) { errorPointer in
            let isEnabled = unsafeBitCast(
                messageSend,
                to: UInt64ErrorFn.self
            )(
                client,
                sel_registerName("isMCLCurrentlyEnabled:"),
                errorPointer
            )
            if isEnabled == 0 {
                errorPointer.pointee = nil
                _ = unsafeBitCast(messageSend, to: BoolErrorFn.self)(
                    client,
                    sel_registerName("enableMCL:"),
                    errorPointer
                )
            }

            errorPointer.pointee = nil
            let success = unsafeBitCast(
                messageSend,
                to: BoolErrorFn.self
            )(
                client,
                sel_registerName("disableMCL:"),
                errorPointer
            )
            if !success {
                let reason = errorPointer.pointee.map {
                    $0.takeUnretainedValue().localizedDescription
                } ?? "unknown error"
                os_log("PowerUIAgent refused to disable the charge limit: %{public}@", reason)
            }
            return success
        }
    }
}
