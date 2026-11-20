#import "HaogeKeyboardToolbarAIActions.h"
#import <CoreFoundation/CoreFoundation.h>
#import "HaogeKeyboardToolbarAIChat.h"
@interface NSObject (HaogeKeyboardToolbarAITextFallback)
- (void)setText:(NSString *)text;
@end
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
@end
