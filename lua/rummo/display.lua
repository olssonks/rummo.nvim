local rummo_cell = require('lua.rummo.cell')

---@class rummoCell
local rummoCell = rummo_cell.rummoCell

local M = {}

local TABCHAR = '  '

---@class rummoDisplay
local rummoDisplay = {
  display_bufnr = 0,
  extmarks_ns = 0,
  extmark_id = 0,
  window_id = 0,
  row_start = 0,
  col_start = 0,
  win_width = 0,
  win_height = 0,
}

M.new_empty_display = function(bufnr, winid, ext_ns)
  return {
    display_bufnr = bufnr,
    extmarks_ns = ext_ns,
    extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ext_ns, 0, 0, {}),
    window_id = winid,
    row_start = 0,
    col_start = 0,
    win_width = 0,
    win_height = 0,
  }
end

---@param bufnr integer
---@param winid integer
---@param ext_ns string
---@param cells table<string, rummoCell>
M.init_displays = function(bufnr, winid, ext_ns, cells)
  for _, cell in pairs(cells) do
    local new_disp = M.new_empty_display(bufnr, winid, ext_ns)
    cell.display = M.add_display(cell.name, cell.output, new_disp)
  end
  return cells
end

---@param cell_name string
---@param cell_lines table
---@param display rummoDisplay
M.add_display = function(cell_name, cell_lines, display)
  local start_line = vim.api.nvim_buf_line_count(display.display_bufnr)
  if start_line ~= 1 then
    start_line = start_line + 2 -- adding lines after prev cell
  end

  cell_lines = M.format_cell_output(cell_name, cell_lines)
  local line_count = #cell_lines

  vim.api.nvim_buf_set_lines(
    display.display_bufnr,
    start_line - 1,
    start_line - 1,
    false,
    cell_lines
  )

  display.extmark_id = vim.api.nvim_buf_set_extmark(
    display.display_bufnr,
    display.extmarks_ns,
    start_line - 1,
    0,
    { end_row = start_line + line_count - 2, end_col = 0 }
  )
  return display
end

M.add_indent = function(cell_lines)
  for i = 1, #cell_lines do
    cell_lines[i] = string.format('%s%s', TABCHAR, cell_lines[i])
  end
  return cell_lines
end

M.format_cell_output = function(cell_name, cell_lines)
  cell_name = string.format('Cell %s:', cell_name)
  cell_lines = M.add_indent(cell_lines)
  if type(cell_lines) ~= table then
    cell_lines = { cell_lines }
  end
  table.insert(cell_lines, 1, cell_name)
  table.insert(cell_lines, '')
  return cell_lines
end

---comment
---@param cell_name string
---@param cell_lines table
---@param display rummoDisplay
M.update_display_buf_for_cell = function(cell_name, cell_lines, display)
  local extmark_info = vim.api.nvim_buf_get_extmark_by_id(
    display.display_bufnr,
    display.extmarks_ns,
    display.extmark_id,
    { details = true }
  )

  vim.api.nvim_buf_set_lines(
    display.display_bufnr,
    extmark_info[1],
    extmark_info[3].end_row - 1,
    false,
    {}
  )

  table.insert(cell_lines, 1, cell_name)
  vim.api.nvim_buf_set_lines(
    display.display_bufnr,
    extmark_info[1],
    extmark_info[3].end_row,
    false,
    cell_lines
  )
end

---Check and shows output display if cursor falls within a cell block in the user_notebook
---@param cells table<string, rummoCell>
M.check_and_show = function(cells)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local enable_display = nil
  for _, cell in pairs(cells) do
    local range = rummo_cell.cell_range_from_extmark(cell)
    if range.row_start <= cursor_pos <= range.row_end then
      enable_display = true
    end
  end
end

---Show the output display
---@param display rummoDisplay
M.show_cell_display = function(display)
  local display_start_line = vim.api.nvim_buf_get_extmark_by_id(
    display.display_bufnr,
    display.extmarks_ns,
    display.extmark_id,
    {}
  )[1]
  if display_start_line == 0 then
    display_start_line = 1
  end
  vim.api.nvim_win_set_cursor(display.window_id, { display_start_line, 0 })
end

-- what was this for?
M.update_display_window = function(cell)
  local extmark_info = vim.api.nvim_buf_get_extmark_by_id(
    cell.display.display_bufnr,
    cell.display.extmarkn_s,
    cell.display.extmark_id,
    { details = true }
  )
end

return M

-- M.output_window = function()
--   local buf = vim.api.nvim_create_buf(false, true)
--   local txt = { '1\n', '2\n', '3\n' }
--   vim.api.nvim_open_win(
--     buf,
--     true,
--     { relative = 'editor', border = { '*' }, row = 3, col = 3, width = 12, height = 12 }
--   )
--   vim.api.nvim_buf_set_text(buf, 0, 0, -1, -1, { string.format('%q', '1\n2\n3\n') })
-- end
--
-- M.gen_window_specs = function(cell_range, height)
--   local row = cell_range.end_row + 1
--   local col = 0
--   local width = vim.api.nvim_win_get_width(0)
--   local height = height or 7
--   return { row = row, col = col, width = width, height = height }
-- end
