#!/usr/bin/env python3
"""Script to check and validate links in different type of files."""
import os
import re
import requests
import typing as t
from pathlib import Path

TIMEOUT = 10
RETRYCODES = (400, 404, 405, 503)
# multiple exceptions must be tuples, not lists in general
OKE = (
    requests.exceptions.TooManyRedirects
)  # FIXME: until full browswer like Arsenic implemented
EXC = (requests.exceptions.ReadTimeout, requests.exceptions.ConnectionError)
IGNORED = [".git"]


def main():
    """Main function for validating links."""
    print("Walk through $PWD")
    bad_urls = check_urls(Path(os.environ["PWD"]))
    print(f"Bad urls: {bad_urls}")


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
            continue
        stem = url.strip("/")
        if not url[0] == "/":
            if {"/", "."}.intersection(stem) or (path / stem).is_file():
                continue
            yield fn.name, url
            continue
        if {"/", "."}.intersection(stem):
            continue
        if not (
            (path / stem).is_file()
            or (path.parent / stem).is_file()
            or (path / stem).is_dir()
        ):
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
                    continue
                else:
                    yield fn.name, url, resp.status_code
                    continue
        except EXC as e:
            if retry(url):
                continue
            yield fn.name, url, str(e)
            continue

        code = resp.status_code
        if code != 200:
            yield fn.name, url, code
        else:
            print(f"OK: {url:80s}")


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


def get_files(path: Path, ext: t.Optional[str] = None) -> t.Iterable[Path]:
    """Yield files in path with suffix ext and recurse directories."""
    path = Path(path).expanduser().resolve()
    if path.name in IGNORED:
        return
    if path.is_dir():
        for p in path.iterdir():
            if p.is_file() and (not ext or p.suffix == ext):
                yield p
            elif p.is_dir():
                yield from get_files(p)
    elif path.is_file() and (not ext or path.suffix == ext):
        yield path
    else:
        raise FileNotFoundError(path)


if __name__ == "__main__":
    main()
