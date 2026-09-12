---The buffer half of the bullet command.
---
---`daemon.installed` is stubbed false throughout, so every case here runs the Lua-splitter
---fallback and never spawns spaCy. That is deliberate on two counts: a test that shells out to
---a 60 MB model is not deterministic, and the fallback is the path that would otherwise never be
---exercised on a machine where the venv exists. The spaCy path is covered end to end by hand;
---what is asserted here is the range arithmetic and the write-back, which is where an off-by-one
---eats a line of someone's draft.
local bullets = require("albertlint.bullets")
local daemon = require("albertlint.parse.daemon")

---@param lines string[]
---@return integer
local function scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

describe("bullets.range", function()
  local installed

  before_each(function()
    installed = daemon.installed
    daemon.installed = function()
      return false
    end
  end)

  after_each(function()
    daemon.installed = installed
  end)

  it("replaces the range with one bullet per sentence", function()
    local buf = scratch({ "One. Two." })
    bullets.range(1, 1)
    assert.same({ "- One.", "- Two." }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("leaves lines outside the range untouched", function()
    local buf = scratch({ "Before.", "One. Two.", "After." })
    bullets.range(2, 2)
    assert.same(
      { "Before.", "- One.", "- Two.", "After." },
      vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    )
  end)

  it("keeps the blank line between two paragraphs in one range", function()
    local buf = scratch({ "One. Two.", "", "Three." })
    bullets.range(1, 3)
    assert.same(
      { "- One.", "- Two.", "", "- Three." },
      vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    )
  end)

  it("joins a sentence wrapped across two lines into one bullet", function()
    local buf = scratch({ "A sentence that runs", "onto a second line. And another." })
    bullets.range(1, 2)
    assert.same(
      { "- A sentence that runs onto a second line.", "- And another." },
      vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    )
  end)

  it("is idempotent on a second run over the result", function()
    local buf = scratch({ "One. Two.", "", "Three." })
    bullets.range(1, 3)
    local once = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    bullets.range(1, #once)
    assert.same(once, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("leaves a heading alone while bulleting the prose under it", function()
    local buf = scratch({ "## Title", "One. Two." })
    bullets.range(1, 2)
    assert.same(
      { "## Title", "- One.", "- Two." },
      vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    )
  end)

  it("does not touch a range that holds nothing but a list", function()
    local buf = scratch({ "- a", "- b" })
    bullets.range(1, 2)
    assert.same({ "- a", "- b" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("refuses a non-modifiable buffer", function()
    local buf = scratch({ "One. Two." })
    vim.bo[buf].modifiable = false
    bullets.range(1, 1)
    vim.bo[buf].modifiable = true
    assert.same({ "One. Two." }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("does nothing when the range is past the end of the buffer", function()
    local buf = scratch({ "One." })
    bullets.range(5, 9)
    assert.same({ "One." }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)

  it("carries the paragraph's indent onto its bullets", function()
    local buf = scratch({ "    One. Two." })
    bullets.range(1, 1)
    assert.same({ "    - One.", "    - Two." }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)
end)
