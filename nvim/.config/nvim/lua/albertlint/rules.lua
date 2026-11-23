---The rule catalogue: data, not logic.
---
---Every rule carries `drill_ref`, naming the pattern in
---a personal log of logged corrections it was derived from, so
---`:AlbertLintCoverage` can report which drilled patterns have no rule yet. Counts in
---comments are instances logged in the source corpus and are there to justify a rule's
---existence, not to be kept current.
---
---Rule kinds, checked in this order by the engine:
---  words   -> one word-boundary, case-SENSITIVE regex built from the keys
---  phrases -> literal substrings, case-insensitive, key maps to the replacement
---  vimre   -> a raw Vim regex, with `message` describing the fix
---  fn      -> a function(line, lnum, ctx) returning a list of {col, end_col, message}
---
---`tier` decides when a rule runs. `live` rules fire debounced while typing and must be
---single-token cheap. `exit` rules wait for InsertLeave so they see a finished sentence.
local S = vim.diagnostic.severity

local M = {}

---Brand and product names he types lowercase. His single most frequent mechanical slip:
---17 instances in the correction log, and 14 to 30 tokens per sample window in an earlier
---corpus review, which makes it a long-standing habit rather than a recent one.
---
---Membership test for this list: would the lowercase form be WRONG in prose in every
---context? `slack` always wants a capital. `hex` does not, because hexadecimal exists.
---Ambiguous names live in `optional_words` below.
local BRANDS = {
  slack = "Slack",
  github = "GitHub",
  gitlab = "GitLab",
  python = "Python",
  docker = "Docker",
  confluence = "Confluence",
  okta = "Okta",
  snowflake = "Snowflake",
  looker = "Looker",
  artifactory = "Artifactory",
  rstudio = "RStudio",
  todoist = "Todoist",
  obsidian = "Obsidian",
  crossfit = "CrossFit",
  jenkins = "Jenkins",
  airflow = "Airflow",
  kubernetes = "Kubernetes",
  terraform = "Terraform",
  databricks = "Databricks",
  xcode = "Xcode",
  postgres = "Postgres",
  jira = "Jira",
  notion = "Notion",
  figma = "Figma",
  sentry = "Sentry",
  peloton = "Peloton",
  fedex = "FedEx",
  javascript = "JavaScript",
  typescript = "TypeScript",
  neovim = "Neovim",
}

---Initialisms. Excluded on purpose: `it` (a pronoun), `id` (a common noun), `cd` and `pr`
---(shell command and a French abbreviation, both common in his prose), `rag` (a cloth).
---A false positive on a pronoun would make the linter unusable in one sitting.
local ACRONYMS = {
  mcp = "MCP",
  api = "API",
  cli = "CLI",
  sql = "SQL",
  json = "JSON",
  yaml = "YAML",
  csv = "CSV",
  tsv = "TSV",
  vpn = "VPN",
  aws = "AWS",
  gcp = "GCP",
  hpc = "HPC",
  pypi = "PyPI",
  uuid = "UUID",
  dns = "DNS",
  ssh = "SSH",
  tls = "TLS",
  etl = "ETL",
  llm = "LLM",
  cdn = "CDN",
  sso = "SSO",
}

---Mass nouns that reject `a`/`an`. Drawn from the 26 instances the corpus review found
---clustering on abstract nouns: `a write access`, `a information`, `making a time`.
---`time` is omitted because `a time` is correct in the occasion sense ("a time when").
local MASS_NOUNS = {
  "access",
  "information",
  "feedback",
  "advice",
  "context",
  "stuff",
  "noise",
  "resistance",
  "training data",
  "evidence",
  "progress",
  "research",
  "software",
  "hardware",
  "equipment",
  "insight",
  "clarity",
  "guidance",
  "homework",
  "luggage",
}

