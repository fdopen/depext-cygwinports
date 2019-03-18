#include <windows.h>
#include <process.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "config.h"

#define SHELL_SPECIAL_CHARS "\"\\ \001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
#define SHELL_SPACE_CHARS " \001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"

static void *
xmalloc(size_t size)
{
  void * ret = malloc(size);
  if ( ret == NULL ){
    fputs("No memory\n",stderr);
    exit(1);
  }
  return ret;
}

static char *
xstrdup(char *p)
{
  char * ret = _strdup(p);
  if ( ret == NULL ){
    fputs("No memory\n",stderr);
    exit(1);
  }
  return ret;
}

static char **
prepare_spawn (char **argv)
{
  size_t argc;
  char **new_argv;
  size_t i;

  /* Count number of arguments.  */
  for (argc = 0; argv[argc] != NULL; argc++)
    ;

  /* Allocate new argument vector.  */
  new_argv = xmalloc((argc + 1) * sizeof *new_argv );

  /* Put quoted arguments into the new argument vector.  */
  for (i = 0; i < argc; i++)
    {
      const char *string = argv[i];

      if (string[0] == '\0')
        new_argv[i] = xstrdup ("\"\"");
      else if (strpbrk (string, SHELL_SPECIAL_CHARS) != NULL)
        {
          int quote_around = (strpbrk (string, SHELL_SPACE_CHARS) != NULL);
          size_t length;
          unsigned int backslashes;
          const char *s;
          char *quoted_string;
          char *p;

          length = 0;
          backslashes = 0;
          if (quote_around)
            length++;
          for (s = string; *s != '\0'; s++)
            {
              char c = *s;
              if (c == '"')
                length += backslashes + 1;
              length++;
              if (c == '\\')
                backslashes++;
              else
                backslashes = 0;
            }
          if (quote_around)
            length += backslashes + 1;

          quoted_string = xmalloc (length + 1);

          p = quoted_string;
          backslashes = 0;
          if (quote_around)
            *p++ = '"';
          for (s = string; *s != '\0'; s++)
            {
              char c = *s;
              if (c == '"')
                {
                  unsigned int j;
                  for (j = backslashes + 1; j > 0; j--)
                    *p++ = '\\';
                }
              *p++ = c;
              if (c == '\\')
                backslashes++;
              else
                backslashes = 0;
            }
          if (quote_around)
            {
              unsigned int j;
              for (j = backslashes; j > 0; j--)
                *p++ = '\\';
              *p++ = '"';
            }
          *p = '\0';

          new_argv[i] = quoted_string;
        }
      else
        new_argv[i] = (char *) string;
    }
  new_argv[argc] = NULL;

  return new_argv;
}

static int is_binary(char * path)
{
  DWORD bin;
  if  ( GetBinaryType (path, &bin) ){
    switch(bin){
    case SCS_32BIT_BINARY: /* fall */
    case SCS_64BIT_BINARY: /* fall */
    case SCS_DOS_BINARY: /* fall */
    case SCS_WOW_BINARY: /* fall */
      return 1;
    }
  }
  return 0;
}

int
main(int argc, char **argv)
{
  char **new_argv;
  char **new_argv_real;
  int i;
  int nargc = argc == 0 ? (argc + 2) : (argc + 1);
  int code;
  int pkg_config_is_binary = 0;
  char * pkg_config = PKG_CONFIG;
  char * pkgconf = PKGCONF;

  if ( is_binary(pkg_config) ) {
    new_argv = xmalloc(nargc * sizeof (char *) );
    new_argv[0] = pkg_config;
    for ( i=1 ; i < argc ; ++i ){
      new_argv[i] = argv[i];
    }
    new_argv[nargc-1] = NULL;
    new_argv_real = prepare_spawn(new_argv);
    code = _spawnv(_P_WAIT, pkg_config , (const char **) new_argv_real );
  }
  else if ( is_binary(pkgconf) ) {
    ++nargc;
    new_argv = xmalloc(nargc * sizeof (char *) );
    new_argv[0] = pkgconf;
#ifdef __i386__
    new_argv[1] = "--personality=i686-w64-mingw32";
#else
    new_argv[1] = "--personality=x86_64-w64-mingw32";
#endif
    for ( i=1 ; i < argc ; ++i ){
      new_argv[i+1] = argv[i];
    }
    new_argv[nargc-1] = NULL;
    new_argv_real = prepare_spawn(new_argv);
    code = _spawnv(_P_WAIT, pkgconf , (const char **) new_argv_real );
  }
  else {
    fputs("pkg-config is not installed. Install it with 'opam depext conf-pkg-config'\n",stderr);
    exit(2);
  }
  if (code == -1) {
    perror("Cannot exec pkg-config");
    exit(127);
  }
  exit(code);
}
