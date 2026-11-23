"""Tests for the capture core.

Run with:  make -C ~/.dotfiles/capture test

Stdlib unittest on purpose: this runs on the capture path, so it must be
runnable on a fresh machine before any package manager exists.
"""

import os
import sys
import tempfile
import unicodedata
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))

import capture_core  # noqa: E402

NOW = datetime(2026, 9, 8, 9, 14, 32, tzinfo=timezone(timedelta(hours=-7)))


class SlugTests(unittest.TestCase):
    def test_takes_the_opening_words_lowercased_and_hyphenated(self):
        self.assertEqual(
            "the-friction-is-naming-it-not-typing-it",
            capture_core.slug("The friction is naming it, not typing it"),
        )

    def test_stops_at_eight_words_so_the_name_stays_scannable(self):
        self.assertEqual(
            "one-two-three-four-five-six-seven-eight",
            capture_core.slug("one two three four five six seven eight nine ten"),
        )

    def test_keeps_hangul_rather_than_stripping_it_to_the_fallback(self):
        # The whole reason the filter is category-based. An ASCII allowlist
        # would reduce every Korean thought to `note`.
        self.assertEqual("무인도-재건-순서", capture_core.slug("무인도 재건 순서"))

    def test_handles_mixed_scripts_in_one_thought(self):
        self.assertEqual("docker-의-volume-구조", capture_core.slug("Docker 의 volume 구조"))

    def test_collapses_punctuation_and_never_leaves_edge_hyphens(self):
        slug = capture_core.slug("  ...why?! does -- this  happen ??  ")
        self.assertEqual("why-does-this-happen", slug)

    def test_drops_emoji_because_decoration_is_not_a_name(self):
        self.assertEqual("shipped-it", capture_core.slug("🎉 shipped it 🎉"))

    def test_falls_back_when_there_is_no_letter_or_digit_at_all(self):
        self.assertEqual(capture_core.FALLBACK_SLUG, capture_core.slug("🎉 ---- !!"))
        self.assertEqual(capture_core.FALLBACK_SLUG, capture_core.slug("   "))

    def test_respects_the_character_cap(self):
        slug = capture_core.slug("supercalifragilistic " * 8)
        self.assertLessEqual(len(slug), capture_core.MAX_SLUG_CHARS)

    def test_drops_whole_words_rather_than_cutting_one_in_half(self):
        slug = capture_core.slug(
            "extraordinarily elaborate designations frequently overrun budgets"
        )
        # Every surviving segment is a complete word from the input.
        source = "extraordinarily elaborate designations frequently overrun budgets"
        for part in slug.split("-"):
            self.assertIn(part, source.split())

    def test_respects_the_decomposed_byte_budget_for_hangul(self):
        # 60 Hangul characters is inside MAX_SLUG_CHARS but ~540 bytes once
        # APFS decomposes them, which is what would actually fail the write.
        slug = capture_core.slug("가나다라마바사아자차카타파하" * 6)
        self.assertLessEqual(
            len(unicodedata.normalize("NFD", slug).encode("utf-8")),
            capture_core.MAX_SLUG_BYTES,
        )

    def test_a_single_over_budget_word_is_clipped_not_dropped(self):
        slug = capture_core.slug("a" * 400)
        self.assertEqual("a" * capture_core.MAX_SLUG_CHARS, slug)

    def test_is_pure_and_repeatable(self):
        text = "the same thought twice"
        self.assertEqual(capture_core.slug(text), capture_core.slug(text))


class RenderTests(unittest.TestCase):
    def test_writes_minimal_frontmatter_then_the_text_verbatim(self):
        out = capture_core.render("the thought, unedited", NOW, "hammerspoon")
        self.assertEqual(
            "---\n"
            'created_at: "2026-09-08T09:14:32-07:00"\n'
            "tags:\n"
            "  - capture\n"
            "source: hammerspoon\n"
            "---\n"
            "\n"
            "the thought, unedited\n",
            out,
        )

    def test_does_not_reword_the_thought(self):
        text = "i dont know why but the 5 word cap IS the design"
        self.assertIn(text, capture_core.render(text, NOW, "shell"))

    def test_keeps_a_multiline_thought_intact(self):
        text = "first line\nsecond line"
        self.assertTrue(capture_core.render(text, NOW, "shell").endswith(text + "\n"))

    def test_sanitizes_a_source_that_would_break_the_yaml(self):
        out = capture_core.render("x", NOW, "weird: source\nmore")
        self.assertIn("source: weird-source-more\n", out)

    def test_falls_back_when_the_source_has_nothing_usable(self):
        self.assertIn("source: unknown\n", capture_core.render("x", NOW, "!!!"))


class WriteTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.vault = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_writes_one_file_per_thought_under_the_capture_dir(self):
        path = capture_core.write("friction is naming it", self.vault, NOW)
        self.assertEqual(
            self.vault / "00-Capture" / "2026-09-08-0914-friction-is-naming-it.md",
            path,
        )
        self.assertIn("friction is naming it", path.read_text(encoding="utf-8"))

    def test_creates_the_capture_dir_but_not_the_vault_root(self):
        missing = self.vault / "no-such-vault"
        with self.assertRaises(FileNotFoundError):
            capture_core.write("x", missing, NOW)
        self.assertFalse(missing.exists())

    def test_suffixes_instead_of_overwriting_a_same_minute_same_slug_capture(self):
        first = capture_core.write("same words here", self.vault, NOW)
        second = capture_core.write("same words here", self.vault, NOW)
        self.assertNotEqual(first, second)
        self.assertTrue(second.name.endswith("-2.md"))
        # The point of the suffix: the first thought is still there.
        self.assertTrue(first.exists())

    def test_suffix_keeps_counting_past_two(self):
        names = [capture_core.write("dup", self.vault, NOW).name for _ in range(3)]
        self.assertEqual(
            ["2026-09-08-0914-dup.md", "2026-09-08-0914-dup-2.md", "2026-09-08-0914-dup-3.md"],
            names,
        )

    def test_refuses_empty_text_rather_than_writing_an_empty_note(self):
        for empty in ("", "   ", "\n\t "):
            with self.assertRaises(ValueError):
                capture_core.write(empty, self.vault, NOW)

    def test_strips_surrounding_whitespace_from_the_body(self):
        path = capture_core.write("  padded thought  \n", self.vault, NOW)
        self.assertTrue(path.read_text(encoding="utf-8").endswith("padded thought\n"))

    def test_writes_utf8_so_korean_round_trips(self):
        path = capture_core.write("무인도 재건 순서", self.vault, NOW)
        self.assertIn("무인도 재건 순서", path.read_text(encoding="utf-8"))

    def test_file_lands_owner_readable_and_never_world_writable(self):
        # Asserted as properties rather than as an exact mode, because the
        # umask of the calling process is part of the answer and a stricter
        # umask is not a bug.
        path = capture_core.write("perms", self.vault, NOW)
        self.assertTrue(os.access(path, os.R_OK | os.W_OK))
        self.assertEqual(0, os.stat(path).st_mode & 0o002)


class PlannedPathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.vault = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_predicts_the_path_without_creating_anything(self):
        path = capture_core.planned_path("dry run thought", self.vault, NOW)
        self.assertFalse(path.exists())
        self.assertFalse((self.vault / "00-Capture").exists())

    def test_agrees_with_write_on_a_clean_directory(self):
        planned = capture_core.planned_path("agreement", self.vault, NOW)
        written = capture_core.write("agreement", self.vault, NOW)
        self.assertEqual(planned, written)

    def test_skips_a_name_already_taken(self):
        capture_core.write("taken", self.vault, NOW)
        planned = capture_core.planned_path("taken", self.vault, NOW)
        self.assertTrue(planned.name.endswith("-2.md"))


if __name__ == "__main__":
    unittest.main()


