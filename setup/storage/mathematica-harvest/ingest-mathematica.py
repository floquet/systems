#!/usr/bin/env python3
import argparse
import hashlib
import os
import shutil
import sqlite3
from pathlib import Path

def sha256_file(path: Path, bufsize: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(bufsize)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def disambiguate(dest: Path, digest: str, reserved: set[Path]) -> Path:
    if dest not in reserved and not dest.exists():
        reserved.add(dest)
        return dest
    stem, suffix = dest.stem, dest.suffix
    cand = dest.with_name(f"{stem}__{digest[:8]}{suffix}")
    idx = 2
    while cand in reserved or cand.exists():
        cand = dest.with_name(f"{stem}__{digest[:8]}_{idx}{suffix}")
        idx += 1
    reserved.add(cand)
    return cand

def main() -> None:
    ap = argparse.ArgumentParser(description="Ingest deduplicated Mathematica files into /mnt/anode warehouse.")
    ap.add_argument("--db", required=True, help="Path to master SQLite inventory")
    ap.add_argument("--dest", default="/mnt/anode/warehouse/mathematica", help="Warehouse root directory")
    ap.add_argument("--default-host", default="isotope", help="Host label when files table lacks a host column")
    ap.add_argument("--host-filter", default=None, help="Only ingest rows originating on this host")
    ap.add_argument("--exclude-m-unknown", action="store_true", help="Exclude unclassified .m files (m_unknown)")
    ap.add_argument("--dry-run", action="store_true", help="Plan and report without writing files")
    args = ap.parse_args()

    dest_root = Path(args.dest)
    if not args.dry_run:
        if not os.path.ismount("/mnt/anode"):
            raise SystemExit("ERROR: /mnt/anode is not mounted.")
        for b in ("nb", "wl", "io"):
            (dest_root / b).mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(args.db)
    cur = conn.cursor()

    file_cols = {r[1] for r in cur.execute("PRAGMA table_info(files)")}
    host_expr = "host" if "host" in file_cols else f"'{args.default_host}'"
    mtime_expr = "mtime_epoch" if "mtime_epoch" in file_cols else "0"
    id_expr = "id" if "id" in file_cols else "rowid"

    cur.execute("""
        CREATE TABLE IF NOT EXISTS ingested_sha256 (
            sha256       TEXT PRIMARY KEY,
            bucket       TEXT NOT NULL,
            dest_relpath TEXT NOT NULL,
            size_bytes   INTEGER NOT NULL,
            source_host  TEXT,
            source_path  TEXT NOT NULL,
            ingested_at  TEXT DEFAULT (datetime('now'))
        )
    """)
    conn.commit()

    already_ingested = {r[0] for r in cur.execute("SELECT sha256 FROM ingested_sha256")}
    reserved_paths = {dest_root / r[0] for r in cur.execute("SELECT dest_relpath FROM ingested_sha256")}

    excluded_tags = ["matlab_m"]
    if args.exclude_m_unknown:
        excluded_tags.append("m_unknown")
    placeholders = ",".join("?" for _ in excluded_tags)

    params = list(excluded_tags)
    host_clause = ""
    if args.host_filter:
        if "host" in file_cols:
            host_clause = "AND host = ?"
            params.append(args.host_filter)
        elif args.host_filter != args.default_host:
            host_clause = "AND 1 = 0"

    query = f"""
        SELECT sha256,
               bucket,
               CASE WHEN preserved_relpath = filename THEN 0 ELSE 1 END AS anchored,
               preserved_relpath,
               filename,
               size_bytes,
               {host_expr} AS src_host,
               full_path,
               {mtime_expr} AS mtime_val
        FROM files
        WHERE is_symlink = 0
          AND sha256 IS NOT NULL
          AND lang_tag NOT IN ({placeholders})
          {host_clause}
        ORDER BY sha256, anchored DESC, mtime_val DESC, {id_expr} ASC
    """

    candidates = []
    seen_sha = set(already_ingested)
    for row in cur.execute(query, params):
        digest = row[0]
        if digest in seen_sha:
            continue
        seen_sha.add(digest)
        candidates.append(row)

    total_bytes = sum(r[5] or 0 for r in candidates)
    print(f"Already ingested: {len(already_ingested):,} unique digests")
    print(f"Queued to ingest: {len(candidates):,} unique digests ({total_bytes / 1e9:.2f} GB)")

    copied = errors = 0
    copied_bytes = 0
    batch = []

    for i, (digest, bucket, anchored, relpath, fname, sz, host, src_str, _) in enumerate(candidates, 1):
        sub_rel = Path(bucket) / (relpath if anchored else Path("_unanchored") / fname)
        target = disambiguate(dest_root / sub_rel, digest, reserved_paths)
        final_rel = str(target.relative_to(dest_root))

        if args.dry_run:
            copied += 1
            copied_bytes += sz or 0
            continue

        src = Path(src_str)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            tmp = target.with_name(f".tmp.{target.name}.{os.getpid()}")
            shutil.copy2(src, tmp)
            actual = sha256_file(tmp)
            if actual != digest:
                tmp.unlink(missing_ok=True)
                raise ValueError(f"SHA-256 mismatch on write: expected {digest}, got {actual}")
            tmp.replace(target)
            batch.append((digest, bucket, final_rel, sz or 0, host, src_str))
            copied += 1
            copied_bytes += sz or 0
        except Exception as exc:
            errors += 1
            print(f"  [WARN] {src_str}: {exc}", flush=True)

        if len(batch) >= 500:
            cur.executemany(
                "INSERT OR IGNORE INTO ingested_sha256 (sha256, bucket, dest_relpath, size_bytes, source_host, source_path) VALUES (?, ?, ?, ?, ?, ?)",
                batch,
            )
            conn.commit()
            batch.clear()

        if i % 5000 == 0:
            print(f"  ...{i:,}/{len(candidates):,} processed ({copied_bytes / 1e9:.2f} GB written, {errors} errors)", flush=True)

    if batch:
        cur.executemany(
            "INSERT OR IGNORE INTO ingested_sha256 (sha256, bucket, dest_relpath, size_bytes, source_host, source_path) VALUES (?, ?, ?, ?, ?, ?)",
            batch,
        )
        conn.commit()

    conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    conn.close()
    mode_lbl = "DRY-RUN" if args.dry_run else "COMPLETE"
    print(f"\n[{mode_lbl}] Files: {copied:,} | Volume: {copied_bytes / 1e9:.2f} GB | Errors: {errors}")

if __name__ == "__main__":
    main()
