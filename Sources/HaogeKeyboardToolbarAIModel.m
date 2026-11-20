#import "HaogeKeyboardToolbarAIModel.h"
// v2 independent implementation using verified v1 recovered algorithms.
// Exact constant data recovered from NSConstantArray at arm64 0x5ee70.

NSArray<NSDictionary *> *haoge_keyboardtoolbarai_actionCatalog(void) {
    return @[
        @{@"id": @"selectAll", @"name": @"全选", @"symbol": @"selection.pin.in.out", @"symbols": @[@"selection.pin.in.out", @"arrow.up.left.and.arrow.down.right"]},
        @{@"id": @"selectAllAndCopy", @"name": @"复制", @"note": @"先全选再复制", @"symbol": @"doc.on.doc"},
        @{@"id": @"paste", @"name": @"粘贴", @"symbol": @"doc.on.clipboard", @"symbols": @[@"doc.on.clipboard", @"arrow.down.doc"]},
        @{@"id": @"showClipboard", @"name": @"剪贴板", @"note": @"需安装 Clipboard 插件", @"symbol": @"list.clipboard", @"symbols": @[@"list.clipboard", @"list.bullet.rectangle", @"doc.text"]},
        @{@"composite": @YES, @"id": @"kt_showAI", @"name": @"AI问答", @"note": @"在 AI 问答设置中配置引擎和 API Key", @"symbol": @"bubble.left.and.bubble.right", @"symbols": @[@"bubble.left.and.bubble.right", @"text.bubble"]},
        @{@"id": @"cut", @"name": @"剪切", @"symbol": @"scissors"},
        @{@"id": @"undo", @"name": @"撤销", @"symbol": @"arrow.uturn.backward"},
        @{@"id": @"clearText", @"name": @"清空", @"symbol": @"trash"},
        @{@"id": @"moveLeft", @"name": @"光标左移", @"symbol": @"arrow.left.circle"},
        @{@"id": @"moveRight", @"name": @"光标右移", @"symbol": @"arrow.right.circle"},
        @{@"id": @"insertNewline", @"name": @"换行", @"symbol": @"arrow.turn.down.left"},
        @{@"id": @"showEmojiKeyboard", @"name": @"表情键盘", @"symbol": @"face.smiling", @"symbols": @[@"face.smiling", @"face.smiling.inverse", @"smiley"]},
        @{@"id": @"done", @"name": @"收起键盘", @"symbol": @"keyboard.chevron.compact.down", @"symbols": @[@"keyboard.chevron.compact.down", @"checkmark.circle"]},
        @{@"composite": @YES, @"id": @"snapperFreeze", @"name": @"Snapper 冻结", @"note": @"需安装 Snapper 4", @"symbol": @"rectangle.and.hand.point.up.left", @"symbols": @[@"rectangle.and.hand.point.up.left", @"camera.viewfinder", @"viewfinder", @"camera"]},
        @{@"composite": @YES, @"id": @"snapperLong", @"name": @"Snapper 长截图", @"note": @"需安装 Snapper 4", @"symbol": @"rectangle.and.hand.point.up.left", @"symbols": @[@"rectangle.and.hand.point.up.left", @"arrow.down.to.line", @"arrow.down.doc"]},
        @{@"composite": @YES, @"id": @"screenshotShell", @"name": @"仅截屏套壳", @"note": @"需装 ScreenShell Pro", @"symbol": @"rectangle.and.hand.point.up.left", @"symbols": @[@"rectangle.and.hand.point.up.left", @"rectangle.on.rectangle", @"square.on.square"]},
        @{@"composite": @YES, @"id": @"screenshotWatermark", @"name": @"仅截图水印", @"note": @"需装 ScreenShell Pro", @"symbol": @"rectangle.and.hand.point.up.left", @"symbols": @[@"rectangle.and.hand.point.up.left", @"drop", @"signature"]},
        @{@"composite": @YES, @"id": @"screenshotBoth", @"name": @"截屏套壳+水印", @"note": @"需装 ScreenShell Pro", @"symbol": @"rectangle.and.hand.point.up.left", @"symbols": @[@"rectangle.and.hand.point.up.left", @"square.on.square", @"rectangle.on.rectangle"]}
    ];
}

// Evidence-backed pure data functions, extracted from +[KTConfig ...] semantics.
// These are renamed integration utilities, not the author's original symbols.

