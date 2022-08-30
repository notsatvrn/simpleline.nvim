local simpleline = {}
local elements = {}
local helpers = {}

-- SIMPLELINE

simpleline.setup = function(config)
  _G.simpleline = simpleline

  helpers.setup_config(config)

  if vim.fn.has('nvim-0.6') == 1 then
    helpers.get_diagnostic_count = function(id)
      return #vim.diagnostic.get(0, { severity = id })
    end

    helpers.diagnostic_levels = {
      { id = vim.diagnostic.severity.ERROR, sign = 'E' },
      { id = vim.diagnostic.severity.WARN, sign = 'W' },
      { id = vim.diagnostic.severity.INFO, sign = 'I' },
      { id = vim.diagnostic.severity.HINT, sign = 'H' },
    }
  else
    helpers.get_diagnostic_count = function(id)
      return vim.lsp.diagnostic.get_count(0, id)
    end

    helpers.diagnostic_levels = {
      { id = 'Error', sign = 'E' },
      { id = 'Warning', sign = 'W' },
      { id = 'Information', sign = 'I' },
      { id = 'Hint', sign = 'H' },
    }
  end

  vim.api.nvim_exec(
    [[augroup Simpleline
      au!
      au WinEnter,BufEnter * setlocal statusline=%!v:lua.simpleline.get('active')
      au WinLeave,BufLeave * setlocal statusline=%!v:lua.simpleline.get('inactive')]],
    false)

  vim.api.nvim_exec(
    [[hi default link SimplelineModeNormal  Cursor
      hi default link SimplelineModeInsert  DiffChange
      hi default link SimplelineModeVisual  DiffAdd
      hi default link SimplelineModeReplace DiffDelete
      hi default link SimplelineModeCommand DiffText
      hi default link SimplelineModeOther   IncSearch

      hi default link SimplelineSecondary   StatusLine
      hi default link SimplelineTertiary    StatusLineNC]],
    false)
end

