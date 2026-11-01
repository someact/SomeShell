#!/usr/bin/env bash
# Build shell/lib/emoji.tsv, the list behind /emoji in the island.
#
#   scripts/emoji-data.sh [max-version]
#
# max-version (default 16.0) leaves out emoji too new for the installed fonts,
# which would show as boxes.
# Sources: Unicode's emoji-test.txt (the set, its order and groups) and the
# CLDR English annotations (keywords). Needs curl and jq.
#
# One line per emoji, tab separated:  emoji  group  name  keywords
# group is one of: smileys people animals food travel activities objects symbols flags
set -euo pipefail

max="${1:-16.0}"
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
out="$here/../shell/lib/emoji.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/test.txt" https://unicode.org/Public/emoji/latest/emoji-test.txt
curl -fsSL -o "$tmp/ann.json" https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/en/annotations.json
jq -r '.annotations.annotations | to_entries[] | [.key, (.value.default // [] | join(" "))] | @tsv' "$tmp/ann.json" >"$tmp/keywords.tsv"

mkdir -p "$(dirname "$out")"
awk -F'\t' -v max="$max" '
    FNR == NR { kw[$1] = $2; next }
    /^# group: / {
        g = tolower($0); sub(/^# group: /, "", g)
        if (g ~ /smileys/) group = "smileys"; else if (g ~ /people/) group = "people"
        else if (g ~ /animals/) group = "animals"; else if (g ~ /food/) group = "food"
        else if (g ~ /travel/) group = "travel"; else if (g ~ /activities/) group = "activities"
        else if (g ~ /objects/) group = "objects"; else if (g ~ /symbols/) group = "symbols"
        else if (g ~ /flags/) group = "flags"; else group = ""
        next
    }
    /; fully-qualified/ {
        # "1F600 ; fully-qualified # 😀 E1.0 grinning face"
        line = $0
        sub(/^[^#]*# /, "", line)
        split(line, parts, " ")
        emoji = parts[1]
        ver = parts[2]; sub(/^E/, "", ver)
        if (ver + 0 > max + 0) next
        name = line; sub(/^[^ ]+ [^ ]+ /, "", name)
        # Skin tone and hair forms are left out; the base emoji stays
        if (name ~ /skin tone/) next
        key = emoji; gsub(/\xef\xb8\x8f/, "", key)
        k = (emoji in kw) ? kw[emoji] : ((key in kw) ? kw[key] : "")
        if (group != "") print emoji "\t" group "\t" name "\t" k
    }
' "$tmp/keywords.tsv" "$tmp/test.txt" >"$out"

echo "$(wc -l <"$out") emoji written to $out"
