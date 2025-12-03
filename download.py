#!/usr/bin/env python3
"""
download.py

Download all .zip files linked from a provided web page.

Usage:
        python download.py [--url URL] [--outdir DIR] [--workers N] [--dry-run]

Defaults:
        URL: https://hcad.org/pdata/pdata-property-downloads.html
        DIR: ./downloads
        WORKERS: 4

Requires: requests, beautifulsoup4
Optional: tqdm (for nicer progress bars)
"""

from __future__ import annotations

import argparse
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Iterable, Optional
from tracing import trace_span, get_tracer, span_context

try:
    import requests
except Exception:
    raise SystemExit(
        "Missing dependency: requests. Install with `pip install requests beautifulsoup4`."
    )

try:
    from bs4 import BeautifulSoup
except Exception:
    raise SystemExit(
        "Missing dependency: beautifulsoup4. Install with `pip install requests beautifulsoup4`."
    )

try:
    from tqdm import tqdm

    HAS_TQDM = True
except Exception:
    HAS_TQDM = False

from urllib.parse import urljoin, urlparse

DEFAULT_URL = "https://hcad.org/pdata/pdata-property-downloads.html"

# Default named file list (filenames under the year folder at download.hcad.org)
DEFAULT_FILENAMES = [
    "Real_acct_owner.zip",
    "Real_acct_ownership_history.zip",
    "Real_building_land.zip",
    "Real_jur_exempt.zip",
    "Code_description_real.zip",
    "PP_files.zip",
    "Code_description_pp.zip",
    "Hearing_files.zip",
]

# Any fully-qualified URLs to always include alongside the year-built CAMA files
DEFAULT_ADDITIONAL_URLS = [
    "https://download.hcad.org/data/GIS/GIS_Public.zip",
]


@trace_span()
def build_urls_for_year(
    year: int,
    filenames: list[str],
    base: str = "https://download.hcad.org/data/CAMA/{year}/{fname}",
) -> list[str]:
    """Return full URLs for the given year and filenames using f-string style formatting."""
    urls = []
    for fname in filenames:
        # Ensure filename ends with .zip
        if not fname.lower().endswith(".zip"):
            fname = fname + ".zip"
        urls.append(base.format(year=year, fname=fname))
    return urls


@trace_span()
def download_year(
    year: int,
    outdir: str = "downloads",
    workers: int = 4,
    filenames: Optional[list[str]] = None,
    base: str = "https://download.hcad.org/data/CAMA/{year}/{fname}",
    dry_run: bool = False,
) -> list[str]:
    """Convenience function to download the default CAMA files for a given year.

    Args:
            year: Year to use in the URL template.
            outdir: Directory to save downloads.
            workers: Number of parallel downloads.
            filenames: Optional list of filenames (defaults to `DEFAULT_FILENAMES`).
            base: URL template with `{year}` and `{fname}` placeholders.
            dry_run: If True, do not download; return the list of URLs.

    Returns:
            List of downloaded file paths (or the list of URLs if `dry_run=True`).
    """
    if filenames is None:
        filenames = DEFAULT_FILENAMES
    urls = build_urls_for_year(year, filenames, base=base)
    # append any additional absolute URLs (e.g., GIS/Public)
    urls.extend(DEFAULT_ADDITIONAL_URLS)
    if dry_run:
        return urls
    return download_all(urls, outdir, workers=workers)


@trace_span()
def find_zip_links(page_url: str, session: requests.Session) -> list[str]:
    """Return a list of absolute URLs pointing to .zip files found on the page.

    Args:
            page_url: The page to parse.
            session: A requests.Session instance to use for fetching.
    """
    r = session.get(page_url, timeout=15)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    links = set()
    for a in soup.find_all("a", href=True):
        href = str(a["href"]).strip()
        # Accept zip links that end with .zip (maybe with query/fragment)
        if ".zip" in href.lower():
            full = urljoin(page_url, href)
            # Only accept http/https
            parsed = urlparse(full)
            if parsed.scheme in ("http", "https"):
                links.add(full)
    return sorted(links)


@trace_span()
def filename_from_url(url: str, resp: Optional[requests.Response] = None) -> str:
    """Try to derive the best filename: use content-disposition, otherwise path basename.
    Fall back to a URL-escaped name if needed.
    """
    # Try header
    if resp is not None:
        cd = resp.headers.get("content-disposition")
        if cd:
            # naive parse
            parts = cd.split(";")
            for p in parts:
                if "filename=" in p.lower():
                    fname = p.split("=", 1)[1].strip().strip('"')
                    return fname
    parsed = urlparse(url)
    name = os.path.basename(parsed.path) or parsed.netloc
    if not name:
        name = parsed.netloc
    return name


