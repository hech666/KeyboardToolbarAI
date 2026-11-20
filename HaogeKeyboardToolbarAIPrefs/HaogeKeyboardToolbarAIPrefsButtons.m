#import "HaogeKeyboardToolbarAIPrefsControllers.h"
#import "HaogeKeyboardToolbarAIPreferences.h"
#import "HaogeKeyboardToolbarAIModel.h"

static NSArray<NSString *> *haoge_keyboardtoolbarai_savedButtons(NSDictionary *prefs) {
    id raw = prefs[@"Buttons"];
    return [raw isKindOfClass:NSArray.class] ? haoge_keyboardtoolbarai_normalizeButtons(raw)
                                           : haoge_keyboardtoolbarai_defaultButtons();
}

static NSString *haoge_keyboardtoolbarai_directionTitle(NSUInteger row) {
    return @[@"点击", @"上滑", @"下滑", @"左滑", @"右滑"][row];
}

static NSString *haoge_keyboardtoolbarai_directionKey(NSUInteger row) {
    return @[@"tap", @"up", @"down", @"left", @"right"][row];
}

static NSInteger haoge_keyboardtoolbarai_bindingSelection(id map, NSString *button, NSUInteger direction,
                                                           NSArray<NSString *> *ids) {
    NSDictionary *assigned = haoge_keyboardtoolbarai_dictionary(haoge_keyboardtoolbarai_dictionary(map)[button]);
    if (!assigned[haoge_keyboardtoolbarai_directionKey(direction)]) return 0;
    NSString *action = haoge_keyboardtoolbarai_bindingAction(map, button, direction);
    NSUInteger index = action ? [ids indexOfObject:action] : NSNotFound;
    return index == NSNotFound ? 1 : (NSInteger)index + 2;
}

@interface HaogeKeyboardToolbarAIPrefsBindings : HaogeKeyboardToolbarAIPrefsPage
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setButton:) NSString *haoge_keyboardtoolbarai_button;
@end

@implementation HaogeKeyboardToolbarAIPrefsBindings {
    NSDictionary *_prefs;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _prefs = haoge_keyboardtoolbarai_readPreferences();
    self.title = haoge_keyboardtoolbarai_actionTitle(self.haoge_keyboardtoolbarai_button, _prefs[@"ActionNames"]);
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 5; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"默认点击执行按钮自身的动作，默认滑动不触发动作。选择「不执行」可显式禁用，包括点击。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSString *action = haoge_keyboardtoolbarai_bindingAction(_prefs[@"ActionBindings"], self.haoge_keyboardtoolbarai_button, path.row);
    NSString *label = action ? haoge_keyboardtoolbarai_actionTitle(action, _prefs[@"ActionNames"]) : @"不执行";
    return haoge_keyboardtoolbarai_cell(haoge_keyboardtoolbarai_directionTitle(path.row), label,
                                       UITableViewCellAccessoryDisclosureIndicator);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSUInteger direction = path.row;
    NSString *button = self.haoge_keyboardtoolbarai_button;
    NSDictionary *prefs = haoge_keyboardtoolbarai_readPreferences();
    NSArray<NSString *> *ids = haoge_keyboardtoolbarai_actionIDs();
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray arrayWithArray:@[@[@"使用默认"], @[@"不执行"]]];
    for (NSString *identifier in ids) {
        [rows addObject:@[haoge_keyboardtoolbarai_actionTitle(identifier, prefs[@"ActionNames"]),
                          haoge_keyboardtoolbarai_actionTitle(identifier, nil)]];
    }
    NSInteger selected = haoge_keyboardtoolbarai_bindingSelection(prefs[@"ActionBindings"], button, direction, ids);
    HaogeKeyboardToolbarAIPrefsChoices *choices = [[HaogeKeyboardToolbarAIPrefsChoices alloc]
        haoge_keyboardtoolbarai_initWithTitle:haoge_keyboardtoolbarai_directionTitle(direction)
        rows:rows selected:selected choose:^BOOL(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index) {
            id bindings = haoge_keyboardtoolbarai_readPreferences()[@"ActionBindings"];
            NSDictionary *updated;
            if (index == 0) {
                NSMutableDictionary *map = [haoge_keyboardtoolbarai_dictionary(bindings) mutableCopy];
                NSMutableDictionary *perButton = [haoge_keyboardtoolbarai_dictionary(map[button]) mutableCopy];
                NSString *key = haoge_keyboardtoolbarai_directionKey(direction);
                if (!perButton[key]) return YES;
                [perButton removeObjectForKey:key];
                if (perButton.count) map[button] = perButton;
                else [map removeObjectForKey:button];
                updated = map;
            } else {
                updated = haoge_keyboardtoolbarai_storeBinding(bindings, button, direction, index == 1 ? @"" : ids[index - 2]);
            }
            if ([page haoge_keyboardtoolbarai_save:@"ActionBindings" value:updated]) return YES;
            id actual = haoge_keyboardtoolbarai_readPreferences()[@"ActionBindings"];
            [page haoge_keyboardtoolbarai_showSelection:haoge_keyboardtoolbarai_bindingSelection(actual, button, direction, ids)];
            return NO;
        }];
    [self haoge_keyboardtoolbarai_push:choices];
}