---Compound modifiers he leaves as two loose words when they sit in front of a noun.
---Pinned drill row; 6 to 9 instances per window in 2020, and again on 2026-08-28
---(`real time albert-linter plugin`).
local COMPOUNDS = {
  ["real time"] = "real-time",
  ["follow up"] = "follow-up",
  ["full time"] = "full-time",
  ["part time"] = "part-time",
  ["one to one"] = "one-to-one",
  ["world class"] = "world-class",
  ["token efficient"] = "token-efficient",
  ["sample level"] = "sample-level",
  ["meta data"] = "metadata",
  ["in house"] = "in-house",
  ["production ready"] = "production-ready",
  ["end to end"] = "end-to-end",
  ["high level"] = "high-level",
  ["low level"] = "low-level",
  ["long term"] = "long-term",
  ["short term"] = "short-term",
  ["read only"] = "read-only",
}

---Literal phrase swaps, each traceable to a logged fix or a Better English note.
local PHRASES = {
  ["highly appreciated"] = "much appreciated",
  ["mechanism on"] = "mechanism for",
  ["approved of"] = "approved for (unless you mean endorsed)",
  ["in your calendar"] = "on your calendar",
  ["discuss about"] = "discuss",
  ["explain me"] = "explain to me",
  ["make a ticket"] = "file a ticket",
  ["made a ticket"] = "filed a ticket",
  ["provide me with"] = "give me",
  ["listening into"] = "sitting in on",
  ["per your announcement"] = "in your announcement",
  ["that are important"] = "that matter",
  ["that are relevant"] = "that apply",
  ["revert back"] = "revert",
  ["combine together"] = "combine",
  ["level up to able to"] = "get up to speed",
  ["in my own words"] = "let me play that back",
  ["close to home"] = "at home (if you mean comfortable)",
  ["thanks for clarification"] = "thanks for clarifying",
  ["thanks for confirmation"] = "thanks for confirming",
  ["thanks for explanation"] = "thanks for explaining",
  ["thanks for information"] = "thanks for the information",
  ["add an additional"] = "add another",
  ["an another"] = "another",
  ["prior to do"] = "before doing",
  ["look forward to meet"] = "looking forward to meeting",
}

