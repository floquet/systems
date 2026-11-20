#!/usr/bin/env python3
"""
Phase 1 Read-Only Mathematica Inventory & Provenance Harvester.
Indexes user Mathematica files (.nb, .wl, .m, .wls, .cdf, .mx) and {nb, wl, io} trees
into SQLite without modifying, moving, or dereferencing symlinks.
"""

import argparse
import hashlib
import os
import re
import socket
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

MATHEMATICA_EXTS = {".nb", ".wl", ".m", ".wls", ".cdf", ".mx"}
SKIP_DIRS = {
    ".git", ".svn", "__pycache__", ".Trash", ".Trashes", ".Spotlight-V100",
    ".fseventsd", ".DocumentRevisions-V100", ".DocumentRevisions-V100-bad-1",
    ".CacheDeleteDiscardedCaches", "Zotero", "ebooks", "ebooks-grande",
    "nas-music-staging", "node_modules", "books-mathematica", "iTunes U",
    "Backups.backupdb"
}
BUCKET_RE = re.compile(
    r"^(nb|wl|io|_nb|_wl|.*_nb|.*_wl|nb-[a-z0-9._-]+|.*\.nb|mathematica nb)$",
    re.IGNORECASE,
)

SCHEMA_SQL = """
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_host TEXT NOT NULL,
    source_volume TEXT NOT NULL,
    source_root TEXT NOT NULL,
    full_path TEXT NOT NULL UNIQUE,
    filename TEXT NOT NULL,
    ext TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    mtime_utc TEXT NOT NULL,
    is_symlink INTEGER NOT NULL,
    symlink_target TEXT,
    sha256 TEXT,
    bucket TEXT,
    preserved_relpath TEXT,
    upstream_prefix TEXT,
    git_repo TEXT,
    warehouse_status TEXT NOT NULL DEFAULT 'pending'
);

CREATE INDEX IF NOT EXISTS idx_files_sha256 ON files(sha256);
CREATE INDEX IF NOT EXISTS idx_files_bucket_relpath ON files(bucket, preserved_relpath);
CREATE INDEX IF NOT EXISTS idx_files_ext ON files(ext);
CREATE INDEX IF NOT EXISTS idx_files_volume ON files(source_volume);
"""


def sha256_file(path: Path, chunk_size: int = 1048576) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def parse_bucket_marker(part: str):
    low = part.lower()
    if low == "wl" or low.endswith("_wl"):
        return "wl", None
    if low == "io":
        return "io", None
    if low.startswith("nb-") and len(low) > 3:
        return "nb", part[3:]
    return "nb", None


def parse_provenance(full_path: Path):
    parts = full_path.parts
    anchor_idx = None
    for i in range(len(parts) - 2, -1, -1):
        if BUCKET_RE.match(parts[i]):
            anchor_idx = i
            break

    if anchor_idx is not None:
        bucket, domain_prefix = parse_bucket_marker(parts[anchor_idx])
        subparts = parts[anchor_idx + 1 :]
        if domain_prefix:
            preserved_relpath = str(Path(domain_prefix, *subparts))
        else:
            preserved_relpath = str(Path(*subparts))
        upstream_prefix = str(Path(*parts[:anchor_idx]))
    else:
        ext = full_path.suffix.lower()
        bucket = "wl" if ext in {".wl", ".wls", ".m"} else "nb"
        preserved_relpath = full_path.name
        upstream_prefix = str(full_path.parent)

    git_repo = None
    for parent in full_path.parents:
        if (parent / ".git").exists():
            git_repo = str(parent)
            break

    return bucket, preserved_relpath, upstream_prefix, git_repo


