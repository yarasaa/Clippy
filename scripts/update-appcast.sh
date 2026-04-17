#!/bin/bash
# update-appcast.sh — Prepend a new <item> to docs/appcast.xml.
#
# Usage:
#   scripts/update-appcast.sh <version> <ed-signature> <length-in-bytes> [dmg-filename]
#
# The DMG URL is built from the release tag and filename. If dmg-filename is
# omitted we fall back to "Clippy-<version>.dmg".

set -euo pipefail

VERSION="${1:?Usage: update-appcast.sh <version> <signature> <length> [dmg]}"
SIGNATURE="${2:?missing signature}"
LENGTH="${3:?missing length}"
DMG_FILENAME="${4:-Clippy-${VERSION}.dmg}"

APPCAST="docs/appcast.xml"
DMG_URL="https://github.com/yarasaa/Clippy/releases/download/v${VERSION}/${DMG_FILENAME}"
RELEASE_NOTES_URL="https://github.com/yarasaa/Clippy/releases/tag/v${VERSION}"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

read -r -d '' NEW_ITEM <<EOF || true
        <item>
            <title>Clippy ${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
            <enclosure
                url="${DMG_URL}"
                sparkle:edSignature="${SIGNATURE}"
                length="${LENGTH}"
                type="application/octet-stream" />
        </item>
EOF

python3 - <<PY
import pathlib, re

path = pathlib.Path("${APPCAST}")
contents = path.read_text()

anchor = "<language>en</language>"
new_item = """${NEW_ITEM}"""

# Idempotent: remove any existing item for the same version before inserting.
contents = re.sub(
    r"\\s*<item>[\\s\\S]*?<sparkle:version>${VERSION}</sparkle:version>[\\s\\S]*?</item>",
    "",
    contents,
)

idx = contents.find(anchor)
if idx == -1:
    raise SystemExit("appcast.xml is missing the <language>en</language> anchor")
insert_at = contents.find("\\n", idx) + 1

updated = contents[:insert_at] + "\\n" + new_item + "\\n" + contents[insert_at:]
path.write_text(updated)
print("Updated ${APPCAST} for ${VERSION}")
PY
