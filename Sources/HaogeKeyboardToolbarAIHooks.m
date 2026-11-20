#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "HaogeKeyboardToolbarAIConfig.h"
#import "HaogeKeyboardToolbarAIPreferences.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAIActions.h"
#import "HaogeKeyboardToolbarAIToolbar.h"
#import "HaogeKeyboardToolbarAIChat.h"

static HaogeKeyboardToolbarAIActions *haoge_keyboardtoolbarai_actions;
static id haoge_keyboardtoolbarai_proxy;
static id haoge_keyboardtoolbarai_reloadObserver;
static id haoge_keyboardtoolbarai_foregroundObserver;
static IMP haoge_keyboardtoolbarai_originalTFLayout,haoge_keyboardtoolbarai_originalTFBecome;
static IMP haoge_keyboardtoolbarai_originalTVLayout,haoge_keyboardtoolbarai_originalTVBecome;
static IMP haoge_keyboardtoolbarai_originalTrait,haoge_keyboardtoolbarai_originalDockMove;
static IMP haoge_keyboardtoolbarai_originalDockHidden,haoge_keyboardtoolbarai_originalDockLayout;

static void haoge_keyboardtoolbarai_tfLayout(id self,SEL cmd) {
    ((void(*)(id,SEL))haoge_keyboardtoolbarai_originalTFLayout)(self,cmd);
    haoge_keyboardtoolbarai_RecoveredInputLayoutAdapter(self);
}
static BOOL haoge_keyboardtoolbarai_tfBecome(id self,SEL cmd) {
    BOOL ok=((BOOL(*)(id,SEL))haoge_keyboardtoolbarai_originalTFBecome)(self,cmd);
    if (ok) haoge_keyboardtoolbarai_RecoveredBecomeFirstResponderAdapter(self);return ok;
}
static void haoge_keyboardtoolbarai_tvLayout(id self,SEL cmd) {
    ((void(*)(id,SEL))haoge_keyboardtoolbarai_originalTVLayout)(self,cmd);
    haoge_keyboardtoolbarai_RecoveredInputLayoutAdapter(self);
}
static BOOL haoge_keyboardtoolbarai_tvBecome(id self,SEL cmd) {
    BOOL ok=((BOOL(*)(id,SEL))haoge_keyboardtoolbarai_originalTVBecome)(self,cmd);
    if (ok) haoge_keyboardtoolbarai_RecoveredBecomeFirstResponderAdapter(self);return ok;
}
static void haoge_keyboardtoolbarai_trait(id self,SEL cmd,id previous) {
    ((void(*)(id,SEL,id))haoge_keyboardtoolbarai_originalTrait)(self,cmd,previous);
    haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(self,previous);
}
static void haoge_keyboardtoolbarai_dockMove(id self,SEL cmd) {
    ((void(*)(id,SEL))haoge_keyboardtoolbarai_originalDockMove)(self,cmd);
    haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(self);
}
static void haoge_keyboardtoolbarai_dockHidden(id self,SEL cmd,BOOL hidden) {
    ((void(*)(id,SEL,BOOL))haoge_keyboardtoolbarai_originalDockHidden)(self,cmd,hidden);
    if (!hidden) haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(self);
}
static void haoge_keyboardtoolbarai_dockLayout(id self,SEL cmd) {
    ((void(*)(id,SEL))haoge_keyboardtoolbarai_originalDockLayout)(self,cmd);
    haoge_keyboardtoolbarai_RecoveredDockGeometryAdapter(self);
}
static void haoge_keyboardtoolbarai_hook(Class cls,SEL selector,IMP replacement,IMP *original,unsigned count,BOOL returnsBool) {
    Method method=class_getInstanceMethod(cls,selector);
    if (!method || method_getNumberOfArguments(method)!=count) return;
    char result[32]={0};method_getReturnType(method,result,sizeof(result));
    if (returnsBool?(result[0]!='B' && result[0]!='c'):(result[0]!='v')) return;
    MSHookMessageEx(cls,selector,replacement,original);
}
static void haoge_keyboardtoolbarai_actionNotification(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    NSString *notification=[(__bridge NSString *)name copy];
    dispatch_async(dispatch_get_main_queue(),^{
        if (![[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_isEnabled]) return;
        NSString *prefix=@"com.haoge.keyboardtoolbarai.action.";
        if ([notification hasPrefix:prefix]) {
            NSString *action=[notification substringFromIndex:prefix.length];
            id input=haoge_keyboardtoolbarai_actions.haoge_keyboardtoolbarai_target;
            if (!input || ![input isFirstResponder] || [HaogeKeyboardToolbarAIChatPanel haoge_keyboardtoolbarai_containsResponder:input]) return;
            if (![haoge_keyboardtoolbarai_actionIDs() containsObject:action]) return;
            SEL selector=NSSelectorFromString([@"haoge_keyboardtoolbarai_" stringByAppendingString:action]);
            if ([haoge_keyboardtoolbarai_actions respondsToSelector:selector]) ((void(*)(id,SEL))objc_msgSend)(haoge_keyboardtoolbarai_actions,selector);
        }
    });
}
__attribute__((constructor)) static void haoge_keyboardtoolbarai_initialize(void) {
    @autoreleasepool {
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
        dispatch_async(dispatch_get_main_queue(),^{
            [HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared];
            haoge_keyboardtoolbarai_actions=[HaogeKeyboardToolbarAIActions new];
            haoge_keyboardtoolbarai_proxy=haoge_keyboardtoolbarai_actionProxy(haoge_keyboardtoolbarai_actions);
            haoge_keyboardtoolbarai_RecoveredSetActionTarget(haoge_keyboardtoolbarai_actions);
            haoge_keyboardtoolbarai_RecoveredSetActionProxy(haoge_keyboardtoolbarai_proxy);
            haoge_keyboardtoolbarai_hook(UITextField.class,@selector(layoutSubviews),(IMP)haoge_keyboardtoolbarai_tfLayout,&haoge_keyboardtoolbarai_originalTFLayout,2,NO);
            haoge_keyboardtoolbarai_hook(UITextField.class,@selector(becomeFirstResponder),(IMP)haoge_keyboardtoolbarai_tfBecome,&haoge_keyboardtoolbarai_originalTFBecome,2,YES);
            haoge_keyboardtoolbarai_hook(UITextView.class,@selector(layoutSubviews),(IMP)haoge_keyboardtoolbarai_tvLayout,&haoge_keyboardtoolbarai_originalTVLayout,2,NO);
            haoge_keyboardtoolbarai_hook(UITextView.class,@selector(becomeFirstResponder),(IMP)haoge_keyboardtoolbarai_tvBecome,&haoge_keyboardtoolbarai_originalTVBecome,2,YES);
            haoge_keyboardtoolbarai_hook(UIToolbar.class,@selector(traitCollectionDidChange:),(IMP)haoge_keyboardtoolbarai_trait,&haoge_keyboardtoolbarai_originalTrait,3,NO);
            Class dock=NSClassFromString(@"UIKeyboardDockView");
            haoge_keyboardtoolbarai_hook(dock,@selector(didMoveToWindow),(IMP)haoge_keyboardtoolbarai_dockMove,&haoge_keyboardtoolbarai_originalDockMove,2,NO);
            haoge_keyboardtoolbarai_hook(dock,@selector(setHidden:),(IMP)haoge_keyboardtoolbarai_dockHidden,&haoge_keyboardtoolbarai_originalDockHidden,3,NO);
            haoge_keyboardtoolbarai_hook(dock,@selector(layoutSubviews),(IMP)haoge_keyboardtoolbarai_dockLayout,&haoge_keyboardtoolbarai_originalDockLayout,2,NO);
            haoge_keyboardtoolbarai_reloadObserver=[NSNotificationCenter.defaultCenter addObserverForName:HaogeKeyboardToolbarAIPreferencesChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){haoge_keyboardtoolbarai_RecoveredToolbarPreferencesDidReload();}];
            haoge_keyboardtoolbarai_foregroundObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{[[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_reload];});}];
            for (NSString *action in haoge_keyboardtoolbarai_actionIDs()) {
                NSString *name=[@"com.haoge.keyboardtoolbarai.action." stringByAppendingString:action];
                CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,haoge_keyboardtoolbarai_actionNotification,(__bridge CFStringRef)name,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
            }

        });
    }
}