extern NSArray<NSDictionary *> *haoge_keyboardtoolbarai_actionCatalog(void);
static NSString *haoge_keyboardtoolbarai_canonicalAction(NSString *action) { // 0x39f5c
    return [action isEqualToString:@"copyText"]?@"selectAllAndCopy":action;
}
static NSString *haoge_keyboardtoolbarai_gestureKey(NSInteger direction) { // 0x39d50 / 0x39d78
    return direction>=1 && direction<=4?@[@"up",@"down",@"left",@"right"][(NSUInteger)direction-1]:@"tap";
}
NSArray<NSString *> *haoge_keyboardtoolbarai_actionIDs(void) {
    NSMutableArray *ids=[NSMutableArray array];
    for (NSDictionary *item in haoge_keyboardtoolbarai_actionCatalog()) [ids addObject:item[@"id"]];
    return ids;
}
// 0x393ec: keep recognized, canonical, unique identifiers in original order.
NSArray<NSString *> *haoge_keyboardtoolbarai_normalizeButtons(id source) {
    NSMutableArray *result=[NSMutableArray array];
    if (![source isKindOfClass:NSArray.class]) return result;
    NSArray *valid=haoge_keyboardtoolbarai_actionIDs();
    for (id item in source) {
        if (![item isKindOfClass:NSString.class]) continue;
        NSString *identifier=haoge_keyboardtoolbarai_canonicalAction(item);
        if ([valid containsObject:identifier] && ![result containsObject:identifier]) [result addObject:identifier];
    }
    return result;
}
// 0x39abc: default buttons omit entries flagged composite (AI/external actions).
NSArray<NSString *> *haoge_keyboardtoolbarai_defaultButtons(void) {
    NSMutableArray *result=[NSMutableArray array];
    for (NSDictionary *item in haoge_keyboardtoolbarai_actionCatalog())
        if (![item[@"composite"] boolValue]) [result addObject:item[@"id"]];
    return result;
}
// 0x39d78: missing tap defaults to the button's own action; missing swipe is nil.
// IMPORTANT: an explicit empty string disables a binding, rather than restoring it.
NSString *haoge_keyboardtoolbarai_bindingAction(id bindings, NSString *button, NSInteger direction) {
    if (!button.length) return nil;
    id perButton=[bindings isKindOfClass:NSDictionary.class]?bindings[button]:nil;
    id action=[perButton isKindOfClass:NSDictionary.class]?perButton[haoge_keyboardtoolbarai_gestureKey(direction)]:nil;
    if (!action) return direction==0?button:nil;
    if (![action isKindOfClass:NSString.class] || ![action length]) return nil;
    NSString *canonical=haoge_keyboardtoolbarai_canonicalAction(action);
    return [haoge_keyboardtoolbarai_actionIDs() containsObject:canonical]?canonical:nil;
}
// 0x39fb0: nil/empty action writes @"", not removal of the gesture key.
// The caller persists the returned dictionary under ActionBindings.
NSDictionary *haoge_keyboardtoolbarai_storeBinding(id bindings,NSString *button,NSInteger direction,NSString *action) {
    if (!button.length) return [bindings isKindOfClass:NSDictionary.class]?bindings:@{};
    NSMutableDictionary *all=[bindings isKindOfClass:NSDictionary.class]?[bindings mutableCopy]:[NSMutableDictionary dictionary];
    id old=all[button];
    NSMutableDictionary *perButton=[old isKindOfClass:NSDictionary.class]?[old mutableCopy]:[NSMutableDictionary dictionary];
    perButton[haoge_keyboardtoolbarai_gestureKey(direction)]=action.length?action:@"";
    all[button]=perButton;
    return all;
}

// Readable ARC reconstruction of arm64 _haoge_keyboardtoolbarai_normalizeEndpoint, 0x26228.
// Original order matters: trim whitespace -> all trailing '/' -> each known suffix ONCE.

NSString *haoge_keyboardtoolbarai_normalizeEndpoint(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *s=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([s hasSuffix:@"/"]) s=[s substringToIndex:s.length-1];
    // NSConstantArray 0x5ec48, order retained.
    for (NSString *suffix in @[@"/chat/completions",@"/models"])
        if ([s hasSuffix:suffix]) s=[s substringToIndex:s.length-suffix.length];
    NSURLComponents *components=[NSURLComponents componentsWithString:s];
    if (![[components.scheme lowercaseString] isEqualToString:@"https"] || !components.host.length ||
        components.user!=nil || components.password!=nil || components.query!=nil || components.fragment!=nil) return nil;
    return s;
}

// ToolBAR-only color parsing and appearance, not keyboard beautification.
// Recovered from +[KTConfig colorFromHexString:] 0x3af88 and KTApplyBarColors 0x198c8.

