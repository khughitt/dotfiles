local scanner = require('science-md.scanner')
local config = require('science-md.config')

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function compact(matches)
  local out = {}
  for _, match in ipairs(matches) do
    table.insert(out, {
      kind = match.kind,
      text = match.text,
      row = match.row,
      col_start = match.col_start,
      col_end = match.col_end,
    })
  end
  return out
end

local lines = {
  '---',
  'questions: [question:q01-model-granularity, task:t406]',
  'Inline hypothesis:h01-growth and interpretation:2026-04-30-slug.',
  '[task label task:t001](question:q02-links) plus topic:lichen and report:r01',
  'discussion:2026-05-03-science-md-plugin-design [@Smith2024] [-@Jones2025] [@A2024; @B-2025]',
  '[UNVERIFIED] and [NEEDS CITATION]',
  'notquestion:q01 should not match as a standalone question ref',
}

local matches = compact(scanner.scan_lines(lines, config.defaults.entities, 10))

assert_eq(#matches, 14, 'match count')
assert_eq(matches[1].kind, 'question', 'first kind')
assert_eq(matches[1].text, 'question:q01-model-granularity', 'first text')
assert_eq(matches[1].row, 11, 'line offset is zero-based row')
assert_eq(matches[2].kind, 'task', 'frontmatter task kind')
assert_eq(matches[3].kind, 'hypothesis', 'hypothesis kind')
assert_eq(matches[4].kind, 'interpretation', 'interpretation kind')
assert_eq(matches[5].kind, 'task', 'link-label task kind')
assert_eq(matches[6].kind, 'question', 'link-target question kind')
assert_eq(matches[7].kind, 'topic', 'topic kind')
assert_eq(matches[8].kind, 'report', 'report kind')
assert_eq(matches[9].kind, 'discussion', 'discussion kind')
assert_eq(matches[10].text, '[@Smith2024]', 'single citation')
assert_eq(matches[11].text, '[-@Jones2025]', 'negative citation')
assert_eq(matches[12].text, '[@A2024; @B-2025]', 'multi citation')
assert_eq(matches[13].kind, 'unverified', 'unverified marker kind')
assert_eq(matches[14].kind, 'needs_citation', 'needs citation marker kind')

local boundary = compact(scanner.scan_lines({ 'xquestion:q01 question:q02' }, config.defaults.entities, 0))
assert_eq(#boundary, 1, 'boundary count')
assert_eq(boundary[1].text, 'question:q02', 'boundary text')

print('scanner_spec passed')
