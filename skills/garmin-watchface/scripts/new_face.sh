#!/usr/bin/env bash
# Start a new watch face from the template.  Usage: new_face.sh <dir> "<Face Name>" <device-id> [device-id...]
# Gives it a fresh app id, its name and the target devices, then you build it with build.sh.
set -euo pipefail
DIR="${1:?target dir}"; NAME="${2:?face name}"; shift 2; [ $# -gt 0 ] || { echo "need at least one device id" >&2; exit 1; }
# the folder may already exist holding only the interview's BRIEF.md
if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" | grep -vx BRIEF.md)" ]; then echo "$DIR already has files" >&2; exit 1; fi
mkdir -p "$DIR" && cp -r "$(dirname "$0")/../template/." "$DIR/"
ID=$(python3 -c 'import uuid; print(uuid.uuid4())')
PRODUCTS=$(for d in "$@"; do printf '            <iq:product id="%s"/>\n' "$d"; done)
python3 - "$DIR" "$ID" "$NAME" "$PRODUCTS" <<'PY'
import sys, pathlib
d, uid, name, products = sys.argv[1:]
m = pathlib.Path(d, "manifest.xml"); s = m.read_text()
s = s.replace("00000000-0000-0000-0000-000000000000", uid).replace('            <iq:product id="fr55"/>\n', products + "\n")
m.write_text(s)
st = pathlib.Path(d, "resources/strings/strings.xml"); st.write_text(st.read_text().replace(">My Face<", f">{name}<"))
PY
J="$DIR/monkey.jungle"
sed -i.bak '/^fr55\./d' "$J" && rm -f "$J.bak"
for d in "$@"; do printf '%s.sourcePath = source\n%s.resourcePath = resources\n' "$d" "$d" >> "$J"; done
echo "created $DIR ($NAME, app id $ID) for: $*"
