UTILS := coffee

.PHONY: build install clean $(UTILS)

build install clean:
	@for util in $(UTILS); do $(MAKE) -C $$util $@ || exit 1; done

$(UTILS):
	$(MAKE) -C $@ install
