local M = {}

M.defaults = {
  enabled = 'auto',
  marker = 'science.yaml',
  debounce_ms = 150,
  viewport_only = true,
  viewport_margin = 10,
  entities = {
    question = {
      pattern = [[\<question:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@constant',
    },
    task = {
      pattern = [[\<task:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@function',
    },
    hypothesis = {
      pattern = [[\<hypothesis:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@type',
    },
    interpretation = {
      pattern = [[\<interpretation:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = '@string.special',
    },
    discussion = {
      pattern = [[\<discussion:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Comment',
      italic = true,
    },
    topic = {
      pattern = [[\<topic:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Number',
    },
    report = {
      pattern = [[\<report:[A-Za-z0-9][A-Za-z0-9._-]*]],
      link = 'Constant',
    },
    cite = {
      pattern = [=[\[-\=@[A-Za-z][A-Za-z0-9_-]*\%(\s*;\s*@\=[A-Za-z][A-Za-z0-9_-]*\)*\]]=],
      link = 'Underlined',
      italic = true,
    },
    unverified = {
      pattern = [=[\[UNVERIFIED\]]=],
      link = 'DiagnosticWarn',
      bold = true,
    },
    needs_citation = {
      pattern = [=[\[NEEDS CITATION\]]=],
      link = 'DiagnosticError',
      bold = true,
    },
  },
}

local function merge_entity(default_entity, override)
  return vim.tbl_deep_extend('force', default_entity or {}, override or {})
end

function M.merge(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend('force', M.defaults, opts)
  merged.entities = vim.deepcopy(M.defaults.entities)
  for kind, entity in pairs(opts.entities or {}) do
    merged.entities[kind] = merge_entity(merged.entities[kind], entity)
  end
  return merged
end

return M
