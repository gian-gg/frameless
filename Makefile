APP := build/Frameless.app
DMG := build/Frameless.dmg
ICON := build/AppIcon.icns
ICONSET := build/AppIcon.iconset
SOURCES := Package.swift Sources Tests
SIGN_ID ?= $(shell security find-identity -v -p codesigning | grep -q '"Frameless Dev"' && echo "Frameless Dev" || echo "-")

# SwiftLint's sourcekitd and Swift Testing's framework path when only the Command Line Tools are installed
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
export TOOLCHAIN_DIR := /Library/Developer/CommandLineTools
TESTING_FW := $(TOOLCHAIN_DIR)/Library/Developer/Frameworks
TEST_FLAGS := -Xswiftc -F -Xswiftc $(TESTING_FW) -Xlinker -rpath -Xlinker $(TESTING_FW) \
	-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays
endif

.PHONY: build app dmg run clean format lint typecheck test check hooks

build:
	swift build -c release

$(ICON): assets/logo.png
	rm -rf $(ICONSET)
	mkdir -p $(ICONSET)
	for size in 16 32 128 256 512; do \
		sips -z $$size $$size $< --out $(ICONSET)/icon_$${size}x$${size}.png >/dev/null; \
		sips -z $$((size * 2)) $$((size * 2)) $< --out $(ICONSET)/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns -o $@ $(ICONSET)

app: build $(ICON)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/Frameless $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	cp $(ICON) $(APP)/Contents/Resources/
	codesign --force --options runtime --entitlements Resources/Frameless.entitlements --sign "$(SIGN_ID)" $(APP)

# Disk image with the app and a shortcut to Applications, for releases
dmg: app
	rm -rf build/dmg $(DMG)
	mkdir -p build/dmg
	cp -R $(APP) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname Frameless -srcfolder build/dmg -fs HFS+ -format UDZO -ov $(DMG)
	rm -rf build/dmg

run: app
	open $(APP)

clean:
	rm -rf .build build

format:
	swift format --in-place --recursive $(SOURCES)
	swiftlint --fix --quiet

lint:
	swift format lint --strict --recursive $(SOURCES)
	swiftlint --strict --quiet

typecheck:
	swift build --build-tests -Xswiftc -warnings-as-errors $(TEST_FLAGS)

test: typecheck
	swift test --skip-build

check: lint test

hooks:
	git config core.hooksPath .githooks
