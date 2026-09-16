-- Standalone Unit Test Suite for related-files.nvim
-- Run with: nvim --headless -u NONE -c "luafile tests/test_related_files.lua" -c "q"

local script_dir = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local root_dir = vim.uv.fs_realpath(vim.fs.dirname(script_dir)) or vim.fs.dirname(script_dir)
package.path = root_dir .. '/lua/?.lua;' .. root_dir .. '/lua/?/init.lua;' .. package.path
vim.opt.rtp:append(root_dir)

local related_files = require 'related-files'

local total_tests = 0
local passed_tests = 0
local failed_tests = 0

local function test(name, fn)
  total_tests = total_tests + 1
  io.write(string.format('  Testing: %-55s ... ', name))
  local ok, err = pcall(fn)
  if ok then
    passed_tests = passed_tests + 1
    io.write '\27[32m✓ PASS\27[0m\n'
  else
    failed_tests = failed_tests + 1
    io.write '\27[31m✗ FAIL\27[0m\n'
    io.write('    Error: ' .. tostring(err) .. '\n')
  end
end

local function assert_eq(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error(
      string.format(
        '%s\nExpected: %s\nActual:   %s',
        msg or 'Assertion failed',
        vim.inspect(expected),
        vim.inspect(actual)
      )
    )
  end
end

print '\nRunning related-files.nvim test suite...'

test('Does not expose direct pick() function', function()
  assert_eq(related_files.pick, nil)
  assert_eq(type(related_files.setup), 'function')
  assert_eq(type(related_files.finder), 'function')
end)

test('Returns empty list when vim.b.related_files is unset', function()
  related_files.clear_history()
  vim.cmd 'enew!'
  vim.b.related_files = nil
  local sorted = related_files.get_sorted(0)
  assert_eq(#sorted, 0)
end)

test('Sorts list format by default order with current file last', function()
  related_files.clear_history()
  vim.cmd 'edit! /tmp/foo.cc'
  vim.b.related_files = {
    { key = 'cc', file = '/tmp/foo.cc' },
    { key = 'h', file = '/tmp/foo.h' },
    { key = 'test', file = '/tmp/foo_test.cc' },
    { key = 'build', file = '/tmp/BUILD' },
  }

  local sorted = related_files.get_sorted(0)
  local keys = vim.tbl_map(function(x) return x.key end, sorted)
  assert_eq(keys, { 'h', 'test', 'build', 'cc' })
end)

test('Prioritizes alternate buffer (#) at the top', function()
  related_files.clear_history()
  vim.cmd 'edit! /tmp/foo.h'
  vim.cmd 'edit! /tmp/foo.cc'
  vim.b.related_files = {
    { key = 'cc', file = '/tmp/foo.cc' },
    { key = 'h', file = '/tmp/foo.h' },
    { key = 'test', file = '/tmp/foo_test.cc' },
    { key = 'build', file = '/tmp/BUILD' },
  }

  local sorted = related_files.get_sorted(0)
  local keys = vim.tbl_map(function(x) return x.key end, sorted)
  assert_eq(keys[1], 'h')
  assert_eq(keys[#keys], 'cc')
end)

test('Prioritizes recently visited files over unvisited files', function()
  related_files.clear_history()
  vim.cmd 'edit! /tmp/BUILD'
  related_files.record_visit(0)

  vim.cmd 'edit! /tmp/foo_test.cc'
  related_files.record_visit(0)

  vim.cmd 'edit! /tmp/foo.cc'
  related_files.record_visit(0)

  vim.b.related_files = {
    { key = 'cc', file = '/tmp/foo.cc' },
    { key = 'h', file = '/tmp/foo.h' },
    { key = 'test', file = '/tmp/foo_test.cc' },
    { key = 'build', file = '/tmp/BUILD' },
  }

  local sorted = related_files.get_sorted(0)
  local keys = vim.tbl_map(function(x) return x.key end, sorted)
  assert_eq(keys, { 'test', 'build', 'h', 'cc' })
end)

test('Supports dictionary format with related_files_order', function()
  related_files.clear_history()
  vim.cmd 'edit! /tmp/unrelated.txt'
  vim.cmd 'edit! /tmp/foo.cc'
  vim.b.related_files = {
    cc = '/tmp/foo.cc',
    h = '/tmp/foo.h',
    test = '/tmp/foo_test.cc',
    build = '/tmp/BUILD',
  }
  vim.b.related_files_order = { cc = 1, h = 2, test = 3, build = 4 }

  local sorted = related_files.get_sorted(0)
  local keys = vim.tbl_map(function(x) return x.key end, sorted)
  assert_eq(keys, { 'h', 'test', 'build', 'cc' })
end)

test('Notifies error when snacks.nvim is missing in setup()', function()
  local notified_msg = nil
  local notified_level = nil
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    notified_msg = msg
    notified_level = level
  end

  local orig_snacks = _G.Snacks
  local orig_loaded = package.loaded['snacks']
  local orig_sources = package.loaded['snacks.picker.config.sources']
  _G.Snacks = nil
  package.loaded['snacks'] = nil
  package.loaded['snacks.picker.config.sources'] = nil

  related_files.setup()

  _G.Snacks = orig_snacks
  package.loaded['snacks'] = orig_snacks
  package.loaded['snacks.picker.config.sources'] = orig_sources
  vim.notify = orig_notify

  assert_eq(notified_level, vim.log.levels.ERROR)
  assert_eq(notified_msg, 'snacks.nvim is required for related-files.nvim')
end)

test('Injects Snacks.picker.related_files on setup()', function()
  local fake_sources = {}
  local picked_source = nil
  local fake_snacks = {
    picker = {
      pick = function(source) picked_source = source end,
    },
  }
  package.loaded['snacks'] = fake_snacks
  package.loaded['snacks.picker.config.sources'] = fake_sources
  _G.Snacks = fake_snacks

  related_files.setup()
  assert_eq(type(fake_sources.related_files), 'table')
  assert_eq(type(fake_snacks.picker.related_files), 'function')

  vim.cmd 'edit! /tmp/foo.cc'
  vim.b.related_files = {
    { key = 'cc', file = '/tmp/foo.cc' },
    { key = 'h', file = '/tmp/foo.h' },
  }
  fake_snacks.picker.related_files()
  assert_eq(picked_source, 'related_files')
end)

print(string.format('\nResults: %d/%d passed, %d failed\n', passed_tests, total_tests, failed_tests))
if failed_tests > 0 then
  vim.cmd 'cquit 1'
else
  vim.cmd 'qall!'
end
