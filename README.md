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

MEASURED at omega-mv `e5b32567a7aff3ce594e3254a622a846a6cd190b` (local run on a DGX Spark, 2026-10-27,
and the same numbers in CI on `ubuntu-24.04-arm`:
[run 40430760804](https://github.com/aien-dev/tree-sitter-omega/actions/runs/40430760804)):

| files | count | parse with zero ERROR/MISSING nodes |
|---|---:|---:|
| all `*.om` files | 811 | **789** |
| files `omc` accepts on its own | 393 | **393** (the CI gate: this must stay 100%) |
| files `omc` refuses | 418 | 396 parse clean, 22 show ERROR |

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
sh scripts/coverage.sh /tmp/omega-mv /tmp/omega-mv/seed/out/omc
```

The script prints one tab-separated line per file (`path omc=accept|refuse parse=clean|error
first-error-node`) and three `COVERAGE` lines, and exits 1 if any file `omc` accepts fails to parse
clean. Without an `omc` argument it reports the `all` row and marks the oracle rows NOT_RUN. `omc` is a
static AArch64 Linux program; on x86_64 the oracle needs qemu-user, and I have not measured that path.

## What the grammar knows, and where it stops

Omega is line oriented: one statement per line, words separated by blanks, `(` and `)` as words of
their own, `note` starting a comment line. The grammar gives structure to everything that is context
free:

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

- `tree-sitter test` runs [`test/corpus/`](test/corpus) (14 cases, 4 of them must produce ERROR) and the
  highlight assertions in [`test/highlight/`](test/highlight) (22 assertions in 2 files).
- CI regenerates `src/` with the pinned CLI and fails if it differs from the committed parser.
- Negative control 1: [`test/negative/malformed.om`](test/negative/malformed.om) must parse with ERROR.
- Negative control 2: the coverage gate, given an oracle that accepts everything, must fail on that
  malformed file.

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

## Human-Directed Agentic Engineering

Development follows Human-Directed Agentic Engineering (HDAE): humans define goals,
architecture, constraints, acceptance criteria, and stopping points; agents implement,
execute checks, diagnose failures, and revise within those boundaries. Human review
retains responsibility for claims, acceptance, and release decisions. This describes
the development method, not a change to runtime autonomy or historical evidence.

For the documented method and a systems-software case study, see Gregory M. Kurtzer
(2026), *Ginux: Building an Independent Kernel That Runs Linux Userspace through
Human-Directed Agentic Engineering*, technical report, v1, Zenodo,
<https://doi.org/10.5281/zenodo.23682548>.
