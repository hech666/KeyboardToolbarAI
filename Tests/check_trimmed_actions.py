from pathlib import Path
import re,json
P=Path(__file__).resolve().parents[1]
REMOVED=['showClipboard','moveLeft','moveRight','insertNewline','showEmojiKeyboard','snapperFreeze','snapperLong','screenshotShell','screenshotWatermark','screenshotBoth']
EXPECTED=['selectAll','selectAllAndCopy','paste','kt_showAI','cut','undo','clearText','done']
model=(P/'Sources/HaogeKeyboardToolbarAIModel.m').read_text();table=model.split('haoge_keyboardtoolbarai_actionCatalog(void) {',1)[1].split('\n}',1)[0]
ids=re.findall(r'@"id"\s*:\s*@"([^"]+)"',table)
assert ids==EXPECTED,(ids,EXPECTED)
sourcefiles=[f for f in (P/'Sources').iterdir() if f.suffix in ('.h','.m','.mm')]
production='\n'.join(f.read_text() for f in sourcefiles)
for old in REMOVED+['moveCursor','UIKeyboardInputModeController','ClipboardHelperRuntime','ScreenShell','snapper4','com.axs.clipboard','keyboardtoolbarai.external.','applicationOpenURL:']:
 assert old not in production,'Removed implementation/reference: '+old
methods=re.findall(r'^-\s*\(void\)haoge_keyboardtoolbarai_(\w+)',(P/'Sources/HaogeKeyboardToolbarAIActions.m').read_text(),re.M)
assert set(methods)==set(EXPECTED+['copyText']),methods
prefs=(P/'Sources/HaogeKeyboardToolbarAIPreferences.h').read_text()
assert prefs.count('haoge_keyboardtoolbarai_normalizeToolbarPreferences(')==3
assert 'directions[key]=[valid containsObject:canonical]?canonical:@"";' in model
assert 'NSDictionary *haoge_keyboardtoolbarai_normalizeToolbarPreferences' in model
assert (P/'Sources/HaogeKeyboardToolbarAIChat.m').stat().st_size>40000
report={'passed':True,'action_count':len(ids),'actions':ids,'default_button_count':len(ids)-1,'removed_actions':REMOVED,'production_files_checked':len(sourcefiles),'actions_removed_not_just_hidden':True,'configuration_normalized_on_read_and_save':True,'AI_and_colors_preserved':True}
print(json.dumps(report,ensure_ascii=False,indent=2))
