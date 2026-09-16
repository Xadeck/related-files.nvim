# related-files.nvim

A lightweight Neovim plugin that injects a `Snacks.picker.related_files()` picker for files related to the current buffer (such as `.cc`, `.h`, `_test.cc`, and `BUILD`), sorted by alternate buffer (`#`), recent visit history, and filetype-defined order.

## Requirements

- Neovim >= 0.10
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (specifically `Snacks.picker`)

If `snacks.nvim` is not installed or loaded, calling `require('related-files').setup()` (or `:RelatedFiles`) will emit an error notification (`vim.log.levels.ERROR`).

## Usage

Initialize the plugin and map `<leader>r` globally in `init.lua`:

```lua
require('related-files').setup()

vim.keymap.set('n', '<leader>r', function()
  Snacks.picker.related_files()
end, { desc = 'Pick related file', silent = true })
```

Then, in any `after/ftplugin/<filetype>.lua` (or autocommand), set `vim.b.related_files` on the buffer:

```lua
-- Example: after/ftplugin/cpp.lua
local buf_name = vim.api.nvim_buf_get_name(0)
if buf_name ~= '' then
  local dir = vim.fs.dirname(buf_name)
  local filename = vim.fs.basename(buf_name)
  local stem = filename:match '^(.*)_test%.[%w_]+$' or filename:match '^(.*)%.[%w_]+$' or filename

  vim.b.related_files = {
    { key = 'cc', file = vim.fs.joinpath(dir, stem .. '.cc') },
    { key = 'h', file = vim.fs.joinpath(dir, stem .. '.h') },
    { key = 'test', file = vim.fs.joinpath(dir, stem .. '_test.cc') },
    { key = 'build', file = vim.fs.joinpath(dir, 'BUILD') },
  }
end
```

### Formats for `vim.b.related_files`

1. **Ordered list (recommended):**
   ```lua
   vim.b.related_files = {
     { key = 'impl', file = '/path/to/foo.go' },
     { key = 'test', file = '/path/to/foo_test.go' },
   }
   ```
2. **Dictionary map:**
   ```lua
   vim.b.related_files = {
     impl = '/path/to/foo.go',
     test = '/path/to/foo_test.go',
   }
   -- Optional explicit ordering:
   vim.b.related_files_order = { impl = 1, test = 2 }
   ```

## Sorting Rules

When `:RelatedFiles` or `Snacks.picker.related_files()` is invoked, items are sorted by:
1. **Alternate buffer (`#`)** first (so pressing `<CR>` immediately jumps back to the alternate file).
2. **Most recently visited** files next.
3. **Default order** defined by the filetype.
4. **Current buffer** last.

## Running Tests

```bash
./tests/run_tests.sh
```
