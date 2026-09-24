APP_NAME := BuildkiteNotch
CONFIG   ?= debug
BUNDLE   := build/$(APP_NAME).app
ARCHS    ?=
ARCH_FLAGS := $(foreach a,$(ARCHS),--arch $(a))
PLIST    := Resources/Info.plist
PLISTBUDDY := /usr/libexec/PlistBuddy

.PHONY: build app run test release install clean icon bump dist publish

build:
	swift build -c $(CONFIG) $(ARCH_FLAGS)

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp "$$(swift build -c $(CONFIG) $(ARCH_FLAGS) --show-bin-path)/$(APP_NAME)" $(BUNDLE)/Contents/MacOS/
ifeq ($(CONFIG),release)
	# Drop debug symbols: they embed absolute paths from the build machine.
	strip -S -x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
endif
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(BUNDLE)

run: app
	-pkill -x $(APP_NAME)
	open $(BUNDLE)

test:
	swift test

release:
	$(MAKE) app CONFIG=release ARCHS="arm64 x86_64"

install: release
	-pkill -x $(APP_NAME)
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(APP_NAME).app

clean:
	rm -rf .build build

icon:
	swift Scripts/make-icon.swift

# make bump VERSION=0.2.0 -> sets the marketing version and increments the build number.
bump:
	@test -n "$(VERSION)" || (echo "usage: make bump VERSION=x.y.z" && exit 1)
	$(PLISTBUDDY) -c "Set :CFBundleShortVersionString $(VERSION)" $(PLIST)
	$(PLISTBUDDY) -c "Set :CFBundleVersion $$(( $$($(PLISTBUDDY) -c 'Print :CFBundleVersion' $(PLIST)) + 1 ))" $(PLIST)
	@echo "Version $$($(PLISTBUDDY) -c 'Print :CFBundleShortVersionString' $(PLIST)) ($$($(PLISTBUDDY) -c 'Print :CFBundleVersion' $(PLIST)))"

# Developer ID signed + notarized zip in build/.
dist:
	Scripts/release.sh

# dist + GitHub release + Homebrew cask update.
publish:
	Scripts/release.sh --publish
