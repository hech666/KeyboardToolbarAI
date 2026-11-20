#import "HaogeKeyboardToolbarAIToolbar.h"
#import <QuartzCore/QuartzCore.h>
#import "HaogeKeyboardToolbarAIConfig.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAIGeometry.h"
#import <objc/message.h>

// New integration boundary: the parent action layer supplies these instances.
// Original uses haoge_keyboardtoolbarai_Tool() at 0x19d34 and haoge_keyboardtoolbarai_ActionProxyFor() at 0x25540.
static id haoge_keyboardtoolbarai_gKTActionTarget;
static id haoge_keyboardtoolbarai_gKTActionProxy;
void haoge_keyboardtoolbarai_RecoveredSetActionTarget(id target) { haoge_keyboardtoolbarai_gKTActionTarget = target; }
void haoge_keyboardtoolbarai_RecoveredSetActionProxy(id proxy) { haoge_keyboardtoolbarai_gKTActionProxy = proxy; }

// Readable recovery for KeyboardTools 5.2.0-206, NOT original source.
// External HaogeKeyboardToolbarAIUIConfig, action target/proxy and AI classes are integration seams.
// This unit contains no keycap/candidate/keyboard-background beautification.

struct haoge_keyboardtoolbarai_ToolbarState {
    BOOL atBottom;
    BOOL icons;
    BOOL attachEnabled;
    NSUInteger buttonCount;
};
static haoge_keyboardtoolbarai_ToolbarState haoge_keyboardtoolbarai_gKTState = {};
static BOOL haoge_keyboardtoolbarai_gKTStateValid = NO;

static void haoge_keyboardtoolbarai_InvalidateToolbarState(void) { haoge_keyboardtoolbarai_gKTStateValid = NO; }

static haoge_keyboardtoolbarai_ToolbarState haoge_keyboardtoolbarai_RefreshToolbarState(void) {
    if (haoge_keyboardtoolbarai_gKTStateValid) return haoge_keyboardtoolbarai_gKTState;
    haoge_keyboardtoolbarai_gKTState.atBottom = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_isToolbarAtBottom];
    haoge_keyboardtoolbarai_gKTState.icons = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_showIcons];
    NSArray *ids = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_buttonIdentifiers];
    haoge_keyboardtoolbarai_gKTState.buttonCount = ids.count;
    haoge_keyboardtoolbarai_gKTState.attachEnabled = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_isEnabled] && ids.count != 0;

    // 0x1a5ac is a one-time Filza check, NOT SpringBoard. In Filza,
    // the top accessory path is disabled; bottom attachment remains eligible.
    static BOOL isFilza;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ isFilza = [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.tigisoftware.Filza"]; });
    haoge_keyboardtoolbarai_gKTState.attachEnabled &= (!isFilza || haoge_keyboardtoolbarai_gKTState.atBottom);
    haoge_keyboardtoolbarai_gKTStateValid = YES;
    return haoge_keyboardtoolbarai_gKTState;
}

static SEL haoge_keyboardtoolbarai_UsableSelector(id target, NSString *identifier, NSInteger direction) {
    if (identifier.length == 0 || !target) return NULL;
    NSString *mapped = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_actionIdentifierForButton:identifier direction:direction];
    if (mapped.length == 0) return NULL;
    SEL sel = NSSelectorFromString([@"haoge_keyboardtoolbarai_" stringByAppendingString:mapped]);
    return (sel && [target respondsToSelector:sel]) ? sel : NULL;
}

