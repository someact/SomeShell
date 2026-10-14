#!/usr/bin/env bash
# Rebuild shell/lib/emoji.tsv, the emoji list of the island picker
# (shell/services/Emojis.qml) and the fuzzel fallback (hypr/scripts/fuzzel-emoji.sh).
#
#   emoji-data.sh [max-version]   default 17.0: newer emoji have no glyph in the
#                                 Noto and Twemoji fonts yet and would show as boxes
#
# Sources: the Unicode emoji-test.txt (the set, its order and groups, the skin
# tone forms) and the CLDR English annotations (keywords). Needs curl and jq.
#
# One line per emoji, tab separated:
#   emoji  group  name  keywords  toned
# group is smileys people animals food travel activities objects symbols flags.
# toned is the "light skin tone" form for emoji that take a skin tone, empty
# otherwise; the shell swaps U+1F3FB in it for the chosen tone (two-person
# emoji then get the same tone twice).
set -euo pipefail

MAX="${1:-17.0}"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OUT="$HERE/../shell/lib/emoji.tsv"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL -o "$TMP/test.txt" https://unicode.org/Public/emoji/latest/emoji-test.txt
curl -fsSL -o "$TMP/ann.json" https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/en/annotations.json
jq -r '.annotations.annotations | to_entries[] | [.key, (.value.default // [] | join(" "))] | @tsv' "$TMP/ann.json" >"$TMP/keywords.tsv"

# Bytes, not characters: FE0F (EF B8 8F) is dropped for the keyword lookup
# because CLDR keys leave it out
LC_ALL=C awk -F '\t' -v max="$MAX" '
FNR == NR { kw[$1] = $2; next }
/^# group: / {
    g = substr($0, 10)
    group = g == "Smileys & Emotion" ? "smileys" : g == "People & Body" ? "people" : g == "Animals & Nature" ? "animals" : \
            g == "Food & Drink" ? "food" : g == "Travel & Places" ? "travel" : g == "Activities" ? "activities" : \
            g == "Objects" ? "objects" : g == "Symbols" ? "symbols" : g == "Flags" ? "flags" : ""
    next
}
/; fully-qualified/ && group != "" {
    line = $0
    sub(/^[^#]*# /, "", line)
    split(line, f, " ")
    emoji = f[1]
    version = substr(f[2], 2) + 0
    if (version > max + 0) next
    name = line
    sub(/^[^ ]+ [^ ]+ /, "", name)
    if (name ~ /: light skin tone$/) {
        base = substr(name, 1, length(name) - 17)
        if (base in index_of) toned[index_of[base]] = emoji
        next
    }
    if (name ~ /skin tone/) next
    n++
    index_of[name] = n
    em[n] = emoji; gr[n] = group; nm[n] = name
    key = emoji
    gsub(/\xef\xb8\x8f/, "", key)
    k[n] = kw[key]
}
END {
    for (i = 1; i <= n; i++)
        printf "%s\t%s\t%s\t%s\t%s\n", em[i], gr[i], nm[i], k[i], toned[i]
}
' "$TMP/keywords.tsv" "$TMP/test.txt" >"$TMP/emoji.tsv"

mv "$TMP/emoji.tsv" "$OUT"
echo "$(wc -l <"$OUT") emoji (up to $MAX) in $OUT"
