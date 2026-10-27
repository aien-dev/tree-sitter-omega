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

MEASURED at omega-mv `e5b32567a7aff3ce594e3254a622a846a6cd190b` (local run on a DGX Spark, 2026-10-27;
the CI run on `ubuntu-24.04-arm` repeats it on every push):

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
or `field` as names. A word the Omega lexer would reject, like `0xG1`, can still split into tokens here
without an ERROR node. This is a syntax tree for editors, not a checker; `omc` remains the authority.

## Tests and CI

- `tree-sitter test` runs [`test/corpus/`](test/corpus) (14 cases, 4 of them must produce ERROR) and the
  highlight assertions in [`test/highlight/`](test/highlight).
- CI regenerates `src/` with the pinned CLI and fails if it differs from the committed parser.
- Negative control 1: [`test/negative/malformed.om`](test/negative/malformed.om) must parse with ERROR.
- Negative control 2: the coverage gate, given an oracle that accepts everything, must fail on that
  malformed file.

## Use it

The `tree-sitter.json` metadata, generated parser and bindings for C, Go, Node, Python, Rust and
Swift are in this repository (from `tree-sitter init`). CI builds the parser through `tree-sitter
test`; I have not yet published the bindings to npm, crates.io or PyPI, and I have not yet run them
inside Neovim, Helix or Zed. For VS Code, use [aien-dev/vscode-omega](https://github.com/aien-dev/vscode-omega).

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
