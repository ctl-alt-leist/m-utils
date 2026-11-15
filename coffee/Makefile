APP     := Coffee.app
BUILD   := build
INSTALL := $(HOME)/Applications

.PHONY: build install run clean

build: $(BUILD)/$(APP)

$(BUILD)/$(APP): Coffee.swift Info.plist
	rm -rf $@
	mkdir -p $@/Contents/MacOS
	swiftc -O Coffee.swift -o $@/Contents/MacOS/Coffee
	cp Info.plist $@/Contents/Info.plist
	codesign --force --sign - $@

install: build
	-pkill -x Coffee
	mkdir -p $(INSTALL)
	rm -rf $(INSTALL)/$(APP)
	cp -R $(BUILD)/$(APP) $(INSTALL)/$(APP)
	open $(INSTALL)/$(APP)

run: build
	open $(BUILD)/$(APP)

clean:
	rm -rf $(BUILD)