UIColor *haoge_keyboardtoolbarai_colorFromHex(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *s=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([s hasPrefix:@"#"]) s=[s substringFromIndex:1];
    NSUInteger count=s.length;
    if (count!=3 && count!=6 && count!=8) return nil;
    unsigned long long v=0;
    if (![[NSScanner scannerWithString:s] scanHexLongLong:&v]) return nil;
    CGFloat r,g,b,a=1;
    if (count==3) { r=((v>>8)&15)/15.0; g=((v>>4)&15)/15.0; b=(v&15)/15.0; }
    else {
        if (count==8) a=((v>>24)&255)/255.0; // AARRGGBB, not RRGGBBAA
        r=((v>>16)&255)/255.0; g=((v>>8)&255)/255.0; b=(v&255)/255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

NSArray<NSDictionary *> *haoge_keyboardtoolbarai_providerPresets(void) { return @[@{@"endpoint":@"https://api.deepseek.com/v1", @"name":@"DeepSeek"}, @{@"endpoint":@"https://dashscope.aliyuncs.com/compatible-mode/v1", @"name":@"通义千问"}, @{@"endpoint":@"https://api.openai.com/v1", @"name":@"OpenAI"}, @{@"endpoint":@"https://api.siliconflow.cn/v1", @"name":@"硅基流动"}, @{@"endpoint":@"https://open.bigmodel.cn/api/paas/v4", @"name":@"智谱"}, @{@"endpoint":@"https://ark.cn-beijing.volces.com/api/v3", @"name":@"豆包"}, @{@"endpoint":@"https://generativelanguage.googleapis.com/v1beta/openai", @"name":@"Gemini"}, @{@"endpoint":@"", @"name":@"自定义"}]; }

static NSArray *haoge_keyboardtoolbarai_defaultPersonas(void) { return @[@{@"id":@"assistant", @"name":@"问答助手", @"prompt":@"请用简洁中文回答问题，先给结论，再补充必要细节。准确，不编造。"}, @{@"id":@"polish", @"name":@"文字润色", @"prompt":@"请润色用户的文字，保留原意，只输出润色后的正文。"}, @{@"id":@"translate", @"name":@"中英翻译", @"prompt":@"请将中文译为英文，将英文译为中文，只输出译文。"}]; }

// New v2 normalization: preserves configured secrets only in memory/storage,
// never logs them; invalid containers cannot reach the network layer.
static NSString *haoge_keyboardtoolbarai_string(id value) {
    return [value isKindOfClass:NSString.class]?value:@"";
}
NSDictionary *haoge_keyboardtoolbarai_normalizeAIConfiguration(id source) {
    NSDictionary *raw=[source isKindOfClass:NSDictionary.class]?source:@{};
    NSMutableArray *profiles=[NSMutableArray array];
    NSMutableSet *profileIDs=[NSMutableSet set];
    id entries=raw[@"profiles"];
    if ([entries isKindOfClass:NSArray.class]) for (id entry in entries) {
        if (profiles.count>=32) break;
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier=haoge_keyboardtoolbarai_string(entry[@"id"]);
        if (!identifier.length || [profileIDs containsObject:identifier]) continue;
        [profileIDs addObject:identifier];
        NSMutableArray *models=[NSMutableArray array];
        id items=entry[@"models"];
        if ([items isKindOfClass:NSArray.class]) for (id model in items) {
            if (models.count>=512) break;
            if ([model isKindOfClass:NSString.class] && [model length] && [model length]<=256 && ![models containsObject:model]) [models addObject:model];
        }
        NSString *model=haoge_keyboardtoolbarai_string(entry[@"model"]);
        if (model.length && model.length<=256 && ![models containsObject:model]) [models insertObject:model atIndex:0];
        if (!model.length) model=models.firstObject?:@"";
        NSString *name=haoge_keyboardtoolbarai_string(entry[@"name"]);
        [profiles addObject:@{@"id":identifier,@"name":name.length?name:@"自定义引擎",
            @"endpoint":haoge_keyboardtoolbarai_string(entry[@"endpoint"]),
            @"key":haoge_keyboardtoolbarai_string(entry[@"key"]),@"model":model,@"models":[models copy]}];
    }
    NSMutableArray *personas=[NSMutableArray array];NSMutableSet *personaIDs=[NSMutableSet set];
    id choices=raw[@"personas"];
    if ([choices isKindOfClass:NSArray.class]) for (id item in choices) {
        if (personas.count>=64) break;
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier=haoge_keyboardtoolbarai_string(item[@"id"]);
        if (!identifier.length || [personaIDs containsObject:identifier]) continue;
        [personaIDs addObject:identifier];
        NSString *name=haoge_keyboardtoolbarai_string(item[@"name"]);
        NSString *prompt=haoge_keyboardtoolbarai_string(item[@"prompt"]);
        if (prompt.length>262144) prompt=[prompt substringToIndex:262144];
        [personas addObject:@{@"id":identifier,@"name":name.length?name:@"自定义人设",@"prompt":prompt}];
    }
    // Missing persona key gets defaults; an explicitly empty array stays empty.
    if (![choices isKindOfClass:NSArray.class]) [personas addObjectsFromArray:haoge_keyboardtoolbarai_defaultPersonas()];
    NSString *selected=haoge_keyboardtoolbarai_string(raw[@"selected"]);
    if (![profileIDs containsObject:selected]) selected=profiles.count?profiles[0][@"id"]:@"";
    NSNumber *stream=[raw[@"stream"] isKindOfClass:NSNumber.class]?@([raw[@"stream"] boolValue]):@YES;
    return @{@"profiles":[profiles copy],@"personas":[personas copy],@"selected":selected,@"stream":stream};
}
