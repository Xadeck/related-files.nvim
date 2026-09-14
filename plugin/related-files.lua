if vim.g.loaded_related_files then return end
vim.g.loaded_related_files = true

vim.api.nvim_create_user_command(
  'RelatedFiles',
  function() require('related-files').pick() end,
  { desc = 'Pick related file for current buffer' }
)

-- Automatically record buffer visits for related-files history sorting
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('RelatedFiles', { clear = true }),
  callback = function(ev) require('related-files').record_visit(ev.buf) end,
})