@trace_span()
def download_file(
    url: str,
    outdir: str,
    session: requests.Session,
    chunk_size: int = 8192,
    retry: int = 3,
) -> str:
    """Download a single file, with retries.

    Returns: path to the file on disk.
    """
    for attempt in range(1, retry + 1):
        try:
            r = session.get(url, stream=True, timeout=30)
            r.raise_for_status()
            fname = filename_from_url(url, r)
            outpath = os.path.join(outdir, fname)
            # If file exists and size matches, skip
            if os.path.exists(outpath):
                remote_size = r.headers.get("Content-Length")
                if remote_size is not None:
                    try:
                        remote_size = int(remote_size)
                    except Exception:
                        remote_size = None
                if remote_size is None or os.path.getsize(outpath) == remote_size:
                    return outpath
            # Stream write to file
            total = None
            content_length = r.headers.get("Content-Length")
            if content_length is not None:
                try:
                    total = int(content_length)
                except Exception:
                    total = None
            if HAS_TQDM and total:
                with (
                    open(outpath + ".part", "wb") as fh,
                    tqdm(
                        total=total,
                        unit="B",
                        unit_scale=True,
                        unit_divisor=1024,
                        leave=False,
                        desc=fname,
                    ) as pbar,
                ):
                    for chunk in r.iter_content(chunk_size=chunk_size):
                        if chunk:
                            fh.write(chunk)
                            pbar.update(len(chunk))
                os.replace(outpath + ".part", outpath)
            else:
                with open(outpath + ".part", "wb") as fh:
                    for chunk in r.iter_content(chunk_size=chunk_size):
                        if chunk:
                            fh.write(chunk)
                os.replace(outpath + ".part", outpath)
            return outpath
        except Exception as e:
            if attempt < retry:
                time.sleep(1 * attempt)
                continue
            raise
    # If we somehow exit the retry loop without returning or raising, raise a clear error
    raise RuntimeError(f"Failed to download {url} after {retry} attempts")


@trace_span()
def download_all(urls: Iterable[str], outdir: str, workers: int = 4) -> list[str]:
    os.makedirs(outdir, exist_ok=True)
    results = []
    with requests.Session() as session:
        session.headers.update(
            {"User-Agent": "HCAD-zip-downloader/1.0 (+https://github.com)"}
        )
        with ThreadPoolExecutor(max_workers=workers) as ex:
            futures = {ex.submit(download_file, u, outdir, session): u for u in urls}
            if HAS_TQDM:
                for fut in tqdm(
                    as_completed(futures), total=len(futures), desc="Downloading"
                ):
                    try:
                        path = fut.result()
                        results.append(path)
                    except Exception as e:
                        print(f"Error downloading {futures[fut]}: {e}")
            else:
                for fut in as_completed(futures):
                    try:
                        path = fut.result()
                        results.append(path)
                    except Exception as e:
                        print(f"Error downloading {futures[fut]}: {e}")
    return results


@trace_span()
def main():
    parser = argparse.ArgumentParser(
        description="Download all .zip files linked from a webpage."
    )
    parser.add_argument(
        "--url", type=str, default=DEFAULT_URL, help="Page URL to scan for .zip files"
    )
    parser.add_argument(
        "--outdir", type=str, default="downloads", help="Directory to save downloads"
    )
    parser.add_argument(
        "--workers", type=int, default=4, help="Number of parallel downloads"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List files to download without downloading",
    )
    parser.add_argument(
        "--use-named-list",
        action="store_true",
        help="Use the built-in list of CAMA filenames and build URLs using --year",
    )
    parser.add_argument(
        "--year",
        type=int,
        default=None,
        help="Year to use when building URLs with --use-named-list (e.g. 2025)",
    )
    args = parser.parse_args()

    with requests.Session() as session:
        session.headers.update(
            {"User-Agent": "HCAD-zip-downloader/1.0 (+https://github.com)"}
        )
        if args.use_named_list:
            if args.year is None:
                print("Error: --year is required when using --use-named-list")
                return
            print(f"Building URLs for year {args.year} using built-in filenames...")
            zip_urls = build_urls_for_year(args.year, DEFAULT_FILENAMES)
            # include any additional absolute URLs (e.g., GIS/Public)
            zip_urls.extend(DEFAULT_ADDITIONAL_URLS)
        else:
            print(f"Scanning {args.url} for .zip files...")
            zip_urls = find_zip_links(args.url, session)
            if not zip_urls:
                print("No .zip files found on the page.")
                return
        print(f"Found {len(zip_urls)} zip file(s):")
        for z in zip_urls:
            print("  ", z)
        if args.dry_run:
            print("Dry run: not downloading.")
            return
        print(f"Downloading into: {args.outdir} (workers={args.workers})")
        downloaded = download_all(zip_urls, args.outdir, workers=args.workers)
        print(f"Downloaded {len(downloaded)} file(s).")


if __name__ == "__main__":
    main()
