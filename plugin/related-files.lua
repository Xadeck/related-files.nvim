if vim.g.loaded_related_files then return end
vim.g.loaded_related_files = true

if pcall(require, 'snacks') then
  require('related-files').setup()
else
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      if pcall(require, 'snacks') then require('related-files').setup() end
    end,
  })
end

vim.api.nvim_create_user_command('RelatedFiles', function()
  local ok, snacks = pcall(require, 'snacks')
  snacks = (ok and snacks) or _G.Snacks
  if not snacks or not snacks.picker then
    vim.notify('snacks.nvim is required for related-files.nvim', vim.log.levels.ERROR)
    return
  end
  if not snacks.picker.related_files then require('related-files').setup() end
  snacks.picker.related_files()
end, { desc = 'Pick related file for current buffer' })

-- Automatically record buffer visits for related-files history sorting
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('RelatedFiles', { clear = true }),
  callback = function(ev) require('related-files').record_visit(ev.buf) end,
})