@end

@interface HaogeKeyboardToolbarAIPrefsActionNames : HaogeKeyboardToolbarAIPrefsPage
@end

@implementation HaogeKeyboardToolbarAIPrefsActionNames {
    NSArray<NSString *> *_identifiers;
    NSDictionary *_names;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自定义动作名";
    _identifiers = haoge_keyboardtoolbarai_actionIDs();
    [self haoge_keyboardtoolbarai_reloadNames];
}

- (void)haoge_keyboardtoolbarai_reloadNames {
    _names = haoge_keyboardtoolbarai_dictionary(haoge_keyboardtoolbarai_readPreferences()[@"ActionNames"]);
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _identifiers.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSString *identifier = _identifiers[path.row];
    NSString *custom = haoge_keyboardtoolbarai_trim(_names[identifier]);
    return haoge_keyboardtoolbarai_cell(haoge_keyboardtoolbarai_actionTitle(identifier, nil),
                                       custom.length ? custom : @"默认", UITableViewCellAccessoryDisclosureIndicator);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSString *identifier = _identifiers[path.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:haoge_keyboardtoolbarai_actionTitle(identifier, nil)
        message:@"留空恢复默认名称。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = haoge_keyboardtoolbarai_trim(self->_names[identifier]);
        field.placeholder = haoge_keyboardtoolbarai_actionTitle(identifier, nil);
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *item) {
        NSString *value = haoge_keyboardtoolbarai_trim(weakAlert.textFields.firstObject.text);
        id actual = haoge_keyboardtoolbarai_readPreferences()[@"ActionNames"];
        NSMutableDictionary *updated = [haoge_keyboardtoolbarai_dictionary(actual) mutableCopy];
        if (value.length) updated[identifier] = value;
        else [updated removeObjectForKey:identifier];
        if (value.length || actual) [self haoge_keyboardtoolbarai_save:@"ActionNames" value:updated];
        [self haoge_keyboardtoolbarai_reloadNames];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@implementation HaogeKeyboardToolbarAIPrefsButtons {
    NSArray<NSString *> *_buttons;
    NSDictionary *_names;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"手势动作设置";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.tableView.allowsSelectionDuringEditing = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self haoge_keyboardtoolbarai_reloadButtons];
}

- (void)haoge_keyboardtoolbarai_reloadButtons {
    NSDictionary *prefs = haoge_keyboardtoolbarai_readPreferences();
    _buttons = haoge_keyboardtoolbarai_savedButtons(prefs);
    _names = haoge_keyboardtoolbarai_dictionary(prefs[@"ActionNames"]);
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? _buttons.count : 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"工具栏按钮" : @"管理";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"点击按钮设置手势；编辑时可拖动排序或删除，也可向左轻扫删除。" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) {
        NSString *button = _buttons[path.row];
        UITableViewCell *cell = haoge_keyboardtoolbarai_cell(haoge_keyboardtoolbarai_actionTitle(button, _names), nil,
                                                              UITableViewCellAccessoryDisclosureIndicator);
        cell.showsReorderControl = YES;
        return cell;
    }
    return haoge_keyboardtoolbarai_cell(@[@"添加按钮", @"自定义动作名", @"恢复默认按钮列表"][path.row], nil,
                                       path.row == 2 ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path { return path.section == 0; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return path.section == 0; }

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source
                             toProposedIndexPath:(NSIndexPath *)destination {
    return destination.section == 0 ? destination : [NSIndexPath indexPathForRow:_buttons.count - 1 inSection:0];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)destination {
    if (source.section != 0 || destination.section != 0 || source.row == destination.row) return;
    NSArray *current = haoge_keyboardtoolbarai_savedButtons(haoge_keyboardtoolbarai_readPreferences());
    if (![current isEqual:_buttons]) {
        [self haoge_keyboardtoolbarai_showError:@"未能排序" message:@"按钮列表已更改。已重新读取，请再试一次。"];
    } else {
        NSMutableArray *changed = [_buttons mutableCopy];
        NSString *button = changed[source.row];
        [changed removeObjectAtIndex:source.row];
        [changed insertObject:button atIndex:destination.row];
        [self haoge_keyboardtoolbarai_save:@"Buttons" value:haoge_keyboardtoolbarai_normalizeButtons(changed)];
    }
    // UIKit is still completing the drag when this callback returns.
    _buttons = haoge_keyboardtoolbarai_savedButtons(haoge_keyboardtoolbarai_readPreferences());
    dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_keyboardtoolbarai_reloadButtons]; });
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete || path.section != 0) return;
    NSString *button = _buttons[path.row];
    NSMutableArray *updated = [haoge_keyboardtoolbarai_savedButtons(haoge_keyboardtoolbarai_readPreferences()) mutableCopy];
    [updated removeObject:button];
    [self haoge_keyboardtoolbarai_save:@"Buttons" value:haoge_keyboardtoolbarai_normalizeButtons(updated)];
    [self haoge_keyboardtoolbarai_reloadButtons];
}

