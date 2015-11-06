exception Error of string

type mingw_arch =
  | Mingw32
  | Mingw64

type config = {
  cygwin_root: string;
  cygwin_arch: string;
  mingw_arch: mingw_arch;
  mirror_cygports: string;
  mirror_cygwin: string;
}

let re_newline = Str.regexp "\\([\r]*[\n]\\)+" ;;
let (//) = Filename.concat

let rex_mingw32 =
  Str.regexp "^mingw64-i686-\\([^ \t]+\\)[ \t]+\\([^ \t]+\\)[ \t]*"

let rex_mingw64 =
  Str.regexp "^mingw64-x86_64-\\([^ \t]+\\)[ \t]+\\([^ \t]+\\)[ \t]*"

let get_packages arch =
  let buf = Buffer.create 8192
  and ebuf = Buffer.create 10 in
  let ec =
    Run.run ~stderr:(`Buffer ebuf) ~stdout:(`Buffer buf) "cygcheck.exe" ["-cd"]
  in
  if ec <> 0 then
    raise (Error (Buffer.contents ebuf));
  let rex = match arch with
  | Mingw32 -> rex_mingw32
  | Mingw64 -> rex_mingw64
  in
  let f htl el =
    if Str.string_match rex el 0 then (
      let a = Str.matched_group 1 el in
      let b = Str.matched_group 2 el in
      Hashtbl.replace htl a b
    );
    htl
  in
  Str.split re_newline (Buffer.contents buf) |>
  List.fold_left f (Hashtbl.create 300)

let get_config fln =
  let open Config_file in
  let group = new group in
  let f ~key ~def help =
    new string_cp ~group [key] def help
  in
  let cyg_root =
    f ~key:"cygwin_root" ~def:"C:/cygwin" "Root folder of your cygwin installation" in
  let cyg_arch =
    f ~key:"cygwin_arch" ~def:"x86" "your cygwin architecture: cygwin-x86 or x86_64" in
  let mingw_arch =
    f ~key:"mingw_arch" ~def:"mingw" "your mingw-toolchain: mingw32 or mingw64" in
  let cyg_mirror =
    f
      ~def:"ftp://ftp-stud.hs-esslingen.de/pub/Mirrors/sources.redhat.com/cygwin/"
      ~key:"mirror_cygwin"
      "cygwin mirror for downloads"
  in
  let cyg_ports =
    f
      ~key:"mirror_ports"
      ~def:"ftp://ftp.gwdg.de/pub/linux/sources.redhat.com/cygwinports/"
      "cygwinports mirror"
  in
  if Sys.file_exists fln = false then
    raise (Error (fln ^ " not found"));
  let () = group#read ~no_default:true fln in
  let cygwin_root = cyg_root#get in
  if Sys.is_directory cygwin_root = false then
    raise (Error "invalid cygwin_root in config_file");
  let mingw_arch =
    match String.lowercase mingw_arch#get with
    | "mingw" | "mingw32" -> Mingw32
    | "mingw64" -> Mingw64
    | _ -> raise (Error "invalid mingw_arch in config file")
  in
  {
    cygwin_root;
    cygwin_arch = cyg_arch#get ;
    mingw_arch;
    mirror_cygports = cyg_ports#get;
    mirror_cygwin = cyg_mirror#get;
  }

let slash_rex = Str.regexp "/"
let winpath s =
  Str.global_replace slash_rex "\\\\" s

let bin_dir = Filename.dirname Sys.executable_name
let etc_dir = (Filename.dirname bin_dir) // "etc"

let get_cywin_args config =
  let key = Filename.concat etc_dir "ports.gpg" in
  [ "-K" ; winpath key ; "-W"; "-B" ; "-R" ; winpath config.cygwin_root ;
    "-l" ; winpath (config.cygwin_root // "packages") ;
    "-n" ; "-s" ; config.mirror_cygports ;
    "-s" ; config.mirror_cygwin ]

let gui config =
  let cygwin_setup = bin_dir // "cygwin-dl.exe" in
  let args = cygwin_setup::(get_cywin_args config) in
  let run = config.cygwin_root // "bin" // "run.exe" in
  let ec = Run.run run args in
  exit (ec)

let install config ipkgs =
  let f () =
    let pkgs_now = get_packages config.mingw_arch in
    fun e -> if Hashtbl.mem pkgs_now e then false else true
  in
  match List.filter (f ()) ipkgs with
  | [] -> ()
  | ipkgs ->
    let cygwin_setup = bin_dir // "cygwin-dl.exe" in
    let str_pkgs =
      let pr = match config.mingw_arch with
      | Mingw64 -> "mingw64-x86_64-"
      | Mingw32 -> "mingw64-i686-" in
      List.map ( fun x -> pr ^ x ) ipkgs |> String.concat ","
    in
    let args = "-P" :: str_pkgs :: "-q" :: (get_cywin_args config) in
    let ec = Run.run cygwin_setup args in
    match List.filter (f ()) ipkgs with
    | [] -> ()
    | _ ->
      let msg =
        if ec <> 0 then
          Printf.sprintf "cygwin setup exit code:%d\n" ec
        else
          "installation failed"
      in
      raise (Error msg)

let print_list arch =
  let buf = Buffer.create 128 in
  let f a b =
    Buffer.add_string buf a;
    Buffer.add_char buf ':';
    for _i = String.length a to 50 do
      Buffer.add_char buf ' ';
    done;
    Buffer.add_string buf b;
    Buffer.add_char buf '\n';
  in
  get_packages arch |> Hashtbl.iter f;
  Buffer.output_buffer stdout buf

let print_usage () =
  let name = Filename.basename Sys.executable_name in
  let name =
    if Filename.check_suffix name ".exe" then
      Filename.chop_suffix name ".exe"
    else
      name
  in
  Printf.eprintf
    "usage:\n'%s gui'\n'%s list'\n'%s status pkg'\n or\'%s install pkg1 pkg2 pkg3'"
    name name name name;
  prerr_endline "";
  exit 1

let print_status arch pkg =
  let htl = get_packages arch in
  if Hashtbl.mem htl pkg then (
    Printf.printf "installed:%s\n" pkg;
    exit 0
  )
  else (
    Printf.eprintf "not installed:%s\n" pkg;
    exit 1
  )

let () =
  let config =
    let fln = etc_dir // "depext-cygwin.conf" in
    try get_config fln
    with
    | exn ->
      Printf.eprintf
        "error while reading %s: %s\n"
        fln
        (Printexc.to_string exn);
      exit 1
  in
  match Array.to_list Sys.argv with
  | [] | _::[] -> print_usage ()
  | _::"gui"::[] -> gui config;
  | _::"list"::[] -> print_list config.mingw_arch
  | _::"install"::pkgs ->
    (try
      install config pkgs;
      exit 0
    with
    | Error s ->
      prerr_endline s;
      exit 1)
  | _::"status"::pkg::[] ->
    print_status config.mingw_arch pkg
  | _ -> print_usage ()