/// Builds only the visible UI and binds the existing action target. It does
/// not implement or execute any KeyboardTools action body.
UIButton *haoge_keyboardtoolbarai_RecoveredBuildToolbarButton(id actionTarget,
                                        NSString *buttonIdentifier,
                                        CGFloat requestedWidth) {
    NSString *mappedTap = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_actionIdentifierForButton:buttonIdentifier direction:0];
    NSString *displayIdentifier = mappedTap.length ? mappedTap : buttonIdentifier;
    NSArray<NSString *> *symbols = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_symbolsForActionIdentifier:displayIdentifier];
    UIImage *image = nil;
    for (NSString *name in symbols) {
        UIImage *candidate = [UIImage systemImageNamed:name];
        if (candidate) { image = [candidate imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; break; }
    }
    NSString *title = [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_displayNameForActionIdentifier:displayIdentifier];
    BOOL imageOnly = image && [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_showIcons];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [UIFont systemFontOfSize:15.0];
    if (imageOnly) [button setImage:image forState:UIControlStateNormal];
    else [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.7; // __const 0x49120 = 0x3fe6666666666666

    SEL tap = haoge_keyboardtoolbarai_UsableSelector(actionTarget, buttonIdentifier, 0);
    if (tap && haoge_keyboardtoolbarai_gKTActionProxy) [button addTarget:haoge_keyboardtoolbarai_gKTActionProxy action:tap forControlEvents:UIControlEventTouchUpInside];
    // Exact original table: 0x491a0={4,8,2,1}; direction 0 is tap.
    // 0x49198 is haoge_keyboardtoolbarai_ButtonMinTitleWidth=40, NOT the table base.
    for (NSNumber *n in [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_allGestureDirections]) {
        NSInteger direction = n.integerValue;
        UISwipeGestureRecognizerDirection uiDirection;
        switch (direction) {
            case 1: uiDirection = UISwipeGestureRecognizerDirectionUp; break;
            case 2: uiDirection = UISwipeGestureRecognizerDirectionDown; break;
            case 3: uiDirection = UISwipeGestureRecognizerDirectionLeft; break;
            case 4: uiDirection = UISwipeGestureRecognizerDirectionRight; break;
            default: continue; // 0 is tap; unknown configured values are ignored
        }
        SEL gestureAction = haoge_keyboardtoolbarai_UsableSelector(actionTarget, buttonIdentifier, direction);
        if (!gestureAction || !haoge_keyboardtoolbarai_gKTActionProxy) continue;
        UISwipeGestureRecognizer *gr = [[UISwipeGestureRecognizer alloc] initWithTarget:haoge_keyboardtoolbarai_gKTActionProxy action:gestureAction];
        gr.direction = uiDirection;
        [button addGestureRecognizer:gr];
    }
    CGFloat width = requestedWidth > 0 ? requestedWidth : (imageOnly ? 28.0 : 40.0);
    button.frame = CGRectMake(0, 0, width, 44.0);
    return button;
}

// 0x193b4: x0=bar, x1=maxItems, d0=widthOverride, x2=compactBottom.
// Readable equivalent; maxItems<=0 means unlimited. Height comes from bar.frame.
static void haoge_keyboardtoolbarai_ApplyRecoveredItems(UIToolbar *bar, NSInteger maxItems, CGFloat widthOverride, BOOL compactBottom) {
    if (!bar) return;
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    NSMutableArray *items = [NSMutableArray array];
    NSInteger count = 0;
    if (compactBottom) {
        CGFloat height = bar.frame.size.height > 0 ? bar.frame.size.height : haoge_keyboardtoolbarai_ButtonSize;
        UIView *wrapper = [UIView new];
        CGFloat x = 0;
        for (NSString *identifier in [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_buttonIdentifiers]) {
            if (maxItems >= 1 && count >= maxItems) break;
            UIButton *button = haoge_keyboardtoolbarai_RecoveredBuildToolbarButton(haoge_keyboardtoolbarai_gKTActionTarget, identifier, widthOverride);
            if (!button) continue;
            button.frame = CGRectMake(x, 0, button.frame.size.width, height);
            [wrapper addSubview:button];
            x += button.frame.size.width + haoge_keyboardtoolbarai_ButtonGap;
            ++count;
        }
        if (count > 0) x -= haoge_keyboardtoolbarai_ButtonGap;
        wrapper.frame = CGRectMake(0, 0, MAX(0, x), height);
        if (wrapper.subviews.count) {
            [items addObject:space];
            [items addObject:[[UIBarButtonItem alloc] initWithCustomView:wrapper]];
            [items addObject:space];
        }
    } else {
        for (NSString *identifier in [HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_buttonIdentifiers]) {
            if (maxItems >= 1 && count >= maxItems) break;
            UIButton *button = haoge_keyboardtoolbarai_RecoveredBuildToolbarButton(haoge_keyboardtoolbarai_gKTActionTarget, identifier, 0);
            if (!button) continue;
            UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:button];
            if (!item) continue;
            [items addObject:space];
            [items addObject:item];
            ++count;
        }
        if (count > 0) [items addObject:space];
    }
    bar.items = items;
    if (count == 0) { CGRect f = bar.frame; f.size.height = 0; bar.frame = f; }
}

