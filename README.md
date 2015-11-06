Cygwin Ports support for OPAM depext

Primitive wrapper around `cygcheck` and cygwin's
[setup-x86.exe](https://www.cygwin.com/) or
[setup-x86_64.exe](https://www.cygwin.com/setup-x86_64.exe).

## Preparation

* add `/usr/i686-w64-mingw32/sys-root/mingw/bin` or
  `/usr/x86_64-w64-mingw32/sys-root/mingw/bin` to your $PATH (in front
  of `/bin`, not after it!)

* `opam install depext depext-cygwinports`

## Usage

```bash
$ opam depext zarith mikmatch_pcre sqlite3
$ opam install zarith mikmatch_pcre sqlite3
```

## Links

* [Cygwin Ports](http://cygwinports.org/)
* [opam-depext](https://github.com/ocaml/opam-depext)
