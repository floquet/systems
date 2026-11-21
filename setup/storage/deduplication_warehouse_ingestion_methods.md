# Content-Addressable Deduplication & Warehouse Ingestion: Architecture and Methods

## 1. The Scale of Redundancy Across Multi-Disk Archives

Years of iterative backups, repository clones, external Apple-formatted drives (`Paradisium`, `Infernum`, `Purgatorium`), and cross-host project trees introduce severe silent duplication. Across the 13 scanned roots on `isotope`, a raw filesystem walk discovered **1,322,000+ file entries**—yet content-level hashing revealed that roughly **9 out of every 10 files were exact byte-for-byte duplicates**.

### Empirical Deduplication Metrics (`isotope` Inventory)

| Asset Class | Raw File Entries | Unique SHA-256 Digests | Duplication Ratio | Deduplicated Volume | Disposition |
| :--- | ---: | ---: | ---: | ---: | :--- |
| **Anchored `{nb,wl,io}` subtrees (`io`)** | 179,617 | 50,412 | 3.56 : 1 | 96.62 GB | Preserved with relative directory tree |
| **Anchored `{nb,wl,io}` subtrees (`nb`)** | 526,633 | 63,438 | 8.30 : 1 | 15.97 GB | Preserved with relative directory tree |
| **Anchored `{nb,wl,io}` subtrees (`wl`)** | 9 | 7 | 1.29 : 1 | < 0.01 GB | Preserved with relative directory tree |
| **Unanchored stray files (`nb`)** | 557,413 | 18,527 | **30.09 : 1** | 28.17 GB | Routed to `nb/_unanchored/` |
| **Unanchored stray files (`io`)** | 5,280 | 1,455 | 3.63 : 1 | 1.94 GB | Routed to `io/_unanchored/` |
| **Unanchored stray files (`wl`)** | 25,040 | 5,146 | 4.87 : 1 | 0.20 GB | Routed to `wl/_unanchored/` |
| **Incidental MATLAB `.m` files** | ~28,000+ | 20,579 | — | Excluded | Quarantined from Mathematica warehouse |
| **Total Warehouse Target** | **1,293,992** | **138,985** | **9.31 : 1** | **142.90 GB** | Written once to `isobar` (`anode` / `cathode`) |

The most extreme duplication occurred in **unanchored `.nb` notebooks** (`557,413` copies collapsing to `18,527` unique files—over **30 copies per unique notebook** on average), where repeated Time Machine snapshots, folder copies, and staging backups multiplied identical notebooks across separate mount points.

---

## 2. Core Architectural Principle: Decouple Discovery from Mutation

Copying files directly during a directory walk fails for three reasons:

1. **Path-based deduplication misses renamed copies:** Two files named `orbit_v1.nb` and `orbit_final_backup.nb` have different paths and timestamps despite identical contents.
2. **Filename collisions overwrite distinct work:** Two different projects often contain `main.nb` or `init.m` with completely different contents.
3. **Network bottlenecks and interrupted transfers:** Copying hundreds of gigabytes over NFS without a persistent state ledger forces a restart from zero if a mount drops or a permission error occurs.

The pipeline solves all three problems by splitting execution into **two strictly isolated phases** backed by an embedded **SQLite relational database** (`mathematica-inventory-isotope.sqlite`):

* **Phase 1 (Read-Only Inventory & Classification):** Walk every source tree in read-only mode, compute cryptographic digests, classify ambiguous file extensions, and record metadata in SQLite without altering a single source byte.
* **Phase 2 (Deterministic Warehouse Ingestion):** Query the SQLite index using `GROUP BY sha256`, resolve path collisions mathematically in memory, verify every write with a post-copy hash check, and commit progress in atomic batches.

---

## 3. Cryptographic Content Identity (SHA-256)

Rather than comparing file sizes, filenames, or modification timestamps (`mtime`), the pipeline identifies unique content using **SHA-256** (`hashlib.sha256()`).

### Streaming Chunked Hashing

Files in scientific archives range from 200-byte `.wl` scripts to multi-gigabyte `.mx` binary dumps and `.io` datasets. Loading an entire file into RAM (`path.read_bytes()`) would exhaust memory on large artifacts. Instead, `sha256_file()` streams fixed **1 MiB (`1,048,576`-byte) blocks** through the hash state machine:

```python
def sha256_file(path: Path, bufsize: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(bufsize)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()
```

* **Memory complexity:** $O(1)$ constant memory (~1 MB buffer regardless of whether a file is 1 KB or 20 GB).
* **Collision resistance:** With a 256-bit digest space ($2^{256}$ possible outputs), two non-identical files will never produce the same hash in practice. If two paths share a SHA-256 digest, they are guaranteed to be byte-for-byte identical.

---

