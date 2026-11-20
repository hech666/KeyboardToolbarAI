#import "HaogeKeyboardToolbarAIChat.h"
#import "HaogeKeyboardToolbarAIConfig.h"
#import "HaogeKeyboardToolbarAIModel.h"
#import "HaogeKeyboardToolbarAINetwork.h"
#import <PhotosUI/PhotosUI.h>
#import <math.h>

// Newly implemented source. Plain selectable text is intentional, not a Markdown renderer.
static NSString *haoge_keyboardtoolbarai_string(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}
static UIResponder *haoge_keyboardtoolbarai_firstResponder(UIView *view) {
    if (view.isFirstResponder) return view;
    for (UIView *child in view.subviews) {
        UIResponder *found = haoge_keyboardtoolbarai_firstResponder(child);
        if (found) return found;
    }
    return nil;
}
static UIButton *haoge_keyboardtoolbarai_button(NSString *title, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
static NSData *haoge_keyboardtoolbarai_jpeg(UIImage *image) {
    if (!image || image.size.width < 1 || image.size.height < 1) return nil;
    CGFloat scale = MIN(1., 1280. / MAX(image.size.width, image.size.height));
    for (NSUInteger pass = 0; pass < 5; pass++) {
        CGSize size = CGSizeMake(MAX(1, floor(image.size.width * scale)), MAX(1, floor(image.size.height * scale)));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.scale = 1; format.opaque = YES;
        UIImage *small = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format]
            imageWithActions:^(UIGraphicsImageRendererContext *context) {
                [UIColor.whiteColor setFill]; UIRectFill((CGRect){CGPointZero, size});
                [image drawInRect:(CGRect){CGPointZero, size}];
            }];
        for (NSNumber *quality in @[@0.78, @0.58, @0.38]) {
            NSData *data = UIImageJPEGRepresentation(small, quality.doubleValue);
            if (data.length && data.length <= 512 * 1024) return data;
        }
        scale *= 0.7;
    }
    return nil;
}

@interface HaogeKeyboardToolbarAIChatCell : UITableViewCell {
    UILabel *_role;
    UITextView *_body;
    UIStackView *_images;
    UIStackView *_actions;
    dispatch_block_t _copyAction;
    dispatch_block_t _insertAction;
}
- (void)haoge_keyboardtoolbarai_setMessage:(NSDictionary *)message copy:(dispatch_block_t)copyAction insert:(dispatch_block_t)insertAction;
@end

@implementation HaogeKeyboardToolbarAIChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        _role = [UILabel new]; _role.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _role.textColor = UIColor.secondaryLabelColor;
        _body = [UITextView new]; _body.editable = NO; _body.selectable = YES;
        _body.scrollEnabled = NO; _body.backgroundColor = UIColor.clearColor;
        _body.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _body.adjustsFontForContentSizeCategory = YES;
        _body.textContainerInset = UIEdgeInsetsZero; _body.textContainer.lineFragmentPadding = 0;
        _images = [UIStackView new]; _images.spacing = 6;
        _images.alignment = UIStackViewAlignmentLeading;
        UIButton *copy = haoge_keyboardtoolbarai_button(@"复制", self, @selector(haoge_keyboardtoolbarai_copy));
        UIButton *insert = haoge_keyboardtoolbarai_button(@"插入原输入框", self, @selector(haoge_keyboardtoolbarai_insert));
        _actions = [[UIStackView alloc] initWithArrangedSubviews:@[copy, insert]];
        _actions.spacing = 18; _actions.alignment = UIStackViewAlignmentLeading;
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_role, _body, _images, _actions]];
        stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 5;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12]]];
    }
    return self;
}
- (void)haoge_keyboardtoolbarai_setMessage:(NSDictionary *)message copy:(dispatch_block_t)copyAction insert:(dispatch_block_t)insertAction {
    NSString *role = message[@"role"], *state = message[@"state"], *text = message[@"text"] ?: @"";
    BOOL assistant = [role isEqualToString:@"assistant"];
    NSString *status = [state isEqualToString:@"pending"] ? @" · 生成中" :
        ([state isEqualToString:@"stopped"] ? @" · 已停止" : ([state isEqualToString:@"error"] ? @" · 失败" : @""));
    _role.text = [(assistant ? @"AI" : @"你") stringByAppendingString:status];
    _body.text = text.length ? text : (assistant ? @"…" : @"[图片]");
    _copyAction = [copyAction copy]; _insertAction = [insertAction copy];
    _actions.hidden = !assistant || !text.length;
    for (UIView *view in [_images.arrangedSubviews copy]) { [_images removeArrangedSubview:view]; [view removeFromSuperview]; }
    for (NSData *data in message[@"images"]) {
        UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage imageWithData:data]];
        view.contentMode = UIViewContentModeScaleAspectFill; view.clipsToBounds = YES;
        [_images addArrangedSubview:view];
        [NSLayoutConstraint activateConstraints:@[[view.widthAnchor constraintEqualToConstant:54], [view.heightAnchor constraintEqualToConstant:54]]];
    }
    [_images addArrangedSubview:[UIView new]]; // Flexible trailing space keeps fixed thumbnails satisfiable.
    _images.hidden = ![message[@"images"] count];
}
- (void)haoge_keyboardtoolbarai_copy { if (_copyAction) _copyAction(); }
- (void)haoge_keyboardtoolbarai_insert { if (_insertAction) _insertAction(); }
@end

@interface HaogeKeyboardToolbarAIChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate> {
    __weak id<UITextInput> _originalInput;
    __weak UIWindow *_originalWindow;
    BOOL _restoreFocus, _closing, _busy, _loadingModels, _picking;
    NSUInteger _generation, _modelsGeneration, _attachmentGeneration;
    dispatch_block_t _cancel, _modelsCancel;
    NSDictionary *_configuration, *_profile, *_persona;
    NSString *_model;
    NSMutableDictionary *_modelCache, *_modelChoices;
    NSMutableArray<NSMutableDictionary *> *_messages;
    NSMutableArray<NSData *> *_attachments;
    NSMutableArray<NSProgress *> *_imageLoads;
    NSMutableDictionary *_activeReply;
    UIView *_card;
    UITableView *_table;
    UITextView *_input;
    UILabel *_status;
    UIStackView *_attachmentBar;
    UIButton *_profileButton, *_modelButton, *_personaButton, *_send, *_retry, *_photo, *_paste;
    NSLayoutConstraint *_inputHeight, *_cardBottom;
}
- (instancetype)haoge_keyboardtoolbarai_initWithInput:(id<UITextInput>)input __attribute__((objc_method_family(init)));
- (BOOL)haoge_keyboardtoolbarai_contains:(UIResponder *)responder;
- (BOOL)haoge_keyboardtoolbarai_focused;
- (NSArray<NSString *> *)haoge_keyboardtoolbarai_availableModels;
- (void)haoge_keyboardtoolbarai_close;
@end
static HaogeKeyboardToolbarAIChatViewController *haoge_keyboardtoolbarai_panel;

