#!/usr/bin/env bash
# ISOTOPE / ISOMER: install the Mathematica harvester.
printf "%s\n" "$(date), $(tput bold)${BASH_SOURCE[0]}$(tput sgr0)"
set -eu
cd "$HOME/repos-isotope/github/systems/setup/storage/mathematica-harvest"
cat > harvest-mathematica.py <<'PYTHON_HARVEST_EOF'
#!/usr/bin/env python3
"""ISOTOPE / ISOMER: read-only Mathematica inventory and optional blended warehouse."""
import argparse
import hashlib
import os
import re
import shutil
import socket
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

EXTS = {'.nb', '.wl', '.m', '.wls', '.cdf', '.mx'}
SKIP = {'.git', '.svn', '__pycache__', '.Trash', 'Zotero', 'node_modules'}
VERSION = re.compile(rb'FrontEndVersion\s*->\s*"([^"\r\n]{1,200})"')
SCHEMA = '''
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS files (
 full_path TEXT PRIMARY KEY, source_host TEXT NOT NULL, source_root TEXT NOT NULL,
 relpath TEXT NOT NULL, filename TEXT NOT NULL, ext TEXT NOT NULL,
 size_bytes INTEGER, mtime_utc TEXT, sha256 TEXT, mathematica_version TEXT,
 is_symlink INTEGER NOT NULL, symlink_target TEXT, warehouse_relpath TEXT,
 status TEXT NOT NULL, error TEXT, indexed_utc TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_hash ON files(sha256);
CREATE INDEX IF NOT EXISTS idx_relpath ON files(relpath);
'''

def stamp():
    return datetime.now().astimezone().isoformat(timespec='seconds')

def log(message):
    print(f'[{stamp()}] {message}', flush=True)

def hash_and_version(path):
    h = hashlib.sha256()
    version = None
    with path.open('rb') as stream:
        first = True
        while chunk := stream.read(1024 * 1024):
            h.update(chunk)
            if first and path.suffix.lower() == '.nb':
                match = VERSION.search(chunk[:1024 * 1024])
                if match:
                    version = match.group(1).decode('utf-8', 'replace')
            first = False
    return h.hexdigest(), version

def unique_destination(relpath, digest, occupied):
    """Reserve a destination, preserving unrelated existing filenames."""
    path = Path(relpath)
    base = path.as_posix()
    if base not in occupied or occupied[base] == digest:
        occupied[base] = digest
        return base
    for length in range(6, 65, 2):
        candidate = (path.parent / f'{path.stem}-{digest[:length]}{path.suffix}').as_posix()
        if candidate not in occupied or occupied[candidate] == digest:
            occupied[candidate] = digest
            return candidate
    raise RuntimeError(f'Cannot assign unique name: {relpath}')

def scan(conn, root, host, interval):
    start = time.monotonic()
    examined = indexed = failed = 0
    last_report = start
    log(f'ROOT host={host} path={root}')
    if not root.is_dir():
        raise SystemExit(f'Not a directory: {root}')
    for directory, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP and not (Path(directory) / d).is_symlink())
        for name in sorted(names):
            examined += 1
            path = Path(directory) / name
            if path.suffix.lower() not in EXTS:
                continue
            indexed += 1
            rel = path.relative_to(root).as_posix()
            digest = version = error = target = None
            status = 'ok'
            try:
                st = path.lstat()
                is_link = path.is_symlink()
                if is_link:
                    target = os.readlink(path)
                    status = 'symlink-skipped'
                elif not path.is_file():
                    status = 'nonregular-skipped'
                else:
                    log(f'HASH {rel} ({st.st_size:,} bytes)') if st.st_size >= 100 * 1024 * 1024 else None
                    digest, version = hash_and_version(path)
                size = st.st_size
                mtime = datetime.fromtimestamp(st.st_mtime, timezone.utc).isoformat()
            except OSError as exc:
                is_link = path.is_symlink()
                size = None
                mtime = None
                status = 'error'
                error = str(exc)
                failed += 1
                log(f'ERROR {rel}: {exc}')
            conn.execute('''INSERT INTO files
                (full_path, source_host, source_root, relpath, filename, ext,
                 size_bytes, mtime_utc, sha256, mathematica_version, is_symlink,
                 symlink_target, warehouse_relpath, status, error, indexed_utc)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(full_path) DO UPDATE SET
                 source_host=excluded.source_host, source_root=excluded.source_root,
                 relpath=excluded.relpath, filename=excluded.filename, ext=excluded.ext,
                 size_bytes=excluded.size_bytes, mtime_utc=excluded.mtime_utc,
                 sha256=excluded.sha256, mathematica_version=excluded.mathematica_version,
                 is_symlink=excluded.is_symlink, symlink_target=excluded.symlink_target,
                 status=excluded.status, error=excluded.error, indexed_utc=excluded.indexed_utc''',
                (str(path), host, str(root), rel, name, path.suffix.lower(), size, mtime,
                 digest, version, int(is_link), target, None, status, error, stamp()))
            now = time.monotonic()
            if indexed % 100 == 0 or now - last_report >= interval:
                conn.commit()
                log(f'PROGRESS examined={examined:,} indexed={indexed:,} failed={failed:,} elapsed={now-start:.1f}s')
                last_report = now
    conn.commit()
    log(f'SCAN DONE examined={examined:,} indexed={indexed:,} failed={failed:,} elapsed={time.monotonic()-start:.1f}s')

