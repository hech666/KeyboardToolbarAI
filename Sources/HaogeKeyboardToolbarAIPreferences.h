#pragma once

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "HaogeKeyboardToolbarAIPaths.h"
#import "HaogeKeyboardToolbarAIModel.h"

static NSString * const HaogeKeyboardToolbarAIPreferencesDomain = @"com.haoge.keyboardtoolbarai";
static NSString * const HaogeKeyboardToolbarAIPreferencesChanged = @"com.haoge.keyboardtoolbarai.preferences-changed";

static inline NSDictionary *haoge_keyboardtoolbarai_readPreferences(void) {
    NSString *path = haoge_keyboardtoolbarai_preferencesPath();
    NSDictionary *values = path.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    if ([values isKindOfClass:[NSDictionary class]]) {
        return haoge_keyboardtoolbarai_normalizeToolbarPreferences(values);
    }
    // Compatibility fallback, not a second writable file location.
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:HaogeKeyboardToolbarAIPreferencesDomain];
    [defaults synchronize];
    return haoge_keyboardtoolbarai_normalizeToolbarPreferences([defaults persistentDomainForName:HaogeKeyboardToolbarAIPreferencesDomain] ?: @{});
}

// The PreferenceBundle is the only caller allowed to write.
static inline BOOL haoge_keyboardtoolbarai_writePreference(NSString *key, id value, NSError **error) {
    NSString *path = haoge_keyboardtoolbarai_preferencesPath();
    if (key.length == 0 || path.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:HaogeKeyboardToolbarAIPreferencesDomain code:1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid preference path or key"}];
        }
        return NO;
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableDictionary *values;
    if ([manager fileExistsAtPath:path]) {
        NSData *existing = [NSData dataWithContentsOfFile:path options:0 error:error];
        id decoded = existing ? [NSPropertyListSerialization propertyListWithData:existing
                         options:NSPropertyListMutableContainers format:NULL error:error] : nil;
        if (![decoded isKindOfClass:[NSDictionary class]]) {
            if (error && !*error) {
                *error = [NSError errorWithDomain:HaogeKeyboardToolbarAIPreferencesDomain code:2
                                        userInfo:@{NSLocalizedDescriptionKey: @"Preferences are not a dictionary"}];
            }
            return NO;
        }
        values = [decoded mutableCopy];
    } else {
        values = [haoge_keyboardtoolbarai_readPreferences() mutableCopy];
    }
    if (value) values[key] = value;
    else [values removeObjectForKey:key];
    values=[haoge_keyboardtoolbarai_normalizeToolbarPreferences(values) mutableCopy];
    if (![manager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
            withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:values
                         format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:HaogeKeyboardToolbarAIPreferencesDomain];
    // Mirror the whole snapshot so cfprefsd cannot flush stale unrelated keys.
    [defaults setPersistentDomain:values forName:HaogeKeyboardToolbarAIPreferencesDomain];
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)HaogeKeyboardToolbarAIPreferencesChanged, NULL, NULL, true);
    return YES;
}
