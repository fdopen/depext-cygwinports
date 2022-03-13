.PHONY: all clean distclean install uninstall wrappers

PREFIX?= /usr/local
OCAMLFLAGS= -g #-bin-annot -safe-string -w A-4-39

OSTYPE:=$(shell ocamlc -config | awk '/^os_type/ { print $$2}')
CC:= $(shell ocamlc -config | awk '/^bytecomp_c_compiler/ {for(i=2;i<=NF;i++) printf "%s " ,$$i}')

ifeq ($(OSTYPE),$(filter $(OSTYPE),Win32 Cygwin))
all: cygwin-install.exe pkg-config.exe
else
all: cygwin-install.exe
endif

WRAPPERS=addr2line.exe ar.exe as.exe cc.exe cpp.exe dlltool.exe dllwrap.exe g++.exe gcc.exe gcov.exe ld.exe nm.exe objcopy.exe objdump.exe ranlib.exe strings.exe strip.exe windres.exe

wrappers: $(WRAPPERS)

SOURCES= config_file.mli config_file.ml run.mli run.ml cygwin.mli cygwin.ml

PACKS = str.cmxa unix.cmxa

cygwin-install.exe: $(SOURCES)
	ocamlopt $(OCAMLFLAGS) $(PACKS) $(SOURCES) -o $@

pkg-config.exe: symlink.c config.h
	$(CC) -s symlink.c -o pkg-config.exe

%.exe : %.c
	$(CC) -s $< -o $@

clean:
	@rm -f *.a *.o *.cm* *.dll *.so *.lib *.obj *.annot cygwin-install.exe pkg-config.exe $(WRAPPERS)

distclean: clean
	@rm -f config.h *.exe *~ depext-cygwin.conf depext-cygwin.raw $(WRAPPERS:.exe=.c)

install: 
	mkdir -p $(PREFIX)/bin $(PREFIX)/etc
	install -m 0755 pkg-config.exe cygwin-dl.exe cygwin-install.exe $(PREFIX)/bin
	install -m 0644 depext-cygwin.conf ports.gpg $(PREFIX)/etc

install-wrappers: wrappers
	mkdir -p $(PREFIX)/bin
	install -m 0755 $(WRAPPERS) $(PREFIX)/bin

uninstall:
	rm -f $(PREFIX)/bin/pkg-config.exe $(PREFIX)/bin/cygwin-dl.exe $(PREFIX)/bin/cygwin-install.exe $(PREFIX)/etc/depext-cygwin.conf $(PREFIX)/etc/ports.gpg
