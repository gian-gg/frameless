APP := build/Frameless.app
SIGN_ID ?= $(shell security find-identity -v -p codesigning | grep -q '"Frameless Dev"' && echo "Frameless Dev" || echo "-")

.PHONY: build app run clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Frameless $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --options runtime --entitlements Resources/Frameless.entitlements --sign "$(SIGN_ID)" $(APP)

run: app
	open $(APP)

clean:
	rm -rf .build build
