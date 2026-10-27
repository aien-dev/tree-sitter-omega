#!/bin/sh
# Parse-coverage of this grammar over the real Omega corpus: every *.om file in an aien-dev/omega-mv
# checkout. Usage:
#   scripts/coverage.sh <omega-mv-dir> [omc]
# stdout, one line per file (tab separated):  <path> omc=<accept|refuse|not_run> parse=<clean|error> <first ERROR/MISSING node or ->
# then three summary lines:
#   COVERAGE all <clean>/<total>
#   COVERAGE omc-accepted <clean>/<accepted>     (only with an omc: files the real compiler accepts)
#   COVERAGE omc-refused-flagged <error>/<refused> (refused files the grammar also marks; this grammar
#                                                  is not a type checker, so most refusals parse clean)
# With an omc (AArch64 Linux; seed/out/omc after `sh seed/omega-from-seed.sh`), each file is fed to it
# on stdin and its exit status decides accept (0) or refuse (non-zero).
# Exit status: 0 when every omc-accepted file parses clean (or no omc was given), 1 otherwise,
# 2 on a usage error. Diagnostics go to stderr.
set -eu
src=${1:?usage: coverage.sh <omega-mv-dir> [omc]}
omc=${2:-}
here=$(cd "$(dirname "$0")/.." && pwd)
ts="$here/node_modules/.bin/tree-sitter"
[ -x "$ts" ] || { echo "coverage.sh: $ts missing; run npm ci" >&2; exit 2; }
[ -z "$omc" ] || [ -x "$omc" ] || { echo "coverage.sh: omc '$omc' is not executable" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$src" && find . -name '*.om' -type f | sed 's|^\./||' | LC_ALL=C sort) >"$work/rel"
[ -s "$work/rel" ] || { echo "coverage.sh: no .om files under $src" >&2; exit 2; }
sed "s|^|$src/|" "$work/rel" >"$work/abs"
# --quiet prints only the files whose tree holds an ERROR or MISSING node, with the first one.
"$ts" parse -p "$here" --quiet --paths "$work/abs" 2>"$work/parse.err" >"$work/parse.out" || true
total=0; clean=0; acc=0; acc_clean=0; ref=0; ref_flag=0
while IFS= read -r f; do
  total=$((total + 1))
  node=$(awk -v p="$src/$f" -F'\t' '{ sub(/ +$/, "", $1) } $1 == p { n = $NF; sub(/^[^(]*/, "", n); print n; exit }' "$work/parse.out")
  if [ -n "$node" ]; then parse=error; else parse=clean; node=-; clean=$((clean + 1)); fi
  if [ -n "$omc" ]; then
    if timeout 20 "$omc" <"$src/$f" >/dev/null 2>&1; then
      verdict=accept; acc=$((acc + 1)); [ "$parse" = error ] || acc_clean=$((acc_clean + 1))
    else
      verdict=refuse; ref=$((ref + 1)); [ "$parse" = clean ] || ref_flag=$((ref_flag + 1))
    fi
  else
    verdict=not_run
  fi
  printf '%s\tomc=%s\tparse=%s\t%s\n' "$f" "$verdict" "$parse" "$node"
done <"$work/rel"
pin=$(git -C "$src" rev-parse HEAD 2>/dev/null || echo unpinned)
echo "COVERAGE all $clean/$total omega-mv=$pin"
if [ -n "$omc" ]; then
  echo "COVERAGE omc-accepted $acc_clean/$acc omega-mv=$pin"
  echo "COVERAGE omc-refused-flagged $ref_flag/$ref omega-mv=$pin"
  [ "$acc_clean" = "$acc" ] || exit 1
else
  echo "COVERAGE omc-accepted NOT_RUN (no omc given)"
fi