// 0x19e50, with action instance/proxy supplied by the parent instead of
// recreating haoge_keyboardtoolbarai_Tool() and the action execution layer.
UIToolbar *haoge_keyboardtoolbarai_RecoveredMakeToolbar(BOOL bottom, id actionTarget) {
    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, haoge_keyboardtoolbarai_ButtonSize)];
    bar.tag = haoge_keyboardtoolbarai_RecoveredToolbarTag;
    bar.tintColor = UIColor.labelColor;
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    (void)actionTarget; // actual action target is provided via setter above
    haoge_keyboardtoolbarai_ApplyRecoveredItems(bar, 0, 0, bottom);
    haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(bar, nil);
    return bar;
}

// MARK: input accessory state machine (0x1af90, 0x1b068, 0x1b0b4, 0x1b314)
// New local storage replaces exact original global addresses; ownership and
// branch semantics are retained. No private binary addresses are called.
static UIToolbar *haoge_keyboardtoolbarai_gTopBar;
static __weak id haoge_keyboardtoolbarai_gPendingInput;
static __weak id haoge_keyboardtoolbarai_gLastAttemptInput;
static BOOL haoge_keyboardtoolbarai_gPendingScheduled;
static BOOL haoge_keyboardtoolbarai_gAccessoryBusy;
static NSUInteger haoge_keyboardtoolbarai_gRapidAttemptCount;
static CFTimeInterval haoge_keyboardtoolbarai_gLastAttemptTime;
static CFTimeInterval haoge_keyboardtoolbarai_gRetryAfter;
static NSHashTable<UIView *> *haoge_keyboardtoolbarai_gDockViews;

