SHELL:=/bin/bash

export PYTHONPATH := /usr/local/lib64/python2.7/site-packages:$(PYTHONPATH)
export PYTHONPATH := /usr/local/lib64/python2.7/dist-packages:$(PYTHONPATH)
export LD_LIBRARY_PATH := /usr/local/lib64:$(LD_LIBRARY_PATH)

XML_PATH = gr-mods/grc
LIB_PATH = gr-mods/lib
PY_PATH = gr-mods/python
H_PATH = gr-mods/include/blockstream

ifeq ($(GUI), 0)
	GRC_FILES = $(shell find grc/ -maxdepth 1 -type f -name '*.grc' ! \
				  -path '*gui.grc')
else
	GRC_FILES = $(shell find grc/ -maxdepth 1 -type f -name '*.grc')
endif
GRC_PY_FILES = $(patsubst grc/%.grc, build/%.py, $(GRC_FILES))

MOD_XML = $(shell find $(XML_PATH) -type f -name '*.xml')
MOD_I_H = $(shell find $(LIB_PATH) -type f -name '*.h')
MOD_CC = $(shell find $(LIB_PATH) -type f -name '*.cc')
MOD_PY = $(shell find $(PY_PATH) -type f -name '*.py')
MOD_H = $(shell find $(H_PATH) -type f -name '*.h')
AFF3CT = $(shell find $(LIB_PATH) -type f -name '*.cpp')

GR_FRAMERS_REPO = https://github.com/gr-vt/gr-framers.git
GR_FRAMERS_BUILD_DIR = gr-framers/build
GR_FRAMERS_BUILD_RC = build/gr-framers_build_record
GR_MODS_BUILD_DIR = gr-mods/build
GR_MODS_BUILD_RC = gr-mods/build_record

.PHONY: build install clean uninstall mods install-mods clean-mods \
uninstall-mods framers install-framers clean-framers uninstall-framers

# Build Rx Flowgraphs
build: $(GRC_PY_FILES)

build/%.py: grc/%.grc
	@echo "Check gr-framers and gr-blockstream installations"
	@python -c "import framers"
	@python -c "import blockstream"
	mkdir -p build
	grcc $< -d $(@D)
	@sed -i 's/'\
	'dest=\"scan_mode\", type=\"intx\", default=0/'\
	'dest=\"scan_mode\", action=\"store_true\", default=False/g' $@
	@chmod u+x $@
	python -m compileall $@
	f=$@ && x=$${f%.py} && y="$${x//_/-}" &&\
	echo "#!/bin/bash" > $$y &&\
	echo "/usr/bin/python $(DESTDIR)/usr/local/lib/bs-rx/$(@F)c \"\$$@\"" >> $$y

# Build GR Framers
framers: $(GR_FRAMERS_BUILD_RC)

$(GR_FRAMERS_BUILD_RC):
	git submodule update --init gr-framers
	mkdir -p $(GR_FRAMERS_BUILD_DIR)
	cd $(GR_FRAMERS_BUILD_DIR) && cmake .. && make
	mkdir -p build
	touch $(GR_FRAMERS_BUILD_RC)

# Install gr-framers
install-framers: $(GR_FRAMERS_BUILD_RC)
	cd $(GR_FRAMERS_BUILD_DIR) && make DESTDIR=$(DESTDIR) install
	-ldconfig

# Build GR Mods
mods: $(GR_MODS_BUILD_RC)

$(GR_MODS_BUILD_RC): $(MOD_CC) $(MOD_I_H) $(AFF3CT) $(MOD_H) $(MOD_XML) $(MOD_PY)
	git submodule update --init gr-mods
	mkdir -p $(GR_MODS_BUILD_DIR)
	cd $(GR_MODS_BUILD_DIR) && cmake .. && make
	touch $(GR_MODS_BUILD_RC)

# Install GR Mods
install-mods: $(GR_MODS_BUILD_RC)
	cd $(GR_MODS_BUILD_DIR) && make DESTDIR=$(DESTDIR) install
	-ldconfig

install:
	mkdir -p $(DESTDIR)/usr/local/bin
	mkdir -p $(DESTDIR)/usr/local/lib/bs-rx
	install -m 0644 build/bs_*.py* $(DESTDIR)/usr/local/lib/bs-rx/
	cd build && ls | grep -v '\.py*' | \
	xargs -L 1 -I '{}' install -m 0755 '{}' $(DESTDIR)/usr/local/bin/

# Clean builds
clean-framers:
	rm -f $(GR_FRAMERS_BUILD_RC)
	$(MAKE) -C $(GR_FRAMERS_BUILD_DIR) clean
	rm -rf $(GR_FRAMERS_BUILD_DIR)

clean-mods:
	rm -f $(GR_MODS_BUILD_RC)
	$(MAKE) -C $(GR_MODS_BUILD_DIR) clean
	rm -rf $(GR_MODS_BUILD_DIR)

clean:
	rm -f $(GRC_PY_FILES)

# Uninstall
uninstall-framers:
	rm -f $(GR_FRAMERS_BUILD_RC)
	$(MAKE) -C $(GR_FRAMERS_BUILD_DIR) uninstall

uninstall-mods:
	rm -f $(GR_MODS_BUILD_RC)
	$(MAKE) -C $(GR_MODS_BUILD_DIR) uninstall

uninstall:
	rm $(DESTDIR)/usr/local/lib/bs_rx*
	rm $(DESTDIR)/usr/local/bin/bs-rx*
