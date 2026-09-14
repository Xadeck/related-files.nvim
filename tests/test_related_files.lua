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
  -- Current file ('cc') is placed at the bottom; others follow their list order
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
  -- test is alternate buffer (#), build was visited before test, h was never visited, cc is current
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

print(string.format('\nResults: %d/%d passed, %d failed\n', passed_tests, total_tests, failed_tests))
if failed_tests > 0 then
  vim.cmd 'cquit 1'
else
  vim.cmd 'qall!'
end
