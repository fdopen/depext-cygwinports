#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <process.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <shellapi.h>
#include <time.h>

#define TOOLKIT_PREFIX "@TOOLKIT_PREFIX@"
#define PROG "@PROG@"
#define NEW_ARG0 ( strcmp(PROG,"cc") ? L"@BIN_PATH@\\@TOOLKIT_PREFIX@@PROG@.exe" : L"@BIN_PATH@\\@TOOLKIT_PREFIX@g@PROG@.exe")

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

/* wchar version now
   TODO: update symlink.c, use new code */
static WCHAR **
prepare_spawn (WCHAR  **orig_argv)
{
  int i;
  int argc = 0;
  WCHAR ** new_argv = NULL;

  for (argc = 0; orig_argv[argc]; argc++);

  new_argv = xmalloc(sizeof (WCHAR *) * (argc+1));

  for (i = 0; i < argc; i++){
    size_t len = 0;
    WCHAR *p = orig_argv[i];
    WCHAR *q;
    BOOLEAN do_quote = !*p;

    while (*p){
      if (*p == ' ' || *p == '\t'){
        do_quote = TRUE;
      }
      else if (*p == '"'){
        len++;
      }
      else if (*p == '\\'){
        WCHAR *r = p;
        while (*r && *r == '\\'){
          r++;
        }
        if (*r == '"'){
          len++;
        }
      }
      len++;
      p++;
    }
    q = xmalloc(sizeof(WCHAR) * (len + do_quote*2 + 1));
    new_argv[i] = q;
    p = orig_argv[i];

    if (do_quote){
      *q++ = '"';
    }

    while (*p){
      if (*p == '"'){
        *q++ = '\\';
      }
      else if (*p == '\\') {
        WCHAR *r = p;
        while (*r && *r == '\\'){
          r++;
        }
        if (*r == '"'){
          *q++ = '\\';
        }
      }
      *q++ = *p;
      p++;
    }

    if (do_quote){
      *q++ = '"';
    }
    *q++ = '\0';
  }
  new_argv[argc] = NULL;
  return new_argv;
}

static void
do_log(char **argv)
{
  enum {BUF_SIZE = 32768};
  enum {TBUF_SIZE = 26};
  char timeline[TBUF_SIZE+1] = {0};
  struct _timeb struct_timeb;
  wchar_t buf_value[BUF_SIZE];
  char buf_directory[BUF_SIZE];
  DWORD len = GetEnvironmentVariableW(L"DEPEXT_WRAPPER_LOG",
                                      buf_value,
                                      BUF_SIZE - 1);
  char *nl;
  if ( len == 0 || len >= BUF_SIZE - 1 ){
    return;
  }
  buf_value[BUF_SIZE-1] = 0;

  if (_ftime64_s(&struct_timeb)){
    return;
  }
  if ( ctime_s(timeline, TBUF_SIZE, &(struct_timeb.time)) ){
    return;
  }
  timeline[TBUF_SIZE]='\0';
  nl = strchr(timeline,'\n');
  if ( nl == NULL){
    return;
  }
  *nl = '\0';
  FILE * fp = _wfopen(buf_value,L"a");
  if ( fp == NULL ){
    return;
  }
  fputs(timeline,fp);
  fputs("|"PROG"|",fp);

  len = GetCurrentDirectoryA(BUF_SIZE - 1 , buf_directory);
  if ( len == 0 || len >= BUF_SIZE - 1 ){
    fputs("(unknown_dir)",fp);
  }
  else {
    buf_directory[len] = '\0';
    fputs(buf_directory,fp);
    fputc('|',fp);
  }
  while ( *argv ){
    fputs(" \"",fp);
    fputs(*argv,fp);
    fputs("\"",fp);
    ++argv;
  }
  fputc('\n',fp);
  fclose(fp);
}

int
main(int ascii_argc, char ** ascii_argv)
{
  WCHAR **new_argv;
  WCHAR **new_argv_real;
  int i;
  int code;
  int argc = 0;
  WCHAR *d_cmdline[2];
  WCHAR ** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  DWORD bin;
  BOOLEAN is_binary = FALSE;

  (void)ascii_argc;
  do_log(ascii_argv);

  if  ( GetBinaryTypeW (NEW_ARG0, &bin) ){
    switch(bin){
    case SCS_32BIT_BINARY: /* fall */
    case SCS_64BIT_BINARY: /* fall */
    case SCS_DOS_BINARY: /* fall */
    case SCS_WOW_BINARY: /* fall */
      is_binary = TRUE;
    }
  }
  if ( is_binary == FALSE ){
    fputs(TOOLKIT_PREFIX PROG "not available \n",stderr);
    exit(2);
  }

  if ( argv == NULL ){
    d_cmdline[0]= NEW_ARG0;
    d_cmdline[1]= L'\0';
    argv = d_cmdline;
    argc = 1;
  }
  new_argv = xmalloc( (1+argc) * sizeof (WCHAR *));
  new_argv[0] = NEW_ARG0;
  for ( i=1 ; i < argc ; ++i ){
    new_argv[i] = argv[i];
  }
  new_argv[argc] = NULL;
  new_argv_real = prepare_spawn(new_argv);
  code = _wspawnv(_P_WAIT, NEW_ARG0 , (const WCHAR **) new_argv_real );
  if (code == -1) {
    perror("Cannot exec pkg-config");
    exit(127);
  }
  exit(code);
  return code;
}
