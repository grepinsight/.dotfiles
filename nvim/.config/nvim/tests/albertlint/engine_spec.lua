---Behavioural tests, written from real logged slips. Each `it` name quotes the sentence it
---came from, so a failure points at the source rather than at the rule.
local engine = require("albertlint.engine")
local config = require("albertlint.config")

---@param text string|string[]
---@return string[] rule ids, sorted
local function codes(text, tier)
  local lines = type(text) == "table" and text or { text }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local diagnostics = engine.scan(buf, tier or "all", config.setup({}))
  local out = {}
  for _, d in ipairs(diagnostics) do
    table.insert(out, d.code)
  end
  table.sort(out)
  vim.api.nvim_buf_delete(buf, { force = true })
  return out
end

---@param list string[]
---@param id string
local function has(list, id)
  return vim.tbl_contains(list, id)
end

describe("albertlint engine", function()
  describe("catches the logged slips", function()
    it("'a real time albert-linter plugin' -> compound modifier", function()
      assert.is_true(has(codes("a real time albert-linter plugin"), "compound-modifier"))
    end)

    it("'on slack' -> brand capitalization", function()
      assert.is_true(has(codes("Nice to meet you on slack today"), "brand-caps"))
    end)

    it("'using mcp ?' -> acronym and space before the mark", function()
      local c = codes("are they using mcp ?")
      assert.is_true(has(c, "acronym-caps"))
      assert.is_true(has(c, "space-before-mark"))
    end)

    it("'a write access' -> mass noun with an intervening modifier", function()
      -- The real 2020 instance. An earlier version required the article to sit directly
      -- on the noun and missed every case that had an adjective in between.
      assert.is_true(has(codes("I don't have a write access to it"), "mass-noun-article"))
    end)

    it("'when you login for the first time' -> noun used as a verb", function()
      -- Missed by the first version, which only fired before a preposition.
      assert.is_true(has(codes("I think when you login for the first time"), "login-verb"))
    end)

    it("'I wish I met you' -> wish without the past perfect", function()
      assert.is_true(has(codes("I wish I met you in person before you left"), "wish-backshift"))
    end)

    it("'I wish I had met you' -> no diagnostic", function()
      assert.is_false(has(codes("I wish I had met you in person"), "wish-backshift"))
    end)

    it("'fragments that are important' -> that-are", function()
      assert.is_true(has(codes("individual fragments that are important"), "that-are"))
    end)

    it("'errors/improvement opportunities' -> slash list", function()
      assert.is_true(has(codes("highlight errors/improvement opportunities"), "slash-list"))
    end)

    it("'and/or' and a date are not slash lists", function()
      assert.is_false(has(codes("ship it and/or revert on 2020/09/01"), "slash-list"))
    end)

    it("'was curious how others do things' -> dropped subject I", function()
      assert.is_true(has(codes("was curious how others do things"), "dropped-subject-i"))
    end)

    it("'since 2020 September' -> reversed date order", function()
      assert.is_true(has(codes("since 2020 September"), "date-order"))
    end)

    it("'I ahve been sitting' -> typo", function()
      local c = codes("Also, I ahve been sitting and now standing up a lot")
      assert.is_true(has(c, "typo"))
    end)

    it("a lowercase sentence start is NOT a typo", function()
      -- `spell` reports this as kind `caps`, and lowercase starts are allowlisted in his
      -- English Practice flow because he types them on purpose for speed.
      assert.is_false(has(codes("My head hurts. slightly behind the temple"), "typo"))
      assert.is_false(has(codes("i like this."), "typo"))
    end)

    it("does not spellcheck inside code spans", function()
      assert.is_false(has(codes("run `mkfifo` and `ahve` in the shell"), "typo"))
    end)

    it("'that  ends with' -> double space", function()
      assert.is_true(has(codes("Find the account number that  ends with 6738"), "double-space"))
    end)
  end)

  describe("stays silent where a match would be wrong", function()
    it("skips an inline code span", function()
      assert.same({}, codes("run `python -m venv` first"))
    end)

    it("skips a fenced block but resumes after it", function()
      local c = codes({ "```bash", "python -m venv", "slack api", "```", "meet on slack" })
      assert.is_true(has(c, "brand-caps"))
      assert.equals(1, #c, "only the line after the fence should be linted")
    end)

    it("skips a URL but lints the prose around it", function()
      -- `slack` inside the URL is masked; `python` after it is prose and is not.
      local c = codes("see https://slack.com/api/docs for python docs")
      assert.equals(1, #c, "only the prose brand should be flagged")
      assert.is_true(has(c, "acronym-caps") or has(c, "brand-caps"))
      assert.same({}, codes("see https://slack.com/slack/slack"))
    end)

    it("lints markdown link TEXT but not the target", function()
      -- Link text is prose the reader sees, so a lowercase brand there is a real slip.
      assert.is_true(has(codes("the [slack docs](https://slack.com/x)"), "brand-caps"))
      assert.same({}, codes("see [the docs](https://slack.com/slack/slack)"))
    end)

    it("skips YAML frontmatter", function()
      assert.same({}, codes({ "---", "tags:", "  - slack", "  - python", "---" }))
    end)

    it("never suggests a replacement identical to the match", function()
      -- `dbt` is correctly lowercase. A catalogue entry mapping it to itself would emit
      -- `dbt is an initialism: dbt`, which is noise that teaches nothing.
      assert.same({}, codes("we ran dbt on the warehouse"))
    end)

    it("does not treat jargon or initialisms as typos", function()
      assert.same({}, codes("We ran dbt on Snowflake via MCP and the API, then check GitHub"))
    end)

    it("does not flag correctly capitalized names", function()
      assert.same({}, codes("Slack and Python and GitHub and MCP are fine"))
    end)
  end)

  describe("tiers", function()
    it("runs only cheap rules in the live tier", function()
      local live = codes("meet on slack about errors/improvement opportunities", "live")
      assert.is_true(has(live, "brand-caps"))
      assert.is_false(has(live, "slash-list"), "slash-list is an exit rule")
    end)

    it("runs sentence rules in the exit tier", function()
      local exit = codes("meet on slack about errors/improvement opportunities", "exit")
      assert.is_true(has(exit, "slash-list"))
      assert.is_false(has(exit, "brand-caps"), "brand-caps is a live rule")
    end)
  end)

  describe("diagnostic shape", function()
    it("spans exactly the offending token", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meet on slack today" })
      local d = engine.scan(buf, "live", config.setup({}))
      local brand
      for _, diag in ipairs(d) do
        if diag.code == "brand-caps" then
          brand = diag
        end
      end
      assert.is_not_nil(brand)
      assert.equals("slack", ("meet on slack today"):sub(brand.col + 1, brand.end_col))
      assert.equals(0, brand.lnum)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("names the replacement in the message", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meet on slack today" })
      local d = engine.scan(buf, "live", config.setup({}))
      assert.is_truthy(d[1].message:find("Slack", 1, true))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("config", function()
    it("honours disabled_rules", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meet on slack" })
      local d = engine.scan(buf, "live", config.setup({ disabled_rules = { "brand-caps" } }))
      assert.same({}, d)
      vim.api.nvim_buf_delete(buf, { force = true })
      config.setup({})
    end)

    it("honours enabled_optional", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "stored as parquet on disk" })
      local off = engine.scan(buf, "live", config.setup({}))
      local on = engine.scan(buf, "live", config.setup({ enabled_optional = { "brand-caps-ambiguous" } }))
      assert.equals(0, #off)
      assert.equals(1, #on)
      vim.api.nvim_buf_delete(buf, { force = true })
      config.setup({})
    end)
  end)
end)
