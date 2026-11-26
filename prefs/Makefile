TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := CallForwardPrefs
CallForwardPrefs_FILES := CFPrefsController.m
CallForwardPrefs_FRAMEWORKS := UIKit
CallForwardPrefs_LDFLAGS := -undefined dynamic_lookup
CallForwardPrefs_CFLAGS := -fobjc-arc
CallForwardPrefs_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

# Dong goi entry PreferenceLoader thang vao .deb o khau stage (duong doc lap voi layout/ o goc du an):
# du thu muc layout/ co rot khoi repo khi up thi .deb van chua entry, Cai dat van hien muc CallForward.
after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"
	@cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CallForward.plist" && echo "CallForward: da dong goi entry PreferenceLoader vao .deb" || echo "CallForward: CANH BAO — copy entry that bai, chi con duong layout/"
