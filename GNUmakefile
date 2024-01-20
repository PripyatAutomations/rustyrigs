# basic makefile for installing/uninstall rustyrigs
PREFIX ?= /usr
RES_DIR ?= ${PREFIX}/share/rustyrigs
DOC_DIR ?= ${PREFIX}/share/doc
BIN_DIR ?= ${PREFIX}/bin
LIB_DIR ?= ${PREFIX}/lib/rustyrigs

NEED_PKG := libgtk3-perl libglib-perl libyaml-perl libhamlib-perl
DEV_NEED_PKG += devscripts dh-make-perl libperl-critic-community-perl libperl-critic-perl

# Documentation
DOCS := $(wildcard doc/*)

# Libraries (perl modules)
LIBS := $(wildcard lib/*.pm lib/RustyRigs/*.pm)

# Resources (icons, data files, etc)
RSRC := $(wildcard res/*)

# files to remove in 'make clean'
clean_files := $(wildcard *~ *.tmp *.out x y z)

SUDO := $(shell command -v sudo 2> /dev/null)

ifneq (root, $(shell whoami))
ifndef SUDO
$(warning sudo is not installed or not found in PATH)
#else
#$(info sudo found at $(SUDO))
endif
endif

bin := rustyrigs

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

uninstall: uninstall-bin uninstall-lib uninstall-res uninstall-docs

install-dirs:
	${SUDO} install -d -m 0755 ${DOC_DIR}
	${SUDO} install -d -m 0755 ${LIB_DIR}
	${SUDO} install -d -m 0755 ${RES_DIR}

install-bin:
	${SUDO} install -m 0755 ${bin} ${BIN_DIR}/${bin}

uninstall-bin:
	${SUDO} ${RM} ${BIN_DIR}/rustyrigs

install-docs:
ifneq (${DOCS},)
	${SUDO} install -m 0644 ${DOCS} ${DOC_DIR}
endif

uninstall-docs:
ifneq (${DOCS},)
	${SUDO} ${RM} $(foreach x,${DOCS},${DOC_DIR}/${x})
endif

#install-res: $(addprefix ${RES_DIR}/, $(notdir ${RSRC})) $(addprefix ${RES_DIR}/, $(RSRC_DIRS))
install-res: $(addprefix ${RES_DIR}/,$(notdir ${RSRC}))

install-lib:
	${SUDO} install -d -m 0755 ${LIB_DIR}
	${SUDO} install -m 0644 ${LIBS} ${LIB_DIR}

uninstall-lib:
	${SUDO} ${RM} ${LIB_DIR}
#	${SUDO} ${RM} $(foreach x,$(notdir ${LIBS}),${LIB_DIR}/${x})

${RES_DIR}/%: res/%
	@${SUDO} install -m 0644 $< $@

${RES_DIR}/%/: res/%/
	@${SUDO} install -d -m 0755 $<

uninstall-res:
ifneq (${RSRC},)
	${SUDO} ${RM} $(foreach x,${RSRC},${RES_DIR}/${x})
endif

###############
# Maintenance #
###############
critic:
	perlcritic rustyrigs $(shell find lib -name \*.pm)

################
# Debian stuff #
################
deb: install-deb-deps
dev-dev: install-deb-dev-deps

install-deb-deps:
	${SUDO} apt install -y ${NEED_PKG}
