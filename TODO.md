# Todo

- Left off fixing display extmarks to return end_row and end_col

## rummo.lua

### cell.lua

- [x ] Define `Cell` class
- [ ] Define basic cell methods
  - [x] initialize `Cell`s from notebook (`init_nb_cells`)
  - [x ] Rename cells to `rummo` style (`init_cell_names`)
  - [x ] update cells after execution (`refresh_nb_cells` and `update_cell`)
  - [x ] tree sitter query notebook (`query_notebook`)
  - [x ] tree sitter query json output file (`query_json`)
- [ ] Move tree sitter queries to out of lua file (queries directory?)

### config.lua

- [ ] Define all config parameters (evolving)
- [ ] Methods for setting parameters

### core.lua

- [ ] Explicit run command from neovim to python (possible ?)
  - this probably needs to use the server/fast api
    - something similar to this
      [github](https://github.com/marimo-team/youtube-material/blob/main/examples/serv.py)
      [youtube](https://www.youtube.com/watch?v=MvMKYYw3qR4)
- [ ] Infer python environment to run notebook (conda, pip, uv) - Have an
      environment list popup to select from - easy to list conda - have input to
      pass pip venv
- [ ] need an attribute for toggling display output
  - could live in runner; config probably better if it makes sense

### display.lua

- [ ] Define display window based on output size
- [ ] Toggle output hiding window
- [ ] Enter/exit output window
- [ ] Window shifts cells down instead of floating (like `image.nvim`) - can use
      extmarks for cells in notebook - maybe temporary extmark for shifting text
      back up - can have a single extmark and update it as needed - this mark can
      be in runner - can use `nvim_buf_attach` to set events by call back

### image.lua

- [ ] Define `Image` class; will held in Display (i.e. `Display.Image...`)
- [ ] Define basic functions
  - [ ] Initialize and add to cell

### init.lua