class ParseDocumentTests(unittest.TestCase):
    def test_round_trips_what_render_wrote(self):
        # The tightest test available: parse the exact bytes render() produces.
        text = "the friction is naming it"
        parsed = capture_core.parse_document(capture_core.render(text, NOW, "hammerspoon"))
        self.assertEqual("2026-09-08T09:14:32-07:00", parsed["created_at"])
        self.assertEqual("hammerspoon", parsed["source"])
        self.assertEqual(text, parsed["text"])
        self.assertEqual(text, parsed["first_line"])
        self.assertFalse(parsed["multiline"])

    def test_splits_the_first_line_off_a_multiline_thought(self):
        rendered = capture_core.render("first line\nsecond line", NOW, "nvim")
        parsed = capture_core.parse_document(rendered)
        self.assertEqual("first line", parsed["first_line"])
        self.assertTrue(parsed["multiline"])
        self.assertEqual("first line\nsecond line", parsed["text"])

    def test_does_not_mistake_a_tag_list_item_for_a_field(self):
        parsed = capture_core.parse_document(capture_core.render("x", NOW, "shell"))
        self.assertEqual("x", parsed["text"])

    def test_survives_a_file_with_no_frontmatter(self):
        # A capture edited by hand, or a stray note dropped in the folder.
        parsed = capture_core.parse_document("just a bare line\n")
        self.assertIsNone(parsed["created_at"])
        self.assertIsNone(parsed["source"])
        self.assertEqual("just a bare line", parsed["text"])

    def test_survives_frontmatter_that_is_missing_the_fields(self):
        parsed = capture_core.parse_document("---\ntitle: something\n---\n\nbody\n")
        self.assertIsNone(parsed["created_at"])
        self.assertEqual("body", parsed["text"])

    def test_survives_unterminated_frontmatter_without_eating_the_body(self):
        parsed = capture_core.parse_document('---\ncreated_at: "2026-09-08T09:14:32-07:00"\n')
        self.assertEqual("2026-09-08T09:14:32-07:00", parsed["created_at"])

    def test_keeps_korean_intact(self):
        parsed = capture_core.parse_document(capture_core.render("무인도 재건 순서", NOW, "nvim"))
        self.assertEqual("무인도 재건 순서", parsed["first_line"])


class ListCapturesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.vault = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _write(self, name, body="a thought"):
        directory = capture_core.capture_dir(self.vault)
        directory.mkdir(parents=True, exist_ok=True)
        (directory / name).write_text(
            capture_core.render(body, NOW, "shell"), encoding="utf-8"
        )

    def test_returns_empty_when_nothing_has_been_captured(self):
        self.assertEqual([], capture_core.list_captures(self.vault))

    def test_returns_empty_rather_than_raising_when_the_folder_is_absent(self):
        self.assertEqual([], capture_core.list_captures(self.vault / "nope"))

    def test_orders_newest_first_by_filename(self):
        self._write("2026-09-07-0800-older.md")
        self._write("2026-09-08-0914-newer.md")
        self._write("2026-09-08-1102-newest.md")
        names = [r["name"] for r in capture_core.list_captures(self.vault)]
        self.assertEqual(
            ["2026-09-08-1102-newest.md", "2026-09-08-0914-newer.md", "2026-09-07-0800-older.md"],
            names,
        )

    def test_ignores_mtime_so_editing_an_old_capture_does_not_promote_it(self):
        # The reason the sort is by name: touching the old file must not move it.
        self._write("2026-09-07-0800-older.md")
        self._write("2026-09-08-0914-newer.md")
        old = capture_core.capture_dir(self.vault) / "2026-09-07-0800-older.md"
        os.utime(old, (2 ** 31 - 1, 2 ** 31 - 1))  # far future mtime
        self.assertEqual(
            "2026-09-08-0914-newer.md", capture_core.list_captures(self.vault)[0]["name"]
        )

    def test_honours_the_limit(self):
        for hour in range(5):
            self._write("2026-09-08-0%d00-thought.md" % hour)
        self.assertEqual(2, len(capture_core.list_captures(self.vault, limit=2)))

    def test_a_limit_takes_the_newest_not_the_first_found(self):
        self._write("2026-09-01-0800-oldest.md")
        self._write("2026-09-09-0800-newest.md")
        only = capture_core.list_captures(self.vault, limit=1)
        self.assertEqual("2026-09-09-0800-newest.md", only[0]["name"])

    def test_ignores_non_markdown_files_such_as_the_base_view(self):
        self._write("2026-09-08-0914-thought.md")
        (capture_core.capture_dir(self.vault) / "Captures.base").write_text("x", encoding="utf-8")
        self.assertEqual(1, len(capture_core.list_captures(self.vault)))

    def test_carries_path_and_parsed_fields_through(self):
        self._write("2026-09-08-0914-thought.md", body="the actual thought")
        record = capture_core.list_captures(self.vault)[0]
        self.assertTrue(record["path"].endswith("2026-09-08-0914-thought.md"))
        self.assertEqual("the actual thought", record["first_line"])
        self.assertEqual("shell", record["source"])

    def test_every_record_carries_its_own_obsidian_deeplink(self):
        self._write("2026-09-08-0914-thought.md")
        record = capture_core.list_captures(self.vault)[0]
        self.assertTrue(record["deeplink"].startswith("obsidian://open?vault="))
        self.assertIn("00-Capture%2F2026-09-08-0914-thought.md", record["deeplink"])

    def test_orders_a_same_minute_burst_by_seconds_not_alphabetically(self):
        # Four thoughts inside one minute is a real case: a burst while
        # thinking. The filename only has minute precision, so the order has to
        # come from frontmatter.
        directory = capture_core.capture_dir(self.vault)
        directory.mkdir(parents=True, exist_ok=True)
        for second, word in ((5, "zebra"), (20, "apple"), (40, "mango")):
            when = NOW.replace(second=second)
            (directory / ("2026-09-08-0914-%s.md" % word)).write_text(
                capture_core.render(word, when, "shell"), encoding="utf-8"
            )
        got = [r["first_line"] for r in capture_core.list_captures(self.vault)]
        self.assertEqual(["mango", "apple", "zebra"], got)

    def test_still_orders_records_whose_frontmatter_lost_created_at(self):
        directory = capture_core.capture_dir(self.vault)
        directory.mkdir(parents=True, exist_ok=True)
        for name in ("2026-09-07-0800-older.md", "2026-09-08-0914-newer.md"):
            (directory / name).write_text("bare body\n", encoding="utf-8")
        names = [r["name"] for r in capture_core.list_captures(self.vault)]
        self.assertEqual(["2026-09-08-0914-newer.md", "2026-09-07-0800-older.md"], names)