def plan(conn, warehouse):
    """Deterministic plan, independent of scan order; never overwrite source."""
    rows = conn.execute('''SELECT full_path, relpath, sha256, size_bytes
                           FROM files WHERE status='ok' AND sha256 IS NOT NULL
                           ORDER BY relpath, sha256, full_path''').fetchall()
    # Reserve every original relative filename before creating suffixed names.
    occupied = {rel: None for _, rel, _, _ in rows}
    # For each relative path, select the lexicographically first hash as unsuffixed.
    groups = {}
    for full, rel, digest, size in rows:
        groups.setdefault(rel, {}).setdefault(digest, []).append((full, size))
    assignments = {}
    for rel in sorted(groups):
        for index, digest in enumerate(sorted(groups[rel])):
            if index == 0:
                destination = rel
                occupied[rel] = digest
            else:
                destination = unique_destination(rel, digest, occupied)
            for full, size in groups[rel][digest]:
                assignments[full] = (destination, digest, size)
    for full, (destination, _, _) in assignments.items():
        conn.execute('UPDATE files SET warehouse_relpath=? WHERE full_path=?', (destination, full))
    conn.commit()
    distinct_paths = {(d, h) for d, h, _ in assignments.values()}
    bytes_needed = sum(next(size for d, h, size in assignments.values() if (d, h) == key) for key in distinct_paths)
    duplicates = len(assignments) - len(distinct_paths)
    conflicts = sum(max(0, len(hashes)-1) for hashes in groups.values())
    log(f'PLAN entries={len(assignments):,} destinations={len(distinct_paths):,} duplicates={duplicates:,} conflicts={conflicts:,} bytes={bytes_needed:,}')
    return assignments

def build(assignments, warehouse):
    """Copy only; verify every destination hash. Existing differences are never overwritten."""
    written = set()
    start = time.monotonic()
    for full, (rel, digest, _) in sorted(assignments.items()):
        if rel in written:
            continue
        target = warehouse / rel
        if target.exists() or target.is_symlink():
            if target.is_symlink() or not target.is_file():
                raise RuntimeError(f'Unsafe existing destination: {target}')
            existing, _ = hash_and_version(target)
            if existing != digest:
                raise RuntimeError(f'Existing destination differs; refusing overwrite: {target}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            # Copy to a temporary file in the destination directory, then rename.
            temp = target.with_name(target.name + f'.tmp-{os.getpid()}')
            try:
                with open(full, 'rb') as src, temp.open('xb') as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
                copied, _ = hash_and_version(temp)
                if copied != digest:
                    raise RuntimeError(f'Hash verification failed: {full}')
                if target.exists() or target.is_symlink():
                    raise RuntimeError(f'Destination appeared during copy: {target}')
                os.link(temp, target)  # atomic create; fails rather than replacing
            finally:
                temp.unlink(missing_ok=True)
        written.add(rel)
        if len(written) % 100 == 0:
            log(f'BUILD files={len(written):,} elapsed={time.monotonic()-start:.1f}s')
    log(f'BUILD DONE files={len(written):,} elapsed={time.monotonic()-start:.1f}s')

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('roots', nargs='+', type=Path, help='nb or _nb roots; content below each root is preserved')
    ap.add_argument('--db', type=Path, default=Path('mathematica-inventory.sqlite'))
    ap.add_argument('--warehouse', type=Path, default=Path('nb-warehouse'))
    ap.add_argument('--host', default=socket.gethostname())
    ap.add_argument('--progress-seconds', type=float, default=10.0)
    ap.add_argument('--build', action='store_true', help='Actually construct warehouse; default is read-only inventory and plan')
    args = ap.parse_args()
    started = time.monotonic()
    roots = [p.expanduser().resolve() for p in args.roots]
    warehouse = args.warehouse.expanduser().resolve()
    db = args.db.expanduser().resolve()
    if any(warehouse == root or warehouse.is_relative_to(root) for root in roots):
        ap.error('Warehouse must not be inside a scanned source root')
    if any(db == root or db.is_relative_to(root) for root in roots):
        ap.error('Database must not be inside a scanned source root')
    log(f'START host={args.host} mode={"BUILD" if args.build else "DRY-RUN"}')
    conn = sqlite3.connect(db)
    try:
        conn.executescript(SCHEMA)
        for root in roots:
            scan(conn, root, args.host, args.progress_seconds)
        assignments = plan(conn, warehouse)
        if args.build:
            build(assignments, warehouse)
        log(f'FINISH total_elapsed={time.monotonic()-started:.1f}s database={db} warehouse={warehouse}')
    finally:
        conn.close()

if __name__ == '__main__':
    main()
PYTHON_HARVEST_EOF
chmod +x harvest-mathematica.py
python3 -m py_compile harvest-mathematica.py
printf 'Installed %s/harvest-mathematica.py\n' "$PWD"

# Invocation (ISOTOPE; dry run):
# cd "$HOME/repos-isotope/github/systems/setup/storage/mathematica-harvest"
# ./harvest-mathematica.py --host isotope --db mathematica-inventory.sqlite --warehouse nb-warehouse "$HOME/Mathematica_files/nb"
# To construct the warehouse after reviewing the plan, repeat with --build.
