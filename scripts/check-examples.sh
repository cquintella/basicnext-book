#!/usr/bin/env bash
# Checks the Basic Next Book against a bni binary.
#
#   BNI=/path/to/bni BN_STDLIB=/path/to/BasicNext/modules/bn scripts/check-examples.sh
#
# 1. Every complete program in en/*.md (a ```basic block that defines
#    FUNCTION Start) is passed to `bni check`. A block may be annotated on the
#    last non-blank line before its fence with one of:
#      <!-- bn-check: expect-error -->   the block illustrates a diagnostic
#      <!-- bn-check: see examples/DIR --> the block is one file of a
#                                          multi-file example checked below
#      <!-- bn-check: skip REASON -->    not checkable on its own
# 2. Every examples/*/main.bn is checked with its own directory on the path.
# Blocks without FUNCTION Start are fragments and are only counted.
set -euo pipefail
cd "$(dirname "$0")/.."
BNI="${BNI:-bni}"
BN_STDLIB="${BN_STDLIB:?set BN_STDLIB to BasicNext/modules/bn}"
"$BNI" --version

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Splits every ```basic block of the book into $work/blocks/blockN.bn and writes one
# manifest line per block: N <TAB> file:line <TAB> marker <TAB> has-Start.
mkdir "$work/blocks"
awk -v out="$work/blocks" '
    FNR == 1 { inside = 0; previous = "" }
    inside && /^```/ {
        close(path)
        printf "%d\t%s:%d\t%s\t%d\n", count, FILENAME, start, marker, hasStart
        inside = 0
        next
    }
    inside {
        print > path
        if (index($0, "FUNCTION Start") > 0) hasStart = 1
        next
    }
    /^```basic$/ {
        count++
        inside = 1
        start = FNR
        hasStart = 0
        path = out "/block" count ".bn"
        printf "" > path
        marker = "-"
        if (match(previous, /^<!-- bn-check: [^ ]+/)) {
            marker = substr(previous, 16, RLENGTH - 15)
        }
        next
    }
    /[^[:space:]]/ { previous = $0 }
' en/*.md > "$work/manifest"

ok=0
fail=0
skipped=0
fragments=0

# Runs `bni check`; prints the first output line on failure.
check() {
    local expect_error="$1"
    local where="$2"
    shift 2
    local output status
    set +e
    output="$("$BNI" check --module-path "$BN_STDLIB" "$@" 2>&1)"
    status=$?
    set -e
    local good=0
    if [ "$expect_error" = 1 ]; then
        [ "$status" -ne 0 ] && good=1
    else
        [ "$status" -eq 0 ] && good=1
    fi
    if [ "$good" = 1 ]; then
        ok=$((ok + 1))
    else
        fail=$((fail + 1))
        echo "FAIL $where (exit $status): $(printf '%s\n' "$output" | head -n 1)"
    fi
}

while IFS="$(printf '\t')" read -r number where marker has_start; do
    if [ "$has_start" != 1 ]; then
        fragments=$((fragments + 1))
        continue
    fi
    case "$marker" in
        skip | see)
            skipped=$((skipped + 1))
            ;;
        expect-error)
            check 1 "$where" "$work/blocks/block$number.bn"
            ;;
        *)
            check 0 "$where" "$work/blocks/block$number.bn"
            ;;
    esac
done < "$work/manifest"

for main in examples/*/main.bn; do
    [ -e "$main" ] || continue
    check 0 "$main" --module-path "$(dirname "$main")" "$main"
done

echo "checked OK: $ok  failed: $fail  skipped (annotated): $skipped  fragments (not checked): $fragments"
[ "$fail" -eq 0 ]