@implementation HaogeKeyboardToolbarAIChatViewController
- (instancetype)haoge_keyboardtoolbarai_initWithInput:(id<UITextInput>)input {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _originalInput = input;
        _originalWindow = [(UIView *)input window];
        _restoreFocus = [(UIResponder *)input isFirstResponder];
        _messages = [NSMutableArray new]; _attachments = [NSMutableArray new];
        _imageLoads = [NSMutableArray new]; _modelCache = [NSMutableDictionary new];
        _modelChoices = [NSMutableDictionary new];
        id raw = [[HaogeKeyboardToolbarAIConfig haoge_keyboardtoolbarai_shared] haoge_keyboardtoolbarai_valueForKey:@"AIConfiguration" defaultValue:@{}];
        _configuration = haoge_keyboardtoolbarai_normalizeAIConfiguration(raw);
        NSArray *profiles = _configuration[@"profiles"];
        NSString *selected = haoge_keyboardtoolbarai_string(_configuration[@"selected"]);
        _profile = profiles.firstObject;
        for (NSDictionary *profile in profiles) if ([profile[@"id"] isEqual:selected]) _profile = profile;
        _model = haoge_keyboardtoolbarai_string(_profile[@"model"]);
        if (!_model.length) _model = [self haoge_keyboardtoolbarai_availableModels].firstObject ?: @"";
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    UIButton *outside = [UIButton buttonWithType:UIButtonTypeCustom];
    outside.frame = self.view.bounds; outside.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    outside.accessibilityLabel = @"关闭 AI 聊天";
    [outside addTarget:self action:@selector(haoge_keyboardtoolbarai_close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:outside];
    _card = [UIView new]; _card.backgroundColor = UIColor.systemBackgroundColor;
    _card.layer.cornerRadius = 16; _card.clipsToBounds = YES;
    _card.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:_card];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    _cardBottom = [_card.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8];
    NSLayoutConstraint *height = [_card.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.91];
    height.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[_cardBottom, height,
        [_card.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:8],
        [_card.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_card.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:8],
        [_card.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-8],
        [_card.widthAnchor constraintLessThanOrEqualToConstant:680]]];
    NSLayoutConstraint *width = [_card.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-16];
    width.priority = UILayoutPriorityDefaultHigh; width.active = YES;
    UILabel *title = [UILabel new]; title.text = @"AI 聊天 · 下拉标题可关闭";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    UIButton *close = haoge_keyboardtoolbarai_button(@"关闭", self, @selector(haoge_keyboardtoolbarai_close));
    UIButton *clear = haoge_keyboardtoolbarai_button(@"清空", self, @selector(haoge_keyboardtoolbarai_clear));
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[title, clear, close]]; header.spacing = 12;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(haoge_keyboardtoolbarai_pan:)];
    [header addGestureRecognizer:pan];
    _profileButton = haoge_keyboardtoolbarai_button(@"服务", self, @selector(haoge_keyboardtoolbarai_profiles));
    _modelButton = haoge_keyboardtoolbarai_button(@"模型", self, @selector(haoge_keyboardtoolbarai_models));
    _personaButton = haoge_keyboardtoolbarai_button(@"角色", self, @selector(haoge_keyboardtoolbarai_personas));
    UIStackView *choices = [[UIStackView alloc] initWithArrangedSubviews:@[_profileButton, _modelButton, _personaButton]];
    choices.distribution = UIStackViewDistributionFillEqually; choices.spacing = 4;
    for (UIButton *button in choices.arrangedSubviews) button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self; _table.delegate = self; _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.rowHeight = UITableViewAutomaticDimension; _table.estimatedRowHeight = 100;
    _table.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_table registerClass:HaogeKeyboardToolbarAIChatCell.class forCellReuseIdentifier:@"message"];
    [_table setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    _status = [UILabel new]; _status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _status.textColor = UIColor.secondaryLabelColor; _status.numberOfLines = 2;
    _status.text = @"选择服务、模型、角色；选择仅在本面板内生效。";
    _attachmentBar = [UIStackView new]; _attachmentBar.spacing = 6; _attachmentBar.hidden = YES;
    _input = [UITextView new]; _input.delegate = self; _input.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _input.adjustsFontForContentSizeCategory = YES; _input.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _input.layer.cornerRadius = 8; _input.accessibilityLabel = @"聊天消息";
    _inputHeight = [_input.heightAnchor constraintEqualToConstant:44]; _inputHeight.active = YES;
    _photo = haoge_keyboardtoolbarai_button(@"图片", self, @selector(haoge_keyboardtoolbarai_pickImages));
    _paste = haoge_keyboardtoolbarai_button(@"粘贴图", self, @selector(haoge_keyboardtoolbarai_pasteImage));
    _retry = haoge_keyboardtoolbarai_button(@"重试", self, @selector(haoge_keyboardtoolbarai_retry));
    _send = haoge_keyboardtoolbarai_button(@"发送", self, @selector(haoge_keyboardtoolbarai_sendOrStop));
    UIStackView *tools = [[UIStackView alloc] initWithArrangedSubviews:@[_photo, _paste, _retry, _send]];
    tools.distribution = UIStackViewDistributionFillEqually;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[header, choices, _table, _status, _attachmentBar, _input, tools]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 6; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
        [stack.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [stack.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-8]]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(haoge_keyboardtoolbarai_keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(haoge_keyboardtoolbarai_keyboard:) name:UIKeyboardWillHideNotification object:nil];
    [self haoge_keyboardtoolbarai_refreshControls];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; self.presentationController.delegate = self;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; [self haoge_keyboardtoolbarai_resizeInput];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || (!self.presentingViewController && !_closing)) [self haoge_keyboardtoolbarai_close];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_cancel) _cancel(); if (_modelsCancel) _modelsCancel();
    for (NSProgress *progress in _imageLoads) [progress cancel];
}
- (BOOL)haoge_keyboardtoolbarai_contains:(UIResponder *)responder {
    if (!responder) return NO;
    if (responder == self) return YES;
    if ([responder isKindOfClass:UIView.class] && self.isViewLoaded && [(UIView *)responder isDescendantOfView:self.view]) return YES;
    // Include presented menus / PHPicker, not unrelated views sharing the original window.
    UIViewController *presented = self.presentedViewController;
    while (presented) {
        if (responder == presented || ([responder isKindOfClass:UIView.class] && presented.isViewLoaded && [(UIView *)responder isDescendantOfView:presented.view])) return YES;
        presented = presented.presentedViewController;
    }
    for (UIResponder *node = responder.nextResponder; node; node = node.nextResponder) if (node == self) return YES;
    return NO;
}
- (BOOL)haoge_keyboardtoolbarai_focused {
    if (_closing) return NO;
    if (self.isViewLoaded && haoge_keyboardtoolbarai_firstResponder(self.view)) return YES;
    for (UIViewController *child = self.presentedViewController; child; child = child.presentedViewController)
        if (child.isViewLoaded && haoge_keyboardtoolbarai_firstResponder(child.view)) return YES;
    return NO;
}
- (void)haoge_keyboardtoolbarai_cancelChat {
    ++_generation; dispatch_block_t cancel = _cancel; _cancel = nil; _busy = NO;
    if ([_activeReply[@"state"] isEqualToString:@"pending"]) _activeReply[@"state"] = @"stopped";
    _activeReply = nil; if (cancel) cancel();
}
- (void)haoge_keyboardtoolbarai_cancelModels {
    ++_modelsGeneration; dispatch_block_t cancel = _modelsCancel; _modelsCancel = nil;
    _loadingModels = NO; if (cancel) cancel();
}
- (void)haoge_keyboardtoolbarai_close {
    if (_closing) return; _closing = YES;
    [self haoge_keyboardtoolbarai_cancelChat]; [self haoge_keyboardtoolbarai_cancelModels];
    ++_attachmentGeneration;
    for (NSProgress *progress in _imageLoads) [progress cancel]; [_imageLoads removeAllObjects];
    [self.view endEditing:YES];
    __weak typeof(self) weakSelf = self;
    void (^finished)(void) = ^{
        typeof(self) self = weakSelf; if (!self) return;
        if (haoge_keyboardtoolbarai_panel == self) haoge_keyboardtoolbarai_panel = nil;
        UIView *original = (UIView *)self->_originalInput;
        UIWindow *window = self->_originalWindow;
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        UIResponder *focused = haoge_keyboardtoolbarai_firstResponder(window);
        BOOL available = YES;
        for (UIView *node = original; node; node = node.superview)
            if (node.hidden || !node.userInteractionEnabled || node.alpha < 0.01) available = NO;
        if ([original isKindOfClass:UIControl.class] && ![(UIControl *)original isEnabled]) available = NO;
        if ([original isKindOfClass:UITextView.class] && ![(UITextView *)original isEditable]) available = NO;
        if (self->_restoreFocus && original && original.window == window && window.isKeyWindow && available &&
            window.windowScene.activationState == UISceneActivationStateForegroundActive &&
            top.isViewLoaded && [original isDescendantOfView:top.view] && (!focused || focused == original))
            [(UIResponder *)original becomeFirstResponder];
    };
    if (self.presentingViewController) [self dismissViewControllerAnimated:YES completion:finished]; else finished();
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController { [self haoge_keyboardtoolbarai_close]; }
- (void)haoge_keyboardtoolbarai_pan:(UIPanGestureRecognizer *)pan {
    CGFloat y = MAX(0, [pan translationInView:self.view].y);
    if (pan.state == UIGestureRecognizerStateChanged) _card.transform = CGAffineTransformMakeTranslation(0, y);
    else if (pan.state == UIGestureRecognizerStateEnded && (y > 100 || [pan velocityInView:self.view].y > 900)) [self haoge_keyboardtoolbarai_close];
    else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled)
        [UIView animateWithDuration:0.2 animations:^{ self->_card.transform = CGAffineTransformIdentity; }];
}
- (void)haoge_keyboardtoolbarai_keyboard:(NSNotification *)note {
    if (_closing || !self.view.window) return;
    if (![note.name isEqualToString:UIKeyboardWillHideNotification] && !_input.isFirstResponder) return;
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self.view convertRect:end fromCoordinateSpace:self.view.window.screen.coordinateSpace];
    CGRect overlap = CGRectIntersection(self.view.bounds, frame);
    CGFloat covered = (!CGRectIsNull(overlap) && CGRectGetMaxY(frame) >= CGRectGetMaxY(self.view.bounds) - 1) ? overlap.size.height : 0;
    if ([note.name isEqualToString:UIKeyboardWillHideNotification]) covered = 0;
    _cardBottom.constant = -8 - MAX(0, covered - self.view.safeAreaInsets.bottom);
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)([note.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16);
    [UIView animateWithDuration:duration delay:0 options:options | UIViewAnimationOptionBeginFromCurrentState animations:^{ [self.view layoutIfNeeded]; } completion:nil];
}
- (void)haoge_keyboardtoolbarai_resizeInput {
    if (_input.bounds.size.width < 1) return;
    CGFloat height = MIN(120, MAX(44, ceil([_input sizeThatFits:CGSizeMake(_input.bounds.size.width, CGFLOAT_MAX)].height)));
    if (fabs(_inputHeight.constant - height) > 0.5) _inputHeight.constant = height;
    _input.scrollEnabled = height >= 120;
}
- (void)textViewDidChange:(UITextView *)textView { [self haoge_keyboardtoolbarai_resizeInput]; }
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    return range.location <= textView.text.length && range.length <= textView.text.length - range.location &&
        textView.text.length - range.length + text.length <= 16000;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _messages.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HaogeKeyboardToolbarAIChatCell *cell = [tableView dequeueReusableCellWithIdentifier:@"message" forIndexPath:indexPath];
    NSString *text = [_messages[indexPath.row][@"text"] copy] ?: @"";
    __weak typeof(self) weakSelf = self;
    [cell haoge_keyboardtoolbarai_setMessage:_messages[indexPath.row] copy:^{ UIPasteboard.generalPasteboard.string = text; }
        insert:^{ [weakSelf haoge_keyboardtoolbarai_insert:text]; }];
    return cell;
}
- (void)haoge_keyboardtoolbarai_insert:(NSString *)text {
    id<UITextInput> original = _originalInput; UIView *view = (UIView *)original;
    if (!original || !view.window || view.window != _originalWindow || [self haoge_keyboardtoolbarai_contains:(UIResponder *)original]) {
        _status.text = @"原输入框已离开窗口，可使用复制。"; return;
    }
    if ([view isKindOfClass:UITextView.class] && ![(UITextView *)view isEditable]) { _status.text = @"原输入框不可编辑。"; return; }
    UITextRange *range = original.selectedTextRange;
    if (!range) range = [original textRangeFromPosition:original.endOfDocument toPosition:original.endOfDocument];
    if (range) { [original replaceRange:range withText:text]; [self haoge_keyboardtoolbarai_close]; }
    else _status.text = @"原输入框当前没有可插入位置。";
}
- (void)haoge_keyboardtoolbarai_reloadMessages:(BOOL)scroll {
    [_table reloadData]; [_table layoutIfNeeded];
    if (scroll && _messages.count) [_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
- (void)haoge_keyboardtoolbarai_alert:(NSString *)message {
    if (_closing || self.presentedViewController) { _status.text = message; return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AI 聊天" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)haoge_keyboardtoolbarai_refreshControls {
    [_profileButton setTitle:[NSString stringWithFormat:@"服务：%@", _profile[@"name"] ?: @"未配置"] forState:UIControlStateNormal];
    [_modelButton setTitle:[NSString stringWithFormat:@"模型：%@", _model.length ? _model : @"未选择"] forState:UIControlStateNormal];
    [_personaButton setTitle:[NSString stringWithFormat:@"角色：%@", _persona[@"name"] ?: @"无"] forState:UIControlStateNormal];
    _profileButton.enabled = !_busy; _modelButton.enabled = !_busy && !_loadingModels;
    _personaButton.enabled = !_busy; _retry.enabled = !_busy && _messages.count > 0;
    [_send setTitle:_busy ? @"停止" : @"发送" forState:UIControlStateNormal];
    _photo.enabled = !_picking && !_busy && _attachments.count < 4;
    _paste.enabled = _photo.enabled;
}
- (UIAlertController *)haoge_keyboardtoolbarai_menu:(NSString *)title anchor:(UIView *)anchor {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView = anchor;
    menu.popoverPresentationController.sourceRect = anchor.bounds;
    return menu;
}
- (void)haoge_keyboardtoolbarai_profiles {
    if (_busy || self.presentedViewController) return;
    UIAlertController *menu = [self haoge_keyboardtoolbarai_menu:@"选择服务（仅内存）" anchor:_profileButton];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *profile in _configuration[@"profiles"]) {
        [menu addAction:[UIAlertAction actionWithTitle:profile[@"name"] ?: @"未命名服务" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            typeof(self) self = weakSelf; if (!self) return;
            [self haoge_keyboardtoolbarai_cancelModels]; self->_profile = profile;
            NSString *identifier = haoge_keyboardtoolbarai_string(profile[@"id"]);
            self->_model = self->_modelChoices[identifier] ?: haoge_keyboardtoolbarai_string(profile[@"model"]);
            self->_status.text = @"已切换服务；历史消息保留，发送时会交给所选服务。";
            [self haoge_keyboardtoolbarai_refreshControls];
        }]];
    }
    [self presentViewController:menu animated:YES completion:nil];
}
- (NSArray<NSString *> *)haoge_keyboardtoolbarai_availableModels {
    NSString *identifier = haoge_keyboardtoolbarai_string(_profile[@"id"]);
    id configured = _modelCache[identifier] ?: _profile[@"models"];
    NSMutableOrderedSet *values = [NSMutableOrderedSet new];
    if ([configured isKindOfClass:NSArray.class]) for (id value in configured)
        if (haoge_keyboardtoolbarai_string(value).length) [values addObject:value];
    NSString *fallback = haoge_keyboardtoolbarai_string(_profile[@"model"]);
    if (fallback.length) [values addObject:fallback];
    if (_model.length) [values addObject:_model];
    return values.array;
}
- (void)haoge_keyboardtoolbarai_models {
    if (_busy || _loadingModels || self.presentedViewController) return;
    UIAlertController *menu = [self haoge_keyboardtoolbarai_menu:@"模型（配置列表 / 手动输入 / 网络加载）" anchor:_modelButton];
    __weak typeof(self) weakSelf = self;
    for (NSString *model in [self haoge_keyboardtoolbarai_availableModels]) {
        [menu addAction:[UIAlertAction actionWithTitle:model style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            typeof(self) self = weakSelf; if (!self) return;
            self->_model = model; self->_modelChoices[haoge_keyboardtoolbarai_string(self->_profile[@"id"])] = model;
            [self haoge_keyboardtoolbarai_refreshControls];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"手动输入模型名称…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIViewController *presented = weakSelf.presentedViewController;
        if (presented) [presented dismissViewControllerAnimated:YES completion:^{ [weakSelf haoge_keyboardtoolbarai_manualModel]; }];
        else [weakSelf haoge_keyboardtoolbarai_manualModel];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"加载 / 刷新模型列表" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [weakSelf haoge_keyboardtoolbarai_loadModels]; }]];
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)haoge_keyboardtoolbarai_manualModel {
    if (_closing || self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"模型名称（仅内存）" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = self->_model; field.autocorrectionType = UITextAutocorrectionTypeNo; field.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"选择" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        typeof(self) self = weakSelf; if (!self) return;
        NSString *model = [weakAlert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (model.length && model.length <= 256) {
            self->_model = model; self->_modelChoices[haoge_keyboardtoolbarai_string(self->_profile[@"id"])] = model;
            [self haoge_keyboardtoolbarai_refreshControls];
        } else [self haoge_keyboardtoolbarai_alert:@"模型名称应为 1–256 个字符。"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)haoge_keyboardtoolbarai_personas {
    if (_busy || self.presentedViewController) return;
    UIAlertController *menu = [self haoge_keyboardtoolbarai_menu:@"选择角色（仅内存）" anchor:_personaButton];
    __weak typeof(self) weakSelf = self;
    [menu addAction:[UIAlertAction actionWithTitle:@"无角色" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        typeof(self) self = weakSelf; if (!self) return; self->_persona = nil; [self haoge_keyboardtoolbarai_refreshControls];
    }]];
    for (NSDictionary *persona in _configuration[@"personas"]) {
        [menu addAction:[UIAlertAction actionWithTitle:persona[@"name"] ?: @"角色" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            typeof(self) self = weakSelf; if (!self) return; self->_persona = persona; [self haoge_keyboardtoolbarai_refreshControls];
        }]];
    }
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)haoge_keyboardtoolbarai_loadModels {
    if (!_profile || _closing || _loadingModels) return;
    [self haoge_keyboardtoolbarai_cancelModels];
    NSUInteger generation = ++_modelsGeneration; _loadingModels = YES;
    NSDictionary *profile = _profile; NSString *identifier = haoge_keyboardtoolbarai_string(profile[@"id"]);
    _status.text = @"正在加载模型列表…"; [self haoge_keyboardtoolbarai_refreshControls];
    __weak typeof(self) weakSelf = self;
    dispatch_block_t cancel = haoge_keyboardtoolbarai_startAIJob(@{@"kind":@"models", @"profile":profile}, nil, ^(NSDictionary *result, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self || self->_closing || generation != self->_modelsGeneration) return;
        self->_modelsCancel = nil; self->_loadingModels = NO;
        if (error) self->_status.text = [NSString stringWithFormat:@"模型加载失败：%@", error.localizedDescription];
        else {
            NSMutableArray *models = [NSMutableArray new];
            for (id value in result[@"models"]) if (haoge_keyboardtoolbarai_string(value).length && ![models containsObject:value]) [models addObject:value];
            self->_modelCache[identifier] = [models copy];
            if (!self->_model.length && models.count) { self->_model = models.firstObject; self->_modelChoices[identifier] = self->_model; }
            self->_status.text = [NSString stringWithFormat:@"已加载 %lu 个模型，点模型按钮选择。", (unsigned long)models.count];
        }
        [self haoge_keyboardtoolbarai_refreshControls];
    });
    if (_loadingModels && generation == _modelsGeneration) _modelsCancel = [cancel copy];
}
- (void)haoge_keyboardtoolbarai_refreshAttachments {
    for (UIView *view in [_attachmentBar.arrangedSubviews copy]) { [_attachmentBar removeArrangedSubview:view]; [view removeFromSuperview]; }
    for (NSUInteger index = 0; index < _attachments.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; button.tag = index;
        [button setImage:[UIImage imageWithData:_attachments[index]] forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.accessibilityLabel = [NSString stringWithFormat:@"附件 %lu，点按删除", (unsigned long)index + 1];
        [button addTarget:self action:@selector(haoge_keyboardtoolbarai_removeImage:) forControlEvents:UIControlEventTouchUpInside];
        [_attachmentBar addArrangedSubview:button];
        [NSLayoutConstraint activateConstraints:@[[button.widthAnchor constraintEqualToConstant:54], [button.heightAnchor constraintEqualToConstant:54]]];
    }
    [_attachmentBar addArrangedSubview:[UIView new]];
    _attachmentBar.hidden = !_attachments.count; [self haoge_keyboardtoolbarai_refreshControls];
}
- (void)haoge_keyboardtoolbarai_removeImage:(UIButton *)button {
    if (_busy || button.tag < 0 || (NSUInteger)button.tag >= _attachments.count) return;
    [_attachments removeObjectAtIndex:(NSUInteger)button.tag]; [self haoge_keyboardtoolbarai_refreshAttachments];
}
- (void)haoge_keyboardtoolbarai_pickImages {
    if (_picking || _busy || _attachments.count >= 4 || self.presentedViewController) return;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = PHPickerFilter.imagesFilter; config.selectionLimit = 4 - _attachments.count;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self; _picking = YES; [self haoge_keyboardtoolbarai_refreshControls];
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSUInteger generation = ++_attachmentGeneration;
    NSUInteger count = MIN(results.count, 4 - _attachments.count);
    if (!count) { _picking = NO; [self haoge_keyboardtoolbarai_refreshControls]; return; }
    _status.text = @"正在压缩图片…";
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray *loaded = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) [loaded addObject:NSNull.null];
    for (NSUInteger i = 0; i < count; i++) {
        NSItemProvider *provider = results[i].itemProvider;
        if (![provider canLoadObjectOfClass:UIImage.class]) continue;
        dispatch_group_enter(group);
        NSProgress *progress = [provider loadObjectOfClass:UIImage.class completionHandler:^(__kindof id<NSItemProviderReading> object, NSError *error) {
            @autoreleasepool {
                NSData *jpeg = [object isKindOfClass:UIImage.class] ? haoge_keyboardtoolbarai_jpeg((UIImage *)object) : nil;
                if (jpeg) @synchronized (loaded) { loaded[i] = jpeg; }
            }
            dispatch_group_leave(group);
        }];
        if (progress) [_imageLoads addObject:progress];
    }
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || self->_closing || generation != self->_attachmentGeneration) return;
        [self->_imageLoads removeAllObjects]; self->_picking = NO;
        NSUInteger added = 0;
        for (id data in loaded) if ([data isKindOfClass:NSData.class] && self->_attachments.count < 4) { [self->_attachments addObject:data]; added++; }
        self->_status.text = added == count ? @"图片已压缩为 JPEG；点缩略图删除（每条最多 4 张）。" : @"部分图片读取失败，请重选；已保留成功项。";
        [self haoge_keyboardtoolbarai_refreshAttachments];
    });
}
- (void)haoge_keyboardtoolbarai_pasteImage {
    if (_busy || _picking || _attachments.count >= 4) return;
    _picking = YES; NSUInteger generation = ++_attachmentGeneration;
    [self haoge_keyboardtoolbarai_refreshControls];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image=UIPasteboard.generalPasteboard.image;
        NSData *jpeg = image?haoge_keyboardtoolbarai_jpeg(image):nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || self->_closing || generation != self->_attachmentGeneration) return;
            self->_picking = NO;
            if (jpeg && self->_attachments.count < 4) [self->_attachments addObject:jpeg];
            self->_status.text = jpeg ? @"图片已粘贴；点缩略图删除。" : @"图片压缩失败。";
            [self haoge_keyboardtoolbarai_refreshAttachments];
        });
    });
}
- (NSArray<NSDictionary *> *)haoge_keyboardtoolbarai_wireMessages {
    // Keep a contiguous recent suffix within the network's 41-message / text / body limits.
    NSMutableArray *wire = [NSMutableArray new]; NSUInteger cost = 0, textUnits = 0;
    for (NSDictionary *message in _messages.reverseObjectEnumerator) {
        NSString *role = message[@"role"], *text = message[@"text"] ?: @"", *state = message[@"state"];
        if ([role isEqualToString:@"assistant"] && (!text.length || [state isEqualToString:@"pending"] || [state isEqualToString:@"error"])) continue;
        NSArray<NSData *> *images = message[@"images"] ?: @[];
        NSUInteger estimate = text.length * 4 + 256;
        for (NSData *data in images) estimate += data.length * 2;
        if (cost + estimate > 6 * 1024 * 1024 || textUnits + text.length > 196608 || wire.count >= 40) break;
        id content = text;
        if (images.count) {
            NSMutableArray *parts = [NSMutableArray new];
            if (text.length) [parts addObject:@{@"type":@"text", @"text":text}];
            for (NSData *data in images) {
                NSString *url = [@"data:image/jpeg;base64," stringByAppendingString:[data base64EncodedStringWithOptions:0]];
                [parts addObject:@{@"type":@"image_url", @"image_url":@{@"url":url}}];
            }
            content = [parts copy];
        }
        [wire insertObject:@{@"role":role, @"content":content} atIndex:0];
        cost += estimate; textUnits += text.length;
    }
    while (wire.count && [wire.firstObject[@"role"] isEqualToString:@"assistant"]) [wire removeObjectAtIndex:0];
    NSString *prompt = haoge_keyboardtoolbarai_string(_persona[@"prompt"]);
    if (prompt.length > 16000) prompt = [prompt substringToIndex:16000];
    if (prompt.length) [wire insertObject:@{@"role":@"system", @"content":prompt} atIndex:0];
    return wire;
}
- (BOOL)haoge_keyboardtoolbarai_ready {
    if (!_profile || !_model.length) { [self haoge_keyboardtoolbarai_alert:@"请先在设置中配置服务，并在这里选择模型。"]; return NO; }
    if (_picking) { _status.text = @"请等待图片处理完成。"; return NO; }
    return !_closing && !_busy;
}
- (void)haoge_keyboardtoolbarai_sendOrStop {
    if (_busy) {
        [self haoge_keyboardtoolbarai_cancelChat]; _status.text = @"已停止；可重试。";
        [self haoge_keyboardtoolbarai_refreshControls]; [self haoge_keyboardtoolbarai_reloadMessages:NO]; return;
    }
    if (![self haoge_keyboardtoolbarai_ready]) return;
    NSString *text = [_input.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length && !_attachments.count) { _status.text = @"请输入消息或选择图片。"; return; }
    if (text.length > 16000) { [self haoge_keyboardtoolbarai_alert:@"单条消息最多 16000 个字符。"]; return; }
    while (_messages.count > 38) [_messages removeObjectAtIndex:0];
    [_messages addObject:[@{@"role":@"user", @"text":text ?: @"", @"images":[_attachments copy], @"state":@"done"} mutableCopy]];
    _input.text = @""; [_attachments removeAllObjects];
    [self haoge_keyboardtoolbarai_resizeInput]; [self haoge_keyboardtoolbarai_refreshAttachments];
    [self haoge_keyboardtoolbarai_startReply];
}
- (void)haoge_keyboardtoolbarai_retry {
    if (![self haoge_keyboardtoolbarai_ready] || !_messages.count) return;
    if ([_messages.lastObject[@"role"] isEqualToString:@"assistant"]) [_messages removeLastObject];
    if (![_messages.lastObject[@"role"] isEqualToString:@"user"]) { _status.text = @"没有可重试的用户消息。"; return; }
    [self haoge_keyboardtoolbarai_startReply];
}
- (void)haoge_keyboardtoolbarai_startReply {
    [self haoge_keyboardtoolbarai_cancelModels];
    NSArray *messages = [self haoge_keyboardtoolbarai_wireMessages];
    _activeReply = [@{@"role":@"assistant", @"text":@"", @"state":@"pending"} mutableCopy];
    [_messages addObject:_activeReply]; _busy = YES;
    NSUInteger generation = ++_generation;
    _status.text = @"正在请求… 可随时停止。";
    [self haoge_keyboardtoolbarai_refreshControls]; [self haoge_keyboardtoolbarai_reloadMessages:YES];
    NSDictionary *options = @{@"profile":_profile, @"model":_model, @"messages":messages,
        @"stream":_configuration[@"stream"] ?: @YES};
    __weak typeof(self) weakSelf = self;
    dispatch_block_t cancel = haoge_keyboardtoolbarai_startAIJob(options, ^(NSString *text) {
        typeof(self) self = weakSelf;
        if (!self || self->_closing || !self->_busy || generation != self->_generation) return;
        self->_activeReply[@"text"] = text ?: @"";
        BOOL bottom = self->_table.contentOffset.y + self->_table.bounds.size.height >= self->_table.contentSize.height - 100;
        [self haoge_keyboardtoolbarai_reloadMessages:bottom];
    }, ^(NSDictionary *result, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self || self->_closing || !self->_busy || generation != self->_generation) return;
        self->_busy = NO; self->_cancel = nil;
        if (error) {
            BOOL cancelled = [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled;
            self->_activeReply[@"state"] = cancelled ? @"stopped" : @"error";
            if (![self->_activeReply[@"text"] length]) self->_activeReply[@"text"] = cancelled ? @"" : [NSString stringWithFormat:@"请求失败：%@", error.localizedDescription];
            self->_status.text = cancelled ? @"请求已取消。" : [NSString stringWithFormat:@"请求失败，可重试：%@", error.localizedDescription];
        } else {
            NSString *text = haoge_keyboardtoolbarai_string(result[@"text"]);
            if (text.length) self->_activeReply[@"text"] = text;
            self->_activeReply[@"state"] = @"done";
            self->_status.text = [self->_activeReply[@"text"] length] ? @"已完成。回复可选择、复制或插入原输入框。" : @"服务返回空正文，可重试或切换模型。";
        }
        self->_activeReply = nil;
        [self haoge_keyboardtoolbarai_refreshControls]; [self haoge_keyboardtoolbarai_reloadMessages:NO];
    });
    if (_busy && generation == _generation) _cancel = [cancel copy];
}
- (void)haoge_keyboardtoolbarai_clear {
    [self haoge_keyboardtoolbarai_cancelChat]; [self haoge_keyboardtoolbarai_cancelModels];
    ++_attachmentGeneration; _picking = NO;
    for (NSProgress *progress in _imageLoads) [progress cancel]; [_imageLoads removeAllObjects];
    [_messages removeAllObjects]; [_attachments removeAllObjects]; _input.text = @"";
    _status.text = @"已清空聊天与附件；当前服务、模型和角色保留。";
    [self haoge_keyboardtoolbarai_resizeInput]; [self haoge_keyboardtoolbarai_refreshAttachments];
    [self haoge_keyboardtoolbarai_reloadMessages:NO];
}
@end

