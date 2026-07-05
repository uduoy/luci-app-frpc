-- Copyright 2024 superzjg@gmail.com
-- Licensed to the public under the MIT License.
--
-- toml_gen: 通用 UCI → TOML 转换引擎 (Schema 驱动)
-- 纯函数式：接收结构化配置表 + Schema，输出 TOML 文本
--
-- Config 表格式:
--   {
--     main   = { key = val, ... },   -- frpc 主 section (flat)
--     server = { key = val, ... },   -- 选中的服务端 section (flat)
--     rules  = {                      -- 规则列表
--       { key = val, ..., _extras = {"line1",...}, _plugin_extras = {"line1",...} },
--       ...
--     },
--   }

local nixio_fs = require "nixio.fs"
local toml_gen = {}

-- ===== 内部：值类型转换 =====

local function toml_value(val, typ)
	if val == nil or val == "" then
		return nil
	end
	if typ == "int" then
		local n = tonumber(val)
		return n and tostring(n) or ('"' .. val .. '"')
	end
	if typ == "bool" then
		return (val == "1" or val == "true") and "true" or "false"
	end
	if typ == "arr" then
		local parts = {}
		local cleaned = val:gsub(",", " ")
		-- 星号特殊处理
		if cleaned == "*" then
			cleaned = '"*"'
		else
			cleaned = cleaned:gsub("(%s+)%*(%s+)", '%1"*"%2'):gsub("^%*%s+", '"*" '):gsub("%s+%*$", ' "*"')
		end
		for item in cleaned:gmatch("%S+") do
			local keep = (item:sub(1,1) == '"' and item:sub(-1,-1) == '"') or
			             (item:sub(1,1) == "'" and item:sub(-1,-1) == "'")
			if not keep then
				item = item:gsub("['\"]", "")
				item = '"' .. item .. '"'
			end
			parts[#parts + 1] = item
		end
		return #parts == 0 and "[]" or ("[" .. table.concat(parts, ", ") .. "]")
	end
	-- 默认 string
	return '"' .. val .. '"'
end

-- ===== 内部：渲染引擎 =====

-- 渲染 global 字段
local function render_global(lines, config, fields, section_name)
	local src = config[section_name]
	if not src then return end
	for _, f in ipairs(fields) do
		local uci_key, toml_key, typ = f[1], f[2], f[3]
		if toml_key then  -- nil 表示跳过
			local v = src[uci_key]
			if v and v ~= "" then
				local tv = toml_value(v, typ)
				if tv then lines[#lines + 1] = toml_key .. " = " .. tv end
			end
		end
	end
end

-- 渲染子表 [header] （从 config.main 读取，key 带前缀）
local function render_subtables(lines, config, subs)
	for _, sub in ipairs(subs) do
		local prefix, header = sub.prefix, sub.header
		local fields, nested = sub.fields, sub.subtables
		local src = config.main
		if src then
			-- 检查是否有值
			local has = false
			local check = function(tbl)
				for _, f in ipairs(tbl) do
					if src[prefix .. "__" .. f[1]] then has = true; return end
				end
			end
			check(fields)
			if not has and nested then
				for _, ns in ipairs(nested) do
					check(ns.fields)
					if has then break end
				end
			end
			if has then
				lines[#lines + 1] = ""
				lines[#lines + 1] = "[" .. header .. "]"
				for _, f in ipairs(fields) do
					local v = src[prefix .. "__" .. f[1]]
					if v and v ~= "" then
						local tv = toml_value(v, f[3])
						if tv then lines[#lines + 1] = f[2] .. " = " .. tv end
					end
				end
				-- 嵌套子表展平写入
				if nested then
					for _, ns in ipairs(nested) do
						local nprefix = prefix .. "__" .. ns.prefix
						for _, f in ipairs(ns.fields) do
							local v = src[nprefix .. "__" .. f[1]]
							if v and v ~= "" then
								local tv = toml_value(v, f[3])
								if tv then lines[#lines + 1] = "  " .. f[2] .. " = " .. tv end
							end
						end
					end
				end
			end
		end
	end
end

-- 渲染数组类型 (rules → [[proxies]] / [[visitors]])
local function render_arrays(lines, config, arrays)
	local rules = config.rules
	if not rules then return end
	for _, arr in ipairs(arrays) do
		for _, rule in ipairs(rules) do
			local skip = arr.check_enabled and rule.enabled ~= "1"
			if not skip then
				local header = arr.header_fn and arr.header_fn(rule) or arr.uci_type
				lines[#lines + 1] = ""
				lines[#lines + 1] = "[[" .. header .. "]]"
				for _, f in ipairs(arr.fields) do
					local v = rule[f[1]]
					if v and v ~= "" then
						local tv = toml_value(v, f[3])
						if tv then lines[#lines + 1] = f[2] .. " = " .. tv end
					end
				end
				-- 插件子节 [proxies.plugin]
				if arr.plugin then
					local pt = rule[arr.plugin.type_key]
					if pt and pt ~= "" then
						lines[#lines + 1] = ""
						lines[#lines + 1] = "  [proxies.plugin]"
						for _, f in ipairs(arr.plugin.fields) do
							local v = rule[f[1]]
							if v and v ~= "" then
								local tv = toml_value(v, f[3])
								if tv then lines[#lines + 1] = "    " .. f[2] .. " = " .. tv end
							end
						end
						-- 插件额外选项
						local pe = rule["_plugin_extras"]
						if pe then
							for _, line in ipairs(pe) do
								lines[#lines + 1] = "    " .. line
							end
						end
					end
				end
				-- 额外选项
				local extras = rule["_extras"]
				local plugin_extras = rule["_plugin_extras"]
				if extras or plugin_extras then
					if plugin_extras then
						for _, line in ipairs(plugin_extras) do
							lines[#lines + 1] = "    " .. line
						end
					end
					if extras then
						for _, line in ipairs(extras) do
							lines[#lines + 1] = line
						end
					end
				end
			end
		end
	end
end

-- ===== 公开 API =====

--- 渲染配置表为 TOML 字符串
--- @param config table  配置表（main, server, rules）
--- @param schema table  Schema 定义
--- @return string       TOML 内容
function toml_gen.render(config, schema)
	local lines = {}
	lines[#lines + 1] = "# 由 LuCI 自动生成"
	lines[#lines + 1] = ""

	-- Global 字段（main 和 server 合并到顶层）
	if schema.global then
		render_global(lines, config, schema.global, "main")
	end
	if schema.server_global and config.server then
		render_global(lines, config, schema.server_global, "server")
	end

	-- 子表
	if schema.subtables then
		render_subtables(lines, config, schema.subtables)
	end

	-- main 额外选项
	if schema.main_extra_key and config.main and config.main[schema.main_extra_key] then
		local extras = config.main[schema.main_extra_key]
		if type(extras) == "table" then
			for _, line in ipairs(extras) do
				lines[#lines + 1] = line
			end
		else
			lines[#lines + 1] = extras
		end
	end

	-- 规则
	if schema.arrays then
		render_arrays(lines, config, schema.arrays)
	end

	return table.concat(lines, "\n") .. "\n"
end

--- 渲染并写入文件
--- @param config      table  配置表
--- @param schema      table  Schema
--- @param output_path string 输出路径
--- @return boolean, string|nil
function toml_gen.generate(config, schema, output_path)
	local toml = toml_gen.render(config, schema)

	-- 确保输出目录存在
	local dir = output_path:match("^(.*/)")
	if dir then
		if not nixio_fs.stat(dir) then
			local ok = nixio_fs.mkdir(dir)
			if not ok then
				return false, "无法创建目录: " .. dir
			end
		end
	end

	local ok, err = nixio_fs.writefile(output_path, toml)
	if not ok then
		return false, err or "写入文件失败: " .. output_path
	end
	return true
end

return toml_gen
