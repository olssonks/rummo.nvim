# Notes

## Possible Architecture

### like iron.nvim

- Nearly everything is handled in Lua
- Small functions to start notebook and querying
- need method for running notebook/instance/server in the background

#### Pros

- Overall simplest structure wise
- Clear separation between the Neovim/Lua portions and Python portions

#### Cons

- Actual Python implementation difficult
  - probably need to set up a server running a notebook and another server/instance
    for querying the notebook
  - \*\* this may be the only route to take, even in pynvim

### pynvim / molten.nvim

- Use pynvim

#### Pros

- simpler Python/marimo implementation

#### Cons

- Handles nearly all Neovim/Lua in Python

### FASTapi / kulala.nvim

- run user marimo notebook embeded in marimo FASTapi (uvicorn) server notebook
- Communicate with server notebook with HTTP (or equivalent) queries in kulala.nvim

#### Pros

- Clear separation between Lua and Python
- marimo implementation straightforward
  - straightforward after understanding FASTapi
- Easy to extend
  - Just need additional HTTP queries and FASTapi function

#### Cons

- Need to work with 3 languages: Lua, Python, HTTP