- (void)haoge_keyboardtoolbarai_addButton {
    NSDictionary *prefs = haoge_keyboardtoolbarai_readPreferences();
    NSArray *buttons = haoge_keyboardtoolbarai_savedButtons(prefs);
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    for (NSDictionary *action in haoge_keyboardtoolbarai_actionCatalog()) {
        NSString *identifier = action[@"id"];
        if ([buttons containsObject:identifier]) continue;
        [ids addObject:identifier];
        [rows addObject:@[haoge_keyboardtoolbarai_actionTitle(identifier, prefs[@"ActionNames"]), action[@"note"] ?: @""]];
    }
    if (!ids.count) {
        [self haoge_keyboardtoolbarai_showError:@"没有可添加的按钮" message:@"动作目录中的按钮均已添加。"];
        return;
    }
    HaogeKeyboardToolbarAIPrefsChoices *choices = [[HaogeKeyboardToolbarAIPrefsChoices alloc]
        haoge_keyboardtoolbarai_initWithTitle:@"添加按钮" rows:rows selected:NSNotFound
        choose:^BOOL(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index) {
            NSMutableArray *updated = [haoge_keyboardtoolbarai_savedButtons(haoge_keyboardtoolbarai_readPreferences()) mutableCopy];
            if ([updated containsObject:ids[index]]) return YES;
            [updated addObject:ids[index]];
            return [page haoge_keyboardtoolbarai_save:@"Buttons" value:haoge_keyboardtoolbarai_normalizeButtons(updated)];
        }];
    [self haoge_keyboardtoolbarai_push:choices];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        HaogeKeyboardToolbarAIPrefsBindings *bindings = [HaogeKeyboardToolbarAIPrefsBindings new];
        bindings.haoge_keyboardtoolbarai_button = _buttons[path.row];
        [self haoge_keyboardtoolbarai_push:bindings];
    } else if (path.row == 0) {
        [self haoge_keyboardtoolbarai_addButton];
    } else if (path.row == 1) {
        [self haoge_keyboardtoolbarai_push:[HaogeKeyboardToolbarAIPrefsActionNames new]];
    } else {
        [self haoge_keyboardtoolbarai_confirm:@"恢复默认按钮列表？"
            message:@"会恢复默认按钮及其顺序。手势绑定和自定义动作名不受影响。" action:@"恢复" handler:^{
                [self haoge_keyboardtoolbarai_save:@"Buttons" value:haoge_keyboardtoolbarai_defaultButtons()];
                [self haoge_keyboardtoolbarai_reloadButtons];
            }];
    }
}

@end
