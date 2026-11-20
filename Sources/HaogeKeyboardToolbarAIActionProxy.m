#import "HaogeKeyboardToolbarAIActions.h"
#import "HaogeKeyboardToolbarAIConfig.h"
@interface HaogeKeyboardToolbarAIActionProxy : NSObject
@property(nonatomic,weak) HaogeKeyboardToolbarAIActions *haoge_keyboardtoolbarai_actions;
@end
void haoge_keyboardtoolbarai_haptic(void) {
    id value=[[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_valueForKey:@"HapticFeedback" defaultValue:@YES];
    if (![value boolValue]) return;
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{haoge_keyboardtoolbarai_haptic();});return; }
    static UIImpactFeedbackGenerator *generator;static dispatch_once_t once;
    dispatch_once(&once,^{generator=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];});
    [generator impactOccurred];[generator prepare];
}
@implementation HaogeKeyboardToolbarAIActionProxy
- (BOOL)respondsToSelector:(SEL)selector { return [self.haoge_keyboardtoolbarai_actions respondsToSelector:selector] || [super respondsToSelector:selector]; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.haoge_keyboardtoolbarai_actions methodSignatureForSelector:selector] ?: [super methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    HaogeKeyboardToolbarAIActions *actions=self.haoge_keyboardtoolbarai_actions;
    if (![[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_isEnabled]) return;
    NSString *name=NSStringFromSelector(invocation.selector);
    if (![name hasPrefix:@"haoge_keyboardtoolbarai_"] || ![actions respondsToSelector:invocation.selector]) { [super forwardInvocation:invocation];return; }
    haoge_keyboardtoolbarai_haptic();
    id input=actions.haoge_keyboardtoolbarai_target;
    if (input && [input isFirstResponder]) [invocation invokeWithTarget:actions];
    else {
        NSString *action=[name substringFromIndex:@"haoge_keyboardtoolbarai_".length];
        NSString *notification=[@"com.haoge.keyboardtoolbarai.action." stringByAppendingString:action];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge CFStringRef)notification,NULL,NULL,true);
    }
}
@end
id haoge_keyboardtoolbarai_actionProxy(HaogeKeyboardToolbarAIActions *actions) { HaogeKeyboardToolbarAIActionProxy *p=[HaogeKeyboardToolbarAIActionProxy new];p.haoge_keyboardtoolbarai_actions=actions;return p; }
