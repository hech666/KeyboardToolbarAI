#import "HaogeKeyboardToolbarAIPrefsControllers.h"
#import "HaogeKeyboardToolbarAIPrefsAIEditors.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAIPreferences.h"

static NSDictionary *haoge_keyboardtoolbarai_savedAI(void) {
    return haoge_keyboardtoolbarai_normalizeAIConfiguration(haoge_keyboardtoolbarai_readPreferences()[@"AIConfiguration"]);
}

static NSUInteger haoge_keyboardtoolbarai_recordIndex(NSArray<NSDictionary *> *records, NSString *identifier) {
    for (NSUInteger index = 0; index < records.count; index++) {
        if ([records[index][@"id"] isEqual:identifier]) return index;
    }
    return NSNotFound;
}

static BOOL haoge_keyboardtoolbarai_commitRecord(HaogeKeyboardToolbarAIPrefsPage *editor,
                                                 NSDictionary *record, NSString *collection, BOOL existing) {
    NSMutableDictionary *config = [haoge_keyboardtoolbarai_savedAI() mutableCopy];
    NSMutableArray<NSDictionary *> *records = [config[collection] mutableCopy];
    NSString *identifier = record[@"id"];
    NSUInteger index = haoge_keyboardtoolbarai_recordIndex(records, identifier);
    if (existing && index == NSNotFound) {
        [editor haoge_keyboardtoolbarai_showError:@"未保存" message:@"该条目已被删除。请返回列表刷新后重试。"];
        return NO;
    }
    NSUInteger limit = [collection isEqual:@"profiles"] ? 32 : 64;
    if (index == NSNotFound && records.count >= limit) {
        [editor haoge_keyboardtoolbarai_showError:@"未保存" message:[NSString stringWithFormat:@"%@最多 %lu 项，请先删除不再使用的条目。",
            [collection isEqual:@"profiles"] ? @"引擎" : @"人设", (unsigned long)limit]];
        return NO;
    }
    if (index != NSNotFound) records[index] = record;
    else [records addObject:record];
    config[collection] = records;
    if ([collection isEqual:@"profiles"] && ![config[@"selected"] length]) config[@"selected"] = identifier;
    NSDictionary *normalized = haoge_keyboardtoolbarai_normalizeAIConfiguration(config);
    NSArray *normalizedRecords = normalized[collection];
    NSUInteger normalizedIndex = haoge_keyboardtoolbarai_recordIndex(normalizedRecords, identifier);
    if (normalizedIndex == NSNotFound || ![normalizedRecords[normalizedIndex] isEqual:record]) {
        [editor haoge_keyboardtoolbarai_showError:@"未保存" message:@"共享模型未保留提交的内容，请检查字段格式。"];
        return NO;
    }
    return [editor haoge_keyboardtoolbarai_save:@"AIConfiguration" value:normalized];
}

@implementation HaogeKeyboardToolbarAIPrefsAI {
    NSDictionary *_configuration;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI 问答";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.tableView.allowsSelectionDuringEditing = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self haoge_keyboardtoolbarai_reloadAI];
}

