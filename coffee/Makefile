APP       := Coffee.app
BUILD     := build
INSTALL   := $(HOME)/Applications
FUNCTIONS := $(HOME)/.config/fish/functions

.PHONY: build install uninstall run clean

build: $(BUILD)/$(APP)

$(BUILD)/$(APP): Coffee.swift Info.plist
	rm -rf $@
	mkdir -p $@/Contents/MacOS
	swiftc -O Coffee.swift -o $@/Contents/MacOS/Coffee
	cp Info.plist $@/Contents/Info.plist
	codesign --force --sign - $@

install: build
	-pkill -x Coffee
	mkdir -p $(INSTALL) $(FUNCTIONS)
	rm -rf $(INSTALL)/$(APP)
	cp -R $(BUILD)/$(APP) $(INSTALL)/$(APP)
	cp coffee.fish $(FUNCTIONS)/coffee.fish
	open $(INSTALL)/$(APP)

uninstall:
	-pkill -x Coffee
	rm -rf $(INSTALL)/$(APP)
	rm -f $(FUNCTIONS)/coffee.fish

run: build
	open $(BUILD)/$(APP)

clean:
	rm -rf $(BUILD)