static BOOL haoge_keyboardtoolbarai_AIContains(id input) {
    Class panel = NSClassFromString(@"HaogeKeyboardToolbarAIChatPanel");
    SEL sel = NSSelectorFromString(@"haoge_keyboardtoolbarai_containsResponder:");
    return panel && [panel respondsToSelector:sel] && ((BOOL(*)(id,SEL,id))objc_msgSend)(panel, sel, input);
}
static BOOL haoge_keyboardtoolbarai_AIVisible(void) {
    Class panel = NSClassFromString(@"HaogeKeyboardToolbarAIChatPanel");
    SEL sel = NSSelectorFromString(@"haoge_keyboardtoolbarai_isVisible");
    return panel && [panel respondsToSelector:sel] && ((BOOL(*)(id,SEL))objc_msgSend)(panel, sel);
}
static UIView *haoge_keyboardtoolbarai_Accessory(id input) {
    SEL sel = @selector(inputAccessoryView);
    return [input respondsToSelector:sel] ? ((id(*)(id,SEL))objc_msgSend)(input, sel) : nil;
}
static BOOL haoge_keyboardtoolbarai_CanSetAccessory(id input) {
    return [input respondsToSelector:NSSelectorFromString(@"setInputAccessoryView:")];
}
static void haoge_keyboardtoolbarai_SetAccessory(id input, UIView *bar) {
    SEL sel = NSSelectorFromString(@"setInputAccessoryView:");
    if ([input respondsToSelector:sel]) ((void(*)(id,SEL,id))objc_msgSend)(input, sel, bar);
}
static UIToolbar *haoge_keyboardtoolbarai_TopBar(void) { // original 0x1ae64, once initializer 0x1aea4
    static dispatch_once_t once;
    dispatch_once(&once, ^{ haoge_keyboardtoolbarai_gTopBar = haoge_keyboardtoolbarai_RecoveredMakeToolbar(NO, haoge_keyboardtoolbarai_gKTActionTarget); });
    return haoge_keyboardtoolbarai_gTopBar;
}
static void haoge_keyboardtoolbarai_ApplyDeferredAccessory(void) {
    id input = haoge_keyboardtoolbarai_gPendingInput;
    haoge_keyboardtoolbarai_gPendingInput = nil;
    haoge_keyboardtoolbarai_gPendingScheduled = NO;
    if (!input || haoge_keyboardtoolbarai_gAccessoryBusy) return;
    if (![input respondsToSelector:@selector(window)] || !((id(*)(id,SEL))objc_msgSend)(input, @selector(window))) return;
    if (haoge_keyboardtoolbarai_AIContains(input) || !haoge_keyboardtoolbarai_CanSetAccessory(input)) return;
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    haoge_keyboardtoolbarai_gAccessoryBusy = YES;
    @try {
        UIView *existing = haoge_keyboardtoolbarai_Accessory(input);
        if (!state.attachEnabled || state.atBottom) {
            if (haoge_keyboardtoolbarai_gTopBar && existing == haoge_keyboardtoolbarai_gTopBar) haoge_keyboardtoolbarai_SetAccessory(input, nil);
            return;
        }
        if (![input isFirstResponder]) return;
        if (existing.tag == haoge_keyboardtoolbarai_RecoveredToolbarTag || existing != nil) {
            // Keep another app's accessory; normal layout never replaces it.
            haoge_keyboardtoolbarai_gRapidAttemptCount = 0;
            return;
        }
        CFTimeInterval now = CACurrentMediaTime();
        if (haoge_keyboardtoolbarai_gLastAttemptInput == input && now - haoge_keyboardtoolbarai_gLastAttemptTime < 0.6) {
            if (++haoge_keyboardtoolbarai_gRapidAttemptCount >= 3) haoge_keyboardtoolbarai_gRetryAfter = now + 1.0;
        } else haoge_keyboardtoolbarai_gRapidAttemptCount = 0;
        if (now < haoge_keyboardtoolbarai_gRetryAfter) return;
        haoge_keyboardtoolbarai_gLastAttemptInput = input;
        haoge_keyboardtoolbarai_gLastAttemptTime = now;
        haoge_keyboardtoolbarai_SetAccessory(input, haoge_keyboardtoolbarai_TopBar());
        // Original deferred layout path does NOT call reloadInputViews here.
    } @finally { haoge_keyboardtoolbarai_gAccessoryBusy = NO; }
}
void haoge_keyboardtoolbarai_RecoveredInputLayoutAdapter(id input) { // called AFTER %orig
    if (haoge_keyboardtoolbarai_AIContains(input)) return;
    BOOL focused=[input isFirstResponder];
    if (focused) haoge_keyboardtoolbarai_RecoveredBecomeFirstResponderAdapter(input);
    if (!focused && (!haoge_keyboardtoolbarai_gTopBar || haoge_keyboardtoolbarai_Accessory(input)!=haoge_keyboardtoolbarai_gTopBar)) return;
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    UIView *existing = haoge_keyboardtoolbarai_Accessory(input);
    BOOL need = state.attachEnabled && !state.atBottom
        ? existing.tag != haoge_keyboardtoolbarai_RecoveredToolbarTag
        : haoge_keyboardtoolbarai_gTopBar && existing == haoge_keyboardtoolbarai_gTopBar;
    if (!need) return;
    haoge_keyboardtoolbarai_gPendingInput = input;
    if (haoge_keyboardtoolbarai_gPendingScheduled) return;
    haoge_keyboardtoolbarai_gPendingScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ haoge_keyboardtoolbarai_ApplyDeferredAccessory(); });
}
void haoge_keyboardtoolbarai_RecoveredBecomeFirstResponderAdapter(id input) { // only if %orig returned YES
    if (haoge_keyboardtoolbarai_AIContains(input)) return;
    SEL sel = NSSelectorFromString(@"setHaoge_keyboardtoolbarai_target:");
    if ([haoge_keyboardtoolbarai_gKTActionTarget respondsToSelector:sel])
        ((void(*)(id,SEL,id))objc_msgSend)(haoge_keyboardtoolbarai_gKTActionTarget, sel, input);
}

