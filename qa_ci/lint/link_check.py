#!/usr/bin/env python3
"""Script to check and validate links in different type of files."""
import logging
import logging.config
import os
import re
import sys
import typing as t
from pathlib import Path

import requests
from fw_logging import get_log_config

loggers = {"gunicorn.access": None, "gunicorn.error": None}
logconfig_dict = get_log_config(loggers=loggers)
logging.config.dictConfig(logconfig_dict)

log = logging.getLogger(__name__)

TIMEOUT = 10
RETRYCODES = (400, 404, 405, 503)
# multiple exceptions must be tuples, not lists in general
EXC = (requests.exceptions.ReadTimeout, requests.exceptions.ConnectionError)
UNICODE_SUPPORT = str(sys.stdout.encoding).lower().startswith("utf")
FORCE_ASCII = os.environ.get("FORCE_ASCII")
OK = "\u2714" if not FORCE_ASCII and UNICODE_SUPPORT else "OK"
FAIL = "\u274c" if not FORCE_ASCII and UNICODE_SUPPORT else "FAIL"


def main(args):
    """Main function for validating links."""
    bad_urls = check_urls_in_files([Path(p) for p in args])
    if bad_urls:
        sys.exit(1)


def check_urls_in_files(paths: t.List[Path]) -> t.List[t.Tuple[str, str, t.Any]]:
    """Validate remote urls in files under given path."""
    bads: t.List[t.Tuple[str, str, t.Optional[t.Any]]] = []
    url = (
        r"https?://[a-zA-Z0-9][a-zA-Z0-9-]{1,61}"
        r"[a-zA-Z0-9]\.[=a-zA-Z0-9\_\/\?\&\%\+\#\.\-]+"
    )
    # Only for .md files
    md_url_re = re.compile(r"\(" + url + r"\)")
    local_re = re.compile(r"\]\(([=a-zA-Z0-9\_\/\?\&\%\+\#\.\-]+)\)")
    url_re = re.compile(r"(?:\#.*)(?P<url>" + url + r")")

    with requests.Session() as sess:
        sess.max_redirects = 5
        for fn in paths:
            text = fn.read_text(errors="ignore")
            if fn.suffix == ".md":
                local_urls = local_re.findall(text)
                remote_urls = md_url_re.findall(text)
                bads.extend(list(check_local(fn, local_urls)))
            else:
                remote_urls = url_re.findall(text)
            bads.extend(list(check_remote(fn, remote_urls, sess)))
    return bads


def check_local(fn: Path, urls: t.List[str]) -> t.Iterable[t.Tuple[str, str, t.Any]]:
    """Check internal links of Markdown files."""
    for url in urls:
        if url[0] == "#":
            log_success(fn, url)
            continue
        f_path = fn.parent / url.strip("/")
        is_file = f_path.is_file()
        is_dir = f_path.is_dir()
        if is_file or is_dir:
            log_success(fn, url)
        else:
            log_fail(fn, url)
            yield fn.name, url, None


def check_remote(
    fn: Path, urls: t.List[str], sess: requests.Session
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
        # anti-crawling behavior doesn't like .head()
        # method--.get() is slower but avoids lots of false positives
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


def log_fail(fn: Path, url: str):
    """Log failed link check."""
    log.error(f"{FAIL}: {fn}: {url:80s}")


def log_success(fn: Path, url: str):
    """Log successful link check."""
    log.info(f"{OK}: {fn}: {url:80s}")


if __name__ == "__main__":
    main(sys.argv[1:])  # pragma: no cover
