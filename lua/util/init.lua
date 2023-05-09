local M = {}
---A helper function to find configurations
---@param config_names string[] A list of config names you want to find (e.g. { ".stylua.toml", "stylua.toml" })
---@param default_dir string Default config directory (e.g. vim.fn.stdpath("config") .. "/lua/plugins/formatting/configs/")
---@return string config_dir The directory of first found configuration (project's config > default's config)
M.config_finder = function(config_names, default_dir)
  -- prevent that user not provide last seperator
  if string.sub(default_dir, string.len(default_dir)) ~= "/" then
    default_dir = default_dir .. "/"
  end

  local config_dir = ""

  -- search from project recursively
  for _, name in ipairs(config_names) do
    local found_root = require("lspconfig").util.root_pattern(name)(vim.loop.cwd())
    if found_root then
      config_dir = found_root .. "/" .. name
      if _G.IS_WINDOWS then
        config_dir = string.gsub(config_dir, "/", "\\\\")
      end
      return config_dir
    end
  end

  -- search from defalut_dir
  for _, name in ipairs(config_names) do
    if vim.loop.fs_stat(default_dir .. name) then
      config_dir = default_dir .. name
      if _G.IS_WINDOWS then
        config_dir = string.gsub(config_dir, "/", "\\\\")
      end
      return config_dir
    end
  end

  return config_dir
end

local _, null_ls_utils = pcall(require, "null-ls.utils")

local get_match_count = function(filepath, needle)
  local grep_cmd = "cat " .. filepath .. " | grep -c --max-count=1 " .. needle
  local grep_cmd_handle = io.popen(grep_cmd)
  if grep_cmd_handle then
    local grep_result = grep_cmd_handle:read("*a")
    grep_cmd_handle:close()
    -- trim whitespace
    local count_matches = string.gsub(grep_result, "^%s*(.-)%s*$", "%1")
    return tonumber(count_matches)
  end
  return 0
end

local is_eslint_project_result = nil
M.is_eslint_project = function(utils)
  if type(is_eslint_project_result) == "boolean" then
    return is_eslint_project_result
  end

  local has_eslintrc_js = utils.root_has_file({ ".eslintrc.js", ".eslintrc.json" })
  if has_eslintrc_js then
    is_eslint_project_result = true
    return true
  end

  local has_package_json = utils.root_has_file({ "package.json" })
  local package_json_has_eslint_config = false
  if has_package_json then
    local filepath = null_ls_utils.path.join({ null_ls_utils.get_root(), "package.json" })

    local count_matches = get_match_count(filepath, "eslintConfig")
    if count_matches >= 1 then
      package_json_has_eslint_config = true
    end
  end

  is_eslint_project_result = package_json_has_eslint_config
  return is_eslint_project_result
end

-- A project is an `eslint prettier` project if it's package.json includes
-- `eslint-plugin-prettier`
local is_eslint_prettier_project_result = nil
M.is_eslint_prettier_project = function(utils)
  if type(is_eslint_prettier_project_result) == "boolean" then
    return is_eslint_prettier_project_result
  end

  local has_package_json = utils.root_has_file({ "package.json" })
  if has_package_json then
    local filepath = null_ls_utils.path.join({ null_ls_utils.get_root(), "package.json" })

    local count_matches = get_match_count(filepath, "eslint-plugin-prettier")
    if count_matches >= 1 then
      is_eslint_prettier_project_result = true
      return is_eslint_prettier_project_result
    end
  end
  is_eslint_prettier_project_result = false
  return is_eslint_prettier_project_result
end

local is_prettier_project_result = nil
M.is_prettier_project = function(utils)
  if type(is_prettier_project_result) == "boolean" then
    return is_prettier_project_result
  end

  if utils.root_has_file({ ".prettierrc" }) then
    is_prettier_project_result = true
    return is_prettier_project_result
  end

  is_prettier_project_result = false
  return is_prettier_project_result
end

M.should_format_with_prettier = function(utils)
  if not is_prettier_project(utils) then
    return false
  end
  if is_eslint_project(utils) and is_eslint_prettier_project(utils) then
    return false
  end
  return true
end

return M
