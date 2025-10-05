local M = {}

---@class rummoCell
M.rummoCell = {
  short_id = '',
  name = '',
  stale = false, -- output window could show stale/fresh
  output = '',
  output_line_count = 0,
  image_files = {},
  cell_type = '',
  cell_id = '',
  display = {},
  nb_bufnr = 0,
  extmarks_ns = 0,
  extmark_id = 0,
}

local ts = vim.treesitter

local init_cell_name_query_expr = [[
(

(decorated_definition    
  (decorator) @celldecorator (#match? @celldecorator "[@]app.cell.*$")
  definition: (function_definition
    name: (identifier) @cellname (#match? @cellname "^[_].*$") (#offset! @cellname)
  ) 
) 

)
]]

local nb_query_expr = [[
(

(decorated_definition    
  (decorator) @celldecorator (#match? @celldecorator "[@]app.cell.*$")
  definition: (function_definition
    name: (identifier) @cellname (#match? @cellname "^[_][A-F0-9]{4}$")
  ) 
) @cell

)
]]

local json_query_expr = [[
(pair
 value: (object
    (pair
        key: (string 
            (string_content) @short_id_key (#match? @short_id_key "short_id")
               )
        value: (_) @short_id
      )
    (pair
        key: (string 
            (string_content) @name_key (#match? @name_key "name")
               )
        value: (_) @name
      )
    (pair
        key: (string 
            (string_content) @stale_key (#match? @stale_key "stale")
               )
        value: (_) @stale
      )
    (pair
        key: (string 
            (string_content) @output_id (#match? @output_id "output")
               )
        value: (_) @output
      )
    (pair
        key: (string 
            (string_content) @img_files_key (#match? @img_files_key "img_files")
               )
        value: (_) @img_files
      )
    (pair
        key: (string 
            (string_content) @cell_id_key (#match? @cell_id_key "cell_id")
               )
        value: (_) @cell_id
      )
    (pair
        key: (string 
            (string_content) @output_line_count_key (#match? @output_line_count_key "output_line_count")
               )
        value: (_) @output_line_count
      )
   )
)
]]

local function look_at(this)
  vim.notify(vim.inspect(this))
end

---@return rummoCell
M.new_empty_cell = function(nb_bufnr, ext_ns)
  return {
    short_id = '',
    name = '',
    stale = false, -- output window could show stale/fresh
    output = '',
    output_line_count = 0,
    image_files = {},
    cell_type = '',
    cell_id = '',
    cell_range = {},
    name_range = {},
    display = {},
    nb_bufnr = nb_bufnr,
    extmarks_ns = ext_ns,
    extmark_id = vim.api.nvim_buf_set_extmark(
      nb_bufnr,
      ext_ns,
      1,
      0,
      { end_row = 1, end_col = 0 }
    ),
  }
end

M.init_nb_cells = function(nb_bufnr, ext_ns)
  local cells = {}
  local cell_names = M.init_cell_names(nb_bufnr)
  for _, name in ipairs(cell_names) do
    local new_cell = M.new_empty_cell(nb_bufnr, ext_ns)
    cells[name] = M.update_cell(new_cell, { name = name }, ext_ns)
  end
  cells = M.refresh_nb_cells(nb_bufnr, cells, ext_ns)
  return cells
end

M.refresh_nb_cells = function(nb_bufnr, cells, ext_ns)
  local nb_matchs = M.query_notebook(nb_bufnr)
  for name, match in pairs(nb_matchs) do
    if cells[name] ~= nil then
      cells[name] = M.update_cell(cells[name], match, ext_ns)
    else
      local new_cell = M.new_empty_cell(nb_bufnr, ext_ns)
      cells[name] = M.update_cell(new_cell, match, ext_ns)
    end
  end
  return cells
end

---Update rummoCell with cell info
---@param cell rummoCell
---@param cell_info table
---@param ext_ns integer
---@return rummoCell
M.update_cell = function(cell, cell_info, ext_ns)
  for i, v in pairs(cell_info) do
    if cell[i] ~= nil then
      cell[i] = v
    end
  end
  local cell_range = cell_info.cell_range
  if cell_range ~= nil then
    vim.api.nvim_buf_set_extmark(
      cell.nb_bufnr,
      ext_ns,
      cell_range.row_start,
      cell_range.col_start,
      { id = cell.extmark_id, end_row = cell_range.row_end, end_col = cell_range.col_end }
    )
  end
  return cell
end

M.init_cell_names = function(bufnr)
  local query = ts.query.parse('python', init_cell_name_query_expr)
  -- local parser = ts.get_parser(bufnr, 'python')
  local tree = ts.get_parser(bufnr, 'python'):parse()
  local root = tree[1]:root()

  local cell_name_range = {}

  for _, _, metadata in query:iter_matches(root, bufnr) do
    local row1, col1, row2, col2 = unpack(metadata[2].range)
    table.insert(
      cell_name_range,
      { row_start = row1, col_start = col1, row_end = row2, col_end = col2 }
    )
  end

  local cell_names = {}
  for i, cell in ipairs(cell_name_range) do
    local rep_cell_name = '_' .. string.format('%04X', i - 1)
    table.insert(cell_names, rep_cell_name)
    --TODO: how to do this in one call of nvim_buf_set_text?

    -- delete name
    vim.api.nvim_buf_set_text(
      bufnr,
      cell.row_start,
      cell.col_start,
      cell.row_end,
      cell.col_end,
      {}
    )
    -- insert new name
    vim.api.nvim_buf_set_text(
      bufnr,
      cell.row_start,
      cell.col_start,
      cell.row_start,
      cell.col_start,
      { rep_cell_name }
    )
  end
  return cell_names
end

local proc_cellname = function(bufnr, nodes)
  local range = {}
  local name = ''
  for _, node in ipairs(nodes) do
    if node:type() == 'identifier' then
      name = ts.get_node_text(node, bufnr)
      local row1, col1, row2, col2 = node:range()
      range = { row_start = row1, col_start = col1, row_end = row2, col_end = col2 }
    end
  end
  return { name = name, name_range = range }
end

local proc_cell = function(bufnr, nodes)
  local range = {}
  for _, node in ipairs(nodes) do
    if node:type() == 'decorated_definition' then
      local row1, col1, row2, col2 = node:range()
      range = { row_start = row1, col_start = col1, row_end = row2, col_end = col2 }
    end
  end
  return { cell_range = range }
end

M.nb_match_funcs = { cell = proc_cell, cellname = proc_cellname }

M.get_text = function(node, type, bufnr)
  local node_text = nil
  if node:type() == type then
    node_text = ts.get_node_text(node, bufnr)
  end
  return node_text
end

---@function
---@param bufnr int
---@return table
M.query_notebook = function(bufnr)
  local nb_query = ts.query.parse('python', nb_query_expr)
  local parser = ts.get_parser(bufnr, 'python')
  local tree = parser:parse()
  local root = tree[1]:root()

  local cells_info = {}

  for pattern, match, metadata in nb_query:iter_matches(root, bufnr, 0, -1) do
    local cell_info = M.process_nb_match(bufnr, match, nb_query)
    cells_info[cell_info.name] = cell_info
  end
  return cells_info
end

M.process_nb_match = function(bufnr, match, nb_query)
  local cell_match = {}
  for id, nodes in pairs(match) do
    local name = nb_query.captures[id]
    if M.nb_match_funcs[name] ~= nil then
      local cell_info = M.nb_match_funcs[name](bufnr, nodes)
      for i, v in pairs(cell_info) do
        cell_match[i] = v
      end
    end
  end
  return cell_match
end

local proc_string_value = function(string_node, bufnr)
  local query = vim.treesitter.query.parse(
    'json',
    [[
  ; query
  (string 
    (string_content) @str)
]]
  )
  local txt = ''
  for pattern, match, metadata in query:iter_matches(string_node, bufnr, 0, -1) do
    for id, nodes in pairs(match) do
      txt = ts.get_node_text(nodes[1], bufnr)
    end
  end
  return txt
end

local proc_array_value = function(string_node, bufnr)
  local query = vim.treesitter.query.parse(
    'json',
    [[
  ; query
  (array 
    (string 
      (string_content) @str))
]]
  )
  local arr = {}
  for pattern, match, metadata in query:iter_matches(string_node, bufnr, 0, -1) do
    local txt = ''
    for id, nodes in pairs(match) do
      txt = ts.get_node_text(nodes[1], bufnr)
      table.insert(arr, txt)
    end
  end
  return arr
end

M.json_match_funcs = { string = proc_string_value, array = proc_array_value }

local keys_to_split = { 'output', 'img_files' }

---@function
---@param bufnr integer
---@return table
M.query_json = function(bufnr)
  local json_query = ts.query.parse('json', json_query_expr)
  local parser = ts.get_parser(bufnr, 'json')
  local tree = parser:parse()
  local root = tree[1]:root()

  local cells = {}
  for pattern, match, metadata in json_query:iter_matches(root, bufnr, 0, -1) do
    local c = {}
    for id, nodes in pairs(match) do
      local name = json_query.captures[id]
      local node_type = nodes[1]:type()
      if M.json_match_funcs[node_type] ~= nil then
        local txt = M.json_match_funcs[node_type](nodes[1], bufnr)
        c[name] = txt
      end
    end
    cells[c.name] = c
  end
  return cells
end

---@param cell rummoCell
M.cell_range_from_extmark = function(cell)
  local extmark_info = vim.api.nvim_buf_get_extmark_by_id(
    cell.nb_bufnr,
    cell.extmarks_ns,
    cell.extmark_id,
    { details = true }
  )
  return { row_start = extmark_info[1], extmark_info[3].end_row }
end

-- local tsquery2 = [[
--
-- (
--
-- (decorated_definition
--   (decorator) @cell.decorator (#match? @cell.decorator "[@]app.cell.*$") (#offset! @cell.decorator)
--   definition: (function_definition
--     name: (identifier) @cell.function_name (#match? @cell.function_name "[_].*$") (#offset! @cell.function_name)
--   )
-- ) @cell.block (#set! @cell.block val @cell.block)
--
-- )
-- 	]]

return M
