#import "HaogeKeyboardToolbarAIPrefsPage.h"
#import "HaogeKeyboardToolbarAIPreferences.h"
#import "HaogeKeyboardToolbarAIModel.h"

NSString *haoge_keyboardtoolbarai_trim(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

NSDictionary *haoge_keyboardtoolbarai_dictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSString *haoge_keyboardtoolbarai_actionTitle(NSString *identifier, id names) {
    NSString *custom = haoge_keyboardtoolbarai_trim(haoge_keyboardtoolbarai_dictionary(names)[identifier]);
    if (custom.length) return custom;
    for (NSDictionary *action in haoge_keyboardtoolbarai_actionCatalog()) {
        if ([action[@"id"] isEqual:identifier]) return action[@"name"] ?: identifier;
    }
    return identifier;
}

UITableViewCell *haoge_keyboardtoolbarai_cell(NSString *title, NSString *detail,
                                              UITableViewCellAccessoryType accessory) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    UIListContentConfiguration *content = [UIListContentConfiguration valueCellConfiguration];
    content.text = title;
    content.secondaryText = detail;
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.numberOfLines = 2;
    cell.contentConfiguration = content;
    cell.accessoryType = accessory;
    return cell;
}

@implementation HaogeKeyboardToolbarAIPrefsPage

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

- (void)haoge_keyboardtoolbarai_showError:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentViewController:alert animated:YES completion:nil];
        }];
    } else {
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)haoge_keyboardtoolbarai_confirm:(NSString *)title message:(NSString *)message
                              action:(NSString *)action handler:(dispatch_block_t)handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:action style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *item) { handler(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)haoge_keyboardtoolbarai_save:(NSString *)key value:(id)value {
    id old = haoge_keyboardtoolbarai_readPreferences()[key];
    if (old == value || [old isEqual:value]) return YES;
    NSError *error = nil;
    BOOL wrote = haoge_keyboardtoolbarai_writePreference(key, value, &error);
    id actual = haoge_keyboardtoolbarai_readPreferences()[key];
    if (wrote && (actual == value || [actual isEqual:value])) return YES;
    [self haoge_keyboardtoolbarai_showError:@"设置未保存"
                                    message:error.localizedDescription ?: @"写入后回读的值与提交值不一致，请检查偏好文件。"];
    return NO;
}

- (void)haoge_keyboardtoolbarai_push:(UIViewController *)controller {
    UINavigationController *navigation = self.navigationController ?: self.parentViewController.navigationController;
    if (navigation) {
        [navigation pushViewController:controller animated:YES];
    } else {
        [self haoge_keyboardtoolbarai_showError:@"无法打开页面" message:@"设置宿主未提供导航控制器。"];
    }
}

@end

@implementation HaogeKeyboardToolbarAIPrefsChoices {
    NSArray<NSArray<NSString *> *> *_rows;
    NSInteger _selected;
    HaogeKeyboardToolbarAIPrefsChoiceHandler _choose;
}

- (instancetype)haoge_keyboardtoolbarai_initWithTitle:(NSString *)title
                                                 rows:(NSArray<NSArray<NSString *> *> *)rows
                                             selected:(NSInteger)selected
                                               choose:(HaogeKeyboardToolbarAIPrefsChoiceHandler)choose {
    self = [super init];
    if (self) {
        self.title = title;
        _rows = [rows copy];
        _selected = selected;
        _choose = [choose copy];
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSArray<NSString *> *option = _rows[path.row];
    return haoge_keyboardtoolbarai_cell(option.firstObject, option.count > 1 ? option[1] : nil,
        path.row == _selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
}

- (void)haoge_keyboardtoolbarai_showSelection:(NSInteger)selected {
    _selected = selected;
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (_choose(self, (NSUInteger)path.row)) [self.navigationController popViewControllerAnimated:YES];
}

@end
