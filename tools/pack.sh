
#!/bin/bash
# tools/pack.sh <id> [outdir]
#   Legacy form: source directory is found by matching addon.json id.
# tools/pack.sh <source-dir> <package-id> <outdir>
#   Explicit form: package source directory and published ID may differ.
# Builds the installable tarball only. Diagnostics are deliberately kept out of it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ge 3 ]]; then
    SRC_ARG="$1"
    ID="$2"
    OUT="$3"
else
    ID="${1:-}"
    OUT="${2:-$ROOT/dist}"
    SRC_ARG="addons/$ID"
fi

[[ -n "${ID:-}" ]] || {
    echo "usage: tools/pack.sh <id> [outdir]" >&2
    echo "   or: tools/pack.sh <source-dir> <package-id> <outdir>" >&2
    exit 2
}

case "$SRC_ARG" in
    /*) SRC="$SRC_ARG" ;;
    *)  SRC="$ROOT/$SRC_ARG" ;;
esac

for PY in python3 python; do
    "$PY" -c pass >/dev/null 2>&1 && break
done

# In legacy mode, locate the source folder by manifest ID if its folder name
# differs from the package ID (for example, addons/airplay -> airplay2).
if [[ ! -f "$SRC/addon.json" ]]; then
    for manifest in "$ROOT"/addons/*/addon.json; do
        [[ -f "$manifest" ]] || continue
        if "$PY" - "$manifest" "$ID" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    manifest = json.load(f)
sys.exit(0 if manifest.get('id') == sys.argv[2] else 1)
PY
        then
            SRC="${manifest%/addon.json}"
            break
        fi
    done
fi

[[ -f "$SRC/addon.json" ]] || {
    echo "pack: $SRC has no addon.json for package ID '$ID'" >&2
    exit 1
}

mkdir -p "$OUT"

NAME=$("$PY" - "$SRC" "$ID" "$OUT" <<'PY'
import gzip, json, os, sys, tarfile

src, aid, out = sys.argv[1:4]
with open(os.path.join(src, 'addon.json')) as f:
    manifest = json.load(f)

if manifest.get('id') != aid:
    raise SystemExit(
        "pack: source manifest ID %r does not match package ID %r"
        % (manifest.get('id'), aid)
    )

version = manifest.get('version')
if not version:
    raise SystemExit("pack: manifest has no version")

name = 'htp1-addon-%s-%s.tar.gz' % (aid, version)
ship_files = {'addon.json', 'README.md'}
# lib/ is included because this build bundles libplist-2.0.so for the target.
ship_dirs = {'bin', 'etc', 'units', 'debs', 'flows', 'www', 'hooks', 'lib'}
path = os.path.join(out, name)

with open(path, 'wb') as raw, \
     gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as gz, \
     tarfile.open(fileobj=gz, mode='w') as tar:
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src).replace(os.sep, '/')
        if rel == '.':
            dirs[:] = sorted(d for d in dirs if d in ship_dirs)
            files = [f for f in files if f in ship_files]
        else:
            dirs.sort()

        top = rel.split('/')[0] if rel != '.' else ''

        for d in dirs:
            arcname = aid + '/' + (d if rel == '.' else rel + '/' + d)
            ti = tarfile.TarInfo(arcname)
            ti.type = tarfile.DIRTYPE
            ti.mode = 0o755
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = 'root'
            ti.mtime = 0
            tar.addfile(ti)

        for f in sorted(files):
            file_path = os.path.join(root, f)
            arcname = aid + '/' + (f if rel == '.' else rel + '/' + f)
            ti = tar.gettarinfo(file_path, arcname)
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = 'root'
            ti.mtime = 0
            ti.mode = 0o755 if top in ('bin', 'hooks') else 0o644
            with open(file_path, 'rb') as fh:
                tar.addfile(ti, fh)

print(name)
PY
)

(cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256")
echo "$OUT/$NAME"