// 0x1ac30 settings-reload path: unlike ordinary layout it deliberately sets the
// shared top toolbar on the action target, then reloads input views. The binary
// does not test attachEnabled here; its normal-layout path reconciles disabled
// state afterward. v2 deliberately corrects that oddity: disabled means removed, and host accessories are preserved.
static void haoge_keyboardtoolbarai_ReconcileTopAfterReload(void) {
    haoge_keyboardtoolbarai_InvalidateToolbarState();
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    if (haoge_keyboardtoolbarai_gTopBar) { haoge_keyboardtoolbarai_ApplyRecoveredItems(haoge_keyboardtoolbarai_gTopBar, 0, 0, NO); haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(haoge_keyboardtoolbarai_gTopBar, nil); }
    SEL targetSel = NSSelectorFromString(@"haoge_keyboardtoolbarai_target");
    id input = [haoge_keyboardtoolbarai_gKTActionTarget respondsToSelector:targetSel]
        ? ((id(*)(id,SEL))objc_msgSend)(haoge_keyboardtoolbarai_gKTActionTarget, targetSel) : nil;
    if (!input || haoge_keyboardtoolbarai_AIVisible() || !haoge_keyboardtoolbarai_CanSetAccessory(input)) return;
    haoge_keyboardtoolbarai_gRapidAttemptCount = 0; haoge_keyboardtoolbarai_gRetryAfter = 0; haoge_keyboardtoolbarai_gAccessoryBusy = YES;
    @try {
        if (!state.attachEnabled || state.atBottom) {
            if (haoge_keyboardtoolbarai_Accessory(input).tag == haoge_keyboardtoolbarai_RecoveredToolbarTag) haoge_keyboardtoolbarai_SetAccessory(input, nil);
        } else {
            UIView *existing=haoge_keyboardtoolbarai_Accessory(input);
            if (existing && existing.tag!=haoge_keyboardtoolbarai_RecoveredToolbarTag) return;
            UIToolbar *bar = haoge_keyboardtoolbarai_TopBar();
            [bar removeFromSuperview];
            bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            bar.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, haoge_keyboardtoolbarai_ButtonSize);
            haoge_keyboardtoolbarai_SetAccessory(input, bar);
        }
        if ([input respondsToSelector:@selector(reloadInputViews)]) ((void(*)(id,SEL))objc_msgSend)(input, @selector(reloadInputViews));
    } @finally { haoge_keyboardtoolbarai_gAccessoryBusy = NO; }
}

// MARK: bottom dock (0x1c218 attachment, 0x1b824 layout)
// New association-key storage (the original uses keys loaded from 0x677e0,
// 0x677e8 and 0x677f0); keys are intentionally not original process pointers.
static char haoge_keyboardtoolbarai_kDockBar, haoge_keyboardtoolbarai_kDockSignature, haoge_keyboardtoolbarai_kDockLastAttempt;
void haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(UIView *dock) {
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    if (!haoge_keyboardtoolbarai_gDockViews) haoge_keyboardtoolbarai_gDockViews = [NSHashTable weakObjectsHashTable];
    [haoge_keyboardtoolbarai_gDockViews addObject:dock];
    UIToolbar *bar = objc_getAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockBar);
    if (!state.attachEnabled || !state.atBottom) {
        if (bar.superview == dock) [bar removeFromSuperview];
        return;
    }
    if (dock.bounds.size.width <= 1 || dock.bounds.size.height <= 1) return;
    if (!bar) {
        bar = haoge_keyboardtoolbarai_RecoveredMakeToolbar(YES, haoge_keyboardtoolbarai_gKTActionTarget);
        objc_setAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockBar, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (bar.superview != dock) {
        [bar removeFromSuperview];
        bar.autoresizingMask = UIViewAutoresizingNone;
        [dock addSubview:bar];
    }
}

