#!/bin/sh

##
# Uninstalls Battery Toolkit and its settings.
#
# Copyright (C) 2022 Marvin Häuser. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
##

# Remove the Battery Toolkit daemon.
sudo rm /Library/LaunchDaemons/io.github.paintaviolin.BatteryToolkit.daemon.plist
sudo rm /Library/PrivilegedHelperTools/io.github.paintaviolin.BatteryToolkit.daemon
sudo launchctl remove io.github.paintaviolin.BatteryToolkit.daemon

# Remove the Battery Toolkit daemon data.
sudo defaults delete io.github.paintaviolin.BatteryToolkit.daemon
sudo security authorizationdb remove io.github.paintaviolin.BatteryToolkit.daemon.manage

# Remove the Battery Toolkit Autostart helper.
launchctl remove io.github.paintaviolin.BatteryToolkit.Autostart

# Remove the Battery Toolkit app data.
defaults remove io.github.paintaviolin.BatteryToolkit
