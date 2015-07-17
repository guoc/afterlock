export ARCHS=armv7 arm64

include theos/makefiles/common.mk

TWEAK_NAME = afterlock
afterlock_FILES = Event.xm
afterlock_LIBRARIES = activator

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	#PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/afterlock; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/afterlock/; fi$(ECHO_END)

after-install::
	install.exec "killall -9 SpringBoard"
