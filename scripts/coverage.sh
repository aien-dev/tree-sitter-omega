#!/bin/sh
# Parse coverage of this grammar over real Omega: every *.om file under one or more directories (CI:
# an aien-dev/omega-mv checkout), with omc as the judge of which files are valid Omega, and
# optionally the composed units a repository builds by concatenation (library units are compiled only
# inside such a unit, never alone).
#
# Usage:
#   scripts/coverage.sh [--omc OMC] [--units MANIFEST]... [LABEL=]DIR...
#
# DIR is searched for *.om files. LABEL (default: the basename of DIR) names the directory in
# manifests and, when more than one DIR is given, prefixes every path printed (LABEL/PATH).
#
# MANIFEST lists composed units, one per line (`#` starts a comment line):
#   unit NAME MEMBER...                 the members concatenated in order
#   each NAME LABEL:GLOB MEMBER...      one unit per directory or file GLOB matches; in NAME and in the
#                                       members, `%` is that match (LABEL:path) and `%n` its basename
#                                       (less a trailing .om)
# A MEMBER is LABEL:PATH (PATH relative to that DIR, may hold a glob, expanded in C order), or `@om2`
# / `@ir` for that profile line. A member that matches no file is a usage error.
#
# stdout, one line per file (tab separated):
#   <path> omc=<accept|refuse|not_run> parse=<clean|error> <first ERROR/MISSING node or ->
# then one line per unit, the node followed by the member and line it falls in:
#   unit:<NAME> omc=<accept|refuse|not_run> parse=<clean|error> <node in MEMBER:LINE or ->
# then the summary lines:
#   COVERAGE all <clean>/<total>
#   COVERAGE omc-accepted <clean>/<accepted>      (only with --omc)
#   COVERAGE omc-refused-flagged <error>/<refused> (refused files the grammar also marks; this
#                                                   grammar is not a type checker, so most parse clean)
#   COVERAGE units-accepted <clean>/<accepted> refused=<n> refused-files-covered=<n>
#                                                  (only with --units; the last field counts files omc
#                                                   refuses alone that are members of an accepted unit)
# each followed by LABEL=<commit> for every DIR (`unpinned` outside git).
# With an omc (AArch64 Linux; seed/out/omc after `sh seed/omega-from-seed.sh`), each file and each
# unit is fed to it on stdin and its exit status decides accept (0) or refuse (non-zero).
# Exit status: 0 when every omc-accepted file and unit parses clean (or no omc was given), 1 otherwise,
# 2 on a usage error. Diagnostics go to stderr.
set -eu
export LC_ALL=C
usage() {
  [ $# = 0 ] || echo "coverage.sh: $*" >&2
  echo "usage: coverage.sh [--omc OMC] [--units MANIFEST]... [LABEL=]DIR..." >&2
  exit 2
}
here=$(cd "$(dirname "$0")/.." && pwd)
ts="$here/node_modules/.bin/tree-sitter"
[ -x "$ts" ] || { echo "coverage.sh: $ts missing; run npm ci" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
omc=
: >"$work/manifests"
: >"$work/dirs"
while [ $# -gt 0 ]; do
  case $1 in
    --omc) [ $# -ge 2 ] || usage "--omc needs a path"; omc=$2; shift 2 ;;
    --units) [ $# -ge 2 ] || usage "--units needs a file"; [ -f "$2" ] || usage "no manifest $2"
      printf '%s\n' "$2" >>"$work/manifests"; shift 2 ;;
    -*) usage "unknown option $1" ;;
    *) case $1 in
         *=*) label=${1%%=*}; dir=${1#*=} ;;
         *) dir=$1; label=$(basename "$1") ;;
       esac
       [ -d "$dir" ] || usage "$dir is not a directory"
       case $label in ''|*[!A-Za-z0-9._-]*) usage "bad label '$label'" ;; esac
       ! awk -F'\t' -v l="$label" '$1 == l { f = 1 } END { exit !f }' "$work/dirs" || usage "label $label given twice"
       printf '%s\t%s\n' "$label" "$(cd "$dir" && pwd)" >>"$work/dirs"
       shift ;;
  esac
