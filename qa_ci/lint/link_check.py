#!/usr/bin/env python3
"""Script to check and validate links in different type of files."""
import os
import re
import requests
import sys
import typing as t
from pathlib import Path

TIMEOUT = 10
RETRYCODES = (400, 404, 405, 503)
# multiple exceptions must be tuples, not lists in general
EXC = (requests.exceptions.ReadTimeout, requests.exceptions.ConnectionError)
INCLUDE = []
EXCLUDE = []
UNICODE_SUPPORT = sys.stdout.encoding.lower().startswith("utf")
OK = "\u2714" if not os.environ.get("FORCE_ASCII") and UNICODE_SUPPORT else "OK"
FAIL = "\u274c" if not os.environ.get("FORCE_ASCII") and UNICODE_SUPPORT else "FAIL"


def main():
    """Main function for validating links."""
    setup_include_exclude()
    bad_urls = check_urls(Path(os.environ["PWD"]))
    if bad_urls:
        sys.exit(1)


def setup_include_exclude():
    """Validate and set up INCLUDE/EXCLUDE."""
    global INCLUDE
    global EXCLUDE
    if os.environ.get("FLYWHEEL_LINK_CHECK_INC"):
        INCLUDE = os.environ.get("FLYWHEEL_LINK_CHECK_INC").split(":")
    if os.environ.get("FLYWHEEL_LINK_CHECK_EXC"):
        if INCLUDE:
            raise ValueError(
                "FLYWHEEL_LINK_CHECK_INC and FLYWHEEL_LINK_CHECK_EXC are mutually exclusive"
            )
        EXCLUDE = os.environ.get("FLYWHEEL_LINK_CHECK_EXC").split(":")
    elif not INCLUDE:
        EXCLUDE = [".git"]


def check_urls(path: Path) -> t.List[t.Tuple[str, str, t.Any]]:
    """Validate remote urls in files under given path."""
    bads: t.List[t.Tuple[str, str, t.Any]] = []
    url_re = r"https?://[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[=a-zA-Z0-9\_\/\?\&\%\+\#\.\-]+"
    # Only for .md files
    md_url_re = re.compile(r"\(" + url_re + r"\)")
    local_re = re.compile(r"\]\(([=a-zA-Z0-9\_\/\?\&\%\+\#\.\-]+)\)")
    url_re = re.compile(r"(?:\#.*)(?P<url>" + url_re + r")")

    with requests.Session() as sess:
        sess.max_redirects = 5
        for fn in get_files(path):
            text = fn.read_text(errors="ignore")
            if fn.suffix == ".md":
                local_urls = local_re.findall(text)
                remote_urls = md_url_re.findall(text)
                bads.extend([bad for bad in check_local(path, fn, local_urls)])
            else:
                remote_urls = url_re.findall(text)
            bads.extend([bad for bad in check_remote(fn, remote_urls, sess)])

    return bads


def check_local(
    path: Path, fn: Path, urls: t.List[str]
) -> t.Iterable[t.Tuple[str, str]]:
    """Check internal links of Markdown files.

    This is a simple static analysis; only plain filename references are handled.
    """
    for url in urls:
        if url[0] == "#":
            log_success(fn, url)
            continue
        stem = url.strip("/")
        if not url[0] == "/":
            if {"/", "."}.intersection(stem) or (path / stem).is_file():
                log_success(fn, url)
                continue
            log_fail(fn, url)
            yield fn.name, url
            continue
        if {"/", "."}.intersection(stem):
            log_success(fn, url)
            continue
        if not (
            (path / stem).is_file()
            or (path.parent / stem).is_file()
            or (path / stem).is_dir()
        ):
            log_fail(fn, url)
            yield fn.name, url


def check_remote(
    fn: Path, urls: t.List[str], sess
) -> t.Iterable[t.Tuple[str, str, t.Any]]:
    """Validate remote url."""
    for url in urls:
        if fn.suffix == ".md":
            url = url[1:-1]
        try:
            resp = sess.head(url, allow_redirects=True, timeout=TIMEOUT)
            if resp.status_code in RETRYCODES:
                if retry(url):
                    log_success(fn, url)
                    continue
                else:
                    log_fail(fn, url)
                    yield fn.name, url, resp.status_code
                    continue
        except EXC as e:
            if retry(url):
                log_success(fn, url)
                continue
            log_fail(fn, url)
            yield fn.name, url, str(e)
            continue
        code = resp.status_code
        if code != 200:
            log_fail(fn, url)
            yield fn.name, url, code
        else:
            log_success(fn, url)


def retry(url: str) -> bool:
    """Retry function for specific status codes."""
    ok = False
    try:
        # anti-crawling behavior doesn't like .head() method--.get() is slower but avoids lots of false positives
        with requests.get(
            url, allow_redirects=True, timeout=TIMEOUT, stream=True
        ) as stream:
            resp_bytes = next(stream.iter_lines(80), None)
            # if resp_bytes is not None and 'html' in resp_bytes.decode('utf8'):
            if resp_bytes and len(resp_bytes) > 10:
                ok = True
    except EXC:
        pass
    return ok


def get_files(path: Path) -> t.Iterable[Path]:
    """Yield files in path matching INCLUDE/EXCLUDE."""
    path = Path(path).expanduser().resolve()
    if INCLUDE:
        for inc in INCLUDE:
            for p in list(path.rglob(f"*{inc}*")).sort():
                yield from iter_path(p)
    else:
        yield from iter_path(path)


def iter_path(path: Path) -> t.Iterable[Path]:
    """Yield files in path and recurse directories."""
    path = Path(path).expanduser().resolve()
    if all(p in EXCLUDE for p in [path, path.stem, path.name]):
        return
    if path.is_dir():
        for p in path.iterdir():
            if p.is_file():
                yield p
            elif p.is_dir():
                yield from iter_path(p)
    elif path.is_file():
        yield path
    else:
        raise FileNotFoundError(path)


def log_fail(fn: Path, url: str):
    """Log failed link check."""
    print(f"{FAIL}: {fn}: {url:80s}")


def log_success(fn: Path, url: str):
    """Log successful link check."""
    print(f"{OK}: {fn}: {url:80s}")


if __name__ == "__main__":
    main()
