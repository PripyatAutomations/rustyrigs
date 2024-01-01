# basic makefile for installing/uninstall grigs
PREFIX ?= /usr
RES_DIR ?= ${PREFIX}/share/grigs
DOC_DIR ?= ${PREFIX}/share/doc
BIN_DIR ?= ${PREFIX}/bin
LIB_DIR ?= ${PREFIX}/lib/grigs

# Documentation 
DOCS := $(wildcard doc/*)

# Libraries (perl modules)
LIBS := $(wildcard ./*.pm)

# Resources (icons, data files, etc)
RSRC := $(wildcard res/*)

# files to remove in 'make clean'
clean_files := $(wildcard *~ *.tmp *.out x y z)

##############################################################

all: world

world:
	@echo "Nothing to build right now."

# This cleans up any temporary files/build artifacts, etc
clean:
	${RM} ${clean_files}

###########
# Install #
###########
install: install-dirs install-lib install-bin install-docs install-res

uninstall: uninstall-bin uninstall-lib uinstall-res uninstall-docs

install-dirs:
	install -d -m 0755 ${DOC_DIR}
	install -d -m 0755 ${LIB_DIR}
	install -d -m 0755 ${RES_DIR}

install-bin:
	install -m 0755 grigs.pl ${BIN_DIR}/grigs

uninstall-bin:
	${RM} ${BIN_DIR}/grigs

install-docs:
ifneq (${DOCS},)
	install -m 0644 ${DOCS} ${DOC_DIR}
endif

uninstall-docs:
ifneq (${DOCS},)
	${RM} $(foreach x,${DOCS},${DOC_DIR}/${x})
endif

install-res: $(addprefix ${RES_DIR}/, $(notdir ${RSRC_FILES})) $(addprefix ${RES_DIR}/, $(RSRC_DIRS))

install-lib:
	install -m 0644 ${LIBS} ${LIB_DIR}

uninstall-libs:
	${RM} $(foreach x,${LIBS},${LIB_DIR}/${x})

${RES_DIR}/%: res/%
	@install -m 0644 $< $@

${RES_DIR}/%/: res/%/
	@install -d -m 0755 $<

uninstall-res:
ifneq (${RSRC},)
	${RM} $(foreach x,${RSRC},${RES_DIR}/${x})
endif


######################
# Build .deb package #
######################
deb:
