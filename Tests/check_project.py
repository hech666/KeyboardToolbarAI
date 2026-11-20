from pathlib import Path
import json,plistlib,re
P=Path(__file__).resolve().parents[1];S=P/'Sources';F=P/'HaogeKeyboardToolbarAIPrefs';checks={}
sources=[*S.glob('*.m'),*S.glob('*.mm'),*F.glob('*.m')];text='\n'.join(f.read_text() for f in sources)
checks['fifteen_implementation_units']=len(sources)==15
code='\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//'))
checks['no_original_runtime_class_dependencies']=not re.search(r'NSClassFromString\(@"(?:KTConfig|KeyboardTools|KTAI\w*)"\)|\[KTConfig ',code)
checks['no_beautification_classes']=not any(t in text for t in ('AxsEffect','AxsConfig','KTCandidateAnimation','candidateGradient','pureBlackKeycap'))
checks['no_placeholder_bodies']=not any(t in text for t in ('TODO','FIXME','Add the plugin','ADAPTER TODO','not implemented'))
make=(P/'Makefile').read_text();checks['mixed_source_collected']='Sources/*.mm' in make and 'Sources/*.m' in make
checks['settings_no_config_runtime_duplicate']='../Sources/HaogeKeyboardToolbarAIModel.m' in (F/'Makefile').read_text() and 'Config.m' not in (F/'Makefile').read_text()
checks['no_example_hook']=(not any((P/'Hooks').glob('*.xm')))
root=plistlib.loads((F/'Resources/HaogeKeyboardToolbarAIRoot.plist').read_bytes());keys={x.get('key') for x in root['items'] if x.get('key')}
checks['seven_toolbar_settings_only']=keys=={'enabled','ToolbarAtBottom','ShowIcons','HapticFeedback','toolbarBgEnabled','toolbarLightColor','toolbarDarkColor'}
checks['disabled_by_default']=next(i for i in root['items'] if i.get('key')=='enabled')['default'] is False
checks['actions_and_ai_settings_links']={i.get('kind') for i in root['items']}>={'buttons','ai'}
loader=plistlib.loads((P/'layout/Library/PreferenceLoader/Preferences/HaogeKeyboardToolbarAIPrefs.plist').read_bytes());info=plistlib.loads((F/'Resources/Info.plist').read_bytes());checks['loader_matches_principal']=loader['entry']['detail']==info['NSPrincipalClass']
network=(S/'HaogeKeyboardToolbarAINetwork.m').read_text();checks['request_resource_timeout_90_300']='timeoutIntervalForRequest = 90.0' in network and 'timeoutIntervalForResource = 300.0' in network
checks['message_limit_1_41']='messages.count < 1 || messages.count > 41' in network
checks['no_real_credentials']=not re.search(r'sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}',text)
checks['serial_network_state']='delegateQueue:self.haoge_keyboardtoolbarai_workQueue' in network
checks['geometry_same_code_tested']='haoge_keyboardtoolbarai_geometry(' in (S/'HaogeKeyboardToolbarAIToolbar.mm').read_text() and 'HaogeKeyboardToolbarAIGeometry.h' in (P/'Tests/geometry.c').read_text()
checks['no_vendor_binary']=not any(p.suffix in ('.deb','.dylib','.o','.a','.macho') for p in P.rglob('*') if p.is_file())
result={'passed':all(checks.values()),'checks':checks};print(json.dumps(result,ensure_ascii=False,indent=2));raise SystemExit(0 if result['passed'] else 1)
