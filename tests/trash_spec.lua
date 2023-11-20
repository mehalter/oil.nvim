require("plenary.async").tests.add_to_env()
local TmpDir = require("tests.tmpdir")
local test_util = require("tests.test_util")

---Get the raw list of filenames from an unmodified oil buffer
---@param bufnr? integer
---@return string[]
local function parse_entries(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].modified then
    error("parse_entries doesn't work on a modified oil buffer")
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  return vim.tbl_map(function(line)
    return line:match("^/%d+ +(.+)$")
  end, lines)
end

a.describe("freedesktop", function()
  local tmpdir
  local tmphome
  local home = vim.env.XDG_DATA_HOME
  a.before_each(function()
    require("oil.config").delete_to_trash = true
    tmpdir = TmpDir.new()
    tmphome = TmpDir.new()
    package.loaded["oil.adapters.trash"] = require("oil.adapters.trash.freedesktop")
    vim.env.XDG_DATA_HOME = tmphome.path
  end)
  a.after_each(function()
    vim.env.XDG_DATA_HOME = home
    if tmpdir then
      tmpdir:dispose()
    end
    if tmphome then
      tmphome:dispose()
    end
    test_util.reset_editor()
    package.loaded["oil.adapters.trash"] = nil
  end)

  a.it("files can be moved to the trash", function()
    tmpdir:create({ "a.txt", "foo/b.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("p", "x", true)
    test_util.actions.save()
    tmpdir:assert_not_exists("a.txt")
    tmpdir:assert_exists("foo/b.txt")
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  a.it("deleting a file moves it to trash", function()
    tmpdir:create({ "a.txt", "foo/b.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    tmpdir:assert_not_exists("a.txt")
    tmpdir:assert_exists("foo/b.txt")
    test_util.actions.open({ "--trash", tmpdir.path })
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  a.it("deleting a directory moves it to trash", function()
    tmpdir:create({ "a.txt", "foo/b.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("foo/")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    tmpdir:assert_not_exists("foo")
    tmpdir:assert_exists("a.txt")
    test_util.actions.open({ "--trash", tmpdir.path })
    assert.are.same({ "foo/" }, parse_entries(0))
  end)

  a.it("deleting a file from trash deletes it permanently", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.reload()
    tmpdir:assert_not_exists("a.txt")
    assert.are.same({}, parse_entries(0))
  end)

  a.it("cannot create files in the trash", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("onew_file.txt", "x", true)
    test_util.actions.save()
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  a.it("cannot rename files in the trash", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("0facwnew_name", "x", true)
    test_util.actions.save()
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  a.it("cannot copy files in the trash", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("yypp", "x", true)
    test_util.actions.save()
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  a.it("can restore files from trash", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.open({ tmpdir.path })
    vim.api.nvim_feedkeys("p", "x", true)
    test_util.actions.save()
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
    tmpdir:assert_fs({
      ["a.txt"] = "a.txt",
    })
  end)

  a.it("can have multiple files with the same name in trash", function()
    tmpdir:create({ "a.txt" })
    test_util.actions.open({ tmpdir.path })
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    tmpdir:create({ "a.txt" })
    test_util.actions.reload()
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.save()
    test_util.actions.open({ "--trash", tmpdir.path })
    assert.are.same({ "a.txt", "a.txt" }, parse_entries(0))
  end)
end)
