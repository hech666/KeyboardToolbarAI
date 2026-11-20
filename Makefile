DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include HaogeKeyboardToolbarAIBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HaogeKeyboardToolbarAI
HaogeKeyboardToolbarAI_FILES = $(wildcard Sources/*.m Sources/*.mm)
HaogeKeyboardToolbarAI_CFLAGS = -fobjc-arc -I./Headers -I./Sources
HaogeKeyboardToolbarAI_CCFLAGS = -std=c++17
HaogeKeyboardToolbarAI_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics QuartzCore PhotosUI UniformTypeIdentifiers ImageIO
HaogeKeyboardToolbarAI_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += HaogeKeyboardToolbarAIPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
