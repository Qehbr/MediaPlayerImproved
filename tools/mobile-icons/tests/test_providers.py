# SPDX-License-Identifier: GPL-2.0-or-later
"""Offline structural fixtures for public store metadata and URL boundaries."""
import gzip
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import providers as p


def play_detail(package="org.example.player", **changes):
    app = {"@type": "SoftwareApplication", "name": "Player",
           "image": "https://play-lh.googleusercontent.com/icon",
           "author": {"@type": "Organization", "name": "Example"}}
    app.update(changes)
    return ('<meta property="og:url" content="https://play.google.com/store/apps/details?id='
            + package + '"><script type="application/ld+json">'
            + json.dumps({"@graph": [app]}) + '</script>')


def apple_app(bundle="org.example.player", **changes):
    app = {"kind": "software", "wrapperType": "software", "bundleId": bundle,
           "trackName": "Player", "trackId": 123, "artistName": "Example",
           "artworkUrl512": "https://is1-ssl.mzstatic.com/image/icon.png",
           "trackViewUrl": "https://apps.apple.com/us/app/player/id123?uo=4"}
    app.update(changes)
    return app


class ProviderTests(unittest.TestCase):
    def test_play_search_name_sources_do_not_include_ratings(self):
        html = '''<a href="/store/apps/details?id=org.example.first" aria-label="First">4.9</a>
        <a href="/store/apps/details?id=org.example.second"><img alt="Icon image Second">4.8</a>
        <a href="/store/apps/details?id=org.example.third"><span class="DdYX5">Third</span>4.7</a>
        <a href="/store/apps/details?id=org.example.first" aria-label="First">duplicate</a>'''
        self.assertEqual(p.parse_play_search(html), [
            {"name": "First", "package": "org.example.first"},
            {"name": "Second", "package": "org.example.second"},
            {"name": "Third", "package": "org.example.third"},
        ])

    def test_play_search_rejects_untrusted_and_ambiguous_package_urls(self):
        html = '''<a aria-label="Player" href="https://play.google.com.evil.test/store/apps/details?id=org.fake.app"></a>
        <a aria-label="Player" href="http://play.google.com/store/apps/details?id=org.fake.app"></a>
        <a aria-label="Player" href="/store/apps/details?id=org.one.app&amp;id=org.two.app"></a>
        <a aria-label="Player" href="/store/apps/details?id=../invalid"></a>'''
        self.assertEqual(p.parse_play_search(html), [])

    def test_play_detail_verifies_canonical_package_and_cdn(self):
        self.assertEqual(p.parse_play_detail(play_detail(), "org.example.player")["author"], "Example")
        self.assertIsNone(p.parse_play_detail(play_detail("org.other.player"), "org.example.player"))
        self.assertIsNone(p.parse_play_detail(play_detail(image="https://evil.test/icon.png"), "org.example.player"))
        self.assertIsNone(p.parse_play_detail(play_detail().replace("https://play.google.com/", "https://play.google.com.evil.test/"), "org.example.player"))

    def test_play_detail_handles_author_shapes_and_image_objects(self):
        for author in ("Example", {"name": "Example"}, [{"name": "Example"}, "Example"]):
            with self.subTest(author=author):
                raw = play_detail(author=author, image={"contentUrl": "https://play-lh.googleusercontent.com/icon"})
                self.assertEqual(p.parse_play_detail(raw, "org.example.player")["author"], "Example")

    def test_play_requires_unique_exact_search_name(self):
        exact = '<a aria-label="Player" href="/store/apps/details?id=org.example.player"></a>'
        other = '<a aria-label="Player Pro" href="/store/apps/details?id=org.other.player"></a>'
        with patch.object(p, "read_url", side_effect=[exact + other, play_detail()]) as read:
            result = p.google_play(" player ")
        self.assertEqual(result["package"], "org.example.player")
        self.assertEqual(read.call_count, 2)
        with patch.object(p, "read_url", return_value=exact + other.replace("Player Pro", "Player")):
            with self.assertRaises(p.AmbiguousMatch):
                p.google_play("Player")

    def test_play_pin_uses_detail_without_name_search(self):
        with patch.object(p, "read_url", return_value=play_detail(name="Localized Player")) as read:
            self.assertEqual(p.google_play("Player", "org.example.player")["name"], "Localized Player")
        self.assertEqual(read.call_count, 1)
        self.assertIn("/store/apps/details?", read.call_args.args[0])

    def test_apple_unique_exact_identity_and_duplicate_deduplication(self):
        raw = json.dumps({"results": [apple_app(), apple_app(), apple_app("org.other.player", trackName="Player Pro")]})
        self.assertEqual(p.parse_apple_search(raw, "PLAYER")["bundleId"], "org.example.player")
        with self.assertRaises(p.AmbiguousMatch):
            p.parse_apple_search(json.dumps({"results": [apple_app(), apple_app("org.other.player")]}), "Player")

    def test_apple_rejects_wrong_domains_and_track_ids(self):
        for changes in ({"artworkUrl512": "https://mzstatic.com.evil.test/icon"},
                        {"trackViewUrl": "https://apps.apple.com.evil.test/id123"},
                        {"trackViewUrl": "https://apps.apple.com/us/app/id124"},
                        {"trackId": True}, {"trackId": "123"}, {"kind": "song"}):
            with self.subTest(changes=changes):
                self.assertIsNone(p.parse_apple_search(json.dumps({"results": [apple_app(**changes)]}), "Player"))

    def test_apple_pin_uses_bundle_lookup_and_allows_localized_title(self):
        raw = json.dumps({"results": [apple_app(trackName="Localized Player"), apple_app("org.other.player")]})
        with patch.object(p, "read_url", return_value=raw) as read:
            result = p.apple("Player", "org.example.player")
        self.assertEqual(result["bundleId"], "org.example.player")
        self.assertIn("/lookup?bundleId=org.example.player&", read.call_args.args[0])

    def test_invalid_pins_fail_before_network(self):
        with patch.object(p, "read_url") as read:
            for lookup in (p.google_play, p.apple):
                with self.assertRaises(ValueError):
                    lookup("Player", "https://evil.test/package")
            read.assert_not_called()

    def test_network_errors_propagate(self):
        with patch.object(p, "read_url", side_effect=TimeoutError("offline")):
            for lookup in (p.google_play, p.apple):
                with self.assertRaises(TimeoutError):
                    lookup("Player")

    def test_https_validation_and_redirects(self):
        for url in ("http://play.google.com/", "https://user@play.google.com/",
                    "https://play.google.com:8443/", "https://play.google.com/\n"):
            self.assertIsNone(p._https_url(url))
        handler = p._SameHostRedirect("play.google.com")
        request = urllib.request.Request("https://play.google.com/start")
        self.assertEqual(handler.redirect_request(request, None, 302, "Found", {}, "/next").full_url,
                         "https://play.google.com/next")
        for url in ("https://evil.test/next", "http://play.google.com/next"):
            with self.assertRaises(ValueError):
                handler.redirect_request(request, None, 302, "Found", {}, url)

    def test_bounded_response_and_gzip_expansion(self):
        def response(data, encoding="identity"):
            stream = io.BytesIO(data)
            stream.headers = {"Content-Encoding": encoding}
            stream.url = "https://play.google.com/test"
            return stream
        with patch.object(p, "MAX_RESPONSE", 128), patch.object(p.urllib.request, "build_opener") as build:
            build.return_value.open.return_value = response(b"small")
            self.assertEqual(p.read_url("https://play.google.com/test"), b"small")
            build.return_value.open.return_value = response(b"x" * 129)
            with self.assertRaises(ValueError):
                p.read_url("https://play.google.com/test")
            build.return_value.open.return_value = response(gzip.compress(b"x" * 129), "gzip")
            with self.assertRaises(ValueError):
                p.read_url("https://play.google.com/test")


if __name__ == "__main__":
    unittest.main()
