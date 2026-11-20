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
- (void)haoge_keyboardtoolbarai_moveLeft;
- (void)haoge_keyboardtoolbarai_moveRight;
- (void)haoge_keyboardtoolbarai_moveCursor:(NSInteger)direction;
- (void)haoge_keyboardtoolbarai_insertNewline;
- (void)haoge_keyboardtoolbarai_showEmojiKeyboard;
- (void)haoge_keyboardtoolbarai_showClipboard;
- (void)haoge_keyboardtoolbarai_snapperFreeze;
- (void)haoge_keyboardtoolbarai_snapperLong;
- (void)haoge_keyboardtoolbarai_screenshotShell;
- (void)haoge_keyboardtoolbarai_screenshotWatermark;
- (void)haoge_keyboardtoolbarai_screenshotBoth;
@end
FOUNDATION_EXPORT id haoge_keyboardtoolbarai_actionProxy(HaogeKeyboardToolbarAIActions *actions);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_haptic(void);
