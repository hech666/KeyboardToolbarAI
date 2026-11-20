#pragma once
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// ABI and recovered behavior notes for KeyboardTools 5.2.0-206 toolbar UI.
/// This header describes the recovered integration surface; it does not claim
/// source-level equivalence or provide private HaogeKeyboardToolbarAIUIConfig implementations.
static const NSInteger haoge_keyboardtoolbarai_RecoveredToolbarTag = 0x4B544F4F; // 0x4F4F | (0x4B54 << 16)
static const CGFloat haoge_keyboardtoolbarai_ButtonSize = 44.0;
static const CGFloat haoge_keyboardtoolbarai_ButtonHomeInset = 12.0;
static const CGFloat haoge_keyboardtoolbarai_ButtonGap = 4.0;
static const CGFloat haoge_keyboardtoolbarai_ButtonIconWidth = 28.0;
static const CGFloat haoge_keyboardtoolbarai_ButtonMinTitleWidth = 40.0;
static const CGFloat haoge_keyboardtoolbarai_RecoveredToolbarHeight = haoge_keyboardtoolbarai_ButtonSize;

/// Original binary function addresses (Mach-O image-relative, arm64 slice).
/// Use only when analyzing the exact supplied image; do not treat as stable ABI.
#define haoge_keyboardtoolbarai__ADDR_REFRESH_STATE       0x1928C
#define haoge_keyboardtoolbarai__ADDR_APPLY_ITEMS         0x193B4
#define haoge_keyboardtoolbarai__ADDR_APPLY_BAR_COLORS    0x198C8
#define haoge_keyboardtoolbarai__ADDR_TOOLBAR_MAKE        0x19E50
#define haoge_keyboardtoolbarai__ADDR_INPUT_HOOK_INSTALL  0x1A31C
#define haoge_keyboardtoolbarai__ADDR_RECONCILE_TOP       0x1AC30
#define haoge_keyboardtoolbarai__ADDR_DOCK_HOOK_INSTALL   0x1B738
#define haoge_keyboardtoolbarai__ADDR_DOCK_LAYOUT         0x1B824
#define haoge_keyboardtoolbarai__ADDR_DOCK_RECONCILE      0x1C218

/// Hook originals, recovered from the image's __DATA pointer slots.
/// Slots below are VM addresses inside __DATA (segment base 0x60000).
/// The ADRP page 0x68000 is not the segment base.
#define haoge_keyboardtoolbarai__ORIG_TF_LAYOUT_SLOT      0x68100
#define haoge_keyboardtoolbarai__ORIG_TF_BECOME_SLOT      0x68108
#define haoge_keyboardtoolbarai__ORIG_TV_LAYOUT_SLOT      0x68110
#define haoge_keyboardtoolbarai__ORIG_TV_BECOME_SLOT      0x68118
#define haoge_keyboardtoolbarai__ORIG_TOOLBAR_TRAIT_SLOT  0x68120
#define haoge_keyboardtoolbarai__ORIG_DOCK_DIDMOVE_SLOT   0x68180
#define haoge_keyboardtoolbarai__ORIG_DOCK_HIDDEN_SLOT    0x68188
#define haoge_keyboardtoolbarai__ORIG_DOCK_LAYOUT_SLOT    0x68190

/// The original config class is queried via these selectors:
/// - isEnabled, isToolbarAtBottom, showIcons, buttonIdentifiers
/// Additional action/UI selectors are listed in TOOLBAR_UI_REPORT.md.
@interface HaogeKeyboardToolbarAIUIConfig : NSObject
+ (BOOL)haoge_keyboardtoolbarai_isEnabled;
+ (BOOL)haoge_keyboardtoolbarai_isToolbarAtBottom;
+ (BOOL)haoge_keyboardtoolbarai_showIcons;
+ (NSArray<NSString *> *)haoge_keyboardtoolbarai_buttonIdentifiers;
+ (NSString *)haoge_keyboardtoolbarai_displayNameForActionIdentifier:(NSString *)identifier;
+ (NSArray<NSString *> *)haoge_keyboardtoolbarai_symbolsForActionIdentifier:(NSString *)identifier;
+ (NSString *)haoge_keyboardtoolbarai_actionIdentifierForButton:(NSString *)identifier direction:(NSInteger)direction;
+ (NSArray<NSNumber *> *)haoge_keyboardtoolbarai_allGestureDirections;
+ (id _Nullable)haoge_keyboardtoolbarai_valueForKey:(NSString *)key inDomain:(NSString *)domain;
@end
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredToolbarPreferencesDidReload(void);

/// Adapter injection points used by the readable hook implementation. The
/// parent/action layer supplies its existing proxy and action target; these
/// functions never implement KeyboardTools actions themselves.
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredSetActionTarget(id _Nullable target);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredSetActionProxy(id _Nullable proxy);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredInputLayoutAdapter(id input);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredBecomeFirstResponderAdapter(id input);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredToolbarTraitAdapter(UIToolbar *bar, UITraitCollection * _Nullable previous);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredDockAttachAdapter(UIView *dock);
FOUNDATION_EXPORT void haoge_keyboardtoolbarai_RecoveredDockGeometryAdapter(UIView *dock);

NS_ASSUME_NONNULL_END
