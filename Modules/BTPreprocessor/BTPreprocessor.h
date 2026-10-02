/*@file
  Copyright (C) 2022 Marvin Häuser. All rights reserved.
  SPDX-License-Identifier: BSD-3-Clause
*/

#ifndef _BTPreprocessor_h_
#define _BTPreprocessor_h_

#include <Foundation/NSString.h>

__BEGIN_DECLS

/// The Battery Toolkit bundle identifier.
extern const NSString *const BT_APP_ID;

/// The Battery Toolkit Service identifier.
extern const NSString *const BT_SERVICE_ID;

/// The Battery Toolkit daemon identifier.
extern const NSString *const BT_DAEMON_ID;

/// The Battery Toolkit daemon connection name.
extern const NSString *const BT_DAEMON_CONN;

/// The Battery Toolkit Autostart identifier.
extern const NSString *const BT_AUTOSTART_ID;

/// The Battery Toolkit signing team identifier.
extern const NSString *const BT_CODESIGN_TEAM;

/// Optional SHA-1 certificate pin for independently signed builds.
extern const NSString *const BT_CODESIGN_CERT_SHA1;

__END_DECLS

#endif