void haoge_keyboardtoolbarai_RecoveredDockGeometryAdapter(UIView *dock) { // AFTER %orig layoutSubviews
    haoge_keyboardtoolbarai_ToolbarState current=haoge_keyboardtoolbarai_RefreshToolbarState();
    if (!current.attachEnabled || !current.atBottom) { haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(dock);return; }
    UIToolbar *bar = objc_getAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockBar);
    if (!bar || bar.superview != dock) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        NSNumber *last = objc_getAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockLastAttempt);
        if (now - last.doubleValue < 0.5) return;
        objc_setAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockLastAttempt, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(dock);
        bar = objc_getAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockBar);
        if (!bar || bar.superview != dock) return;
    }
    CGSize size = dock.bounds.size;
    if (size.width <= 1 || size.height <= 1) return;
    CGFloat left = 8;
    CGFloat right = MAX(size.width - 8, 8);
    CGRect reserved = CGRectNull;
    Class dockButtonClass = NSClassFromString(@"UIKeyboardDockItemButton");
    // Original inspects DIRECT dock subviews, not a recursive view traversal.
    for (UIView *subview in dock.subviews) {
        if (subview == bar || !dockButtonClass || ![subview isKindOfClass:dockButtonClass]) continue;
        CGRect r = [subview convertRect:subview.bounds toView:dock];
        if (r.size.width <= 0 || r.size.height <= 0) continue;
        reserved = CGRectIsNull(reserved) ? r : CGRectUnion(reserved, r);
        if (CGRectGetMidX(r) < size.width / 2) left = MAX(left, CGRectGetMaxX(r) + 4);
        else right = MIN(right, CGRectGetMinX(r) - 4);
    }
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    HaogeKeyboardToolbarAIGeometry geometry=haoge_keyboardtoolbarai_geometry(size.width,size.height,left,right,state.icons,(long)state.buttonCount,!CGRectIsNull(reserved),CGRectIsNull(reserved)?0:reserved.origin.y,CGRectIsNull(reserved)?0:reserved.size.height);
    CGFloat width=geometry.width,x=geometry.x,y=geometry.y,height=geometry.height,buttonWidth=geometry.buttonWidth;
    NSInteger count=geometry.count;
    // Height must be set before rebuilding compact items (they adopt it).
    CGRect f = bar.frame; f.size.height = height; bar.frame = f;
    NSString *signature = [NSString stringWithFormat:@"%ld|%.1f|%.1f", (long)count, buttonWidth, height];
    if (![objc_getAssociatedObject(bar, &haoge_keyboardtoolbarai_kDockSignature) isEqualToString:signature]) {
        objc_setAssociatedObject(bar, &haoge_keyboardtoolbarai_kDockSignature, signature, OBJC_ASSOCIATION_COPY_NONATOMIC);
        haoge_keyboardtoolbarai_ApplyRecoveredItems(bar, count, buttonWidth, YES);
    }
    CGRect target = CGRectMake(x, y, MAX(width, 0), height);
    if (!CGRectEqualToRect(bar.frame, target)) bar.frame = target;
}