@implementation HaogeKeyboardToolbarAIChatPanel
+ (void)haoge_keyboardtoolbarai_openForInput:(id<UITextInput>)input {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_keyboardtoolbarai_openForInput:input]; }); return;
    }
    if (![input isKindOfClass:UIView.class] || ![(id)input conformsToProtocol:@protocol(UITextInput)] ||
        [self haoge_keyboardtoolbarai_containsResponder:(UIResponder *)input] || haoge_keyboardtoolbarai_panel) return;
    UIView *view = (UIView *)input; UIWindow *window = view.window;
    if (!window || !window.windowScene || window.windowScene.activationState != UISceneActivationStateForegroundActive) return;
    UIViewController *presenter = window.rootViewController;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if (!presenter || presenter.isBeingDismissed || presenter.isBeingPresented || presenter.view.window != window) return;
    HaogeKeyboardToolbarAIChatViewController *panel = [[HaogeKeyboardToolbarAIChatViewController alloc] haoge_keyboardtoolbarai_initWithInput:input];
    haoge_keyboardtoolbarai_panel = panel;
    [(UIResponder *)input resignFirstResponder];
    [presenter presentViewController:panel animated:YES completion:nil];
}
+ (BOOL)haoge_keyboardtoolbarai_containsResponder:(UIResponder *)responder {
    if (NSThread.isMainThread) return [haoge_keyboardtoolbarai_panel haoge_keyboardtoolbarai_contains:responder];
    __block BOOL value = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{ value = [haoge_keyboardtoolbarai_panel haoge_keyboardtoolbarai_contains:responder]; });
    return value;
}
+ (BOOL)haoge_keyboardtoolbarai_isVisible {
    if (NSThread.isMainThread) return haoge_keyboardtoolbarai_panel != nil;
    __block BOOL value = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{ value = haoge_keyboardtoolbarai_panel != nil; }); return value;
}
+ (BOOL)haoge_keyboardtoolbarai_hasFocusedInput {
    if (NSThread.isMainThread) return [haoge_keyboardtoolbarai_panel haoge_keyboardtoolbarai_focused];
    __block BOOL value = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{ value = [haoge_keyboardtoolbarai_panel haoge_keyboardtoolbarai_focused]; }); return value;
}
@end
