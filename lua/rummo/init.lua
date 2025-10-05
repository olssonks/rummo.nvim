local rummo_cell = require('lua.rummo.cell')
local rummo_disp = require('lua.rummo.display')
local rummo_core = require('lua.rummo.core')

local config = require('lua.rummo.config').config

---@class rummoCell
local rummoCell = rummo_cell.rummoCell

---@class rummoDisplay
local rummoDisplay = rummo_disp.rummoDisplay

---@class rummoRunner
local rummoRunner = rummo_core.rummoRunner

local M = {}

---comment
---@param nb_bufnr integer
---@return rummoRunner
M.init_runner = function(nb_bufnr)
  local runner = {}

  -- runner.notebook_bufnr = vim.api.nvim_win_get_buf(nb_bufnr)
  runner.notebook_bufnr = nb_bufnr
  runner.notebook_cells = {}
  runner.json_bufnr = vim.api.nvim_create_buf(false, true)
  runner.display_bufnr = vim.api.nvim_create_buf(false, true)
  runner.extmarks_ns = vim.api.nvim_create_namespace('rummo')
  runner.display_winid = vim.api.nvim_open_win(runner.display_bufnr, false, {
    relative = 'win',
    row = 20,
    col = 0,
    width = 40,
    height = 12,
    title = 'rummo',
    title_pos = 'right',
    border = { '*' },
  })

  runner.text_shift_extmark = {
    id = vim.api.nvim_buf_set_extmark(nb_bufnr, runner.extmarks_ns, 0, 0, {}),
    original_pos = { 0, 0 },
    shifted = false,
  }

  vim.api.nvim_set_hl(runner.extmarks_ns, 'rummoDisplay', config.display_hl)

  -- vim.api.nvim_win_hide(runner.display_winid)

  return runner
end

---comment
---@param runner rummoRunner
---@return rummoRunner
M.init_notebook = function(runner)
  local cells = rummo_cell.init_nb_cells(runner.notebook_bufnr, runner.extmarks_ns)

  cells = rummo_disp.init_displays(
    runner.display_bufnr,
    runner.display_winid,
    runner.extmarks_ns,
    cells
  )
  runner.notebook_cells = cells
  return runner
end

M.launch_server_notebook = function(runner)
  local user_nb = vim.api.nvim_buf_get_name(runner.notebook_bufnr)
  local server_nb = vim.expand('../../scripts/rummo/notebook_server.py')
  local launch_cmd = { 'python', '-m', 'marimo', 'edit', '--watch', tostring(server_nb) }
end

return M
