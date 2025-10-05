local M = {}

M.defaultConfig = {
  headless = true,
  marimo_opts = {
    runtime = {
      auto_reload = 'autorun',
      on_cell_change = 'autorun',
      watcher_on_save = 'autorun',
      default_auto_download = { html = false, ipynb = false },
    },
    save = {
      autosave = 'after_delay',
      autosave_delay = 1000,
    },
  },
  display_hl = { link = 'Pmenu' },
}

M.opts_to_nb_script_config = function(opts)
  local script_start = '# /// script'
  local runtime_line = '# [tool.marimo.runtime]'
  local save_line = '# [tool.marimo.save]'
  local script_end = '# ///'

  local runtime_opts = {}
  for k, v in pairs(opts.marimo_opts.runtime) do
    local _str = string.format('# %s = %s', tostring(k), tostring(v))
    table.insert(runtime_opts, _str)
  end

  local save_opts = {}
  for k, v in pairs(opts.marimo_opts.save) do
    local _str = string.format('# %s = %s', tostring(k), tostring(v))
    table.insert(save_opts, _str)
  end

  return {
    script_start,
    runtime_line,
    table.concat(runtime_opts, '\n'),
    save_line,
    table.concat(save_opts, '\n'),
    script_end,
  }
end

M.set_nb_config = function(opts, nb_bufnr)
  local script_config_lines = M.opts_to_nb_script_config(opts)
  vim.api.nvim_buf_set_lines(nb_bufnr, 0, 0, false, script_config_lines)
  return #script_config_lines + 1
end

M.remove_nb_config = function(nb_bufnr, config_end_line)
  vim.api.nvim_buf_set_lines(nb_bufnr, 0, config_end_line, false, {})
end

-- use defaultConfig if not setup
M.config = M.config or M.defaultConfig

return M
