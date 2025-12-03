#!/usr/bin/env python3
"""
main.py

Example entrypoint that downloads a year's CAMA files (and GIS bundle) and then
optionally extracts them into a structured directory tree.

New behavior:
    When --extract is provided, previously extracted folders are deleted and a
    fresh extraction is performed (uses overwrite cleaning logic in extract.py).

Usage examples:
    # Download only
    python main.py --year 2025 --outdir downloads/2025

    # Download then clean + extract into 'extracted' (default) directory
    python main.py --year 2025 --outdir downloads/2025 --extract

    # Custom extraction directory with manifest
    python main.py --year 2025 --outdir downloads/2025 --extract \
        --extracted-outdir extracted_2025 --manifest extracted_2025
"""

from __future__ import annotations

import argparse
from download import download_year
from extract import extract_all
from tracing import trace_span


@trace_span()
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download HCAD CAMA files for a given year"
    )
    parser.add_argument(
        "--year", type=int, required=True, help="Year to download (e.g. 2025)"
    )
    parser.add_argument(
        "--outdir", type=str, default="downloads", help="Output directory"
    )
    parser.add_argument(
        "--workers", type=int, default=4, help="Parallel downloads & extraction workers"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print URLs without downloading"
    )
    parser.add_argument(
        "--extract",
        action="store_true",
        help="After download, delete existing extracted folders (if any) and extract all archives",
    )
    parser.add_argument(
        "--extracted-outdir",
        type=str,
        default="extracted",
        help="Destination root for structured extraction (creates gis_data/ & pdata/)",
    )
    parser.add_argument(
        "--manifest",
        type=str,
        default=None,
        help="Path or directory for writing extraction manifest JSON",
    )
    parser.add_argument(
        "--pattern",
        type=str,
        default=None,
        help="Optional glob pattern to filter which zip files are extracted",
    )
    args = parser.parse_args()

    if args.dry_run:
        urls = download_year(
            args.year, outdir=args.outdir, workers=args.workers, dry_run=True
        )
        print(f"URLs to download for {args.year}:")
        for u in urls:
            print(u)
        return

    print(f"Starting download for year {args.year} into '{args.outdir}'")
    downloaded = download_year(args.year, outdir=args.outdir, workers=args.workers)
    print(f"Completed: {len(downloaded)} files downloaded")

    if args.extract:
        print(
            f"Beginning clean extraction into '{args.extracted_outdir}' (overwrite=True, workers={args.workers})"
        )
        results = extract_all(
            indir=args.outdir,
            outdir=args.extracted_outdir,
            overwrite=True,
            pattern=args.pattern,
            workers=args.workers,
            manifest=args.manifest,
        )
        extracted_ok = sum(
            1 for r in results if not r.get("error") and not r.get("skipped")
        )
        print(
            f"Extraction complete: {len(results)} archive entries processed; successful new extractions: {extracted_ok}."
        )
    else:
        print("Extraction step skipped (use --extract to enable).")


if __name__ == "__main__":
    main()
