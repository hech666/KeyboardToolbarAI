#import "HaogeKeyboardToolbarAIPrefsAIEditors.h"
#import "HaogeKeyboardToolbarAIModel.h"

static UITextField *haoge_keyboardtoolbarai_field(NSString *text, NSString *placeholder, BOOL verbatim) {
    UITextField *field = [UITextField new];
    field.text = text ?: @"";
    field.placeholder = placeholder;
    field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    field.adjustsFontForContentSizeCategory = YES;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    if (verbatim) {
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.spellCheckingType = UITextSpellCheckingTypeNo;
        field.smartQuotesType = UITextSmartQuotesTypeNo;
        field.smartDashesType = UITextSmartDashesTypeNo;
    }
    return field;
}

static UITextView *haoge_keyboardtoolbarai_textView(NSString *text) {
    UITextView *view = [UITextView new];
    view.text = text ?: @"";
    view.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    view.adjustsFontForContentSizeCategory = YES;
    view.backgroundColor = UIColor.clearColor;
    view.autocapitalizationType = UITextAutocapitalizationTypeNone;
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    view.smartQuotesType = UITextSmartQuotesTypeNo;
    view.smartDashesType = UITextSmartDashesTypeNo;
    return view;
}

static UITableViewCell *haoge_keyboardtoolbarai_editorCell(UIView *view) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:view];
    UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6],
        [view.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6]
    ]];
    return cell;
}

static NSArray<NSString *> *haoge_keyboardtoolbarai_manualModels(NSString *text) {
    NSMutableArray *models = [NSMutableArray array];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@",\n\r，"];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:separators]) {
        NSString *model = haoge_keyboardtoolbarai_trim(line);
        if (model.length && ![models containsObject:model]) [models addObject:model];
    }
    return models;
}

@implementation HaogeKeyboardToolbarAIPrefsProfileEditor {
    UITextField *_name;
    UITextField *_endpoint;
    UITextField *_key;
    UITextField *_model;
    UITextView *_models;
    NSString *_provider;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI 引擎";
    NSDictionary *record = self.haoge_keyboardtoolbarai_record;
    _name = haoge_keyboardtoolbarai_field(haoge_keyboardtoolbarai_trim(record[@"name"]), @"引擎名称", NO);
    _endpoint = haoge_keyboardtoolbarai_field(haoge_keyboardtoolbarai_trim(record[@"endpoint"]), @"https://example.com/v1", YES);
    _endpoint.keyboardType = UIKeyboardTypeURL;
    _key = haoge_keyboardtoolbarai_field(haoge_keyboardtoolbarai_trim(record[@"key"]), @"API Key（仅保存在本机偏好文件）", YES);
    _key.secureTextEntry = YES;
    _key.textContentType = @"";
    _model = haoge_keyboardtoolbarai_field(haoge_keyboardtoolbarai_trim(record[@"model"]), @"当前模型 ID", YES);
    NSArray *models = [record[@"models"] isKindOfClass:NSArray.class] ? record[@"models"] : @[];
    _models = haoge_keyboardtoolbarai_textView([models componentsJoinedByString:@"\n"]);
    _provider = @"自定义";
    for (NSDictionary *preset in haoge_keyboardtoolbarai_providerPresets()) {
        if ([preset[@"endpoint"] length] && [preset[@"endpoint"] isEqual:_endpoint.text]) _provider = preset[@"name"];
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
        style:UIBarButtonItemStyleDone target:self action:@selector(haoge_keyboardtoolbarai_saveProfile)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 7; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 3 || section == 4 ? 2 : 1; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"服务商预设", @"名称", @"HTTPS 接口地址", @"API Key", @"当前模型", @"模型列表（手动输入）", @"保存"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) return @"填写兼容 Chat Completions 的 HTTPS 基础地址。不能包含账户、密码、查询参数或片段。保存时会规范化已知接口后缀。";
    if (section == 3) return @"Key 不上传、不记录日志。偏好文件不是钥匙串；请妥善保管设备和备份。";
    if (section == 5) return @"用英文逗号、中文逗号或换行分隔模型 ID。可直接输入当前模型；保存时会补进列表。本页不发送网络请求。";
    if (section == 6) return @"只有点击保存才写入。返回而未保存会丢弃草稿。";
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return path.section == 5 ? 150 : MAX(50, [UIFont preferredFontForTextStyle:UIFontTextStyleBody].lineHeight + 24);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) return haoge_keyboardtoolbarai_cell(@"选择服务商", _provider, UITableViewCellAccessoryDisclosureIndicator);
    if (path.section == 1) return haoge_keyboardtoolbarai_editorCell(_name);
    if (path.section == 2) return haoge_keyboardtoolbarai_editorCell(_endpoint);
    if (path.section == 3) {
        if (path.row == 0) return haoge_keyboardtoolbarai_editorCell(_key);
        return haoge_keyboardtoolbarai_cell(_key.secureTextEntry ? @"显示 API Key" : @"隐藏 API Key", nil, UITableViewCellAccessoryNone);
    }
    if (path.section == 4) {
        if (path.row == 0) return haoge_keyboardtoolbarai_editorCell(_model);
        return haoge_keyboardtoolbarai_cell(@"从手动模型列表选择", nil, UITableViewCellAccessoryDisclosureIndicator);
    }
    if (path.section == 5) return haoge_keyboardtoolbarai_editorCell(_models);
    return haoge_keyboardtoolbarai_cell(@"保存引擎", nil, UITableViewCellAccessoryNone);
}

