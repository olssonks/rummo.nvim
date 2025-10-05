local rummo_cell = require('lua.rummo.cell')
local config = require('lua.rummo.config').config
local rummo_disp = require('lua.rummo.display')

---@class rummoCell
local rummoCell = rummo_cell.rummoCell

local M = {}

---@class rummoRunner
local rummoRunner = {
  notebook_bufnr = 0,
  notebook_cells = {},
  json_bufnr = 0,
  display_bufnr = 0,
  display_winid = 0,
  extmarks_ns = 0,
  script_config_extmark = 0,
  text_shift_extmark = { id = 0, original_pos = { 0, 0 }, shifted = false },
}

-- M.refresh_output_window
--

---Check and shows output display if cursor falls within a cell block in the user_notebook
---@param runner rummoRunner
M.check_and_show = function(runner)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local enable_display = nil
  local cell_to_display = nil

  for _, cell in pairs(runner.notebook_cells) do
    local range = rummo_cell.cell_range_from_extmark(cell)
    if range.row_start <= cursor_pos <= range.row_end then
      enable_display = true
      cell_to_display = cell
      break
    end
  end
end

M.shift_text_with_show = function(
  nb_bufnr,
  extmark_ns,
  shift_origin,
  shift_amount,
  text_shift_extmark
)
  local new_anchor = vim.api.nvim_buf_get_extmark_by_id(
    cell.display.display_bufnr,
    cell.display.extmarks.ns,
    cell.display.extmarks.end_id,
    {}
  )[1]
  vim.api.nvim_buf_set_extmark(
    nb_bufnr,
    extmark_ns,
    new_anchor + 1,
    0,
    { id = text_shift_extmark.id }
  )
end

return M
