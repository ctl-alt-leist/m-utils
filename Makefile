UTILS := coffee

.PHONY: build install uninstall clean $(UTILS)

build install uninstall clean:
	@for util in $(UTILS); do $(MAKE) -C $$util $@ || exit 1; done

$(UTILS):
	$(MAKE) -C $@ install