// Caller should run this on main after preference reload; it is an explicit
// integration point rather than duplicating the parent's notification layer.
void haoge_keyboardtoolbarai_RecoveredToolbarPreferencesDidReload(void) {
    haoge_keyboardtoolbarai_ReconcileTopAfterReload();
    haoge_keyboardtoolbarai_ToolbarState state = haoge_keyboardtoolbarai_RefreshToolbarState();
    for (UIView *dock in haoge_keyboardtoolbarai_gDockViews.allObjects) {
        UIToolbar *bar = objc_getAssociatedObject(dock, &haoge_keyboardtoolbarai_kDockBar);
        if (!bar) continue;
        // 0x1bf4c checks bottom mode here, not attachEnabled. 0x1c218 is the
        // attachment state machine used on didMoveToWindow/unhide/layout retry.
        if (!state.attachEnabled || !state.atBottom) { if (bar.superview == dock) [bar removeFromSuperview]; }
        else {
            if (bar.superview != dock) [dock addSubview:bar];
            [dock setNeedsLayout];
            objc_setAssociatedObject(bar, &haoge_keyboardtoolbarai_kDockSignature, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(bar, nil);
        }
    }
}

// ToolBAR-only background preferences retained from the screenshot.
// Parser and contrast math are restored in Readable/ToolbarColor.m.
extern "C" void haoge_keyboardtoolbarai_RecoveredApplyToolbarBackground(UIToolbar *,BOOL,BOOL,id);
void haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(UIToolbar *bar, UITraitCollection *previous) {
    if (bar.tag != haoge_keyboardtoolbarai_RecoveredToolbarTag) return;
    (void)previous;
    BOOL bottom=haoge_keyboardtoolbarai_RefreshToolbarState().atBottom;
    BOOL enabled=!bottom && [[HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_valueForKey:@"toolbarBgEnabled" inDomain:@"com.haoge.keyboardtoolbarai"] boolValue];
    NSString *key=bar.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark?@"toolbarDarkColor":@"toolbarLightColor";
    id value=enabled?[HaogeKeyboardToolbarAIUIConfig haoge_keyboardtoolbarai_valueForKey:key inDomain:@"com.haoge.keyboardtoolbarai"]:nil;
    haoge_keyboardtoolbarai_RecoveredApplyToolbarBackground(bar,bottom,enabled,value);
}

@implementation HaogeKeyboardToolbarAIUIConfig
+ (BOOL)haoge_keyboardtoolbarai_isEnabled { return [[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_isEnabled]; }
+ (id)haoge_keyboardtoolbarai_valueForKey:(NSString *)key inDomain:(NSString *)domain { (void)domain; return [[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_valueForKey:key defaultValue:nil]; }
+ (BOOL)haoge_keyboardtoolbarai_isToolbarAtBottom { return [[self haoge_keyboardtoolbarai_valueForKey:@"ToolbarAtBottom" inDomain:@""] boolValue]; }
+ (BOOL)haoge_keyboardtoolbarai_showIcons { id v=[self haoge_keyboardtoolbarai_valueForKey:@"ShowIcons" inDomain:@""]; return [v isKindOfClass:NSNumber.class]?[v boolValue]:YES; }
+ (NSArray *)haoge_keyboardtoolbarai_buttonIdentifiers { id v=[self haoge_keyboardtoolbarai_valueForKey:@"Buttons" inDomain:@""]; return [v isKindOfClass:NSArray.class]?haoge_keyboardtoolbarai_normalizeButtons(v):haoge_keyboardtoolbarai_defaultButtons(); }
+ (NSString *)haoge_keyboardtoolbarai_displayNameForActionIdentifier:(NSString *)identifier { id names=[self haoge_keyboardtoolbarai_valueForKey:@"ActionNames" inDomain:@""];id v=[names isKindOfClass:NSDictionary.class]?names[identifier]:nil;if ([v isKindOfClass:NSString.class] && [v length]) return v;for (NSDictionary *item in haoge_keyboardtoolbarai_actionCatalog()) if ([item[@"id"] isEqual:identifier]) return item[@"name"];return identifier; }
+ (NSArray *)haoge_keyboardtoolbarai_symbolsForActionIdentifier:(NSString *)identifier { for (NSDictionary *item in haoge_keyboardtoolbarai_actionCatalog()) if ([item[@"id"] isEqual:identifier]) return item[@"symbols"]?:@[item[@"symbol"]]; return @[]; }
+ (NSString *)haoge_keyboardtoolbarai_actionIdentifierForButton:(NSString *)identifier direction:(NSInteger)direction { return haoge_keyboardtoolbarai_bindingAction([self haoge_keyboardtoolbarai_valueForKey:@"ActionBindings" inDomain:@""],identifier,direction); }
+ (NSArray *)haoge_keyboardtoolbarai_allGestureDirections { return @[@0,@1,@2,@3,@4]; }
@end
