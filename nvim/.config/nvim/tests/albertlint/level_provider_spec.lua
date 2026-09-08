---The two backends, and the credential handling that must not regress.
---
---The openai argv test is the important one, and it is a standing regression test rather
---than a formality: argv is world-readable through `ps`, so passing the key as
---`-H "Authorization: Bearer ..."` would expose it to every local process for the lifetime
---of the request. The key goes to curl on stdin instead. The header form is the obvious
---simplification, so this is what catches someone making it.
---
---No network here. `provider.call` is not exercised; a headless test must not spend money.
---What is tested is argv construction, the request body, scrubbing, and parsing.
local provider = require("albertlint.level.provider")

-- Not a real key, and named so that a secret scanner reading this public repo does not
-- have to guess. It still starts with `sk-` because that is the prefix the scrubber
-- pattern matches, and the test is worthless against a string the pattern would miss.
local FAKE_KEY = "sk-NOT-A-REAL-KEY-test-fixture-only"

describe("level.provider claude argv", function()
  it("carries all three isolation flags", function()
    -- Measured 2026-08-26 and recorded in util/claude.lua: --safe-mode alone still left
    -- 12 skills reachable, --disable-slash-commands is what takes it to zero, and
    -- --strict-mcp-config drops the MCP servers. "Vanilla claude" needs all three.
    local joined = table.concat(provider.claude_cmd({}), " ")

    assert.is_true(joined:find("--safe-mode", 1, true) ~= nil)
    assert.is_true(joined:find("--disable-slash-commands", 1, true) ~= nil)
    assert.is_true(joined:find("--strict-mcp-config", 1, true) ~= nil)
  end)

  it("agrees with util.claude's measured raw flag set", function()
    -- Do not re-derive the flags. If util/claude.lua learns a fourth one, this fails and
    -- points at the drift instead of letting the two definitions diverge silently.
    local raw = require("util.claude").raw_flags
    local joined = table.concat(provider.claude_cmd({}), " ")

    assert.is_true(#raw > 0)
    for _, flag in ipairs(raw) do
      assert.is_true(joined:find(flag, 1, true) ~= nil, "missing " .. flag)
    end
  end)

  it("pins the model, because the default one returned no findings", function()
    -- Measured 2026-08-28: without --model sonnet the CLI's default returned
    -- {"findings":[]} twice on a five-line sample with an obvious missing `the`.
    local cmd = provider.claude_cmd({})
    local joined = table.concat(cmd, " ")

    assert.is_true(joined:find("--model", 1, true) ~= nil)
    assert.is_true(joined:find("sonnet", 1, true) ~= nil)
  end)

  it("replaces the model in place rather than appending a second flag", function()
    local cmd = provider.claude_cmd({ model = "opus" })
    local joined = table.concat(cmd, " ")

    assert.is_true(joined:find("--model opus", 1, true) ~= nil)
    assert.is_nil(joined:find("sonnet", 1, true))
    -- One --model, not two, or the CLI sees a conflicting pair.
    local _, count = joined:gsub("%-%-model", "")
    assert.equals(1, count)
  end)

  it("does not mutate the shared CLAUDE_CMD table", function()
    -- Returned by reference, a caller's model override would rewrite the module-level
    -- default for every later call in the session.
    local before = table.concat(provider.CLAUDE_CMD, " ")

    provider.claude_cmd({ model = "opus" })
    provider.claude_cmd({ model = "haiku" })

    assert.equals(before, table.concat(provider.CLAUDE_CMD, " "))
  end)
end)

describe("level.provider openai credential handling", function()
  it("never puts the key in argv", function()
    local joined = table.concat(provider.openai_argv("/tmp/body.json", { key = FAKE_KEY }), " ")

    assert.is_nil(joined:find("sk-", 1, true))
    assert.is_nil(joined:find(FAKE_KEY, 1, true))
    assert.is_nil(joined:find("Bearer", 1, true))
    assert.is_nil(joined:find("Authorization", 1, true))
  end)

  it("reads its config from stdin", function()
    local argv = provider.openai_argv("/tmp/body.json", {})

    local found = false
    for i, arg in ipairs(argv) do
      if arg == "--config" and argv[i + 1] == "-" then
        found = true
      end
    end
    assert.is_true(found, "expected `--config -` so the auth header arrives on stdin")
  end)

  it("references the body by path rather than inlining it", function()
    -- Inlined, a long prose body would hit argv's length ceiling and would also be
    -- visible in ps alongside everything else.
    local joined = table.concat(provider.openai_argv("/tmp/body.json", {}), " ")

    assert.is_true(joined:find("@/tmp/body.json", 1, true) ~= nil)
  end)

  it("puts the key in the stdin config, which is the only place it belongs", function()
    local cfg = provider.openai_config(FAKE_KEY)

    assert.is_true(cfg:find(FAKE_KEY, 1, true) ~= nil)
    assert.is_true(cfg:find("Authorization", 1, true) ~= nil)
    -- curl's config format is one directive per line and needs the trailing newline.
    assert.equals("\n", cfg:sub(-1))
  end)

  it("asks for a strict json schema so malformed JSON is impossible", function()
    local body = provider.openai_body("test-model", "PROMPT", "1: some text")

    assert.is_true(body:find("json_schema", 1, true) ~= nil)
    assert.is_true(body:find("findings", 1, true) ~= nil)
    assert.is_true(body:find("occurrence", 1, true) ~= nil)
    -- The body carries the author's prose, never the key.
    assert.is_nil(body:find("sk-", 1, true))
  end)

  it("pins the measured default model", function()
    -- Not a style assertion. This default was measured 2026-09-08, three runs per
    -- candidate against a sample with four known errors, and the previous value
    -- (`gpt-4o`) returned ZERO findings on two runs of three -- the exact failure
    -- config.lua records for the semantic tier, where reporting nothing on flawed prose
    -- reads as "your writing is fine". `gpt-6-astra`, three months newer, was less
    -- consistent than this. If you are changing this line, re-run the measurement first;
    -- the table is in provider.lua.
    assert.equals("gpt-5.5", provider.OPENAI_DEFAULT_MODEL)
  end)

  it("threads the default into the request body when no override is given", function()
    local decoded = vim.json.decode(
      provider.openai_body(provider.OPENAI_DEFAULT_MODEL, "PROMPT", "1: text")
    )

    assert.equals("gpt-5.5", decoded.model)
  end)

  it("produces a body that round-trips as JSON", function()
    local decoded = vim.json.decode(provider.openai_body("test-model", "PROMPT", "1: text"))

    assert.equals("test-model", decoded.model)
    assert.equals("PROMPT", decoded.messages[1].content)
    assert.equals("1: text", decoded.messages[2].content)
    assert.is_true(decoded.response_format.json_schema.strict)
  end)
end)

describe("level.provider scrub", function()
  it("removes a bearer token from text headed for a notify", function()
    -- curl writes the effective request to stderr under some verbosity settings, and a
    -- vim.notify goes into the message history where it persists for the session.
    local out = provider.scrub("curl: Authorization: Bearer " .. FAKE_KEY .. " failed")

    assert.is_nil(out:find(FAKE_KEY, 1, true))
    assert.is_nil(out:find("sk-", 1, true))
  end)

  it("removes a bare key even with no Bearer prefix", function()
    local out = provider.scrub("error near " .. FAKE_KEY)

    assert.is_nil(out:find(FAKE_KEY, 1, true))
  end)

  it("removes the live environment key even if it is not sk-shaped", function()
    -- A key from a gateway or a proxy need not match the sk- pattern, so the value in
    -- the environment is scrubbed literally as a backstop.
    local saved = vim.env.OPENAI_API_KEY
    vim.env.OPENAI_API_KEY = "GATEWAY-abc123-not-sk-shaped"

    local out = provider.scrub("failed with GATEWAY-abc123-not-sk-shaped in the header")

    vim.env.OPENAI_API_KEY = saved
    assert.is_nil(out:find("GATEWAY-abc123", 1, true))
  end)

  it("leaves ordinary text alone", function()
    assert.equals("connection refused", provider.scrub("connection refused"))
  end)

  it("handles nil without erroring", function()
    assert.equals("", provider.scrub(nil))
  end)
end)

describe("level.provider parse", function()
  it("strips a markdown fence around the JSON", function()
    -- Models wrap JSON in a fence often enough that stripping is cheaper than
    -- re-prompting, which is the lesson semantic.lua already encodes.
    local parsed, err = provider.parse('```json\n{"findings":[]}\n```')

    assert.is_nil(err)
    assert.same({}, parsed.findings)
  end)

  it("accepts a bare object", function()
    local parsed = provider.parse('{"findings":[{"line":1}]}')

    assert.equals(1, #parsed.findings)
  end)

  it("errors when there is no JSON object at all", function()
    local parsed, err = provider.parse("I could not do that.")

    assert.is_nil(parsed)
    assert.is_true(err:find("no JSON", 1, true) ~= nil)
  end)

  it("errors when the object has no findings key", function()
    local parsed, err = provider.parse('{"result":"ok"}')

    assert.is_nil(parsed)
    assert.is_true(err:find("findings", 1, true) ~= nil)
  end)

  it("errors on malformed JSON rather than throwing", function()
    local parsed, err = provider.parse('{"findings":[},}')

    assert.is_nil(parsed)
    assert.is_not_nil(err)
  end)

  it("unwraps an OpenAI chat completion envelope", function()
    -- The envelope's `content` is itself a JSON string, so this is two decodes deep.
    local envelope = vim.json.encode({
      choices = { { message = { content = '{"findings":[{"line":3}]}' } } },
    })

    local parsed = provider.parse(envelope)

    assert.equals(3, parsed.findings[1].line)
  end)

  it("handles nil input", function()
    local parsed, err = provider.parse(nil)

    assert.is_nil(parsed)
    assert.is_not_nil(err)
  end)
end)
