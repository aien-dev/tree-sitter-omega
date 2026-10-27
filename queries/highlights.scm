; Omega (.om) highlights. Word lists come from the reserved-word table in aien-dev/omega-mv
; seed/omc/omc.om (fn kw, fn kw2) and docs/one_layer/OMEGESE.md. When several patterns match one node,
; the later pattern wins (tree-sitter CLI 0.27, Neovim), so the generic identifier capture comes first
; and the word lists come last.

(identifier) @variable

; ---- definitions ----
(function_definition
  name: (identifier) @function)

(global_declaration
  name: (identifier) @variable)

(text_declaration
  name: (identifier) @variable)

(const_declaration
  name: (identifier) @constant)

(struct_declaration
  name: (identifier) @type.definition)

(layout_declaration
  name: (identifier) @type.definition)

(abstract_declaration
  name: (identifier) @type.definition)

(holds_declaration
  name: (identifier) @type)

(field_declaration
  name: (identifier) @variable.member)

(for_statement
  counter: (identifier) @variable)

(assignment
  name: (identifier) @variable)

; The first word of a line that is not an assignment is a call (or an assignment written without `=`).
(expression_statement
  (expression
    .
    (identifier) @function.call))

(parameter_list
  (identifier) @variable.parameter)

; ---- words that are identifiers to the grammar ----
((identifier) @boolean
  (#any-of? @boolean "true" "false"))

((identifier) @type.builtin
  (#any-of? @type.builtin
    "bool" "uchar" "u8" "ushort" "u16" "uint" "u32" "ulong" "u64" "byte" "i8" "short" "i16" "int"
    "i32" "long" "i64" "f32" "f64" "void"))

((identifier) @keyword.operator
  (#any-of? @keyword.operator
    "add" "sub" "mul" "div" "rem" "and" "or" "xor" "shl" "shr" "eq" "ne" "lt" "le" "gt" "ge" "neg"
    "not" "rotr" "rotl" "bitcast" "fsqrt" "fabs" "fmin" "fmax" "sizeof" "offsetof"))

((identifier) @keyword.modifier
  (#any-of? @keyword.modifier
    "view" "edit" "own" "out" "fresh" "inline" "unroll" "at" "little" "big" "ops"))

((identifier) @keyword
  (#any-of? @keyword "requires" "ensures" "invariant" "new" "free" "seal" "open" "part"))

((identifier) @variable.builtin
  (#eq? @variable.builtin "result"))

; Host and memory words: built-in operations that take values.
((identifier) @function.builtin
  (#any-of? @function.builtin
    "get" "len" "read" "write" "pread" "pwrite" "cwd" "readlnk" "sockopt" "random" "envcnt"
    "envread" "chdir" "ftrunc" "stat" "link" "symlnk" "chmod" "faccess" "getuid" "geteuid" "getgid"
    "getegid" "lstat" "truncate" "chown" "fchdir" "getppid" "umask" "fdsync" "memfd" "setsid"
    "getpgid" "setpgid" "getsid" "syncfs" "shutdown" "devctl" "mapnew" "mapdrop" "mapread"
    "mapwrite" "devcall" "uvmctl" "mapaddr" "mapget" "mapset" "maphold" "mapbind" "flock" "sockname"
    "realns" "execprog" "renames" "rmdir" "killpid" "pipefds" "getpid" "waitio" "getdnts" "connect"
    "bind" "waitpid" "fstat" "recv" "send" "sleepns" "argcnt" "argread" "fclose" "fsync" "fchmod"
    "fseek" "socknew" "listen" "accept" "fork" "dupfd" "monons" "fopen" "unlink" "makedir"
    "peercred" "pollfds" "sendmsg"))

(comment) @comment

; ---- structural keywords (tokens in the grammar) ----
[
  "fn"
  "to"
  "end"
  "global"
  "text"
  "const"
  "struct"
  "layout"
  "field"
  "abstract"
  "holds"
  "export"
] @keyword

[
  "if"
  "else"
] @keyword.conditional

[
  "while"
  "for"
  "bound"
  (break_statement)
  (continue_statement)
] @keyword.repeat

[
  "ret"
  "exit"
  "trap"
] @keyword.return

"put" @function.builtin

(profile
  name: _ @keyword.directive
  option: (identifier) @keyword.directive)

(profile
  name: _ @keyword.directive)

"=" @operator

[
  "("
  ")"
] @punctuation.bracket

; ---- literals ----
(integer) @number

(float) @number.float

(string) @string

(escape_sequence) @string.escape

(unsized) @type
