"""Tests for claude-fleet's pure helpers.

Run with:  python3 -m unittest discover -s ~/.dotfiles/hammerspoon/tests

Stdlib unittest on purpose, matching the script itself: it runs under
/usr/bin/python3 with no environment set up.
"""

import importlib.machinery
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / ".hammerspoon" / "claude-fleet"

# The script has no .py extension, so name the loader explicitly.
_loader = importlib.machinery.SourceFileLoader("claude_fleet", str(SCRIPT))
_spec = importlib.util.spec_from_loader("claude_fleet", _loader)
fleet = importlib.util.module_from_spec(_spec)
_loader.exec_module(fleet)

SCREEN = """\
  Its dbt CI passed and the review bot approved it.
  Next: request a reviewer from the browser tab.
✻ Cooked for 26s · done 6:36 AM
※ recap: We're clearing open PRs. Next, ask a teammate to review.
──────────────────────────────────────────
❯
──────────────────────────────────────────
  project (main) | 508.5K tokens
"""


class LastTurnMarkerTests(unittest.TestCase):
    def test_finds_the_done_line_of_the_finished_turn(self):
        self.assertEqual("✻ Cooked for 26s · done 6:36 AM", fleet.last_turn_marker(SCREEN))

    def test_takes_the_newest_when_several_turns_are_on_screen(self):
        screen = "✻ Baked for 38m 17s · done 8:03 PM\n" + SCREEN
        self.assertEqual("✻ Cooked for 26s · done 6:36 AM", fleet.last_turn_marker(screen))

    def test_none_when_no_turn_has_finished_on_screen(self):
        self.assertIsNone(fleet.last_turn_marker("❯ \n  project (main)\n"))

    def test_falls_back_to_the_recap_line_when_no_done_line_is_on_screen(self):
        screen = "  Next: reply continue.\n※ recap: You're clearing failures.\n❯ \n"
        self.assertEqual("※ recap: You're clearing failures.", fleet.last_turn_marker(screen))

    def test_prefers_the_done_line_over_the_recap(self):
        self.assertTrue(fleet.last_turn_marker(SCREEN).startswith("✻"))

    def test_ignores_done_in_ordinary_prose(self):
        self.assertIsNone(fleet.last_turn_marker("  the migration is done 6:36 AM tomorrow, roughly\n"))


class DisplayTitleTests(unittest.TestCase):
    def test_strips_the_idle_glyph(self):
        self.assertEqual("Nightly build", fleet.display_title("✳ Nightly build", "thoughts-42"))

    def test_strips_a_spinner_glyph(self):
        self.assertEqual("Fleet status sync", fleet.display_title("◑ Fleet status sync", "thoughts-d9"))

    def test_keeps_a_title_that_starts_with_a_digit(self):
        self.assertEqual("2026 review", fleet.display_title("✳ 2026 review", "thoughts-79"))

    def test_falls_back_when_the_window_has_no_title(self):
        self.assertEqual("thoughts-0a", fleet.display_title("", "thoughts-0a"))
        self.assertEqual("thoughts-0a", fleet.display_title("✳ ", "thoughts-0a"))
        self.assertEqual("thoughts-0a", fleet.display_title(None, "thoughts-0a"))


class ReadStateTests(unittest.TestCase):
    MARK = "✻ Cooked for 26s · done 6:36 AM"

    def test_a_turn_never_seen_is_unread(self):
        self.assertEqual(("unread", None), fleet.read_state("idle", self.MARK, None, focused=False))

    def test_a_turn_seen_at_last_focus_is_idle(self):
        self.assertEqual(("idle", self.MARK), fleet.read_state("idle", self.MARK, self.MARK, focused=False))

    def test_a_newer_turn_than_the_one_seen_is_unread(self):
        older = "✻ Baked for 2m · done 6:30 AM"
        self.assertEqual(("unread", older), fleet.read_state("idle", self.MARK, older, focused=False))

    def test_focusing_the_window_marks_it_read(self):
        self.assertEqual(("idle", self.MARK), fleet.read_state("idle", self.MARK, None, focused=True))

    def test_without_a_marker_the_reported_state_stands(self):
        self.assertEqual(("idle", None), fleet.read_state("idle", None, None, focused=False))

    def test_only_idle_is_reinterpreted(self):
        for state in ("busy", "waiting", "blocked"):
            self.assertEqual((state, None), fleet.read_state(state, self.MARK, None, focused=False))


class KittyFocusTests(unittest.TestCase):
    """Shaped like real `kitty @ ls` output with kitty frontmost."""

    TREE = [{
        "is_focused": True,
        "tabs": [
            {"is_focused": False, "windows": [
                {"id": 8, "is_focused": True, "title": "✳ Background tab",
                 "foreground_processes": [{"pid": 100}]}]},
            {"is_focused": True, "windows": [
                {"id": 86, "is_focused": True, "title": "◐ Tab on screen",
                 "foreground_processes": [{"pid": 200}]}]},
        ],
    }]

    def setUp(self):
        self._real = fleet.kitty_instances
        fleet.kitty_instances = lambda: [(2, "/tmp/kitty-1", self.TREE)]

    def tearDown(self):
        fleet.kitty_instances = self._real

    def test_a_background_tab_is_not_focused_even_though_its_window_flag_is_set(self):
        self.assertFalse(fleet.kitty_windows()[100]["focused"])

    def test_the_tab_on_screen_is_focused(self):
        self.assertTrue(fleet.kitty_windows()[200]["focused"])

    def test_nothing_is_focused_when_kitty_is_in_the_background(self):
        self.TREE[0]["is_focused"] = False
        try:
            self.assertFalse(fleet.kitty_windows()[200]["focused"])
        finally:
            self.TREE[0]["is_focused"] = True


class StateTableTests(unittest.TestCase):
    def test_unread_is_grouped_with_needs_input(self):
        self.assertEqual("Needs input", fleet.STATES["unread"][2])
        self.assertIn("unread", fleet.NEEDS_INPUT)


if __name__ == "__main__":
    unittest.main()
