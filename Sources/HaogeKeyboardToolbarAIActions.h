#pragma once
#import <UIKit/UIKit.h>
@interface HaogeKeyboardToolbarAIActions : NSObject
@property(nonatomic,weak) id<UITextInput> haoge_keyboardtoolbarai_target;
- (void)haoge_keyboardtoolbarai_kt_showAI;
- (void)haoge_keyboardtoolbarai_done;
- (void)haoge_keyboardtoolbarai_copyText;
- (void)haoge_keyboardtoolbarai_paste;
- (void)haoge_keyboardtoolbarai_selectAllAndCopy;
- (void)haoge_keyboardtoolbarai_selectAll;
- (void)haoge_keyboardtoolbarai_undo;
- (void)haoge_keyboardtoolbarai_clearText;
- (void)haoge_keyboardtoolbarai_cut;
@end
FOUNDATION_EXPORT id haoge_keyboardtoolbarai_actionProxy(HaogeKeyboardToolbarAIActions *actions);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_haptic(void);
