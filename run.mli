type io_out =
    [ `Buffer of Buffer.t
    | `Fd of Unix.file_descr
    | `Fun of string -> unit
    | `Null
    | `Stderr
    | `Stdout ]



type io_in =
    [ `Fd of Unix.file_descr
(*    | `Fun of out_channel -> unit (* don't use this one *) *)
    | `Null
    | `String of string ]

val run :
  ?env:string array ->
  ?stdin:io_in ->
  ?stderr:io_out ->
  ?stdout:io_out ->
  string -> string list -> int