- (void)haoge_keyboardtoolbarai_chooseProvider {
    [self.view endEditing:YES];
    NSArray<NSDictionary *> *presets = haoge_keyboardtoolbarai_providerPresets();
    NSMutableArray *rows = [NSMutableArray array];
    NSInteger selected = NSNotFound;
    for (NSDictionary *preset in presets) {
        if ([preset[@"name"] isEqual:_provider]) selected = rows.count;
        [rows addObject:@[preset[@"name"], preset[@"endpoint"]]];
    }
    __weak typeof(self) weakSelf = self;
    HaogeKeyboardToolbarAIPrefsChoices *choices = [[HaogeKeyboardToolbarAIPrefsChoices alloc]
        haoge_keyboardtoolbarai_initWithTitle:@"服务商预设" rows:rows selected:selected
        choose:^BOOL(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index) {
            HaogeKeyboardToolbarAIPrefsProfileEditor *owner = weakSelf;
            if (!owner) return YES;
            NSDictionary *preset = presets[index];
            NSString *newEndpoint = preset[@"endpoint"];
            owner->_provider = preset[@"name"];
            if (!owner->_name.text.length) owner->_name.text = preset[@"name"];
            // Custom preserves the existing draft address, enabling edits of a preset.
            if (newEndpoint.length) owner->_endpoint.text = newEndpoint;
            [owner.tableView reloadData];
            return YES;
        }];
    [self haoge_keyboardtoolbarai_push:choices];
}

- (void)haoge_keyboardtoolbarai_chooseModel {
    [self.view endEditing:YES];
    NSMutableArray<NSString *> *models = [haoge_keyboardtoolbarai_manualModels(_models.text) mutableCopy];
    NSString *current = haoge_keyboardtoolbarai_trim(_model.text);
    if (current.length && ![models containsObject:current]) [models addObject:current];
    if (!models.count) {
        [self haoge_keyboardtoolbarai_showError:@"模型列表为空" message:@"请先在模型列表或当前模型字段手动输入模型 ID。"];
        return;
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *model in models) [rows addObject:@[model]];
    __weak typeof(self) weakSelf = self;
    HaogeKeyboardToolbarAIPrefsChoices *choices = [[HaogeKeyboardToolbarAIPrefsChoices alloc]
        haoge_keyboardtoolbarai_initWithTitle:@"当前模型" rows:rows selected:[models indexOfObject:current]
        choose:^BOOL(HaogeKeyboardToolbarAIPrefsChoices *page, NSUInteger index) {
            HaogeKeyboardToolbarAIPrefsProfileEditor *owner = weakSelf;
            if (owner) owner->_model.text = models[index];
            return YES;
        }];
    [self haoge_keyboardtoolbarai_push:choices];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) [self haoge_keyboardtoolbarai_chooseProvider];
    else if (path.section == 3 && path.row == 1) {
        _key.secureTextEntry = !_key.secureTextEntry;
        [tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == 4 && path.row == 1) [self haoge_keyboardtoolbarai_chooseModel];
    else if (path.section == 6) [self haoge_keyboardtoolbarai_saveProfile];
}

