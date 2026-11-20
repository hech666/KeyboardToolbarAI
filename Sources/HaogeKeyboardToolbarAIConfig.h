#pragma once

#import <Foundation/Foundation.h>

@interface HaogeKeyboardToolbarAIConfig : NSObject
+ (instancetype)haoge_keyboardtoolbarai_shared;
- (BOOL)haoge_keyboardtoolbarai_isEnabled;
- (id)haoge_keyboardtoolbarai_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (NSDictionary *)haoge_keyboardtoolbarai_snapshot;
- (void)haoge_keyboardtoolbarai_reload;
@end
