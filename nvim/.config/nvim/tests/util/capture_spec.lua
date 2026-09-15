local capture = require("util.capture")

describe("util.capture.argv", function()
  it("passes the thought as one argument, so no quoting is needed", function()
    local argv = capture.argv("a thought with 'quotes' and $VARS", "nvim")
    assert.equals("a thought with 'quotes' and $VARS", argv[#argv])
  end)

  it("puts -- before the text, so a leading hyphen is text and not a flag", function()
    local argv = capture.argv("--wat, that is not a flag", "nvim")
    assert.equals("--", argv[#argv - 1])
  end)

  it("records the source it was given", function()
    local argv = capture.argv("x", "raycast")
    assert.equals("--source", argv[2])
    assert.equals("raycast", argv[3])
  end)

  it("defaults the source to nvim rather than leaving it empty", function()
    assert.equals("nvim", capture.argv("x", nil)[3])
  end)

  it("calls the linked entry point, not a repo-relative path", function()
    assert.truthy(capture.argv("x", "nvim")[1]:find("/bin/capture", 1, true))
  end)
end)

describe("util.capture.selection_text", function()
  it("joins selected lines with newlines", function()
    assert.equals("first\nsecond", capture.selection_text({ "first", "second" }))
  end)

  it("trims the blank edges a visual line selection picks up", function()
    assert.equals("thought", capture.selection_text({ "", "  thought  ", "" }))
  end)

  it("leaves the interior shape alone, including blank lines between paragraphs", function()
    local lines = { "first para", "", "second para" }
    assert.equals("first para\n\nsecond para", capture.selection_text(lines))
  end)

  it("returns empty string for an empty or nil selection, so run() can refuse", function()
    assert.equals("", capture.selection_text({}))
    assert.equals("", capture.selection_text(nil))
    assert.equals("", capture.selection_text({ "", "   " }))
  end)
end)

describe("util.capture.basename", function()
  it("reduces a written path to the filename for the notification", function()
    local path = "/Users/x/Thoughts/00-Capture/2026-09-08-0914-friction-is-naming-it.md"
    assert.equals("2026-09-08-0914-friction-is-naming-it.md", capture.basename(path))
  end)

  it("keeps a Korean filename intact", function()
    assert.equals("2026-09-08-0914-무인도-재건-순서.md",
      capture.basename("/v/00-Capture/2026-09-08-0914-무인도-재건-순서.md"))
  end)

  it("passes through a bare filename", function()
    assert.equals("note.md", capture.basename("note.md"))
  end)
end)

describe("util.capture.list_argv", function()
  it("asks for JSON, which is the only format the picker can parse", function()
    assert.equals("--json", capture.list_argv(20)[2])
  end)

  it("passes the limit through as a string, since argv has no numbers", function()
    local argv = capture.list_argv(50)
    assert.equals("-n", argv[3])
    assert.equals("50", argv[4])
  end)

  it("defaults to a limit rather than listing an unbounded folder", function()
    assert.equals("200", capture.list_argv(nil)[4])
  end)

  it("calls captures, not capture, so a browse can never write", function()
    assert.truthy(capture.list_argv(1)[1]:find("/bin/captures", 1, true))
  end)
end)

describe("util.capture.display_for", function()
  it("shows the timestamp and the thought, in the CLI's format", function()
    assert.equals(
      "2026-09-08 09:14  friction is naming it",
      capture.display_for({
        created_at = "2026-09-08T09:14:32-07:00",
        first_line = "friction is naming it",
      })
    )
  end)

  it("marks a multi-line capture so the truncation is visible", function()
    local line = capture.display_for({
      created_at = "2026-09-08T09:14:32-07:00",
      first_line = "first line",
      multiline = true,
    })
    assert.truthy(line:find("[...]", 1, true))
  end)

  it("falls back to the filename when frontmatter lost created_at", function()
    local line = capture.display_for({
      name = "2026-09-08-0914-thought.md",
      first_line = "thought",
    })
    assert.equals("2026-09-08 09:14  thought", line)
  end)

  it("labels an empty body instead of rendering a blank row", function()
    local line = capture.display_for({ created_at = "2026-09-08T09:14:32-07:00", first_line = "" })
    assert.truthy(line:find("(empty)", 1, true))
  end)

  it("keeps Korean intact", function()
    local line = capture.display_for({
      created_at = "2026-09-08T09:14:32-07:00",
      first_line = "무인도 재건 순서",
    })
    assert.truthy(line:find("무인도 재건 순서", 1, true))
  end)
end)

describe("util.capture.entries_from_json", function()
  local JSON = [[
    [{"path": "/v/00-Capture/2026-09-08-0914-a.md", "created_at": "2026-09-08T09:14:32-07:00",
      "source": "hammerspoon", "first_line": "the first thought", "multiline": false,
      "name": "2026-09-08-0914-a.md"}]
  ]]

  it("turns a record into a picker entry with a path telescope can open", function()
    local entries = capture.entries_from_json(JSON)
    assert.equals(1, #entries)
    assert.equals("/v/00-Capture/2026-09-08-0914-a.md", entries[1].path)
  end)

  it("makes the source searchable, so you can filter by which door you used", function()
    assert.truthy(capture.entries_from_json(JSON)[1].ordinal:find("hammerspoon", 1, true))
  end)

  it("makes the thought searchable", function()
    assert.truthy(capture.entries_from_json(JSON)[1].ordinal:find("the first thought", 1, true))
  end)

  it("returns empty for empty output rather than erroring inside a keymap", function()
    assert.equals(0, #capture.entries_from_json(""))
    assert.equals(0, #capture.entries_from_json("   "))
    assert.equals(0, #capture.entries_from_json(nil))
  end)

  it("returns empty for malformed JSON instead of throwing", function()
    assert.equals(0, #capture.entries_from_json("{not json at all"))
  end)

  it("skips a record with no path, which could not be opened anyway", function()
    assert.equals(0, #capture.entries_from_json('[{"first_line": "orphan"}]'))
  end)

  it("preserves the order it was given, because the CLI already sorted it", function()
    local entries = capture.entries_from_json(
      '[{"path":"/a.md","first_line":"newest"},{"path":"/b.md","first_line":"older"}]'
    )
    assert.equals("/a.md", entries[1].path)
    assert.equals("/b.md", entries[2].path)
  end)
end)