def scan_root(conn: sqlite3.Connection, host: str, volume: str, root: Path):
    if not root.exists():
        print(f"[SKIP] Root does not exist: {root}", file=sys.stderr)
        return

    cur = conn.cursor()
    scanned = 0
    indexed = 0

    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = [
            d for d in dirnames
            if d not in SKIP_DIRS and not d.endswith(".app")
        ]
        dpath = Path(dirpath)
        in_bucket_tree = any(BUCKET_RE.match(p) for p in dpath.parts)

        for fname in filenames:
            scanned += 1
            if fname.startswith("._") or fname == ".DS_Store":
                continue
            fpath = dpath / fname
            ext = fpath.suffix.lower()
            if ext not in MATHEMATICA_EXTS and not in_bucket_tree:
                continue

            try:
                st = fpath.lstat()
            except OSError as exc:
                print(f"[WARN] lstat failed on {fpath}: {exc}", file=sys.stderr)
                continue

            is_link = 1 if os.path.islink(fpath) else 0
            link_target = os.readlink(fpath) if is_link else None
            mtime_utc = datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat()

            digest = None
            if not is_link and os.path.isfile(fpath):
                try:
                    digest = sha256_file(fpath)
                except OSError as exc:
                    print(f"[WARN] hash failed on {fpath}: {exc}", file=sys.stderr)

            bucket, preserved_relpath, upstream_prefix, git_repo = parse_provenance(fpath)

            cur.execute(
                """
                INSERT INTO files (
                    source_host, source_volume, source_root, full_path, filename, ext,
                    size_bytes, mtime_utc, is_symlink, symlink_target, sha256,
                    bucket, preserved_relpath, upstream_prefix, git_repo
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(full_path) DO UPDATE SET
                    source_volume=excluded.source_volume,
                    size_bytes=excluded.size_bytes,
                    mtime_utc=excluded.mtime_utc,
                    is_symlink=excluded.is_symlink,
                    symlink_target=excluded.symlink_target,
                    sha256=excluded.sha256,
                    bucket=excluded.bucket,
                    preserved_relpath=excluded.preserved_relpath,
                    upstream_prefix=excluded.upstream_prefix,
                    git_repo=excluded.git_repo
                """,
                (
                    host, volume, str(root), str(fpath), fname, ext,
                    st.st_size, mtime_utc, is_link, link_target, digest,
                    bucket, preserved_relpath, upstream_prefix, git_repo
                ),
            )
            indexed += 1
            if indexed % 1000 == 0:
                conn.commit()
                print(f"  ... [{volume}] indexed {indexed} items (scanned {scanned})", flush=True)

    conn.commit()
    print(f"[DONE] {host}:{volume} ({root}) -> indexed {indexed} items (scanned {scanned})")


def print_summary(conn: sqlite3.Connection):
    cur = conn.cursor()
    print("\n=== INVENTORY SUMMARY BY EXTENSION ===")
    for row in cur.execute("""
        SELECT ext,
               COUNT(*) AS total_entries,
               SUM(is_symlink) AS symlinks,
               COUNT(DISTINCT sha256) AS unique_hashes,
               ROUND(SUM(CASE WHEN is_symlink=0 THEN size_bytes ELSE 0 END) / 1048576.0, 2) AS total_mb
        FROM files
        GROUP BY ext
        ORDER BY total_entries DESC
    """):
        print(f"  ext={row[0] or '<none>':6s} | entries={row[1]:6d} | symlinks={row[2]:4d} | unique_sha256={row[3]:6d} | total_MB={row[4]}")

    print("\n=== INVENTORY SUMMARY BY VOLUME ===")
    for row in cur.execute("""
        SELECT source_volume,
               COUNT(*) AS total_entries,
               COUNT(DISTINCT sha256) AS unique_hashes,
               ROUND(SUM(CASE WHEN is_symlink=0 THEN size_bytes ELSE 0 END) / 1048576.0, 2) AS total_mb
        FROM files
        GROUP BY source_volume
        ORDER BY total_entries DESC
    """):
        print(f"  vol={row[0]:22s} | entries={row[1]:6d} | unique_sha256={row[2]:6d} | total_MB={row[3]}")


def main():
    parser = argparse.ArgumentParser(description="Harvest Mathematica file metadata & SHA-256 into SQLite.")
    parser.add_argument("--db", default="mathematica-inventory.sqlite", help="SQLite database path")
    parser.add_argument("--host", default=socket.gethostname(), help="Source hostname label")
    parser.add_argument("--spec", action="append", required=True, help="VOLUME:PATH pair to scan")
    args = parser.parse_args()

    conn = sqlite3.connect(args.db)
    conn.executescript(SCHEMA_SQL)

    for spec in args.spec:
        vol, raw_path = spec.split(":", 1)
        scan_root(conn, args.host, vol, Path(raw_path).expanduser())

    print_summary(conn)
    conn.close()


if __name__ == "__main__":
    main()