done
[ -s "$work/dirs" ] || usage
[ -z "$omc" ] || [ -x "$omc" ] || usage "omc '$omc' is not executable"
ndirs=$(wc -l <"$work/dirs")
dirof() { awk -F'\t' -v l="$1" '$1 == l { print $2; f = 1 } END { exit !f }' "$work/dirs"; }
show() { if [ "$ndirs" = 1 ]; then printf '%s' "$2"; else printf '%s/%s' "$1" "$2"; fi; }

# files: label, path relative to its DIR, path printed, absolute path
: >"$work/files"
while IFS="$(printf '\t')" read -r label dir; do
  (cd "$dir" && find . -name '*.om' -type f | sed 's|^\./||' | sort) | while IFS= read -r f; do
    printf '%s\t%s\t%s\t%s\n' "$label" "$f" "$(show "$label" "$f")" "$dir/$f"
  done >>"$work/files"
done <"$work/dirs"
[ -s "$work/files" ] || { echo "coverage.sh: no .om files under the given directories" >&2; exit 2; }

# units: compose each into $work/u/<n>.om; <n>.map holds `<first line> <member printed>` per member
mkdir "$work/u"
: >"$work/units"
nu=0
member() { # LABEL:PATH or @om2/@ir -> appends to the unit being composed
  case $1 in
    @om2|@ir) printf '%s\n' "${1#@}" >>"$cur"; printf '%s\t%s\n' "$line" "$1" >>"$map"; line=$((line + 1)); return ;;
    *:*) ;;
    *) echo "coverage.sh: $mf: member '$1' is not LABEL:PATH, @om2 or @ir" >&2; exit 2 ;;
  esac
  ml=${1%%:*}; mp=${1#*:}
  md=$(dirof "$ml") || { echo "coverage.sh: $mf: no DIR labelled '$ml'" >&2; exit 2; }
  hits=$(cd "$md" && set +f && for g in $mp; do [ -f "$g" ] && printf '%s\n' "$g"; done; true)
  [ -n "$hits" ] || { echo "coverage.sh: $mf: member $1 matches no file" >&2; exit 2; }
  for g in $hits; do
    cat "$md/$g" >>"$cur"
    printf '%s\t%s\n' "$line" "$(show "$ml" "$g")" >>"$map"
    line=$(( $(wc -l <"$cur") + 1 ))
  done
}
compose() { # NAME MEMBER...
  nu=$((nu + 1)); cur="$work/u/$nu.om"; map="$work/u/$nu.map"; : >"$cur"; : >"$map"; line=1
  printf '%s\t%s\n' "$nu" "$1" >>"$work/units"; shift
  for m in "$@"; do member "$m"; done
}
set -f
while IFS= read -r mf; do
  while IFS= read -r l || [ -n "$l" ]; do
    set -- $l
    [ $# -gt 0 ] || continue
    case $1 in
      \#*) ;;
      unit) [ $# -ge 3 ] || { echo "coverage.sh: $mf: '$l' needs NAME and members" >&2; exit 2; }
        shift; compose "$@" ;;
      each) [ $# -ge 4 ] || { echo "coverage.sh: $mf: '$l' needs NAME, LABEL:GLOB and members" >&2; exit 2; }
        tpl=$2; gl=${3%%:*}; gp=${3#*:}; shift 3
        gd=$(dirof "$gl") || { echo "coverage.sh: $mf: no DIR labelled '$gl'" >&2; exit 2; }
        ds=$(cd "$gd" && set +f && for g in $gp; do [ -e "$g" ] && printf '%s\n' "${g%/}"; done; true)
        [ -n "$ds" ] || { echo "coverage.sh: $mf: $gl:$gp matches nothing" >&2; exit 2; }
        for d in $ds; do
          n=$(basename "$d" .om)
          # Manifest words hold no blanks, so the expanded words split back on blanks (globbing is off).
          compose $(for a in "$tpl" "$@"; do printf '%s\n' "$a" | sed "s|%n|$n|g; s|%|$gl:$d|g"; done)
        done ;;
      *) echo "coverage.sh: $mf: unknown line '$l'" >&2; exit 2 ;;
    esac
  done <"$mf"
done <"$work/manifests"
set +f

# --quiet prints only the files whose tree holds an ERROR or MISSING node, with the first one.
{ cut -f4 "$work/files"; awk -F'\t' -v u="$work/u" '{ print u "/" $1 ".om" }' "$work/units"; } >"$work/abs"
"$ts" parse -p "$here" --quiet --paths "$work/abs" 2>"$work/parse.err" >"$work/parse.out" || true
firstnode() { awk -v p="$1" -F'\t' '{ sub(/ +$/, "", $1) } $1 == p { n = $NF; sub(/^[^(]*/, "", n); print n; exit }' "$work/parse.out"; }
judge() { if [ -z "$omc" ]; then echo not_run; elif timeout "$2" "$omc" <"$1" >/dev/null 2>&1; then echo accept; else echo refuse; fi; }

total=0; clean=0; acc=0; acc_clean=0; ref=0; ref_flag=0
: >"$work/refused"
while IFS="$(printf '\t')" read -r label rel p abs; do
  total=$((total + 1))
  node=$(firstnode "$abs")
  if [ -n "$node" ]; then parse=error; else parse=clean; node=-; clean=$((clean + 1)); fi
  verdict=$(judge "$abs" 20)
  case $verdict in
    accept) acc=$((acc + 1)); [ "$parse" = error ] || acc_clean=$((acc_clean + 1)) ;;
    refuse) ref=$((ref + 1)); [ "$parse" = clean ] || ref_flag=$((ref_flag + 1)); printf '%s\n' "$p" >>"$work/refused" ;;
  esac
  printf '%s\tomc=%s\tparse=%s\t%s\n' "$p" "$verdict" "$parse" "$node"
