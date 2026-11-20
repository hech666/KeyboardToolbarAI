#import "HaogeKeyboardToolbarAIPrefsControllers.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAIPreferences.h"
#import <math.h>

static NSString *haoge_keyboardtoolbarai_hexForColor(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        if (![color getWhite:&r alpha:&a]) return nil;
        g = b = r;
    }
    unsigned (^byte)(CGFloat) = ^unsigned(CGFloat c) {
        return (unsigned)lround(fmin(1.0, fmax(0.0, c)) * 255.0);
    };
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", byte(a), byte(r), byte(g), byte(b)];
}

static UIView *haoge_keyboardtoolbarai_swatch(UIColor *color) {
    UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    swatch.backgroundColor = color ?: UIColor.clearColor;
    swatch.layer.cornerRadius = 12;
    swatch.layer.borderWidth = 1;
    swatch.layer.borderColor = UIColor.tertiaryLabelColor.CGColor;
    return swatch;
}

@interface HaogeKeyboardToolbarAIPrefsColor : HaogeKeyboardToolbarAIPrefsPage <UIColorPickerViewControllerDelegate>
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setRow:) NSDictionary *haoge_keyboardtoolbarai_row;
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setDraft:) NSString *haoge_keyboardtoolbarai_draft;
@end

@implementation HaogeKeyboardToolbarAIPrefsColor

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.haoge_keyboardtoolbarai_row[@"label"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"选色器支持透明度。颜色按 #AARRGGBB 保存；保存前不会应用。恢复系统外观只清除当前模式的自定义颜色。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.row == 0) {
        NSString *hex = self.haoge_keyboardtoolbarai_draft ?:
            haoge_keyboardtoolbarai_trim(haoge_keyboardtoolbarai_readPreferences()[self.haoge_keyboardtoolbarai_row[@"key"]]);
        UIColor *color = haoge_keyboardtoolbarai_colorFromHex(hex);
        UITableViewCell *cell = haoge_keyboardtoolbarai_cell(@"选择颜色", color ? hex : @"跟随系统", UITableViewCellAccessoryNone);
        cell.accessoryView = haoge_keyboardtoolbarai_swatch(color);
        return cell;
    }
    return haoge_keyboardtoolbarai_cell(path.row == 1 ? @"保存颜色" : @"恢复系统外观",
                                      nil, UITableViewCellAccessoryNone);
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)path {
    return path.row != 1 || self.haoge_keyboardtoolbarai_draft ? path : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSString *key = self.haoge_keyboardtoolbarai_row[@"key"];
    if (path.row == 0) {
        id seed = self.haoge_keyboardtoolbarai_draft ?: haoge_keyboardtoolbarai_readPreferences()[key];
        UIColorPickerViewController *picker = [UIColorPickerViewController new];
        picker.delegate = self;
        picker.supportsAlpha = YES;
        picker.selectedColor = haoge_keyboardtoolbarai_colorFromHex(seed) ?:
            haoge_keyboardtoolbarai_colorFromHex(self.haoge_keyboardtoolbarai_row[@"initialColor"]) ?: UIColor.clearColor;
        [self presentViewController:picker animated:YES completion:nil];
        return;
    }
    NSString *value = path.row == 1 ? self.haoge_keyboardtoolbarai_draft : nil;
    BOOL saved = [self haoge_keyboardtoolbarai_save:key value:value];
    self.haoge_keyboardtoolbarai_draft = nil;
    [tableView reloadData];
    if (saved) [self.navigationController popViewControllerAnimated:YES];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)picker
                  didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    self.haoge_keyboardtoolbarai_draft = haoge_keyboardtoolbarai_hexForColor(color);
    if (!continuously) [self.tableView reloadData];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
    if (self.haoge_keyboardtoolbarai_draft) {
        self.haoge_keyboardtoolbarai_draft = haoge_keyboardtoolbarai_hexForColor(picker.selectedColor);
        [self.tableView reloadData];
    }
}

@end

@implementation HaogeKeyboardToolbarAIPrefsMain {
    NSArray<NSDictionary *> *_rows;
    NSDictionary *_prefs;
    NSString *_section;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:@"HaogeKeyboardToolbarAIRoot" ofType:@"plist"];
    NSDictionary *resource = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    _rows = resource[@"items"];
    _section = resource[@"section"];
    self.parentViewController.title = resource[@"title"] ?: @"键盘工具栏 AI";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _prefs = haoge_keyboardtoolbarai_readPreferences();
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _rows.count; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return _section; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return _rows.count ? nil : @"无法读取设置资源 HaogeKeyboardToolbarAIRoot.plist。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = _rows[path.row];
    NSString *kind = row[@"kind"];
    NSString *key = row[@"key"];
    if ([kind isEqual:@"switch"]) {
        UITableViewCell *cell = haoge_keyboardtoolbarai_cell(row[@"label"], nil, UITableViewCellAccessoryNone);
        UISwitch *toggle = [UISwitch new];
        toggle.tag = path.row;
        id raw = _prefs[key];
        toggle.on = [([raw isKindOfClass:NSNumber.class] ? raw : row[@"default"]) boolValue];
        toggle.accessibilityLabel = row[@"label"];
        [toggle addTarget:self action:@selector(haoge_keyboardtoolbarai_switchChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    NSString *hex = key ? haoge_keyboardtoolbarai_trim(_prefs[key]) : nil;
    UIColor *color = haoge_keyboardtoolbarai_colorFromHex(hex);
    if ([kind isEqual:@"color"]) {
        UITableViewCell *cell = haoge_keyboardtoolbarai_cell(row[@"label"], color ? hex : @"跟随系统", UITableViewCellAccessoryNone);
        cell.accessoryView = haoge_keyboardtoolbarai_swatch(color);
        return cell;
    }
    return haoge_keyboardtoolbarai_cell(row[@"label"], nil, UITableViewCellAccessoryDisclosureIndicator);
}

- (void)haoge_keyboardtoolbarai_switchChanged:(UISwitch *)toggle {
    NSDictionary *row = _rows[toggle.tag];
    NSString *key = row[@"key"];
    BOOL saved = [self haoge_keyboardtoolbarai_save:key value:@(toggle.isOn)];
    _prefs = haoge_keyboardtoolbarai_readPreferences();
    if (!saved) {
        id actual = _prefs[key];
        [toggle setOn:[([actual isKindOfClass:NSNumber.class] ? actual : row[@"default"]) boolValue] animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = _rows[path.row];
    NSString *kind = row[@"kind"];
    if ([kind isEqual:@"color"]) {
        HaogeKeyboardToolbarAIPrefsColor *color = [HaogeKeyboardToolbarAIPrefsColor new];
        color.haoge_keyboardtoolbarai_row = row;
        [self haoge_keyboardtoolbarai_push:color];
    } else if ([kind isEqual:@"buttons"]) {
        [self haoge_keyboardtoolbarai_push:[HaogeKeyboardToolbarAIPrefsButtons new]];
    } else if ([kind isEqual:@"ai"]) {
        [self haoge_keyboardtoolbarai_push:[HaogeKeyboardToolbarAIPrefsAI new]];
    }
}

@end
