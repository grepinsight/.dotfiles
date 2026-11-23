---Catalogue integrity. These tests protect against the failure mode that actually
---happened while writing the plugin: a rule whose regex does not compile, or whose Lua
---long-bracket string swallowed its own terminator, is silently dead rather than loud.
local rules = require("albertlint.rules")

describe("albertlint rules catalogue", function()
  it("has rules", function()
    assert.is_true(#rules.rules > 0)
  end)

  it("gives every rule a unique id", function()
    local seen = {}
    for _, list in ipairs({ rules.rules, rules.optional }) do
      for _, rule in ipairs(list) do
        assert.is_nil(seen[rule.id], "duplicate rule id: " .. tostring(rule.id))
        seen[rule.id] = true
      end
    end
  end)

  it("gives every rule a tier, severity, message and drill_ref", function()
    for _, list in ipairs({ rules.rules, rules.optional }) do
      for _, rule in ipairs(list) do
        assert.is_true(rule.tier == "live" or rule.tier == "exit", rule.id .. " tier")
        assert.is_number(rule.severity, rule.id .. " severity")
        assert.is_string(rule.message, rule.id .. " message")
        assert.is_string(rule.drill_ref, rule.id .. " drill_ref")
      end
    end
  end)

  it("gives every rule exactly one matcher kind", function()
    for _, list in ipairs({ rules.rules, rules.optional }) do
      for _, rule in ipairs(list) do
        local kinds = 0
        for _, key in ipairs({ "words", "phrases", "vimre", "fn" }) do
          if rule[key] then
            kinds = kinds + 1
          end
        end
        assert.equals(1, kinds, rule.id .. " should declare exactly one matcher")
      end
    end
  end)

  it("compiles every vimre as a Vim regex", function()
    for _, list in ipairs({ rules.rules, rules.optional }) do
      for _, rule in ipairs(list) do
        if rule.vimre then
          local ok = pcall(vim.regex, rule.vimre)
          assert.is_true(ok, "regex does not compile: " .. rule.id)
        end
      end
    end
  end)

  it("names a real function for every fn rule", function()
    local engine = require("albertlint.engine")
    for _, list in ipairs({ rules.rules, rules.optional }) do
      for _, rule in ipairs(list) do
        if rule.fn then
          assert.is_function(engine._fns[rule.fn], "missing fn: " .. rule.fn)
        end
      end
    end
  end)

  it("keeps pronouns and shell commands out of the acronym list", function()
    -- A false positive on `it` or `cd` would make the linter unusable in one sitting,
    -- so this is pinned rather than left to review.
    for _, rule in ipairs(rules.rules) do
      if rule.id == "acronym-caps" then
        for _, banned in ipairs({ "it", "id", "cd", "pr", "ci", "rag", "a", "i" }) do
          assert.is_nil(rule.words[banned], "acronym list must not contain " .. banned)
        end
      end
    end
  end)

  it("keeps live-tier rules cheap: no fn matchers while typing", function()
    -- fn rules scan the line with Lua patterns and run per keystroke otherwise.
    for _, rule in ipairs(rules.rules) do
      if rule.tier == "live" then
        assert.is_nil(rule.fn, rule.id .. " is a live rule and must not use fn")
      end
    end
  end)
end)
