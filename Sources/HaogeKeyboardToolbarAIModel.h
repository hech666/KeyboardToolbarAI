#pragma once
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSArray<NSDictionary *> *haoge_keyboardtoolbarai_actionCatalog(void);
FOUNDATION_EXPORT NSArray<NSString *> *haoge_keyboardtoolbarai_actionIDs(void);
FOUNDATION_EXPORT NSArray<NSString *> *haoge_keyboardtoolbarai_normalizeButtons(id value);
FOUNDATION_EXPORT NSArray<NSString *> *haoge_keyboardtoolbarai_defaultButtons(void);
FOUNDATION_EXPORT NSString *haoge_keyboardtoolbarai_bindingAction(id map,NSString *button,NSInteger direction);
FOUNDATION_EXPORT NSDictionary *haoge_keyboardtoolbarai_storeBinding(id map,NSString *button,NSInteger direction,NSString *action);
FOUNDATION_EXPORT NSDictionary *haoge_keyboardtoolbarai_normalizeToolbarPreferences(id source);
FOUNDATION_EXPORT NSArray<NSDictionary *> *haoge_keyboardtoolbarai_providerPresets(void);
FOUNDATION_EXPORT NSDictionary *haoge_keyboardtoolbarai_normalizeAIConfiguration(id raw);
FOUNDATION_EXPORT NSString *haoge_keyboardtoolbarai_normalizeEndpoint(id raw);
FOUNDATION_EXPORT UIColor *haoge_keyboardtoolbarai_colorFromHex(id raw);
