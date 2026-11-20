include ../HaogeKeyboardToolbarAIBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HaogeKeyboardToolbarAIPrefs
HaogeKeyboardToolbarAIPrefs_FILES = $(wildcard *.m) ../Sources/HaogeKeyboardToolbarAIModel.m
HaogeKeyboardToolbarAIPrefs_CFLAGS = -fobjc-arc -I../Sources
HaogeKeyboardToolbarAIPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
HaogeKeyboardToolbarAIPrefs_PRIVATE_FRAMEWORKS = Preferences
HaogeKeyboardToolbarAIPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
