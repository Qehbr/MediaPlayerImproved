# SPDX-License-Identifier: GPL-2.0-or-later
"""Fetch public Google Play and Apple App Store icon metadata.

The module does not download icon images or change desktop files. Store results
are matched by exact normalized name unless a package or bundle ID is supplied.
Names are not globally unique; callers must retain known identity constraints.
Network errors propagate so the caller can record them and try another source.
AmbiguousMatch means the caller must stop the chain until identity is resolved.
"""

from __future__ import annotations

import gzip
import io
import json
import re
import unicodedata
import urllib.parse
import urllib.request

from bs4 import BeautifulSoup

MAX_RESPONSE = 4 * 1024 * 1024
TIMEOUT = 12
_PACKAGE_RE = re.compile(r"[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+\Z")
_BUNDLE_RE = re.compile(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+\Z")


class AmbiguousMatch(ValueError):
    """Multiple distinct apps match; do not continue with another provider."""


def norm(value: str) -> str:
    """Normalize case and whitespace without dropping meaningful punctuation."""
    if not isinstance(value, str):
        return ""
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def _https_url(value, hosts=None, suffix=None):
    """Return a parsed URL only for HTTPS hosts without credentials or odd ports."""
    if not isinstance(value, str) or any(ord(c) < 32 for c in value):
        return None
    try:
        parsed = urllib.parse.urlsplit(value)
        if (parsed.scheme != "https" or not parsed.hostname
                or parsed.username is not None or parsed.password is not None
                or parsed.port not in (None, 443)):
            return None
    except ValueError:
        return None
    host = parsed.hostname.lower()
    if hosts is not None and host not in hosts:
        return None
    if suffix is not None and not host.endswith("." + suffix):
        return None
    return parsed


class _SameHostRedirect(urllib.request.HTTPRedirectHandler):
    def __init__(self, host):
        super().__init__()
        self.host = host

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urllib.parse.urljoin(req.full_url, newurl)
        if _https_url(target, hosts={self.host}) is None:
            raise ValueError("Store response redirected outside its HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, target)


def read_url(url: str) -> bytes:
    """Fetch bounded public metadata, including bounded gzip decompression."""
    parsed = _https_url(url)
    if parsed is None:
        raise ValueError("An HTTPS metadata URL is required")
    request = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (compatible; MediaPlayerImprovedMobileIcons/1.0)",
        "Accept-Encoding": "gzip, identity",
    })
    opener = urllib.request.build_opener(_SameHostRedirect(parsed.hostname.lower()))
    with opener.open(request, timeout=TIMEOUT) as response:
        if _https_url(response.url, hosts={parsed.hostname.lower()}) is None:
            raise ValueError("Unexpected metadata response URL")
        raw = response.read(MAX_RESPONSE + 1)
        encoding = response.headers.get("Content-Encoding", "identity").strip().lower()
    if len(raw) > MAX_RESPONSE:
        raise ValueError("Metadata response exceeds size limit")
    if encoding == "gzip":
        with gzip.GzipFile(fileobj=io.BytesIO(raw)) as compressed:
            raw = compressed.read(MAX_RESPONSE + 1)
        if len(raw) > MAX_RESPONSE:
            raise ValueError("Decompressed metadata exceeds size limit")
    elif encoding not in ("", "identity"):
        raise ValueError("Unsupported metadata content encoding")
    return raw


def parse_play_search(html) -> list[dict]:
    """Read app labels and package IDs; never treat ratings as part of a name."""
    soup = BeautifulSoup(html, "html.parser")
    found = {}
    for anchor in soup.find_all("a", href=True):
        url = urllib.parse.urljoin("https://play.google.com", anchor["href"])
        parsed = _https_url(url, hosts={"play.google.com"})
        if parsed is None or parsed.path != "/store/apps/details":
            continue
        packages = urllib.parse.parse_qs(parsed.query).get("id", [])
        if len(packages) != 1 or not _PACKAGE_RE.fullmatch(packages[0]):
            continue
        name = anchor.get("aria-label", "").strip()
        if not name:
            image = anchor.find("img", alt=re.compile(r"^Icon image "))
            if image:
                name = image["alt"][len("Icon image "):].strip()
        if not name:
            title = anchor.select_one("span.DdYX5")
            if title:
                name = title.get_text(" ", strip=True)
        if name:
            found[packages[0]] = {"name": name, "package": packages[0]}
    return list(found.values())


def _schema_apps(value):
    if isinstance(value, list):
        for item in value:
            yield from _schema_apps(item)
    elif isinstance(value, dict):
        kind = value.get("@type")
        if kind == "SoftwareApplication" or (
                isinstance(kind, list) and "SoftwareApplication" in kind):
            yield value
        if "@graph" in value:
            yield from _schema_apps(value["@graph"])


def _author_name(value):
    if isinstance(value, str):
        return value.strip() or None
    if isinstance(value, dict):
        return _author_name(value.get("name"))
    if isinstance(value, list):
        names = list(dict.fromkeys(filter(None, (_author_name(x) for x in value))))
        return ", ".join(names) or None
    return None


