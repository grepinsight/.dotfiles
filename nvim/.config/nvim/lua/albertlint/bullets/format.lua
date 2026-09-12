---Turning a run of lines into a bullet list. Pure, same shape as `parse/sentence.lua`.
---
---Split in two halves on purpose. This file decides *placement*, which is the whole risk
---surface: the transform changes no words, so the only way it can damage a draft is by putting
---a marker on a line that should not have one, or by joining text across a boundary that
---should have held. The segmenter decides where sentences end and lives elsewhere, behind a
---pipe.
---
---The block list is the interface between the two. The caller segments only `prose` blocks and
---hands the results back keyed by block index, so `skip` blocks are unreachable from the
---segmenter and a heading or an existing list cannot be rewritten even by a buggy one.
local M = {}

---A line that already carries a list marker: `-`, `*`, `+`, or `1.` / `2)`.
---
---The trailing `%s` is what keeps this off prose. Without it `well-scoped work is the goal.`
---reads as a bullet whose text is `scoped work...`, and `-5 degrees is cold.` reads as one too,
---so a selection of ordinary sentences would pass straight through untouched and the command
---would look broken rather than wrong. Any sentence opening on a hyphenated modifier hits this.
---@param line string
---@return boolean
local function is_list_item(line)
  return line:match("^%s*[-*+]%s") ~= nil or line:match("^%s*%d+[.)]%s") ~= nil
end

---@param line string
---@return boolean
local function is_heading(line)
  return line:match("^%s*#+%s") ~= nil
end

---@param line string
---@return boolean
local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

---@param line string
---@return string
local function trim(line)
  return (line:gsub("^%s+", ""):gsub("%s+$", ""))
end

---`vim.list_extend` would do this, and is avoided so the module stays loadable and testable
---with no `vim` at all, the same way `parse/sentence.lua` is.
---@param dest string[]
---@param src string[]
local function extend(dest, src)
  for _, item in ipairs(src) do
    table.insert(dest, item)
  end
end

---Split a selection into blocks: runs of prose, runs of blank lines, and lines left alone.
---
---A block is the unit a bullet group is built from. Three kinds:
---
---  `prose` -- lines joined into one `text`, to be segmented and re-emitted as bullets
---  `blank` -- blank lines, emitted verbatim so paragraph spacing survives
---  `skip`  -- a heading or an existing list item, emitted verbatim
---
---A heading gets its own block rather than joining the prose beneath it, so `## Title` plus a
---paragraph does not become one bullet beginning with the title.
---@param lines string[]
---@return table[] `{ { kind, lines, text?, indent? } }`
function M.blocks(lines)
  local blocks = {}
  local i = 1

  local function push(kind, chunk, text, indent)
    table.insert(blocks, { kind = kind, lines = chunk, text = text, indent = indent })
  end

  while i <= #lines do
    local line = lines[i]
    if is_blank(line) then
      local chunk = {}
      while i <= #lines and is_blank(lines[i]) do
        table.insert(chunk, lines[i])
        i = i + 1
      end
      push("blank", chunk)
    elseif is_heading(line) then
      -- Exactly one line, so the paragraph under a heading is still prose. Swallowing the run
      -- would make `## Title` plus a paragraph into a single untouched block.
      push("skip", { line })
      i = i + 1
    elseif is_list_item(line) then
      -- The whole run here, unlike a heading. A wrapped list item's continuation line is plain
      -- indented text, so stopping at the first non-marker line would classify it as prose and
      -- a second run of the command would bullet the continuation separately. That is the one
      -- way this transform is not idempotent, so the run has to hold until a blank line.
      local chunk = {}
      while i <= #lines and not is_blank(lines[i]) and not is_heading(lines[i]) do
        table.insert(chunk, lines[i])
        i = i + 1
      end
      push("skip", chunk)
    else
      local chunk, parts = {}, {}
      local indent = line:match("^%s*") or ""
      while i <= #lines and not is_blank(lines[i]) and not is_heading(lines[i]) and not is_list_item(lines[i]) do
        table.insert(chunk, lines[i])
        table.insert(parts, trim(lines[i]))
        i = i + 1
      end
      -- Joined with a single space after trimming each line, so a sentence wrapped across two
      -- lines is one sentence and a trailing space does not become a double one.
      push("prose", chunk, table.concat(parts, " "), indent)
    end
  end

  return blocks
end

---The texts to segment, and which block each one came from.
---
---Returned as two parallel lists rather than a map, because the segmenter takes a list and the
---indices are how its answers get filed back onto the right blocks.
---@param blocks table[]
---@return string[] texts, integer[] indices
function M.prose_texts(blocks)
  local texts, indices = {}, {}
  for i, block in ipairs(blocks) do
    if block.kind == "prose" then
      table.insert(texts, block.text)
      table.insert(indices, i)
    end
  end
  return texts, indices
end

M.MARKER = "- "

---Render the blocks back to lines, one bullet per sentence.
---@param blocks table[]
---@param sentences table<integer, string[]> Keyed by block index; prose blocks only
---@return string[]
function M.render(blocks, sentences)
  local out = {}
  for i, block in ipairs(blocks) do
    if block.kind == "prose" then
      local emitted = 0
      for _, sentence in ipairs(sentences[i] or {}) do
        local text = trim(sentence)
        if text ~= "" then
          table.insert(out, block.indent .. M.MARKER .. text)
          emitted = emitted + 1
        end
      end
      if emitted == 0 then
        -- Nothing came back, so the block is left exactly as it was. A failed segmentation
        -- should cost the user nothing, and an empty bullet is worse than no change.
        extend(out, block.lines)
      end
    else
      extend(out, block.lines)
    end
  end
  return out
end

return M
