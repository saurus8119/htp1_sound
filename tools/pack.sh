#!/bin/bash
# tools/pack.sh <id> [outdir]
# Builds the installable tarball only. Diagnostics are deliberately kept out of it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ID="${1:-}"
OUT="${2:-$ROOT/dist}"
[[ -n "$ID" ]] || { echo "usage: tools/pack.sh <id> [outdir]" >&2; exit 2; }
SRC="$ROOT/addons/$ID"
[[ -f "$SRC/addon.json" ]] || { echo "pack: $SRC has no addon.json" >&2; exit 1; }
for PY in python3 python; do "$PY" -c pass >/dev/null 2>&1 && break; done
mkdir -p "$OUT"
NAME=$("$PY" - "$SRC" "$ID" "$OUT" <<'PY'
import gzip, json, os, sys, tarfile
src, aid, out = sys.argv[1:4]
manifest = json.load(open(os.path.join(src, 'addon.json')))
name = 'htp1-addon-%s-%s.tar.gz' % (aid, manifest['version'])
ship_files = {'addon.json', 'README.md'}
# lib/ is included because this build bundles libplist-2.0.so for the target.
ship_dirs = {'bin', 'etc', 'units', 'debs', 'flows', 'www', 'hooks', 'lib'}
path = os.path.join(out, name)
with open(path, 'wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as gz, tarfile.open(fileobj=gz, mode='w') as tar:
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src).replace(os.sep, '/')
        if rel == '.':
            dirs[:] = sorted(d for d in dirs if d in ship_dirs)
            files = [f for f in files if f in ship_files]
        else:
            dirs.sort()
        top = rel.split('/')[0] if rel != '.' else ''
        for d in dirs:
            ti = tarfile.TarInfo(aid + '/' + (d if rel == '.' else rel + '/' + d))
            ti.type = tarfile.DIRTYPE
            ti.mode = 0o755
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = 'root'
            ti.mtime = 0
            tar.addfile(ti)
        for f in sorted(files):
            file_path = os.path.join(root, f)
            ti = tar.gettarinfo(file_path, aid + '/' + (f if rel == '.' else rel + '/' + f))
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
