
TARGET := iphone:clang:latest:16.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NetworkMonitor
NetworkMonitor_FILES = Tweak.xm
NetworkMonitor_CFLAGS = -fobjc-arc
NetworkMonitor_FRAMEWORKS = Foundation
NetworkMonitor_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

BUNDLE_NAME = NetworkMonitorPrefs
NetworkMonitorPrefs_FILES = NMRootListController.m
NetworkMonitorPrefs_INSTALL_PATH = /Library/PreferenceBundles
NetworkMonitorPrefs_FRAMEWORKS = UIKit Foundation
NetworkMonitorPrefs_PRIVATE_FRAMEWORKS = Preferences
NetworkMonitorPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 Preferences || true"
