#pragma once

#import <UIKit/UIKit.h>

NSString *haoge_keyboardtoolbarai_trim(id value);
NSDictionary *haoge_keyboardtoolbarai_dictionary(id value);
NSString *haoge_keyboardtoolbarai_actionTitle(NSString *identifier, id names);
UITableViewCell *haoge_keyboardtoolbarai_cell(NSString *title, NSString *detail,
                                              UITableViewCellAccessoryType accessory);

@interface HaogeKeyboardToolbarAIPrefsPage : UITableViewController
- (void)haoge_keyboardtoolbarai_showError:(NSString *)title message:(NSString *)message;
- (void)haoge_keyboardtoolbarai_confirm:(NSString *)title message:(NSString *)message
                               action:(NSString *)action handler:(dispatch_block_t)handler;
- (BOOL)haoge_keyboardtoolbarai_save:(NSString *)key value:(id)value;
- (void)haoge_keyboardtoolbarai_push:(UIViewController *)controller;
@end

@class HaogeKeyboardToolbarAIPrefsChoices;
typedef BOOL (^HaogeKeyboardToolbarAIPrefsChoiceHandler)(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index);
@interface HaogeKeyboardToolbarAIPrefsChoices : HaogeKeyboardToolbarAIPrefsPage
- (void)haoge_keyboardtoolbarai_showSelection:(NSInteger)selected;
- (instancetype)haoge_keyboardtoolbarai_initWithTitle:(NSString *)title
                                                 rows:(NSArray<NSArray<NSString *> *> *)rows
                                             selected:(NSInteger)selected
                                               choose:(HaogeKeyboardToolbarAIPrefsChoiceHandler)choose
    __attribute__((objc_method_family(init)));
@end
