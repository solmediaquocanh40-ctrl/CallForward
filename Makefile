TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME := CallForward
CallForward_FILES := Tweak.x PhoneUI.x
CallForward_FRAMEWORKS := UIKit CallKit
CallForward_CFLAGS := -fobjc-arc

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
