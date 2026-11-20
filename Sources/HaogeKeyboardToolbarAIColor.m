#import "HaogeKeyboardToolbarAIModel.h"
void haoge_keyboardtoolbarai_RecoveredApplyToolbarBackground(UIToolbar *bar,BOOL bottom,BOOL enabled,id colorValue) {
    if (!bar || bar.tag!=0x4B544F4F) return;
    UIToolbarAppearance *appearance=[UIToolbarAppearance new];
    UIColor *tint=UIColor.labelColor;
    bar.backgroundColor=nil;bar.barTintColor=nil;
    UIColor *color=(!bottom && enabled)?haoge_keyboardtoolbarai_colorFromHex(colorValue):nil;
    if (bottom) { [appearance configureWithTransparentBackground];bar.opaque=NO; }
    else if (color) {
        [appearance configureWithOpaqueBackground];appearance.backgroundColor=color;
        CGFloat white=0,alpha=0,r=0,g=0,b=0;
        if (![color getWhite:&white alpha:&alpha])
            white=[color getRed:&r green:&g blue:&b alpha:&alpha]?(0.2126*r+0.7152*g+0.0722*b):0;
        tint=white>0.5?UIColor.blackColor:UIColor.whiteColor;
    } else [appearance configureWithDefaultBackground];
    appearance.shadowColor=UIColor.clearColor;
    bar.standardAppearance=appearance;
    if (@available(iOS 15.0,*)) bar.scrollEdgeAppearance=appearance;
    bar.tintColor=tint;
    [bar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
}
