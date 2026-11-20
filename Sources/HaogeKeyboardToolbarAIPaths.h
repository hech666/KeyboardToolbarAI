#pragma once

#import <Foundation/Foundation.h>

#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
#import <roothide.h>
#endif
// This project loads its settings resource through NSBundle/PreferenceLoader.
// No global resource resolver is needed; only the shared preference path below.

static inline NSString *haoge_keyboardtoolbarai_preferencesPath(void) {
    NSString *path = @"/var/mobile/Library/Preferences/com.haoge.keyboardtoolbarai.plist";
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
    return jbroot(path);
#else
    // Mobile user preferences do not use the rootless installation prefix.
    return path;
#endif
}