def parse_play_detail(html, expected_package: str):
    """Verify the canonical package and read only the primary app's JSON-LD."""
    if not isinstance(expected_package, str) or not _PACKAGE_RE.fullmatch(expected_package):
        raise ValueError("Invalid Android package ID")
    soup = BeautifulSoup(html, "html.parser")
    canonical = soup.find("meta", property="og:url")
    page = canonical.get("content", "") if canonical else ""
    parsed = _https_url(page, hosts={"play.google.com"})
    if (parsed is None or parsed.path != "/store/apps/details"
            or urllib.parse.parse_qs(parsed.query).get("id") != [expected_package]):
        return None
    candidates = []
    for tag in soup.find_all("script", type="application/ld+json"):
        try:
            document = json.loads(tag.get_text())
        except (TypeError, ValueError):
            continue
        for app in _schema_apps(document):
            name = app.get("name")
            image = app.get("image")
            if isinstance(image, dict):
                image = image.get("contentUrl") or image.get("url")
            if (not isinstance(name, str) or not name.strip()
                    or _https_url(image, hosts={"play-lh.googleusercontent.com"}) is None):
                continue
            candidates.append({
                "provider": "google-play", "name": name.strip(),
                "package": expected_package, "author": _author_name(app.get("author")),
                "icon": image, "page": page,
            })
    unique = {(x["name"], x["icon"]): x for x in candidates}
    return next(iter(unique.values())) if len(unique) == 1 else None


def google_play(name: str, expected_package: str | None = None):
    """Find an exact unique app, or fetch a known Android package directly."""
    if expected_package is not None:
        if not isinstance(expected_package, str) or not _PACKAGE_RE.fullmatch(expected_package):
            raise ValueError("Invalid Android package ID")
        package = expected_package
    else:
        if not norm(name):
            return None
        query = urllib.parse.urlencode({"q": name, "c": "apps", "hl": "en", "gl": "US"})
        html = read_url("https://play.google.com/store/search?" + query)
        candidates = [x for x in parse_play_search(html) if norm(x["name"]) == norm(name)]
        if len(candidates) > 1:
            raise AmbiguousMatch("Multiple Google Play packages have this exact app name")
        if not candidates:
            return None
        package = candidates[0]["package"]
    query = urllib.parse.urlencode({"id": package, "hl": "en", "gl": "US"})
    result = parse_play_detail(read_url("https://play.google.com/store/apps/details?" + query), package)
    if result and (expected_package is not None or norm(result["name"]) == norm(name)):
        return result
    return None


def parse_apple_search(raw, name: str, expected_bundle: str | None = None):
    """Read Apple search or lookup JSON and reject ambiguous app identities."""
    data = json.loads(raw)
    if not isinstance(data, dict) or not isinstance(data.get("results"), list):
        return None
    matches = {}
    for app in data["results"]:
        if not isinstance(app, dict) or app.get("kind") != "software" or app.get("wrapperType") != "software":
            continue
        bundle, title = app.get("bundleId"), app.get("trackName")
        if not isinstance(bundle, str) or not _BUNDLE_RE.fullmatch(bundle):
            continue
        if expected_bundle is not None:
            if bundle != expected_bundle:
                continue
        elif not norm(name) or norm(title) != norm(name):
            continue
        if not isinstance(title, str) or not title.strip():
            continue
        track_id = app.get("trackId")
        if not isinstance(track_id, int) or isinstance(track_id, bool) or track_id <= 0:
            continue
        image = app.get("artworkUrl512") or app.get("artworkUrl100")
        page = app.get("trackViewUrl")
        parsed_page = _https_url(page, hosts={"apps.apple.com", "itunes.apple.com"})
        if (_https_url(image, suffix="mzstatic.com") is None or parsed_page is None
                or not re.search(r"/id" + str(track_id) + r"(?:/|$)", parsed_page.path)):
            continue
        matches[bundle] = {
            "provider": "apple-app-store", "name": title.strip(), "bundleId": bundle,
            "trackId": track_id, "author": _author_name(app.get("artistName")),
            "icon": image, "page": page,
        }
    if len(matches) > 1:
        raise AmbiguousMatch("Multiple Apple App Store bundles have this exact app name")
    return next(iter(matches.values())) if matches else None


def apple(name: str, expected_bundle: str | None = None):
    """Use a pinned bundle lookup when possible; otherwise search exact names."""
    if expected_bundle is not None:
        if not isinstance(expected_bundle, str) or not _BUNDLE_RE.fullmatch(expected_bundle):
            raise ValueError("Invalid Apple bundle ID")
        endpoint = "lookup"
        params = {"bundleId": expected_bundle, "entity": "software", "country": "us"}
    else:
        if not norm(name):
            return None
        endpoint = "search"
        params = {"term": name, "entity": "software", "media": "software", "country": "us", "limit": 50}
    url = "https://itunes.apple.com/" + endpoint + "?" + urllib.parse.urlencode(params)
    return parse_apple_search(read_url(url), name, expected_bundle)