## 4. Semantic Triage: Separating Mathematica `.m` from MATLAB `.m`

File extensions are ambiguous across scientific ecosystems: both Wolfram Mathematica packages and MathWorks MATLAB scripts use `.m`. A naive `*.m` sweep would pollute the `wl/` warehouse with tens of thousands of third-party MATLAB toolbox files.

### Two-Stage Regex Header Inspection

Instead of scanning all 1.32 million rows, the classifier queries `SELECT sha256, MIN(full_path) FROM files WHERE ext = '.m' GROUP BY sha256`—reducing the inspection workload to **26,976 unique `.m` digests**. For each unique digest, it reads only the first **4,096 bytes** (`latin-1` decoding so arbitrary binary bytes never raise `UnicodeDecodeError`) and applies two compiled regular expressions:

1. **Mathematica signature (`MMA_RE`):** Matches Wolfram Language constructs (`BeginPackage[`, `(* ::Package:: *)`, `SetDelayed`, `Module[`, `Block[`, `ClearAll[`).
2. **MATLAB signature (`MAT_RE`):** Matches line-anchored MATLAB syntax (`function `, `%` comment lines, `classdef `, `properties`, `methods`).

This single pass isolated **20,579 incidental MATLAB digests** (`matlab_m`) from **1,188 confirmed Mathematica packages** (`mathematica_m`) and **5,209 legacy/data `.m` files** (`m_unknown`), preventing MATLAB toolboxes from ever entering `/mnt/anode/warehouse/mathematica/wl/`.

---

## 5. Canonical Representative Selection & Collision-Safe Naming

When 30 duplicate copies of the same file exist across multiple drives, the ingestion query (`ingest-mathematica.py`) must pick **one canonical source** and assign **one deterministic destination path** on `/mnt/anode`.

### Deterministic Ranking (`ORDER BY`)

The SQL query sorts candidate rows for each digest using a multi-key priority order:

```sql
ORDER BY sha256, anchored DESC, mtime_val DESC, rowid ASC
```

1. **`anchored DESC`:** Copies found inside structured `{nb, wl, io}` project subtrees (`anchored = 1`) always beat stray copies (`anchored = 0`). That preserves the file's original relative directory hierarchy (`<bucket>/<preserved_relpath>`).
2. **`mtime_val DESC`:** Among equally anchored copies, the newest modification timestamp is preferred so the destination preserves accurate file metadata via `shutil.copy2()`.
3. **Single-pass Python deduplication (`seen_sha`):** Iterating through the sorted cursor and skipping any digest already in `seen_sha` selects the highest-priority row for every unique SHA-256 in a single linear pass ($O(N)$).

### Hash-Suffixed Collision Resolution (`disambiguate`)

Across the inventory, **2,187 relative paths** had *different* file contents sharing the *same* path (for example, `projectA/nb/analysis.nb` on two drives where one copy was edited further). Overwriting would destroy unique work; skipping would lose the variant.

`disambiguate()` resolves this deterministically:

* The highest-priority version claims the clean path: `analysis.nb`.
* Any distinct SHA-256 targeting that same path receives an 8-character digest suffix before the extension: `analysis__9f4c12a8.nb`.

```python
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
```

Every unique file is preserved, paths remain human-readable, and no file is ever silently clobbered.

---

## 6. Atomic Write-Verify-Rename & Resumable Ledger

Writing 138,985 files (~143 GB) over NFSv3 requires protection against partial writes and network interruptions:

1. **Atomic Temp-File Staging:** Each file is copied to a hidden sibling `.tmp.<filename>.<pid>` on `/mnt/anode` rather than directly to its final filename.
2. **Read-Back SHA-256 Verification:** Immediately after `shutil.copy2()`, `sha256_file(tmp)` hashes the newly written file over NFS and compares it against the expected SHA-256 from SQLite. If a bit flip or truncated write ever occurs, the temp file is unlinked and an error is raised.
3. **Atomic POSIX Rename (`tmp.replace(target)`):** Only after the hash matches does the file move into its final path—guaranteeing that no half-written file ever appears in the warehouse.
4. **Checkpointed SQLite Ledger (`ingested_sha256`):** Every 500 verified files, the script commits `(sha256, bucket, dest_relpath, size_bytes, source_host, source_path)` into the `ingested_sha256` table and runs `PRAGMA wal_checkpoint(TRUNCATE)` on completion.

### Cross-Host Extensibility

Because `ingested_sha256` is keyed by `sha256`, scanning additional machines (`isomer`, `/mnt/mirovia`, `/mnt/T7-Shield`) and merging their rows into the same SQLite database requires **zero changes** to the ingestion logic: any file whose SHA-256 already exists in `ingested_sha256` is skipped automatically, transferring only genuinely unseen files to `isobar`.