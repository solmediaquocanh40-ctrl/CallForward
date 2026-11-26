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
