---- iron.core ----

--- Local helpers for creating a new repl.
-- Should be used by core functions, but not
-- exposed to the end-user
-- @local
local new_repl = {}

--- Create a new repl on the current window
-- Simple wrapper around the low level functions
-- Useful to avoid rewriting the get_def + create + save pattern
-- @param ft filetype
-- @param bufnr buffer to be used.
-- @param current_bufnr current buffer.
-- @tparam cleanup function Function to cleanup if call fails
-- @return saved snapshot of repl metadata
new_repl.create = function(ft, bufnr, current_bufnr, cleanup)
  local meta
  local success, repl = pcall(ll.get_repl_def, ft)

  if not success and cleanup ~= nil then
    cleanup()
    error(repl)
  end

  success, meta = pcall(ll.create_repl_on_current_window, ft, repl, bufnr, current_bufnr)
  if success then
    ll.set(ft, meta)

    local filetype = config.repl_filetype(bufnr, ft)
    if filetype ~= nil then
      vim.api.nvim_set_option_value('filetype', filetype, { buf = bufnr })
    end

    return meta
  elseif cleanup ~= nil then
    cleanup()
  end

  error(meta)
end

--- Create a new repl on a new repl window
-- Adds a layer on top of @{new_repl.create},
-- ensuring it is created on a new window
-- @param ft filetype
-- @return saved snapshot of repl metadata
new_repl.create_on_new_window = function(ft)
  local current_bufnr = vim.api.nvim_get_current_buf()
  local bufnr = ll.new_buffer()

  local replwin = ll.new_window(bufnr)
  vim.api.nvim_set_current_win(replwin)
  local meta = new_repl.create(ft, bufnr, current_bufnr, function()
    vim.api.nvim_win_close(replwin, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  return meta
end

---- iron.lowerlevel ----

--- Low level functions for iron
-- This is needed to reduce the complexity of the user API functions.
-- There are a few rules to the functions in this document:
--    * They should not interact with each other
--        * An exception for this is @{lowlevel.get_repl_def} during the transition to v3
--    * They should do one small thing only
--    * They should not care about setting/cleaning up state (i.e. moving back to another window)
--    * They must be explicit in their documentation about the state changes they cause.
-- @module lowlevel
-- @alias ll
local ll = {}

ll.store = {}

-- Quick fix for changing repl_open_cmd
ll.tmp = {}

-- TODO This should not be part of lowlevel
ll.get = function(ft)
  if ft == nil or ft == '' then
    error('Empty filetype')
  end
  return config.scope.get(ll.store, ft)
end

-- TODO this should not be part of lowlevel
ll.set = function(ft, fn)
  return config.scope.set(ll.store, ft, fn)
end

ll.get_buffer_ft = function(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == nil or ft == '' then
    error('Empty filetype')
  elseif fts[ft] == nil and config.repl_definition[ft] == nil then
    error("There's no REPL definition for current filetype " .. ft)
  end
  return ft
end

--- Creates the repl in the current window
-- This function effectively creates the repl without caring
-- about window management. It is expected that the client
-- ensures the right window is created and active before calling this function.
-- If @{\\config.close_window_on_exit} is set to true, it will plug a callback
-- to the repl so the window will automatically close when the process finishes
-- @param ft filetype of the current repl
-- @param repl definition of the repl being created
-- @param repl.command table with the command to be invoked.
-- @param bufnr Buffer to be used
-- @param current_bufnr Current buffer
-- @param opts Options passed through to the terminal
-- @warning changes current window's buffer to bufnr
-- @return unsaved metadata about created repl
ll.create_repl_on_current_window = function(ft, repl, bufnr, current_bufnr, opts)
  vim.api.nvim_win_set_buf(0, bufnr)
  -- TODO Move this out of this function
  -- Checking config should be done on an upper layer.
  -- This layer should be simpler
  opts = opts or {}
  if config.close_window_on_exit then
    opts.on_exit = function()
      local bufwinid = vim.fn.bufwinid(bufnr)
      while bufwinid ~= -1 do
        vim.api.nvim_win_close(bufwinid, true)
        bufwinid = vim.fn.bufwinid(bufnr)
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  else
    opts.on_exit = function() end
  end

  local cmd = repl.command
  if type(repl.command) == 'function' then
    local meta = {
      current_bufnr = current_bufnr,
    }
    cmd = repl.command(meta)
  end
  local job_id = vim.fn.termopen(cmd, opts)

  return {
    ft = ft,
    bufnr = bufnr,
    job = job_id,
    repldef = repl,
  }
end

--- Wrapper function for getting repl definition from config
-- This allows for an easier transition between old and new methods
-- @tparam string ft filetype of the desired repl
-- @return repl definition
ll.get_repl_def = function(ft)
  -- TODO should not call providers directly, but from config
  return config.repl_definition[ft] or providers.first_matching_binary(ft)
end

--- Creates a new window for placing a repl.
-- Expected to be called before creating the repl.
-- It knows nothing about the repl and only takes in account the
-- configuration.
-- @warning might change the current window
-- @param bufnr buffer to be used
-- @param repl_open_cmd command to be used to open the repl. if nil than will use config.repl_open_cmd
-- @return window id of the newly created window
ll.new_window = function(bufnr, repl_open_cmd)
  if repl_open_cmd == nil then
    repl_open_cmd = ll.tmp.repl_open_cmd
  end

  if type(repl_open_cmd) == "function" then
    local result = repl_open_cmd(bufnr)
    if type(result) == "table" then
      return view.openfloat(result, bufnr)
    else
      return result
    end
  else
    vim.cmd(repl_open_cmd)
    vim.api.nvim_set_current_buf(bufnr)
    return vim.fn.bufwinid(bufnr)
  end
end

--- Creates a new buffer to be used by the repl
-- @return the buffer id
ll.new_buffer = function()
  return vim.api.nvim_create_buf(config.buflisted, config.scratch_repl)
end

--- Wraps the condition checking of whether a repl exists
-- created for convenience
-- @tparam table meta metadata for repl. Can be nil.
-- @treturn boolean whether the repl exists
ll.repl_exists = function(meta)
  return meta ~= nil and vim.api.nvim_buf_is_loaded(meta.bufnr)
end

--- Sends data to an existing repl of given filetype
-- The content supplied is ensured to be a table of lines,
-- being coerced if supplied as a string.
-- As a side-effect of pasting the contents to the repl,
-- it changes the scroll position of that window.
-- Does not affect currently active window and its cursor position.
-- @tparam table meta metadata for repl. Should not be nil
-- @tparam string ft name of the filetype
-- @tparam string|table data A multiline string or a table containing lines to be sent to the repl
-- @warning changes cursor position if window is visible
ll.send_to_repl = function(meta, data)
  local dt = data

  if type(data) == "string" then
    dt = vim.split(data, '\n')
  end

  dt = format(meta.repldef, dt)

  local window = vim.fn.bufwinid(meta.bufnr)
  if window ~= -1 then
    vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(meta.bufnr), 0})
  end

  --TODO check vim.api.nvim_chan_send
  --TODO tool to get the progress of the chan send function
  vim.fn.chansend(meta.job, dt)

  if window ~= -1 then
    vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(meta.bufnr), 0})
  end