done <"$work/files"

uacc=0; uacc_clean=0; uref=0
: >"$work/covered"
while IFS="$(printf '\t')" read -r n name; do
  f="$work/u/$n.om"
  node=$(firstnode "$f")
  if [ -n "$node" ]; then
    parse=error
    row=$(printf '%s\n' "$node" | sed -n 's/^([^[]*\[\([0-9]*\),.*/\1/p')
    at=$(awk -F'\t' -v r="$((row + 1))" '$1 <= r { m = $2; s = $1 } END { print m ":" r - s + 1 }' "$work/u/$n.map")
    node="$node in $at"
  else parse=clean; node=-; fi
  verdict=$(judge "$f" 120)
  case $verdict in
    accept) uacc=$((uacc + 1)); [ "$parse" = error ] || uacc_clean=$((uacc_clean + 1)); cut -f2 "$work/u/$n.map" >>"$work/covered" ;;
    refuse) uref=$((uref + 1)) ;;
  esac
  printf 'unit:%s\tomc=%s\tparse=%s\t%s\n' "$name" "$verdict" "$parse" "$node"
done <"$work/units"

pins=$(while IFS="$(printf '\t')" read -r label dir; do
  printf ' %s=%s' "$label" "$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo unpinned)"; done <"$work/dirs")
echo "COVERAGE all $clean/$total$pins"
if [ -n "$omc" ]; then
  echo "COVERAGE omc-accepted $acc_clean/$acc$pins"
  echo "COVERAGE omc-refused-flagged $ref_flag/$ref$pins"
else
  echo "COVERAGE omc-accepted NOT_RUN (no omc given)"
fi
if [ -s "$work/units" ]; then
  if [ -n "$omc" ]; then
    covered=$(sort -u "$work/covered" | grep -Fxf "$work/refused" | wc -l || true)
    echo "COVERAGE units-accepted $uacc_clean/$uacc refused=$uref refused-files-covered=$covered$pins"
  else
    echo "COVERAGE units-accepted NOT_RUN (no omc given)"
  fi
fi
[ "$acc_clean" = "$acc" ] && [ "$uacc_clean" = "$uacc" ] || exit 1
