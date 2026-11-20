#import "HaogeKeyboardToolbarAIActions.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import "HaogeKeyboardToolbarAIChat.h"
#import "HaogeKeyboardToolbarAIConfig.h"
// Declared dynamically: the original binary has runtime selector guards.
@interface NSObject (HaogeKeyboardToolbarAIPrivateSelectors)
+ (id)sharedInputModeController;
+ (id)sharedInstance;
+ (id)sharedRuntime;
+ (id)keyboardInputModeWithIdentifier:(NSString *)identifier;
+ (void)haoge_keyboardtoolbarai_openForInput:(id)input;
- (id)inputModeWithIdentifier:(NSString *)identifier;
- (NSArray *)keyboardInputModes;
- (BOOL)isEmojiInputMode;
- (id)currentInputMode;
- (id)lastUsedInputMode;
- (id)currentSystemInputModeExcludingEmoji:(BOOL)exclude;
- (void)setKeyboardInputMode:(id)mode userInitiated:(BOOL)initiated;
- (void)activateKayoko;
- (void)setText:(NSString *)text;
@end
// 0x3c4fc: text fields use Return delegate semantics, not a literal newline.
void haoge_keyboardtoolbarai_insertNewlineForInput(id target) {
    if (!target) return;
    if ([target isKindOfClass:UITextField.class]) {
        UITextField *field=target;
        id<UITextFieldDelegate> delegate=field.delegate;
        if (![delegate respondsToSelector:@selector(textFieldShouldReturn:)] ||
            [delegate textFieldShouldReturn:field]) [field resignFirstResponder];
    } else if ([target respondsToSelector:@selector(insertText:)]) {
        [target insertText:@"\n"];
    }
}
// 0x19010: resign the input, then request an external action in SpringBoard.
// The notification-to-URL receiver is separate; see ExternalActions.m.
static void haoge_keyboardtoolbarai_externalAction(HaogeKeyboardToolbarAIActions *tool, NSString *action) {
    if (!action.length) return;
    id target=tool.haoge_keyboardtoolbarai_target;
    BOOL hadFocus=[target isFirstResponder] && [target respondsToSelector:@selector(resignFirstResponder)];
    if (hadFocus) [target resignFirstResponder];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,hadFocus?400000000:0),dispatch_get_main_queue(),^{
        NSString *name=[@"com.haoge.keyboardtoolbarai.external." stringByAppendingString:action];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge CFStringRef)name,NULL,NULL,true);
    });
}
static dispatch_queue_t haoge_keyboardtoolbarai_clipboardQueue(void) { static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("com.haoge.keyboardtoolbarai.clipboard",DISPATCH_QUEUE_SERIAL);});return q;}
@implementation HaogeKeyboardToolbarAIActions
// 0x18208 + block 0x1828c.
- (void)haoge_keyboardtoolbarai_kt_showAI {
    id input=self.haoge_keyboardtoolbarai_target;
    dispatch_async(dispatch_get_main_queue(),^{
        if ([input conformsToProtocol:@protocol(UITextInput)])
            [NSClassFromString(@"HaogeKeyboardToolbarAIChatPanel") haoge_keyboardtoolbarai_openForInput:input];
    });
}
// 0x182d4.
- (void)haoge_keyboardtoolbarai_done { [(id)self.haoge_keyboardtoolbarai_target resignFirstResponder]; }
// 0x18318: standard responder action first, selected text fallback second.
- (void)haoge_keyboardtoolbarai_copyText {
    if ([UIApplication.sharedApplication sendAction:@selector(copy:) to:nil from:nil forEvent:nil]) return;
    UITextRange *range=self.haoge_keyboardtoolbarai_target.selectedTextRange;
    NSString *text=range && !range.empty?[self.haoge_keyboardtoolbarai_target textInRange:range]:nil;
    if (!text) return;
    dispatch_async(haoge_keyboardtoolbarai_clipboardQueue(),^{ UIPasteboard.generalPasteboard.string=text; });
}
- (void)haoge_keyboardtoolbarai_paste {
    if ([UIApplication.sharedApplication sendAction:@selector(paste:) to:nil from:nil forEvent:nil]) return;
    static BOOL busy=NO;
    if (busy) return;
    busy=YES;
    __weak id input=self.haoge_keyboardtoolbarai_target;
    CFAbsoluteTime start=CFAbsoluteTimeGetCurrent();
    dispatch_async(haoge_keyboardtoolbarai_clipboardQueue(),^{
        NSString *text=UIPasteboard.generalPasteboard.string;
        dispatch_async(dispatch_get_main_queue(),^{
            busy=NO;id target=input;
            if (text.length && target && [target isFirstResponder] && CFAbsoluteTimeGetCurrent()-start<2.0 && [target respondsToSelector:@selector(insertText:)]) [target insertText:text];
        });
    });
}
// 0x185c4 + block 0x18658: the visible "复制" action selects all first.
- (void)haoge_keyboardtoolbarai_selectAllAndCopy {
    [self haoge_keyboardtoolbarai_selectAll];
    __weak HaogeKeyboardToolbarAIActions *weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{ [weakSelf haoge_keyboardtoolbarai_copyText]; });
}
// 0x18698 / 0x186e0 / 0x18754 / 0x1883c.
- (void)haoge_keyboardtoolbarai_selectAll { [(id)self.haoge_keyboardtoolbarai_target selectAll:nil]; }
- (void)haoge_keyboardtoolbarai_undo { [[(id)self.haoge_keyboardtoolbarai_target undoManager] undo]; }
- (void)haoge_keyboardtoolbarai_clearText {
    [self haoge_keyboardtoolbarai_selectAll];
    if (![UIApplication.sharedApplication sendAction:@selector(delete:) to:nil from:nil forEvent:nil] &&
        [(id)self.haoge_keyboardtoolbarai_target respondsToSelector:@selector(setText:)]) [(id)self.haoge_keyboardtoolbarai_target setText:@""];
}
- (void)haoge_keyboardtoolbarai_cut { [(id)self.haoge_keyboardtoolbarai_target cut:nil]; }
// 0x18884 / 0x1888c / 0x18894.
- (void)haoge_keyboardtoolbarai_moveLeft { [self haoge_keyboardtoolbarai_moveCursor:UITextLayoutDirectionLeft]; } // original literal 3
- (void)haoge_keyboardtoolbarai_moveRight { [self haoge_keyboardtoolbarai_moveCursor:UITextLayoutDirectionRight]; } // original literal 2
- (void)haoge_keyboardtoolbarai_moveCursor:(NSInteger)direction {
    id<UITextInput> input=self.haoge_keyboardtoolbarai_target;
    UITextRange *range=input.selectedTextRange;
    if (!range) return;
    UITextPosition *position=[input positionFromPosition:range.start inDirection:(UITextLayoutDirection)direction offset:1];
    if (position) input.selectedTextRange=[input textRangeFromPosition:position toPosition:position];
}
// 0x18a30.
- (void)haoge_keyboardtoolbarai_insertNewline { haoge_keyboardtoolbarai_insertNewlineForInput(self.haoge_keyboardtoolbarai_target); }
// 0x18a74. Runtime selector checks are retained; private UIKit APIs are not assumed universal.
- (void)haoge_keyboardtoolbarai_showEmojiKeyboard {
    Class controllerClass=NSClassFromString(@"UIKeyboardInputModeController");
    Class modeClass=NSClassFromString(@"UIKeyboardInputMode");
    id controller=nil, emoji=nil;
    if ([controllerClass respondsToSelector:@selector(sharedInputModeController)]) {
        controller=[controllerClass sharedInputModeController];
        if ([controller respondsToSelector:@selector(inputModeWithIdentifier:)]) emoji=[controller inputModeWithIdentifier:@"emoji"];
        if (!emoji && [controller respondsToSelector:@selector(keyboardInputModes)]) {
            for (id candidate in [controller keyboardInputModes]) {
                if ([candidate isKindOfClass:modeClass] && [candidate isEmojiInputMode]) { emoji=candidate; break; }
            }
        }
    }
    if (!emoji && [modeClass respondsToSelector:@selector(keyboardInputModeWithIdentifier:)])
        emoji=[modeClass keyboardInputModeWithIdentifier:@"emoji"];
    Class implClass=NSClassFromString(@"UIKeyboardImpl");
    if (![implClass respondsToSelector:@selector(sharedInstance)]) return;
    id impl=[implClass sharedInstance];
    if (![impl respondsToSelector:@selector(setKeyboardInputMode:userInitiated:)]) return;
    // Re-querying the controller matches the original method's second stage.
    controller=[controllerClass respondsToSelector:@selector(sharedInputModeController)]?[controllerClass sharedInputModeController]:nil;
    id current=[controller respondsToSelector:@selector(currentInputMode)]?[controller currentInputMode]:nil;
    if ([current isKindOfClass:modeClass] && [current isEmojiInputMode]) {
        id previous=[controller respondsToSelector:@selector(lastUsedInputMode)]?[controller lastUsedInputMode]:nil;
        if (![previous isKindOfClass:modeClass] || [previous isEmojiInputMode])
            previous=[controller respondsToSelector:@selector(currentSystemInputModeExcludingEmoji:)]?[controller currentSystemInputModeExcludingEmoji:YES]:nil;
        if ([previous isKindOfClass:modeClass] && ![previous isEmojiInputMode]) [impl setKeyboardInputMode:previous userInitiated:YES];
    } else if ([emoji isKindOfClass:modeClass]) {
        [impl setKeyboardInputMode:emoji userInitiated:YES];
    }
}
// 0x18f1c. This package uses com.axs.clipboard.core.show, not the Aurora Kayoko notification.
- (void)haoge_keyboardtoolbarai_showClipboard {
    Class cls=NSClassFromString(@"ClipboardHelperRuntime");
    if ([cls respondsToSelector:@selector(sharedRuntime)]) {
        id runtime=[cls sharedRuntime];
        if ([runtime respondsToSelector:@selector(activateKayoko)]) { [runtime activateKayoko]; return; }
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.axs.clipboard.core.show"),NULL,NULL,true);
}
// 0x18fc8 / 0x1914c / 0x19194 / 0x191dc / 0x19224.
- (void)haoge_keyboardtoolbarai_snapperFreeze { haoge_keyboardtoolbarai_externalAction(self,[NSStringFromSelector(_cmd) substringFromIndex:@"haoge_keyboardtoolbarai_".length]); }
- (void)haoge_keyboardtoolbarai_snapperLong { haoge_keyboardtoolbarai_externalAction(self,[NSStringFromSelector(_cmd) substringFromIndex:@"haoge_keyboardtoolbarai_".length]); }
- (void)haoge_keyboardtoolbarai_screenshotShell { haoge_keyboardtoolbarai_externalAction(self,[NSStringFromSelector(_cmd) substringFromIndex:@"haoge_keyboardtoolbarai_".length]); }
- (void)haoge_keyboardtoolbarai_screenshotWatermark { haoge_keyboardtoolbarai_externalAction(self,[NSStringFromSelector(_cmd) substringFromIndex:@"haoge_keyboardtoolbarai_".length]); }
- (void)haoge_keyboardtoolbarai_screenshotBoth { haoge_keyboardtoolbarai_externalAction(self,[NSStringFromSelector(_cmd) substringFromIndex:@"haoge_keyboardtoolbarai_".length]); }
@end
