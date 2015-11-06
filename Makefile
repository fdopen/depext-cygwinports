.PHONY: all clean distclean install uninstall

PREFIX?= /usr/local
OCAMLFLAGS= -g -bin-annot -safe-string -w A-4-39

OSTYPE:=$(shell ocamlc -config | awk '/^os_type/ { print $$2}')
CC:= $(shell ocamlc -config | awk '/^bytecomp_c_compiler/ {for(i=2;i<=NF;i++) printf "%s " ,$$i}')

ifeq ($(OSTYPE),$(filter $(OSTYPE),Win32 Cygwin))
all: cygwin-install.exe pkg-config.exe
else
all: cygwin-install.exe
endif

SOURCES= run.mli run.ml cygwin.mli cygwin.ml

PACKS = str,unix,config-file,bytes

cygwin-install.exe: $(SOURCES)
	ocamlfind ocamlopt -package $(PACKS) -linkpkg $(SOURCES) -o $@

pkg-config.exe: symlink.c config.h
	$(CC) -s symlink.c -o pkg-config.exe

clean::
	@rm -f *.a *.o *.cm* *.dll *.so *.lib *.obj *.annot cygwin-install.exe pkg-config.exe

distclean:: clean
	@rm -f config.h cygwin-dl.exe *~ depext-cygwin.conf

install: 
	mkdir -p $(PREFIX)/bin $(PREFIX)/etc
	install -m 0755 pkg-config.exe cygwin-dl.exe cygwin-install.exe $(PREFIX)/bin
	install -m 0644 depext-cygwin.conf ports.gpg $(PREFIX)/etc

uninstall:
	rm -f $(PREFIX)/bin/pkg-config.exe $(PREFIX)/bin/cygwin-dl.exe $(PREFIX)/bin/cygwin-install.exe $(PREFIX)/etc/depext-cygwin.conf $(PREFIX)/etc/ports.gpg
