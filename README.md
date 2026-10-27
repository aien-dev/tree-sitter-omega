# tree-sitter-omega

A [tree-sitter](https://tree-sitter.github.io/) grammar for Omega (`.om`), the language of
[aien-dev/omega-mv](https://github.com/aien-dev/omega-mv). It gives editors and tools a fast,
error-tolerant syntax tree of Omega source: blocks, declarations, statements, comments, text, numbers,
plus highlight and scope queries.

[![grammar](https://github.com/aien-dev/tree-sitter-omega/actions/workflows/ci.yml/badge.svg)](https://github.com/aien-dev/tree-sitter-omega/actions/workflows/ci.yml)

**Connected repos:** [aien-dev/omega-mv](https://github.com/aien-dev/omega-mv) (the language and
`omc`; this grammar is measured against commit `e5b32567` in [`omega.ref`](omega.ref)) ·
[aien-dev/vscode-omega](https://github.com/aien-dev/vscode-omega) (VS Code support whose TextMate
grammar follows this one).

## How well it parses real Omega

I measure the grammar against every `*.om` file in omega-mv, and I use the real compiler as the judge
of which files are valid. CI clones omega-mv at `omega.ref`, rebuilds `omc` from the 408-byte seed
(`sh seed/omega-from-seed.sh`), feeds each file to `omc`, and parses each file with this grammar. (The
seed chain's own limits: the 408 bytes are a binary written as commented hex text and turned into
bytes by a POSIX shell script whose `printf` is the one outside tool; the chain runs only on AArch64
Linux; matching the published omc hash is a fixed-output reproducibility check along one build path,
not diverse double compilation, and it does not prove omc correct.)

MEASURED at omega-mv `e5b32567a7aff3ce594e3254a622a846a6cd190b` (local run on a DGX Spark, 2026-10-28,
grammar of this commit; the file rows match CI on `ubuntu-24.04-arm` for the previous grammar,
[run 40430760804](https://github.com/aien-dev/tree-sitter-omega/actions/runs/40430760804)):

| files | count | parse with zero ERROR/MISSING nodes |
|---|---:|---:|
| all `*.om` files | 811 | **789** |
| files `omc` accepts on its own | 393 | **393** (the CI gate: this must stay 100%) |
| files `omc` refuses | 418 | 396 parse clean, 22 show ERROR |
| library units composed as their build scripts compose them ([`test/units/omega-mv.units`](test/units/omega-mv.units)) | 16, all accepted by `omc` | **16** (also a CI gate) |

Read the third row carefully. Most refused files are not broken syntax: library units such as
`om/tls/*.om` are compiled only after their build script prepends an `om2` line and concatenates them
with their neighbours (`om/tls/build.sh`), so `omc` refuses each one alone (for these, error 16), and
many test fixtures are refused for type or contract reasons that a syntax tree does not see. The 22
files that show ERROR are all deliberate syntax-error fixtures, for example a missing
`end`, an unclosed `(`, an upper-case word, or OM-1/OM-2 brace and bracket probes:

```
seed/omc/om2/s1/diag-eof.om          seed/omc/om2/s1/diag-noend.om
seed/omc/om2/s3/l-bad-noend.om       seed/omc/om2/s4/x-bad-nofn.om
seed/omc/tests/float/neg_dot.om      seed/omc/tests/paren/neg_unclosed.om
seed/omc/tests/struct/no_end.om      seed/qualification/om2/sec/s0s2/s0/upper.om
seed/qualification/om2/sec/s0s2/s1/{d-eof-left,d-eof-mid,d-eof-noend,d-unknown-args}.om
seed/qualification/om2/sec/s0s2/s2bnd/{om1,om2}-{brace,bracket,group-open,left-paren,short-eof}.om
```

Run it yourself on any AArch64 Linux machine:

```sh
git clone https://github.com/aien-dev/tree-sitter-omega && cd tree-sitter-omega
npm ci --ignore-scripts && (cd node_modules/tree-sitter-cli && node install.js)
sha256sum -c tree-sitter-cli.sha256       # the CLI binary install.js fetched (linux-arm64)
git clone https://github.com/aien-dev/omega-mv /tmp/omega-mv
git -C /tmp/omega-mv checkout --detach e5b32567a7aff3ce594e3254a622a846a6cd190b
(cd /tmp/omega-mv && sh seed/omega-from-seed.sh)
sh scripts/coverage.sh --omc /tmp/omega-mv/seed/out/omc --units test/units/omega-mv.units /tmp/omega-mv
```

`scripts/coverage.sh [--omc OMC] [--units MANIFEST]... [LABEL=]DIR...` measures any list of
directories (the label defaults to the directory's name). It prints one tab-separated line per file
(`path omc=accept|refuse parse=clean|error first-error-node`), one `unit:NAME` line per composed unit
(the first error is located as `in MEMBER:LINE`), and `COVERAGE` lines that end with every
directory's commit. A manifest line `unit NAME MEMBER...` concatenates its members in order, as
`cat` in a build script does; `each NAME LABEL:GLOB MEMBER...` makes one unit per matching file or
directory; a member is `LABEL:PATH` or `@om2` / `@ir` for that profile line. The script exits 1 if
any file or unit `omc` accepts fails to parse clean, and 2 on a usage error (an unknown label, a
member that matches no file). Without `--omc` it reports the `all` row and marks the oracle rows
NOT_RUN. `omc` is a static AArch64 Linux program; on x86_64 the oracle needs qemu-user, and I have not
measured that path.

### Every other public aien-dev repository with Omega in it

MEASURED 2026-10-28 on a DGX Spark with the same `omc` (sha256 `2c824805…029f`), one
`coverage.sh` run over omega-mv and the 25 other public aien-dev repositories that hold `*.om` files,
with every manifest in [`test/units/`](test/units). "Before" is the previous grammar (`9b63612`) under
the same script and manifests.

| repository @ commit | `*.om` files | `omc` accepts | accepted files clean, before → after |
|---|---:|---:|---:|
| omega-rosetta @ `a5b7330a` (branch `corpus/200`: 216 tasks; 47 exercises with stub, `test.om`, `.meta/example.om`) | 357 | 296 | 296 → **296**; all 357 clean |
| omega-bridge @ `358c5051` | 128 | 126 | 126 → **126** |
| CUDApp @ `e7b9e1fc` | 116 | 34 | 34 → **34** |
| sovereign-intelligence @ `d0f6939a` | 95 | 52 | 52 → **52** |
| aienos.com @ `ee3833cf` | 29 | 14 | 13 → **14** |
| aien-architecture-mv @ `df796a8a` | 13 | 12 | 12 → **12** |
| omnet @ `83f605b1` | 47 | 9 | 9 → **9** |
| babel @ `13ad42d9` (with `build/`, from its `build.sh`) | 10 | 2 | 1 → **2** |
| AienOS-nv @ `240ee9af` | 9 | 2 | 2 → **2** |
| omega-harness @ `82b89c28` | 2 | 2 | 2 → **2** |
| omega-blas, omega-dnn, omega-gpu-bench, omega-kernel-template, omega-packages, omega-bridge-kit | 7 | 6 | 6 → **6** |
| cortex, omtex, omega-gpu-driver, aien-sovereign-core-mv, synapse-{board,claims,map,mcp,pulse} | 75 | 0 | — |
| **all, with omega-mv** | **1699** | **948** | 946 → **948** |
| composed units in `test/units/` (94 of them omega-rosetta exercises: stub + test, example + test) | 169 | 164 | 160 → **164** |

On omega-rosetta `main` (`60dcf9b2`, 39 files, 34 accepted) the result was the same: 34 → 34.

Files `omc` refuses alone are mostly library units and exercise parts; the manifests compile them the
way their repositories' build scripts do, and those 164 units cover 209 of them. The 5 refused units
are the synapse tools, whose sources are marked work in progress (`omc` errors 3, 9, 12 and 23 at
omega-mv `e5b32567`). Beyond the 22 fixtures above, two refused files show ERROR: synapse-map
`src/40-xerj.om` line 134 (a stray `end`; its unit is refused with error 3) and aien-architecture-mv
`tools/zero-legacy/fixtures/tree/src/sh.om` (a shell script fixture).

The two defects these runs found are fixed in this grammar: the `note` comment was lexed inside text
(`" note "`, `"x\nnote add three\nfn"`: a MISSING `"` in seven files and four units), and a name that
starts with `note` (`notes`, `noted`) was split into a comment and a name without any ERROR node
(`omc` ends the `note` word at a blank, a parenthesis or the end). Both are cases in
[`test/corpus/notes.txt`](test/corpus/notes.txt).

## What the grammar knows, and where it stops

Omega is line oriented: one statement per line, words separated by blanks, `(` and `)` as words of
their own, `note` starting a comment line. As in `omc`, the comment word is exactly `note`, ended by a
blank, a parenthesis or the end of the line (`notes` and `noted` are names), and a `note` inside text
is text. The grammar gives structure to everything that is context free:

- `fn ... to ...` / `export fn` definitions with parameter list and return type, closed by `end`
- `if` / `else`, `while` (with an optional `bound`), `for`, `layout` with `field` lines, one-line `struct ... end`
- `global`, `text`, `const`, `abstract`, `holds` declarations and the `om2 ...` / `ir` profile line
- `ret`, `put`, `trap`, `exit`, `break`, `continue`, `name = value` assignments and call lines
- integers (decimal, `0x` hex), floats (`1.5`, `2.5e-3`, `3f32`), text with escapes, `*` unsized views

Values stay a flat sequence of words. Omega values are prefix expressions whose arity depends on each
word and, for calls, on the callee's signature, so a context-free grammar cannot build the call tree
honestly; I leave that to `omc`. Operator, type, contract and host words (`add`, `uint`, `requires`,
`fopen`, ...) are ordinary identifiers in the tree and get their colour from
[`queries/highlights.scm`](queries/highlights.scm), because OM-1 units may use OM-2 words such as `open`
or `field` as names; a name a declaration defines (`fn rotr`, `global out`, `at = ...`) keeps the
definition's colour. A word the Omega lexer would reject, like `0xG1`, can still split into tokens here
without an ERROR node. This is a syntax tree for editors, not a checker; `omc` remains the authority.

## Tests and CI

- `tree-sitter test` runs [`test/corpus/`](test/corpus) (16 cases, 4 of them must produce ERROR) and the
  highlight assertions in [`test/highlight/`](test/highlight) (22 assertions in 2 files).
- CI regenerates `src/` with the pinned CLI and fails if it differs from the committed parser.
- The coverage gate: every omega-mv file `omc` accepts, and the 16 units in
  [`test/units/omega-mv.units`](test/units/omega-mv.units), must parse clean.
- Negative control 1: [`test/negative/malformed.om`](test/negative/malformed.om) must parse with ERROR.
- Negative control 2: the coverage gate, given an oracle that accepts everything, must fail on that
  malformed file.
- Negative control 3: the same fake oracle and a unit that composes the malformed file with a valid
  one must fail as `unit:... parse=error ... in malformed.om:<line>`, naming the malformed member.

## Use it

The `tree-sitter.json` metadata, generated parser and bindings for C, Go, Node, Python, Rust and
Swift are in this repository (from `tree-sitter init`). CI builds the parser through `tree-sitter
test`; I have not yet published the bindings to npm, crates.io or PyPI, and I have not yet run them
inside Neovim, Helix or Zed. For VS Code, use [aien-dev/vscode-omega](https://github.com/aien-dev/vscode-omega).

## Editors and registries

Where I checked each project's rule for taking a new grammar (2026-10-27), and where Omega stands:

| project | rule | status |
|---|---|---|
| GitHub Linguist | [CONTRIBUTING: usage requirements](https://github.com/github-linguist/linguist/blob/main/CONTRIBUTING.md#language-extension-and-filename-usage-requirements): at least 2000 files per extension indexed in the last year, spread across many users; the language owner's own repos are filtered out | not met. GitHub code search on 2026-10-27: `extension:om "fn main to int"` gives 718 files, and `-org:aien-dev` gives 0. No PR until Omega is used widely outside my repos |
| nvim-treesitter | [CONTRIBUTING: Parsers](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/CONTRIBUTING.md#parsers): the filetype must be detected by Neovim nightly, the parser tested by users, CI via tree-sitter/workflows, queries checked by `ts_query_ls` | gated: Neovim does not detect `.om` as Omega yet, and the grammar has no outside users yet |
| Helix | [Adding new languages](https://github.com/helix-editor/helix/blob/master/book/src/guides/adding_languages.md): a `languages.toml` entry, Helix-named queries in `runtime/queries/<name>/`, `cargo xtask docgen` | no written usage gate; not submitted, because I have not run the grammar inside Helix (Helix uses its own capture names) |
| Zed | [Publishing prerequisites](https://zed.dev/docs/extensions/publishing/prerequisites): a Zed extension repo, tested manually in Zed at the submitted commit, then a PR to zed-industries/extensions | gated: needs a manual test in Zed, which I have not run |

## Foreign dependencies

These are packaging and editor glue, not part of Omega:

| dependency | version | what it does here |
|---|---|---|
| tree-sitter-cli (npm, Rust binary) | 0.27.1, linux-arm64 binary sha256 in `tree-sitter-cli.sha256` | generates `src/parser.c` from `grammar.js`, runs the tests, parses the corpus |
| Node.js | 24 | evaluates `grammar.js` and runs the CLI wrapper |
| tree-sitter (npm), node-addon-api, node-gyp-build, prebuildify | as locked in `package-lock.json` | Node binding scaffold from `tree-sitter init`; not used by CI |

The Omega side has no replacement yet: an Omega-native parser generator would be the
first-party path, and until it exists the generated C parser is the tree-sitter project's format.

## Licence

Apache-2.0 WITH LLVM-exception. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