end

---- iron.fts.python ----

-- luacheck: globals vim
local bracketed_paste_python = require('iron.fts.common').bracketed_paste_python
local python = {}

local executable = function(exe)
  return vim.api.nvim_call_function('executable', { exe }) == 1
end

local pyversion = executable('python3') and 'python3' or 'python'

local def = function(cmd)
  return {
    command = cmd,
    format = bracketed_paste_python,
  }
end

python.ptipython = def({ 'ptipython' })
python.ipython = def({ 'ipython', '--no-autoindent' })
python.ptpython = def({ 'ptpython' })
python.python = def({ pyversion })

return python

---- iron.config ----
---
--- Default values
--@module config
local config

--- Default configurations for iron.nvim
-- @table config.values
-- @tfield false|string highlight_last Either false or the name of a highlight group
-- @field scratch_repl When enabled, the repl buffer will be a scratch buffer
-- @field should_map_plug when enabled iron will provide its mappings as `<plug>(..)` as well,
-- for backwards compatibility
-- @field close_window_on_exit closes repl window on process exit
local values = {
  highlight_last = "IronLastSent",
  visibility = require("iron.visibility").toggle,
  scope = require("iron.scope").path_based,
  scratch_repl = false,
  close_window_on_exit = true,
  preferred = setmetatable({}, {
    __newindex = function(tbl, k, v)
      vim.deprecate("config.preferred", "config.repl_definition", "3.1", "iron.nvim")
      rawset(tbl, k, v)
    end
  }),
  repl_definition = setmetatable({}, {
    __index = function(tbl, key)
      local repl_definitions = require("iron.fts")[key]
      local repl_def
      for _, v in pairs(repl_definitions) do
        if vim.fn.executable(v.command[1]) == 1 then
          repl_def = v
          break
        end
      end
      if repl_def == nil then
        error("Failed to locate REPL executable, aborting")
      else
        rawset(tbl, key, repl_def)
        return repl_def
      end
    end
  }),
  repl_filetype = function(bufnr, ft)
    return "iron"
  end,
  should_map_plug = false,
  repl_open_cmd = view.split.botright(40),
  current_view = 1,
  views = {
    view.bottom(40)
  },
  mark = { -- Arbitrary numbers
    save_pos = 20,
    send = 77,
  },
  buflisted = false,
  ignore_blank_lines = true,
}

