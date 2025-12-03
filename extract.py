#!/usr/bin/env python3
"""
extract.py

Extract all .zip files from a downloads directory into a structured extracted
directory tree.

Usage:
    python extract.py [--indir DIR] [--outdir DIR] [--overwrite] [--pattern GLOB] [--workers N] [--manifest PATH]

Output layout (new default):
    <outdir>/
        gis_data/    # GIS_Public.zip and any nested GIS zip archives
            GIS_Public/...
            <nested_gis_zip_1>/...
            ...
        pdata/       # All other property data zips (each in its own folder)
            Real_acct_owner/...
            Hearing_files/...
            ...

Cleaning behavior:
    If --overwrite is passed, existing `<outdir>/gis_data` and `<outdir>/pdata`
    directories are removed entirely before extraction starts to guarantee a
    clean, reproducible state.

GIS handling:
    GIS_Public.zip is extracted first into `gis_data/` then any nested zips
    discovered below `gis_data/GIS_Public` are extracted into `gis_data/` as
    peer folders.

Security:
    Zip-Slip protection is enforced by `safe_extract` and preserved for nested
    archives.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import logging
import os
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Optional, Sequence
from tracing import trace_span, get_tracer, span_context
import shutil


@trace_span()
def iter_zip_files(indir: str, pattern: Optional[str] = None) -> Iterable[Path]:
    p = Path(indir)
    if not p.exists():
        return []
    matches = [f for f in p.rglob("*.zip") if f.is_file()]
    if pattern:
        # Use fnmatch against the filename only and also the relative path
        filtered = []
        for f in matches:
            rel = str(f.relative_to(p))
            if fnmatch.fnmatch(f.name, pattern) or fnmatch.fnmatch(rel, pattern):
                filtered.append(f)
        return filtered
    return matches


@trace_span()
def safe_extract(zipf: zipfile.ZipFile, target_dir: Path) -> None:
    """Extract a ZipFile into target_dir while preventing Zip-Slip vulnerabilities."""
    target_dir.mkdir(parents=True, exist_ok=True)
    for member in zipf.namelist():
        member_path = target_dir.joinpath(member)
        try:
            # Resolve to check path traversal
            abs_target = member_path.resolve()
        except Exception:
            # Skip paths we can't resolve
            continue
        if not str(abs_target).startswith(str(target_dir.resolve())):
            # Unsafe path, skip
            print(f"Skipping unsafe member: {member}")
            continue
        # Create parent dirs if needed
        member_parent = abs_target.parent
        member_parent.mkdir(parents=True, exist_ok=True)
        if member.endswith("/"):
            # directory entry
            continue
        with zipf.open(member) as src, open(abs_target, "wb") as dst:
            dst.write(src.read())


@trace_span()
def extract_zip_file(
    zip_path: Path,
    outdir: Path,
    overwrite: bool = False,
    category: Optional[str] = None,
) -> dict:
    """Extract a single zip file into outdir/<zip_basename>/ and return info dict.

    Args:
        zip_path: Path to .zip archive.
        outdir: Base output directory (category root) under which a folder named after the zip basename will be created.
        overwrite: If True and destination exists, it will be deleted before extraction.
        category: Optional string identifying logical grouping (e.g. 'gis' or 'pdata').
    """
    base = zip_path.stem
    dest = outdir.joinpath(base)
    info = {
        "zip": str(zip_path),
        "destination": str(dest),
        "skipped": False,
        "extracted_files": 0,
        "total_bytes": 0,
        "error": None,
        "category": category,
    }
    if dest.exists():
        if overwrite:
            try:
                shutil.rmtree(dest)
                logging.info("Removed existing directory before overwrite: %s", dest)
            except Exception:
                logging.exception("Failed removing existing directory %s", dest)
        else:
            logging.info("Skipping existing extraction: %s", dest)
            info["skipped"] = True
            return info
    logging.info("Extracting %s -> %s", zip_path, dest)
    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            safe_extract(zf, dest)
        # compute totals
        total_files = 0
        total_bytes = 0
        for root, _, files in os.walk(dest):
            for fn in files:
                total_files += 1
                try:
                    total_bytes += os.path.getsize(os.path.join(root, fn))
                except Exception:
                    pass
        info["extracted_files"] = total_files
        info["total_bytes"] = total_bytes
    except zipfile.BadZipFile:
        info["error"] = "BadZipFile"
        logging.exception("Bad zip file: %s", zip_path)
    except Exception as e:
        info["error"] = str(e)
        logging.exception("Error extracting %s: %s", zip_path, e)
    return info


@trace_span("_extract_zip_list")
def _extract_zip_list(
    zip_paths: Sequence[Path],
    outdir_p: Path,
    overwrite: bool,
    workers: int,
    category: Optional[str] = None,
) -> List[dict]:
    """Internal helper to extract a sequence of zip Paths with optional threading.

    Each zip is extracted under outdir_p/<zip_basename>. Category passed through for manifest metadata.
    """
    results: List[dict] = []
    if not zip_paths:
        return results
    if workers and workers > 1:
        with ThreadPoolExecutor(max_workers=workers) as ex:
            futures = {
                ex.submit(extract_zip_file, z, outdir_p, overwrite, category): z
                for z in zip_paths
            }
            for fut in as_completed(futures):
                try:
                    info = fut.result()
                    results.append(info)
                except Exception as e:  # pragma: no cover (defensive)
                    z = futures[fut]
                    logging.exception("Error extracting %s: %s", z, e)
                    results.append(
                        {"zip": str(z), "destination": None, "error": str(e)}
                    )
    else:
        for z in zip_paths:
            info = extract_zip_file(z, outdir_p, overwrite=overwrite, category=category)
            results.append(info)
    return results


@trace_span()
def extract_all(
    indir: str = "downloads",
    outdir: str = "extracted",
    overwrite: bool = False,
    pattern: Optional[str] = None,
    workers: int = 1,
    manifest: Optional[str] = None,
) -> List[dict]:
    indir_p = Path(indir)
    outdir_p = Path(outdir)
    outdir_p.mkdir(parents=True, exist_ok=True)
    # Structured category roots
    pdata_root = outdir_p.joinpath("pdata")
    gis_root = outdir_p.joinpath("gis_data")
    # Clean if overwrite requested
    if overwrite:
        for p in (pdata_root, gis_root):
            if p.exists():
                try:
                    shutil.rmtree(p)
                    logging.info("Pre-clean removed directory: %s", p)
                except Exception:
                    logging.exception("Failed pre-clean removal for %s", p)
    pdata_root.mkdir(parents=True, exist_ok=True)
    gis_root.mkdir(parents=True, exist_ok=True)
    zip_files = list(iter_zip_files(indir, pattern=pattern))
    results: List[dict] = []

    if not zip_files:
        logging.info("No zip files found in %s", indir)
        return results

    # 1. Prioritize GIS_Public.zip if present.
    gis_public_candidates = [z for z in zip_files if z.name.lower() == "gis_public.zip"]
    processed: List[Path] = []
    if gis_public_candidates:
        logging.info("GIS_Public.zip detected; extracting GIS bundle first.")
        results.extend(
            _extract_zip_list(
                gis_public_candidates, gis_root, overwrite, workers, category="gis"
            )
        )
        processed.extend(gis_public_candidates)
        # Nested zips under gis_root/GIS_Public
        gis_public_dir = gis_root.joinpath("GIS_Public")
        if gis_public_dir.exists():
            nested_zips = [p for p in gis_public_dir.rglob("*.zip") if p.is_file()]
            if nested_zips:
                logging.info(
                    "Found %d nested GIS zip(s); extracting into gis_data root.",
                    len(nested_zips),
                )
                results.extend(
                    _extract_zip_list(
                        nested_zips, gis_root, overwrite, workers, category="gis"
                    )
                )
                processed.extend(nested_zips)
        else:
            logging.warning(
                "Expected GIS_Public directory not found at %s", gis_public_dir
            )

    # 2. Extract remaining (non GIS_Public) top-level zips.
    remaining = [z for z in zip_files if z not in processed]
    if remaining:
        results.extend(
            _extract_zip_list(
                remaining, pdata_root, overwrite, workers, category="pdata"
            )
        )

    # write manifest if requested
    if manifest:
        try:
            manifest_path = Path(manifest)
            if manifest_path.is_dir():
                # create timestamped manifest file in dir
                ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
                manifest_path = manifest_path.joinpath(f"manifest_{ts}.json")
            with open(manifest_path, "w", encoding="utf-8") as fh:
                json.dump(
                    {"generated_at": datetime.utcnow().isoformat(), "results": results},
                    fh,
                    indent=2,
                )
            logging.info("Wrote manifest to %s", manifest_path)
        except Exception:
            logging.exception("Failed to write manifest")

    return results


@trace_span()
def main() -> None:
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s"
    )
    parser = argparse.ArgumentParser(
        description="Extract all .zip files from a directory"
    )
    parser.add_argument(
        "--indir",
        type=str,
        default="downloads",
        help="Directory to search for .zip files",
    )
    parser.add_argument(
        "--outdir",
        type=str,
        default="extracted",
        help="Directory to extract files into",
    )
    parser.add_argument(
        "--overwrite", action="store_true", help="Overwrite existing extracted folders"
    )
    parser.add_argument(
        "--pattern",
        type=str,
        default=None,
        help="Glob pattern to filter zip files (e.g. '*owner*.zip')",
    )
    parser.add_argument(
        "--workers", type=int, default=1, help="Number of parallel extractions"
    )
    parser.add_argument(
        "--manifest",
        type=str,
        default=None,
        help="Path to manifest file or directory to write manifest JSON",
    )
    # Removed --gis-outdir (legacy behavior now replaced by structured layout)
    args = parser.parse_args()

    results = extract_all(
        args.indir,
        args.outdir,
        overwrite=args.overwrite,
        pattern=args.pattern,
        workers=args.workers,
        manifest=args.manifest,
    )
    print(f"Processed {len(results)} archive(s) into '{args.outdir}'")


if __name__ == "__main__":
    main()
