//
// Copyright (C) 2022 - 2024 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import Cocoa
import os.log

@MainActor
internal final class BTSettingsViewController: NSViewController {
    private let autostartSetting = "autostart"
    
    private var currentSettings: [String: NSObject & Sendable]? = nil
    
    @IBOutlet private var tabView: NSTabView!
    @IBOutlet private var userTab: NSTabViewItem!
    @IBOutlet private var powerTab: NSTabViewItem!
    
    @IBOutlet private var autostartSwitch: NSSwitch!
    
    @IBOutlet private var minChargeTextField: NSTextField!
    @IBOutlet private var minChargeSlider: NSSlider!
    @IBOutlet private var minChargeStepper: NSStepper!
    
    @IBOutlet private var maxChargeTextField: NSTextField!
    @IBOutlet private var maxChargeSlider: NSSlider!
    @IBOutlet private var maxChargeStepper: NSStepper!
    
    @IBOutlet private var adapterSleepSwitch: NSSwitch!
    @IBOutlet private var preventSleepOnPowerSwitch: NSSwitch!
    @IBOutlet private var magSafeSyncSwitch: NSSwitch!
    
    private var minChargeVal = BTSettingsInfo.Defaults.minCharge
    private var maxChargeVal = BTSettingsInfo.Defaults.maxCharge

    @IBAction private func minChargeAction(_ sender: NSControl) {
        self.setMinCharge(value: sender.integerValue)
    }

    @IBAction private func maxChargeAction(_ sender: NSControl) {
        self.setMaxCharge(value: sender.integerValue)
    }
    
    @IBAction private func cancelButtonAction(_: NSButton) {
        self.view.window?.windowController?.close()
    }
    
    @IBAction private func doneButtonAction(_: NSButton) {
        // Clicking the button does not necessarily end editing in the active
        // text field before this action runs. End it explicitly so the field's
        // action validates and applies the typed value before we save.
        if let window = self.view.window,
           !window.makeFirstResponder(nil) {
            NSSound.beep()
            return
        }

        let autostart = (self.autostartSwitch.state == .on)
        let success = autostart ?
        BTLoginItem.enable() :
        BTLoginItem.disable()
        
        if success {
            UserDefaults.standard.setValue(
                autostart,
                forKey: self.autostartSetting
            )
        } else {
            BTErrorHandler.errorHandler(
                error: BTError.unknown,
                window: self.view.window
            )
        }
        
        let settings: [String: NSObject & Sendable] = [
            BTSettingsInfo.Keys.minCharge: NSNumber(value: self.minChargeVal),
            BTSettingsInfo.Keys.maxCharge: NSNumber(value: self.maxChargeVal),
            BTSettingsInfo.Keys.adapterSleep: NSNumber(
                value: self.adapterSleepSwitch.state == .off
            ),
            BTSettingsInfo.Keys.preventSleepOnPower: NSNumber(
                value: self.preventSleepOnPowerSwitch.state == .on
            ),
            BTSettingsInfo.Keys.magSafeSync: NSNumber(
                value: self.magSafeSyncSwitch.state == .on
            ),
        ]
        //
        // Submit the settings to the daemon only when they changed.
        //
        guard !(settings as NSDictionary).isEqual(to: self.currentSettings)
        else {
            os_log("Power settings have not changed, ignoring")
            //
            // If the previous operations failed, we displayed an error prompt
            // and must not close the window.
            //
            if success {
                self.view.window?.windowController?.close()
            }
            
            return
        }
        
        Task {
            do {
                try await BTDaemonXPCClient.setSettings(settings: settings)
                //
                // If the previous operations failed, we already displayed an
                // error prompt and must not close the window.
                //
                guard success else {
                    return
                }
                
                self.view.window?.windowController?.close()
            } catch{
                BTErrorHandler.errorHandler(
                    error: error,
                    window: self.view.window
                )
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.initUserState()
        
        Task {
            await self.initPowerState()
            self.view.window?.center()
            //
            // Activate the app when the Settings window is shown, e.g., when
            // invoked from the Menu Bar Extra.
            //
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func selectUserTab() {
        self.tabView.selectTabViewItem(self.userTab)
    }
    
    func selectPowerTab() {
        self.tabView.selectTabViewItem(self.powerTab)
    }
    
    private func setMinCharge(value: Int) {
        let value = Swift.min(
            Swift.max(value, Int(BTSettingsInfo.Bounds.minChargeMin)),
            100
        )
        self.minChargeVal = UInt8(value)

        if self.maxChargeVal < self.minChargeVal {
            self.maxChargeVal = self.minChargeVal
            self.updateMaxChargeControls()
        }

        self.updateMinChargeControls()
    }
    
    private func setMaxCharge(value: Int) {
        let value = Swift.min(
            Swift.max(value, Int(BTSettingsInfo.Bounds.maxChargeMin)),
            100
        )
        self.maxChargeVal = UInt8(value)

        if self.maxChargeVal < self.minChargeVal {
            self.minChargeVal = self.maxChargeVal
            self.updateMinChargeControls()
        }

        self.updateMaxChargeControls()
    }

    private func updateMinChargeControls() {
        let value = Int(self.minChargeVal)
        self.minChargeTextField.integerValue = value
        self.minChargeSlider.integerValue = value
        self.minChargeStepper.integerValue = value
    }

    private func updateMaxChargeControls() {
        let value = Int(self.maxChargeVal)
        self.maxChargeTextField.integerValue = value
        self.maxChargeSlider.integerValue = value
        self.maxChargeStepper.integerValue = value
    }
    
    private func setAdapterSleep(value: Bool) {
        self.adapterSleepSwitch.state = value ? .off : .on
    }
    
    private func setMagSafeSync(value: Bool) {
        self.magSafeSyncSwitch.state = value ? .on : .off
    }
    
    private func initUserState() {
        let autostart = UserDefaults.standard.bool(
            forKey: self.autostartSetting
        )
        self.autostartSwitch.state = autostart ? .on : .off
    }
    
    private func initPowerState() async {
        do {
            let settings = try await BTActions.getSettings()
            self.currentSettings = settings
            
            let minChargeNum =
            settings[BTSettingsInfo.Keys.minCharge] as? NSNumber
            let maxChargeNum =
            settings[BTSettingsInfo.Keys.maxCharge] as? NSNumber
            let adapterSleepNum =
            settings[BTSettingsInfo.Keys.adapterSleep] as? NSNumber
            let magSafeSyncNum =
            settings[BTSettingsInfo.Keys.magSafeSync] as? NSNumber
            
            guard let minCharge = minChargeNum?.intValue,
                  let maxCharge = maxChargeNum?.intValue,
                  let adapterSleep = adapterSleepNum?.boolValue
            else {
                BTErrorHandler.errorHandler(error: BTError.commFailed)
                return
            }
            
            self.setMinCharge(value: minCharge)
            self.setMaxCharge(value: maxCharge)
            self.setAdapterSleep(value: adapterSleep)
            let preventSleep =
                settings[BTSettingsInfo.Keys.preventSleepOnPower] as? NSNumber
            self.preventSleepOnPowerSwitch.state =
                (preventSleep?.boolValue ??
                    BTSettingsInfo.Defaults.preventSleepOnPower) ? .on : .off
            
            if let magSafeSync = magSafeSyncNum?.boolValue {
                self.magSafeSyncSwitch.isEnabled = true
                self.setMagSafeSync(value: magSafeSync)
            } else {
                self.magSafeSyncSwitch.isEnabled = false
            }
        } catch {
            BTErrorHandler.errorHandler(error: error)
        }
    }
}