-- HACK for LDoc to correctly link @see annotations
config = vim.deepcopy(values)
config.values = values

return config

---- rummo.iron-like ----

local irl = {}

irl.create_repl = function(ft, bufnr, current_bufnr, cleanup)
  local meta
  local success, repl = pcall(irl.get_repl_def, ft)

  if not success and cleanup ~= nil then
    cleanup()
    error(repl)
  end

  success, meta = pcall(ll.create_repl_on_current_window, ft, repl, bufnr, current_bufnr)
  if success then
    ll.set(ft, meta)

    local filetype = config.repl_filetype(bufnr, ft)
    if filetype ~= nil then
      vim.api.nvim_set_option_value('filetype', filetype, { buf = bufnr })
    end

    return meta
  elseif cleanup ~= nil then
    cleanup()
  end

  error(meta)
end

irl.create_repl_on_current_window = function(ft, repl, bufnr, current_bufnr, opts)
  vim.api.nvim_win_set_buf(0, bufnr)
  -- TODO Move this out of this function
  -- Checking config should be done on an upper layer.
  -- This layer should be simpler
  opts = opts or {}
  if config.close_window_on_exit then
    opts.on_exit = function()
      local bufwinid = vim.fn.bufwinid(bufnr)
      while bufwinid ~= -1 do
        vim.api.nvim_win_close(bufwinid, true)
        bufwinid = vim.fn.bufwinid(bufnr)
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  else
    opts.on_exit = function() end
  end

  local cmd = repl.command
  if type(repl.command) == 'function' then
    local meta = {
      current_bufnr = current_bufnr,
    }
    cmd = repl.command(meta)
  end
  local job_id = vim.fn.termopen(cmd, opts)

  return {
    ft = ft,
    bufnr = bufnr,
    job = job_id,
    repldef = repl,
  }
end


irl.get_repl_def = function(ft)
  -- TODO should not call providers directly, but from config
  return irl.repl_definition[ft]
end

-- v.command[1] -> python.command[1] what is 1?
-- I think this starts the ipython/python instance

irl.repl_definition = setmetatable({}, {
    __index = function(tbl, key)
      local repl_definitions = require("iron.fts")[key]
      local repl_def
      for _, v in pairs(repl_definitions) do
        if vim.fn.executable(v.command[1]) == 1 then
          repl_def = v
          break
        end
      end
      if repl_def == nil then
        error("Failed to locate REPL executable, aborting")
      else
        rawset(tbl, key, repl_def)
        return repl_def
      end
    end
  })

