### The project name
PROJECT=wetri

### Dependencies
DEP_BINS=bash cat seq ps rm

### Destination Paths
D_BIN=/usr/local/bin
D_DOC=/usr/local/share/doc/$(PROJECT)

### Lists of files to be installed
F_DOCS=ABOUT README LICENSE CHANGES

###############################################################################

all: install

install: test bin docs

test:
	@echo "==> Checking for required external dependencies"
	for bindep in $(DEP_BINS) ; do \
		which $$bindep > /dev/null || exit 1 ; \
	done

	@echo "==> It all looks good Captain!"

bin: test src/$(PROJECT).sh
	install -D -m 0755 src/$(PROJECT).sh $(DESTDIR)$(D_BIN)/$(PROJECT)

docs: $(F_DOCS)
	for f in $(F_DOCS) ; do \
		install -D -m 0644 $$f $(DESTDIR)$(D_DOC)/$$f || exit 1 ; \
	done

uninstall:
	rm -f $(DESTDIR)$(D_BIN)/$(PROJECT)
	rm -f $(DESTDIR)$(D_DOC)/*
	rmdir $(DESTDIR)$(D_DOC)/
