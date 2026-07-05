--!/usr/bin/lua
-- frpc TOML 配置生成器 (Schema 驱动)
-- 调用: lua /usr/lib/lua/frpc/gen.lua [config_name] [output_path]
-- 默认: lua /usr/lib/lua/frpc/gen.lua frpc /var/etc/frpc/frpc.main.toml

local config_name = arg[1] or "frpc"
local output_path = arg[2] or ("/var/etc/" .. config_name .. "/" .. config_name .. ".main.toml")
local uci_path = "/etc/config/" .. config_name

local frpc = require "luci.tools.toml_gen_frpc"
local gen = require "luci.tools.toml_gen"

local config = frpc.read_uci(uci_path)
if not config then
	io.stderr:write("ERROR: 无法读取 " .. uci_path .. "\n")
	os.exit(1)
end

-- 检查 main 是否启用
if config.main.enabled ~= "1" then os.exit(0) end

-- 查找引用的 server
local server_ref = config.main.server
if server_ref and server_ref ~= "" then
	for _, svr in ipairs(config.servers) do
		if svr[".name"] == server_ref then
			config.server = svr
			break
		end
	end
end

-- 验证必要字段
if not config.server then
	io.stderr:write("ERROR: server 未配置\n")
	os.exit(1)
end

local ok, err = gen.generate(config, frpc.schema, output_path)
if not ok then
	io.stderr:write("ERROR: " .. (err or "生成失败") .. "\n")
	os.exit(1)
end
os.exit(0)
