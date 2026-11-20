#import "HaogeKeyboardToolbarAIConfig.h"
#import "HaogeKeyboardToolbarAIPreferences.h"

@interface HaogeKeyboardToolbarAIConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void haoge_keyboardtoolbarai_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    HaogeKeyboardToolbarAIConfig *config = (__bridge HaogeKeyboardToolbarAIConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config haoge_keyboardtoolbarai_reload];
    });
}

@implementation HaogeKeyboardToolbarAIConfig

+ (instancetype)haoge_keyboardtoolbarai_shared {
    static HaogeKeyboardToolbarAIConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.haoge.keyboardtoolbarai.preferences", DISPATCH_QUEUE_SERIAL);
        [self haoge_keyboardtoolbarai_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, haoge_keyboardtoolbarai_preferencesDidChange,
            (__bridge CFStringRef)HaogeKeyboardToolbarAIPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self haoge_keyboardtoolbarai_reload]; });
    }
    return self;
}

- (void)haoge_keyboardtoolbarai_reload {
    self.snapshot = haoge_keyboardtoolbarai_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HaogeKeyboardToolbarAIPreferencesChanged object:self];
    });
}

- (id)haoge_keyboardtoolbarai_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (NSDictionary *)haoge_keyboardtoolbarai_snapshot { return self.snapshot ?: @{}; }

- (BOOL)haoge_keyboardtoolbarai_isEnabled {
    id value = [self haoge_keyboardtoolbarai_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