- (void)haoge_keyboardtoolbarai_reloadAI {
    _configuration = haoge_keyboardtoolbarai_savedAI();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    return [_configuration[section == 1 ? @"profiles" : @"personas"] count] + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"对话设置", @"AI 引擎", @"人设"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"默认引擎用于打开对话时的初始选择；流式开关保存到 AIConfiguration。";
    if (section == 1) return @"点击编辑；向左轻扫或点编辑可删除。服务商、接口、Key、模型均在引擎页配置。本页不发起网络请求。";
    return @"点击编辑名称和 Prompt；向左轻扫或点编辑可删除。人设可全部删除。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0 && path.row == 0) {
        NSString *selected = _configuration[@"selected"];
        NSString *name = @"未选择";
        for (NSDictionary *profile in _configuration[@"profiles"]) {
            if ([profile[@"id"] isEqual:selected]) name = profile[@"name"];
        }
        return haoge_keyboardtoolbarai_cell(@"默认引擎", name, UITableViewCellAccessoryDisclosureIndicator);
    }
    if (path.section == 0) {
        UITableViewCell *cell = haoge_keyboardtoolbarai_cell(@"流式输出", nil, UITableViewCellAccessoryNone);
        UISwitch *toggle = [UISwitch new];
        toggle.on = [_configuration[@"stream"] boolValue];
        toggle.accessibilityLabel = @"流式输出";
        [toggle addTarget:self action:@selector(haoge_keyboardtoolbarai_streamChanged:)
            forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    BOOL profiles = path.section == 1;
    NSArray<NSDictionary *> *records = _configuration[profiles ? @"profiles" : @"personas"];
    if ((NSUInteger)path.row == records.count) return haoge_keyboardtoolbarai_cell(profiles ? @"添加引擎" : @"添加人设", nil,
                                                                                  UITableViewCellAccessoryDisclosureIndicator);
    NSDictionary *record = records[path.row];
    NSString *detail = profiles ? record[@"model"] : record[@"prompt"];
    if (profiles && [record[@"id"] isEqual:_configuration[@"selected"]]) detail = [@"默认 · " stringByAppendingString:detail ?: @""];
    return haoge_keyboardtoolbarai_cell(record[@"name"], detail, UITableViewCellAccessoryDisclosureIndicator);
}

- (void)haoge_keyboardtoolbarai_streamChanged:(UISwitch *)toggle {
    NSMutableDictionary *config = [haoge_keyboardtoolbarai_savedAI() mutableCopy];
    config[@"stream"] = @(toggle.on);
    [self haoge_keyboardtoolbarai_save:@"AIConfiguration" value:haoge_keyboardtoolbarai_normalizeAIConfiguration(config)];
    _configuration = haoge_keyboardtoolbarai_savedAI();
    [toggle setOn:[_configuration[@"stream"] boolValue] animated:YES];
}

- (void)haoge_keyboardtoolbarai_chooseSelected {
    NSDictionary *config = haoge_keyboardtoolbarai_savedAI();
    NSArray<NSDictionary *> *profiles = config[@"profiles"];
    if (!profiles.count) {
        [self haoge_keyboardtoolbarai_showError:@"没有引擎" message:@"请先添加并保存一个 AI 引擎。"];
        return;
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *profile in profiles) [rows addObject:@[profile[@"name"], profile[@"model"] ?: @""]];
    NSInteger selected = haoge_keyboardtoolbarai_recordIndex(profiles, config[@"selected"]);
    HaogeKeyboardToolbarAIPrefsChoices *choices = [[HaogeKeyboardToolbarAIPrefsChoices alloc]
        haoge_keyboardtoolbarai_initWithTitle:@"默认引擎" rows:rows selected:selected
        choose:^BOOL(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index) {
            NSString *identifier = profiles[index][@"id"];
            NSMutableDictionary *latest = [haoge_keyboardtoolbarai_savedAI() mutableCopy];
            NSArray *current = latest[@"profiles"];
            if (haoge_keyboardtoolbarai_recordIndex(current, identifier) == NSNotFound) {
                [page haoge_keyboardtoolbarai_showError:@"未保存" message:@"引擎已被删除，请返回列表刷新。"];
                return NO;
            }
            latest[@"selected"] = identifier;
            if ([page haoge_keyboardtoolbarai_save:@"AIConfiguration" value:haoge_keyboardtoolbarai_normalizeAIConfiguration(latest)]) return YES;
            NSDictionary *actual = haoge_keyboardtoolbarai_savedAI();
            [page haoge_keyboardtoolbarai_showSelection:haoge_keyboardtoolbarai_recordIndex(profiles, actual[@"selected"])];
            return NO;
        }];
    [self haoge_keyboardtoolbarai_push:choices];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        if (path.row == 0) [self haoge_keyboardtoolbarai_chooseSelected];
        return;
    }
    NSString *collection = path.section == 1 ? @"profiles" : @"personas";
    NSArray<NSDictionary *> *records = _configuration[collection];
    BOOL existing = (NSUInteger)path.row < records.count;
    NSDictionary *record = existing ? records[path.row] : @{ @"id": NSUUID.UUID.UUIDString };
    HaogeKeyboardToolbarAIPrefsRecordCommit commit = ^BOOL(HaogeKeyboardToolbarAIPrefsPage *editor, NSDictionary *updated) {
        return haoge_keyboardtoolbarai_commitRecord(editor, updated, collection, existing);
    };
    if (path.section == 1) {
        HaogeKeyboardToolbarAIPrefsProfileEditor *editor = [HaogeKeyboardToolbarAIPrefsProfileEditor new];
        editor.haoge_keyboardtoolbarai_record = record;
        editor.haoge_keyboardtoolbarai_commit = commit;
        [self haoge_keyboardtoolbarai_push:editor];
    } else {
        HaogeKeyboardToolbarAIPrefsPersonaEditor *editor = [HaogeKeyboardToolbarAIPrefsPersonaEditor new];
        editor.haoge_keyboardtoolbarai_record = record;
        editor.haoge_keyboardtoolbarai_commit = commit;
        [self haoge_keyboardtoolbarai_push:editor];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) return NO;
    return (NSUInteger)path.row < [_configuration[path.section == 1 ? @"profiles" : @"personas"] count];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete || path.section == 0) return;
    NSString *collection = path.section == 1 ? @"profiles" : @"personas";
    NSDictionary *record = _configuration[collection][path.row];
    NSString *identifier = record[@"id"];
    NSString *message = path.section == 1 ? @"删除后不能恢复。若删除默认引擎，将选用剩余首个引擎。" : @"删除后不能恢复。";
    [self haoge_keyboardtoolbarai_confirm:[NSString stringWithFormat:@"删除「%@」？", record[@"name"]]
        message:message action:@"删除" handler:^{
            NSMutableDictionary *latest = [haoge_keyboardtoolbarai_savedAI() mutableCopy];
            NSMutableArray<NSDictionary *> *records = [latest[collection] mutableCopy];
            NSUInteger index = haoge_keyboardtoolbarai_recordIndex(records, identifier);
            if (index == NSNotFound) {
                [self haoge_keyboardtoolbarai_showError:@"条目已不存在" message:@"列表已重新读取。"];
                [self haoge_keyboardtoolbarai_reloadAI];
                return;
            }
            [records removeObjectAtIndex:index];
            latest[collection] = records;
            if ([collection isEqual:@"profiles"] && [latest[@"selected"] isEqual:identifier]) {
                latest[@"selected"] = records.firstObject[@"id"] ?: @"";
            }
            [self haoge_keyboardtoolbarai_save:@"AIConfiguration" value:haoge_keyboardtoolbarai_normalizeAIConfiguration(latest)];
            [self haoge_keyboardtoolbarai_reloadAI];
        }];
}

@end
