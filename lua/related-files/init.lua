local M = {}

local history = {}
local last_time = 0

local function next_timestamp()
  local now = vim.uv.now()
  if now <= last_time then now = last_time + 1 end
  last_time = now
  return now
end

--- Record a visit for the given buffer (defaults to current buffer).
---@param bufnr? integer
function M.record_visit(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  if path ~= '' then history[path] = next_timestamp() end
end

--- Reset visit history (useful for testing).
function M.clear_history()
  history = {}
  last_time = 0
end

--- Build and return the sorted list of related file entries for a buffer.
---@param bufnr? integer
---@return table[]
function M.get_sorted(bufnr)
  bufnr = bufnr or 0
  local related = vim.b[bufnr].related_files
  if not related or vim.tbl_isempty(related) then return {} end

  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local alt_buf = vim.fn.bufnr '#'
  local alt_file = (alt_buf ~= -1) and vim.api.nvim_buf_get_name(alt_buf) or ''

  local list = {}
  if vim.islist(related) then
    for i, item in ipairs(related) do
      local key = item.key or item[1] or tostring(i)
      local file = item.file or item.path or item[2]
      if file then
        table.insert(list, {
          key = key,
          file = file,
          is_current = (file == current_file),
          is_alt = (file == alt_file and file ~= current_file),
          time = history[file] or 0,
          order = item.order or i,
        })
      end
    end
  else
    local default_order = vim.b[bufnr].related_files_order or {}
    for key, val in pairs(related) do
      local file = type(val) == 'table' and (val.file or val.path or val[1]) or val
      local order = (type(val) == 'table' and val.order) or default_order[key] or 99
      if file then
        table.insert(list, {
          key = key,
          file = file,
          is_current = (file == current_file),
          is_alt = (file == alt_file and file ~= current_file),
          time = history[file] or 0,
          order = order,
        })
      end
    end
  end

  table.sort(list, function(a, b)
    if a.is_current ~= b.is_current then return b.is_current end
    if a.is_alt ~= b.is_alt then return a.is_alt end
    if a.time ~= b.time then return a.time > b.time end
    if a.order ~= b.order then return a.order < b.order end
    return tostring(a.key) < tostring(b.key)
  end)

  return list
end

--- Open the related files picker for the current buffer.
function M.pick()
  local list = M.get_sorted(0)
  if #list == 0 then
    vim.notify('No related files found for current buffer', vim.log.levels.WARN)
    return
  end

  M.record_visit(0)

  local width = 5
  for _, entry in ipairs(list) do
    width = math.max(width, #tostring(entry.key))
  end

  local items = {}
  for _, entry in ipairs(list) do
    table.insert(items, {
      text = string.format('%-' .. width .. 's %s', entry.key, vim.fs.basename(entry.file)),
      file = entry.file,
    })
  end

  Snacks.picker.pick {
    title = 'Related Files',
    items = items,
    layout = { preset = 'dropdown', preview = false },
    confirm = function(picker, item)
      picker:close()
      if item and item.file then
        vim.cmd.edit(item.file)
        M.record_visit(0)
      end
    end,
  }
end

return M