class DeeplinkTests(unittest.TestCase):
    VAULT = Path("/Users/x/Thoughts")

    def test_builds_an_obsidian_uri_with_the_path_separator_encoded(self):
        # %2F is not cosmetic: an unencoded slash in the `file` parameter is
        # read as part of the query string rather than as the path.
        self.assertEqual(
            "obsidian://open?vault=Thoughts&file=00-Capture%2F2026-09-08-0914-a.md",
            capture_core.deeplink(self.VAULT / "00-Capture/2026-09-08-0914-a.md", self.VAULT),
        )

    def test_derives_the_vault_name_from_the_folder(self):
        link = capture_core.deeplink(self.VAULT / "00-Capture/a.md", self.VAULT)
        self.assertIn("vault=Thoughts", link)

    def test_accepts_a_vault_name_that_differs_from_the_folder(self):
        link = capture_core.deeplink(
            self.VAULT / "00-Capture/a.md", self.VAULT, vault_name="My Notes"
        )
        self.assertIn("vault=My%20Notes", link)

    def test_percent_encodes_korean_as_utf8(self):
        link = capture_core.deeplink(self.VAULT / "00-Capture/무인도.md", self.VAULT)
        self.assertIn("%EB%AC%B4%EC%9D%B8%EB%8F%84", link)
        self.assertNotIn("무인도", link)

    def test_encodes_characters_that_would_break_the_query_string(self):
        link = capture_core.deeplink(self.VAULT / "00-Capture/a&b=c.md", self.VAULT)
        self.assertNotIn("&b=", link)
        self.assertIn("%26b%3Dc", link)

    def test_refuses_a_path_outside_the_vault(self):
        # There is no vault-relative link to a file that is not in the vault.
        with self.assertRaises(ValueError):
            capture_core.deeplink(Path("/tmp/elsewhere.md"), self.VAULT)

    def test_tolerates_a_trailing_slash_on_the_vault_root(self):
        link = capture_core.deeplink(self.VAULT / "00-Capture/a.md", Path("/Users/x/Thoughts/"))
        self.assertIn("vault=Thoughts", link)

    def test_is_pure_and_repeatable(self):
        args = (self.VAULT / "00-Capture/a.md", self.VAULT)
        self.assertEqual(capture_core.deeplink(*args), capture_core.deeplink(*args))