- (void)haoge_keyboardtoolbarai_saveProfile {
    [self.view endEditing:YES];
    NSString *name = haoge_keyboardtoolbarai_trim(_name.text);
    NSString *endpoint = haoge_keyboardtoolbarai_normalizeEndpoint(_endpoint.text);
    NSString *key = haoge_keyboardtoolbarai_trim(_key.text);
    NSString *model = haoge_keyboardtoolbarai_trim(_model.text);
    if (!name.length || !endpoint.length || !key.length || !model.length) {
        NSString *message = !endpoint.length ? @"接口地址必须是有效的 HTTPS 基础地址，且不能含账户、密码、查询参数或片段。"
            : @"请填写名称、API Key 和当前模型。";
        [self haoge_keyboardtoolbarai_showError:@"引擎未保存" message:message];
        return;
    }
    NSMutableArray *models = [haoge_keyboardtoolbarai_manualModels(_models.text) mutableCopy];
    if (![models containsObject:model]) [models addObject:model];
    BOOL valid = models.count <= 512;
    for (NSString *identifier in models) if (identifier.length > 256) valid = NO;
    if (!valid) {
        [self haoge_keyboardtoolbarai_showError:@"引擎未保存" message:@"模型最多 512 项，每个模型 ID 最多 256 个 UTF-16 字符。"];
        return;
    }
    NSMutableDictionary *record = [self.haoge_keyboardtoolbarai_record mutableCopy] ?: [NSMutableDictionary dictionary];
    record[@"name"] = name;
    record[@"endpoint"] = endpoint;
    record[@"key"] = key;
    record[@"model"] = model;
    record[@"models"] = models;
    if (!haoge_keyboardtoolbarai_trim(record[@"id"]).length) record[@"id"] = NSUUID.UUID.UUIDString;
    if (self.haoge_keyboardtoolbarai_commit && self.haoge_keyboardtoolbarai_commit(self, record)) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end

@implementation HaogeKeyboardToolbarAIPrefsPersonaEditor {
    UITextField *_name;
    UITextView *_prompt;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI 人设";
    _name = haoge_keyboardtoolbarai_field(haoge_keyboardtoolbarai_trim(self.haoge_keyboardtoolbarai_record[@"name"]), @"人设名称", NO);
    _prompt = haoge_keyboardtoolbarai_textView(haoge_keyboardtoolbarai_trim(self.haoge_keyboardtoolbarai_record[@"prompt"]));
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
        style:UIBarButtonItemStyleDone target:self action:@selector(haoge_keyboardtoolbarai_savePersona)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"名称", @"系统提示词（Prompt）", @"保存"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 1 ? @"作为 AI 对话的系统提示词；可输入多行。只有点击保存才应用，返回会丢弃草稿。" : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path {
    return path.section == 1 ? 260 : MAX(50, [UIFont preferredFontForTextStyle:UIFontTextStyleBody].lineHeight + 24);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) return haoge_keyboardtoolbarai_editorCell(_name);
    if (path.section == 1) return haoge_keyboardtoolbarai_editorCell(_prompt);
    return haoge_keyboardtoolbarai_cell(@"保存人设", nil, UITableViewCellAccessoryNone);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 2) [self haoge_keyboardtoolbarai_savePersona];
}

- (void)haoge_keyboardtoolbarai_savePersona {
    [self.view endEditing:YES];
    NSString *name = haoge_keyboardtoolbarai_trim(_name.text);
    NSString *prompt = haoge_keyboardtoolbarai_trim(_prompt.text);
    if (!name.length || !prompt.length || prompt.length > 262144) {
        [self haoge_keyboardtoolbarai_showError:@"人设未保存"
            message:prompt.length > 262144 ? @"Prompt 不能超过 262144 个 UTF-16 字符。" : @"名称和 Prompt 都不能为空。"];
        return;
    }
    NSMutableDictionary *record = [self.haoge_keyboardtoolbarai_record mutableCopy] ?: [NSMutableDictionary dictionary];
    record[@"name"] = name;
    record[@"prompt"] = prompt;
    if (!haoge_keyboardtoolbarai_trim(record[@"id"]).length) record[@"id"] = NSUUID.UUID.UUIDString;
    if (self.haoge_keyboardtoolbarai_commit && self.haoge_keyboardtoolbarai_commit(self, record)) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