---@type table[]
M.rules = {
  -- ── live tier: single-token, cheap, safe to run mid-typing ──────────────────────
  {
    id = "brand-caps",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Word form: brand capitalization dropped",
    words = BRANDS,
    message = "%s is a proper noun: %s",
  },
  {
    id = "acronym-caps",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Capitalization & Proper Nouns: acronym typed lowercase",
    words = ACRONYMS,
    message = "%s is an initialism: %s",
  },
  {
    id = "double-space",
    tier = "live",
    severity = S.ERROR,
    drill_ref = "Punctuation: double space between words",
    vimre = [[\a\zs  \+\ze\a]],
    message = "Double space between words. One space, always.",
  },
  {
    id = "space-before-mark",
    tier = "live",
    severity = S.ERROR,
    drill_ref = "Punctuation: space before a closing mark",
    -- Space before , . ? ! ; : or a closing paren. Requires a letter or digit before the
    -- space so a line of prose is matched but an indented list marker is not.
    vimre = [==[\w\zs\s\+\ze[,.?!;:)]]==],
    message = "No space before a closing mark. Your trigger is a technical token just before it.",
  },
  {
    id = "ellipsis-length",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Punctuation: ellipsis length",
    vimre = [==[\.\.\.\.\+\|\a\zs\.\.\ze\($\|[^.]\)]==],
    message = "Exactly three periods for an ellipsis, or one for a full stop.",
  },
  {
    id = "login-verb",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Word Form & Compounds: the noun login used as a verb",
    -- Two signals, either sufficient: a subject or modal in front of it (`you login`),
    -- or a preposition after it (`login to`). The first is what catches
    -- `when you login for the first time`, which the preposition list alone missed.
    vimre = [[\c\(\<\(you\|i\|we\|they\|to\|can\|must\|could\|cannot\|please\|should\|will\|did\|didn't\)\s\+\)\@<=\(login\|logout\|signup\)\>\|\c\<\(login\|logout\|signup\|setup\)\ze\s\+\(to\|into\|in\|with\|as\|out\|of\|from\|for\)\>]],
    message = "That is the noun. The verb is two words: log in, log out, set up, sign up.",
  },
  {
    id = "date-order",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Word Order & Sentence Structure: date order reversed",
    vimre = [==[\c\<[12]\d\{3}\s\+\(january\|february\|march\|april\|may\|june\|july\|august\|september\|october\|november\|december\)\>]==],
    message = "English puts the month first: September 2020, not 2020 September.",
  },
  {
    id = "spaced-em-dash",
    tier = "live",
    severity = S.WARN,
    drill_ref = "no-spaced-em-dash rule",
    vimre = [[\s—\s]],
    message = "Spaced em dash. Use a comma, a colon, parentheses, or end the sentence.",
  },

  -- ── exit tier: needs a finished sentence ────────────────────────────────────────
  {
    id = "compound-modifier",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Punctuation (hyphen): compound modifier left as two loose words",
    phrases = COMPOUNDS,
    message = "Hyphenate a compound modifier before its noun: %s",
  },
  {
    id = "phrase-swap",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "various logged fixes and Better English notes",
    phrases = PHRASES,
    message = "%s",
  },
  {
    id = "that-are",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "Phrasing (economy): that are + complement left unreduced",
    -- 10 instances, found only by searching the Original column for the token, because
    -- each had been filed under a different family label.
    vimre = [[\c\<that \(are\|is\|were\|was\) \a\+]],
    message = "Cut `that are`: delete it before a participle, front the adjective, or use a verb (important -> matter).",
  },
  {
    id = "slash-list",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "Clarity & Verbosity: slash-list where and is meant",
    fn = "slash_list",
    message = "A slash hands the choice to the reader. If you mean both, write `and`.",
  },
  {
    id = "stacked-relatives",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "Phrasing (clarity): stacked relative clauses",
    fn = "stacked_relatives",
    message = "Two or more relative clauses in one sentence. Promote one into the noun phrase.",
  },
  {
    id = "mass-noun-article",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Article: spurious a before a mass noun",
    fn = "mass_noun_article",
    message = "%s is uncountable and takes no article.",
  },
  {
    id = "double-additive",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Redundancy: double additive also X as well",
    fn = "double_additive",
    message = "Two additive markers doing one job. Drop one.",
  },
  {
    id = "dropped-subject-i",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Dropped Words & Ellipsis: subject pronoun I dropped at clause start",
    -- 20 instances in the corpus review, all with a first-person mental-state verb.
    vimre = [[\c^\s*\(was curious\|wanted to\|wondered\|thought \|am going to\|will check\|need to check\|guess \)]],
    message = "Missing `I`. Your cue is a message opening with a mental-state verb.",
  },
  {
    id = "wish-backshift",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Tense: I wish + bare past instead of past perfect",
    -- 2 attempts, 2 malformed, 0 correct, eleven days apart to two people. The scope is
    -- narrow on purpose: `should have looked it up` in the same window is correctly
    -- formed, so the gap is this frame, not past counterfactuals in general. Claiming
    -- the broad version would have been false.
    vimre = [[\c\<i wish \(i\|we\|you\|he\|she\|they\) \(had\)\@!\a\+ed\>\|\c\<i wish \(i\|we\) \(met\|got\|knew\|saw\|went\|made\|took\|came\|found\|said\)\>]],
    message = "Present regret about the past is `wish + had` + participle: `I wish I had met you`.",
  },
  {
    id = "curious-if",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Word Choice: if where whether is required after a verb of inquiry",
    vimre = [[\c\<\(curious\|confirm\|check\|verify\|wondering\|ask\) if\>]],
    message = "After a verb of inquiry the complement is `whether`, not `if`.",
  },
  {
    id = "can-i-say",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "Phrasing & Idiom: Can I say X for a comprehension check",
    vimre = [[\c\<can i \(say\|assume\)\>]],
    message = "Asks permission, not for a check. Try `Is it fair to say...` or `Let me play that back:`.",
  },
  {
    id = "nominalized-subject",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "English Mistake - Nominalization Density",
    vimre = [[\c^\s*\(my \(ask\|plan\|question\|solution\|concern\|takeaway\)\|the reason \a\+ \a\+ \a\+\) is\>]],
    message = "The subject is an action. Make it a verb: `I'm asking...` rather than `My ask is...`.",
  },
  {
    id = "typo",
    tier = "exit",
    severity = S.WARN,
    drill_ref = "Spelling, Typos & Dictation",
    -- The second largest family in the correction log at 140 rows, and ~11 per sample
    -- window. Runs at exit tier because a word in progress is a misspelling by
    -- definition, so this cannot fire while typing.
    fn = "typo",
    message = "`%s` is not a word. `zg` adds it to your spellfile if it should be.",
  },
  {
    id = "hedge-density",
    tier = "exit",
    severity = S.HINT,
    drill_ref = "English Mistake - Hedge & Stance Calibration",
    fn = "hedge_density",
    -- "line", not "paragraph": `fns.hedge_density` takes a single line and its own comment
    -- explains why. The message said paragraph, which overstates the rule's reach and
    -- misled a design review into treating it as general over-hedging detection.
    message = "Three or more hedges in one line. Did you already check this? Then drop the hedge.",
  },
}

---Rules held back from the default set, switchable via `enabled_optional`.
---Each carries the reason it misfires, so the trade-off is visible before enabling.
M.optional = {
  {
    id = "brand-caps-ambiguous",
    tier = "live",
    severity = S.HINT,
    drill_ref = "Proper noun: product name typed lowercase",
    -- These are the names that are ALSO common nouns, which is exactly what makes the
    -- lowercase form parse as the wrong sense. It is also what makes the rule noisy:
    -- hexadecimal, a lance, a feather, parquet flooring.
    words = {
      hex = "Hex",
      lance = "Lance",
      feather = "Feather",
      parquet = "Parquet",
      iceberg = "Iceberg",
      vim = "Vim",
      emacs = "Emacs",
      zoom = "Zoom",
      kestra = "Kestra",
    },
    message = "%s may be the product name: %s",
  },
  {
    id = "no-space-before-paren",
    tier = "live",
    severity = S.HINT,
    drill_ref = "Punctuation: space on the wrong side of the mark",
    -- Off by default because `func(arg)` in prose about code is legitimate and common in
    -- his writing, and the engine's code-span skipping cannot catch an unfenced mention.
    vimre = [[\a\zs(\ze\a]],
    message = "A space goes before an opening parenthesis in prose.",
  },
  {
    id = "a-vs-an",
    tier = "live",
    severity = S.WARN,
    drill_ref = "Article: a/an chosen by spelling rather than sound",
    -- Off by default: the sound rule needs an exception lexicon (a URL, an hour, a UUID,
    -- an FDA filing, a one-off) and a bare vowel-letter test produces steady noise.
    fn = "a_vs_an",
    message = "The a/an choice follows the following SOUND, not the letter.",
  },
}

---Words whose article is `a` despite a vowel letter, and vice versa. Used by `a_vs_an`.
M.an_exceptions = {
  -- consonant SOUND, vowel letter: takes `a`
  a_despite_vowel = { "url", "uuid", "ui", "ux", "user", "unit", "union", "unique", "one", "once", "european" },
  -- vowel SOUND, consonant letter: takes `an`
  an_despite_consonant = { "hour", "honest", "honor", "fda", "sql", "ssh", "http", "mcp", "llm", "s3", "x", "l2", "err", "ec2", "nda", "rfc" },
}

---Correctly-lowercase tool names. Not in ACRONYMS, because there is nothing to correct;
---listed here so the typo rule does not report them as misspellings.
local LOWERCASE_TOOLS = { "dbt", "nvim", "npm", "jq", "ripgrep", "fzf", "tmux", "zsh", "uv" }

---Words the plugin already knows are correct, as a lowercased set. The spell checker has
---no idea `MCP` or `GitHub` are words; this catalogue does, so the typo rule consults it
---rather than asking the user to `zg` fifty product names one at a time.
M.known_words = {}
for _, map in ipairs({ BRANDS, ACRONYMS }) do
  for key, value in pairs(map) do
    M.known_words[key:lower()] = true
    M.known_words[value:lower()] = true
  end
end
for _, word in ipairs(LOWERCASE_TOOLS) do
  M.known_words[word] = true
end
for _, extra in ipairs(M.optional) do
  if extra.words then
    for key, value in pairs(extra.words) do
      M.known_words[key:lower()] = true
      M.known_words[value:lower()] = true
    end
  end
end

M.mass_nouns = MASS_NOUNS

return M