simpleline.get = function(active)
  local content_config = simpleline.config[active]
  local content = {}
  for i, cv in ipairs(content_config.left) do
    if type(cv) == 'table' then
      for _, v in ipairs(cv) do
        if type(v) == 'string' then
          content[i] = elements[v](i)
        else
          content[i] = elements[v[0]](i, v[1])
        end
      end
    end
  end
  content[#content+1] = '%='
  for i, cv in ipairs(content_config.right) do
    if type(cv) == 'table' then
      for _, v in ipairs(cv) do
        if type(v) == 'string' then
          content[#content+1] = elements[v](#content_config.right-(i-1))
        else
          content[#content+1] = elements[v[1]](#content_config.right-(i-1), v[2])
        end
      end
    end
  end

  return table.concat(content, '')
end

-- GETTERS

elements.file = function(pos)
  if vim.bo.buftype == 'terminal' then
    return '%t '
  end

  return helpers.format('%F%m%r', '%f%m%r', pos)
end

elements.mode = function(pos)
  local mode_info = helpers.modes[vim.fn.mode()]

  return helpers.format(mode_info.long, mode_info.short, pos)
end

elements.location = function(pos)
  return helpers.highlight('%l|%2v', pos)
end

elements.git = function(pos)
  if vim.bo.buftype ~= '' then
    return ''
  end

  local head = vim.b.gitsigns_head or ''

  if head == '' then
    return ''
  end

  local signs = helpers.truncate(vim.b.gitsigns_status or '', '')
  local icon = simpleline.config.use_icons and '' or 'Git'

  if signs == '' then
    return helpers.highlight(string.format('%s %s', icon, head), pos)
  end

  return helpers.highlight(string.format('%s %s %s', icon, head, signs), pos)
end

elements.diagnostics = function(pos)
  if vim.api.nvim_win_get_width(0) < 100 or vim.bo.buftype ~= '' or next(vim.lsp.buf_get_clients()) == nil then
    return ''
  end

  local t = {}
  for _, level in ipairs(helpers.diagnostic_levels) do
    local n = helpers.get_diagnostic_count(level.id)
    if n > 0 then
      t[#t+1] = string.format(' %s%s', level.sign, n)
    end
  end

  local icon = simpleline.config.use_icons and '' or 'LSP'
  if vim.tbl_count(t) == 0 then
    return helpers.highlight(string.format('%s -', icon), pos)
  end
  return helpers.highlight(string.format('%s%s', icon, table.concat(t, '')), pos)
end

elements.type = function(pos)
  local filetype = vim.bo.filetype

  if filetype == '' or vim.bo.buftype ~= '' then
    return ''
  end

  return helpers.highlight(string.format('%s %s', helpers.get_file_icon(), filetype), pos)
end

elements.text = function(pos, args)
  return helpers.highlight(args[1], pos)
end

-- HELPERS

helpers.devicons = nil

helpers.get_file_icon = function()
  if not simpleline.config.use_icons then
    return ''
  end

  if helpers.devicons == nil then
    local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
    if not has_devicons then
      return ''
    end
    helpers.devicons = devicons
  end

  if helpers.devicons ~= nil then
    return helpers.devicons.get_icon(
      vim.fn.expand('%:t'),
      vim.fn.expand('%:e'),
      { default = true }
    )
  end
end

helpers.get_hl = function(pos)
  if pos == 1 then
    return helpers.modes[vim.fn.mode()].hl
  elseif pos == 2 then
    return 'SimplelineSecondary'
  else
    return 'SimplelineTertiary'
  end
end

helpers.highlight = function(str, pos)
  if str:len() == 0 then
    return ''
  end

  return string.format('%%#%s# %s ', helpers.get_hl(pos), str)
end

helpers.truncate = function(long, short)
  if vim.api.nvim_win_get_width(0) < 100 then
    return short
  end

  return long
end

helpers.format = function(long, short, pos)
  return helpers.highlight(helpers.truncate(long, short), pos)
end

local CTRL_S = vim.api.nvim_replace_termcodes('<C-S>', true, true, true)
local CTRL_V = vim.api.nvim_replace_termcodes('<C-V>', true, true, true)

helpers.modes = setmetatable({
  ['n']    = { long = 'NORMAL',   short = 'N',   hl = 'SimplelineModeNormal' },
  ['v']    = { long = 'VISUAL',   short = 'V',   hl = 'SimplelineModeVisual' },
  ['V']    = { long = 'V-LINE',   short = 'V-L', hl = 'SimplelineModeVisual' },
  [CTRL_V] = { long = 'V-BLOCK',  short = 'V-B', hl = 'SimplelineModeVisual' },
  ['s']    = { long = 'SELECT',   short = 'S',   hl = 'SimplelineModeVisual' },
  ['S']    = { long = 'S-LINE',   short = 'S-L', hl = 'SimplelineModeVisual' },
  [CTRL_S] = { long = 'S-BLOCK',  short = 'S-B', hl = 'SimplelineModeVisual' },
  ['i']    = { long = 'INSERT',   short = 'I',   hl = 'SimplelineModeInsert' },
  ['R']    = { long = 'REPLACE',  short = 'R',   hl = 'SimplelineModeReplace' },
  ['c']    = { long = 'COMMAND',  short = 'C',   hl = 'SimplelineModeCommand' },
  ['r']    = { long = 'PROMPT',   short = 'P',   hl = 'SimplelineModeOther' },
  ['!']    = { long = 'SHELL',    short = 'SH',  hl = 'SimplelineModeOther' },
  ['t']    = { long = 'TERMINAL', short = 'T',   hl = 'SimplelineModeOther' },
}, {
  __index = function()
    return   { long = 'UNKNOWN',  short = 'U',   hl = 'SimplelineModeOther' }
  end,
})

helpers.default_config = {
  active = {
    left = {{'mode'}, {'git'}, {'file'}},
    right = {{'diagnostics'}, {'type'}, {'location'}},
  },
  inactive = {
    left = {{'mode'}, {'git'}, {'file'}},
    right = {{'diagnostics'}, {'type'}, {'location'}},
  },
  use_icons = true,
  always_show = true,
}

helpers.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', helpers.default_config, config or {})

  vim.validate({
    active = { config.active, 'table' },
    inactive = { config.inactive, 'table' },
    use_icons = { config.use_icons, 'boolean' },
    always_show = { config.always_show, 'boolean' },
  })

  vim.validate({
    ['active.left'] = { config.active.left, 'table' },
    ['active.right'] = { config.active.right, 'table' },
    ['inactive.left'] = { config.inactive.left, 'table' },
    ['inactive.right'] = { config.inactive.right, 'table' },
  })

  simpleline.config = config
end

return simpleline
