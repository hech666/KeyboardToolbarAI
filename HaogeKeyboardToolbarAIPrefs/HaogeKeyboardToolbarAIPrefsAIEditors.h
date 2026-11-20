#pragma once

#import "HaogeKeyboardToolbarAIPrefsPage.h"

typedef BOOL (^HaogeKeyboardToolbarAIPrefsRecordCommit)(HaogeKeyboardToolbarAIPrefsPage *editor, NSDictionary *record);

@interface HaogeKeyboardToolbarAIPrefsProfileEditor : HaogeKeyboardToolbarAIPrefsPage
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setRecord:) NSDictionary *haoge_keyboardtoolbarai_record;
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setCommit:) HaogeKeyboardToolbarAIPrefsRecordCommit haoge_keyboardtoolbarai_commit;
@end

@interface HaogeKeyboardToolbarAIPrefsPersonaEditor : HaogeKeyboardToolbarAIPrefsPage
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setRecord:) NSDictionary *haoge_keyboardtoolbarai_record;
@property (nonatomic, copy, setter=haoge_keyboardtoolbarai_setCommit:) HaogeKeyboardToolbarAIPrefsRecordCommit haoge_keyboardtoolbarai_commit;
@end
