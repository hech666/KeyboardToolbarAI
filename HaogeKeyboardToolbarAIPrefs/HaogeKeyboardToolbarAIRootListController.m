#import "HaogeKeyboardToolbarAIRootListController.h"
#import "HaogeKeyboardToolbarAIPrefsControllers.h"

@implementation HaogeKeyboardToolbarAIRootListController {
    HaogeKeyboardToolbarAIPrefsMain *_settings;
}

- (NSMutableArray *)specifiers {
    // PSListController is the PreferenceLoader host; UIKit owns the actual rows.
    if (!_specifiers) _specifiers = [NSMutableArray array];
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"键盘工具栏 AI";
    _settings = [[HaogeKeyboardToolbarAIPrefsMain alloc] init];
    [self addChildViewController:_settings];
    _settings.view.frame = self.view.bounds;
    _settings.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_settings.view];
    [_settings didMoveToParentViewController:self];
}

@end
