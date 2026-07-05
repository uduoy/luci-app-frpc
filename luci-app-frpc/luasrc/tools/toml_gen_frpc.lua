-- Copyright 2024 superzjg@gmail.com
-- Licensed to the public under the MIT License.
--
-- frpc 的 Schema 定义 + UCI 读取器

local nixio_fs = require "nixio.fs"

local frpc = {}

-- ===== UCI 读取器 =====

-- 解析 UCI 配置文件为结构化配置表
-- @param uci_path  UCI 配置文件路径 (默认 /etc/config/frpc)
-- @return table    { main = {...}, servers = {{...}}, rules = {...} }
function frpc.read_uci(uci_path)
	uci_path = uci_path or "/etc/config/frpc"
	local content = nixio_fs.readfile(uci_path)
	if not content then
		return nil, "无法读取: " .. uci_path
	end

	local config = { main = {}, servers = {}, rules = {} }
	local current_section = nil

	local function new_section()
		local s = {}
		-- setmetatable for list handling
		return s
	end

	for line in content:gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed == "" or trimmed:sub(1,1) == "#" then
			-- 跳过注释和空行
		else
			-- config 'type' 'name' 或 config type name
			local stype, sname = trimmed:match("^config%s+['\"]([^'\"]+)['\"]%s+['\"]([^'\"]+)['\"]")
			if not stype then
				stype, sname = trimmed:match("^config%s+(%S+)%s+(%S+)")
			end
			if not stype then
				stype = trimmed:match("^config%s+['\"]([^'\"]+)['\"]")
				if not stype then
					stype = trimmed:match("^config%s+(%S+)")
				end
			end

			if stype then
				stype = stype:gsub("^['\"]", ""):gsub("['\"]$", "")
				if sname then sname = sname:gsub("^['\"]", ""):gsub("['\"]$", "") end

				if stype == "frpc" then
					current_section = config.main
					config.main[".name"] = sname or "main"
				elseif stype == "server" then
					current_section = new_section()
					current_section[".name"] = sname or "server_" .. tostring(#config.servers + 1)
					table.insert(config.servers, current_section)
				elseif stype == "rule" then
					current_section = new_section()
					current_section[".name"] = sname or "rule_" .. tostring(#config.rules + 1)
					current_section["enabled"] = "1"
					table.insert(config.rules, current_section)
				else
					current_section = nil
				end
			elseif current_section then
				-- option key 'value'
				local ok, key, val = trimmed:match("^%s*(option)%s+(%S+)%s+['\"]([^'\"]*)['\"]")
				if not ok then
					ok, key, val = trimmed:match("^%s*(option)%s+(%S+)%s+(%S+)")
				end
				if ok then
					if val then val = val:gsub("^['\"]", ""):gsub("['\"]$", "") end
					current_section[key] = val
				else
					-- list key 'value'
					local lk, lv = trimmed:match("^%s*list%s+(%S+)%s+['\"]([^'\"]*)['\"]")
					if not lk then
						lk, lv = trimmed:match("^%s*list%s+(%S+)%s+(%S+)")
					end
					if lk then
						if lv then lv = lv:gsub("^['\"]", ""):gsub("['\"]$", "") end
						if not current_section["_lists"] then current_section["_lists"] = {} end
						local lst = current_section["_lists"]
						if not lst[lk] then lst[lk] = {} end
						table.insert(lst[lk], lv or "")
					end
				end
			end
		end
	end

	-- 处理列表值转换为 _extras
	for _, rule in ipairs(config.rules) do
		local lists = rule["_lists"]
		if lists then
			rule["_extras"] = lists["extra_options"]
			rule["_plugin_extras"] = lists["extra_options_plugin"]
			rule["requestHeaders__set"] = lists["requestHeaders__set"]
			rule["responseHeaders__set"] = lists["responseHeaders__set"]
			rule["healthCheck__httpHeaders"] = lists["healthCheck__httpHeaders"]
			rule["metadatas"] = lists["metadatas"]
			rule["annotations"] = lists["annotations"]
			rule["_lists"] = nil
		end
	end
	if config.main and config.main["_lists"] then
		local lists = config.main["_lists"]
		config.main["com_extra_options"] = lists["com_extra_options"]
		config.main["start"] = lists["start"]
		config.main["metadatas"] = lists["metadatas"]
		config.main["_lists"] = nil
	end

	return config
end

-- ===== Schema 定义 =====

-- 映射规则: { UCI_key, TOML_key, 类型 }
-- 类型: "string" / "int" / "bool" / "arr"
-- TOML_key = nil 表示不写入 TOML

frpc.schema = {
	-- 主配置顶层字段 (来自 frpc.main)
	global = {
		{ "enabled",             nil,                nil },
		{ "user",                "user",              "string" },
		{ "serverAddr",          "serverAddr",        "string" },
		{ "serverPort",          "serverPort",        "int" },
		{ "natHoleStunServer",   "natHoleStunServer", "string" },
		{ "dnsServer",           "dnsServer",         "string" },
		{ "loginFailExit",       "loginFailExit",     "bool" },
		{ "udpPacketSize",       "udpPacketSize",     "int" },
	},

	-- 服务端字段合并到顶层 (来自 frpc server)
	server_global = {
		{ "serverAddr",          "serverAddr",          "string" },
		{ "serverPort",          "serverPort",          "int" },
		{ "auth__method",        "auth.method",         "string" },
		{ "auth__token",         "auth.token",          "string" },
		{ "transport__tcpMux",   "transport.tcpMux",    "bool" },
		{ "transport__tcpMuxKeepaliveInterval", "transport.tcpMuxKeepaliveInterval", "int" },
	},

	-- 子表: [section_header]
	subtables = {
		{ prefix = "log",        header = "log",        fields = {
			{ "to",                "to",                "string" },
			{ "level",             "level",             "string" },
			{ "maxDays",           "maxDays",           "int" },
			{ "disablePrintColor", "disablePrintColor", "bool" },
		}},
		{ prefix = "transport",  header = "transport",  fields = {
			{ "poolCount",                "poolCount",           "int" },
			{ "protocol",                 "protocol",            "string" },
			{ "wireProtocol",             "wireProtocol",        "string" },
			{ "connectServerLocalIP",     "connectServerLocalIP", "string" },
			{ "dialServerTimeout",        "dialServerTimeout",   "int" },
			{ "dialServerKeepalive",      "dialServerKeepalive", "int" },
			{ "proxyURL",                "proxyURL",            "string" },
			{ "heartbeatInterval",       "heartbeatInterval",   "int" },
			{ "heartbeatTimeout",        "heartbeatTimeout",    "int" },
		}, subtables = {
			{ prefix = "quic", fields = {
				{ "keepalivePeriod",     "keepalivePeriod",     "int" },
				{ "maxIdleTimeout",      "maxIdleTimeout",      "int" },
				{ "maxIncomingStreams",  "maxIncomingStreams",  "int" },
			}},
			{ prefix = "tls",  fields = {
				{ "enable",                      "enable",                      "bool" },
				{ "disableCustomTLSFirstByte",  "disableCustomTLSFirstByte",  "bool" },
				{ "certFile",                    "certFile",                    "string" },
				{ "keyFile",                     "keyFile",                     "string" },
				{ "trustedCaFile",               "trustedCaFile",               "string" },
				{ "serverName",                  "serverName",                  "string" },
			}},
		}},
		{ prefix = "webServer",  header = "webServer",  fields = {
			{ "addr",              "addr",              "string" },
			{ "port",              "port",              "int" },
			{ "user",              "user",              "string" },
			{ "password",          "password",          "string" },
			{ "assetsDir",         "assetsDir",         "string" },
			{ "pprofEnable",       "pprofEnable",       "bool" },
		}},
	},

	-- main 额外选项
	main_extra_key = "com_extra_options",

	-- 数组类型 (规则)
	arrays = {{
		uci_type = "rule",
		check_enabled = true,
		header_fn = function(rule)
			return rule["visitor"] == "1" and "visitors" or "proxies"
		end,
		fields = {
			{ "name",              "name",              "string" },
			{ "type",              "type",              "string" },
			{ "secretKey",        "secretKey",         "string" },
			{ "multiplexer",      "multiplexer",       "string" },
			{ "localIP",          "localIP",           "string" },
			{ "localPort",        "localPort",         "int" },
			{ "remotePort",       "remotePort",        "int" },
			{ "allowUsers",       "allowUsers",        "arr" },
			{ "transport__bandwidthLimit",     "transport.bandwidthLimit",     "string" },
			{ "transport__bandwidthLimitMode", "transport.bandwidthLimitMode", "string" },
			{ "transport__useEncryption",      "transport.useEncryption",      "bool" },
			{ "transport__useCompression",     "transport.useCompression",     "bool" },
			{ "transport__proxyProtocolVersion", "transport.proxyProtocolVersion", "string" },
			{ "loadBalancer__group",           "loadBalancer.group",           "string" },
			{ "loadBalancer__groupKey",        "loadBalancer.groupKey",        "string" },
			{ "healthCheck__type",             "healthCheck.type",             "string" },
			{ "healthCheck__path",             "healthCheck.path",             "string" },
			{ "healthCheck__timeoutSeconds",   "healthCheck.timeoutSeconds",   "int" },
			{ "healthCheck__maxFailed",        "healthCheck.maxFailed",        "int" },
			{ "healthCheck__intervalSeconds",  "healthCheck.intervalSeconds",  "int" },
			{ "routeByHTTPUser",   "routeByHTTPUser",   "string" },
			{ "httpUser",          "httpUser",          "string" },
			{ "httpPassword",     "httpPassword",      "string" },
			{ "subdomain",        "subdomain",         "string" },
			{ "customDomains",    "customDomains",     "arr" },
			{ "locations",        "locations",         "arr" },
			{ "hostHeaderRewrite", "hostHeaderRewrite", "string" },
			-- Visitor 字段
			{ "serverName",       "serverName",        "string" },
			{ "serverUser",       "serverUser",        "string" },
			{ "bindAddr",         "bindAddr",          "string" },
			{ "bindPort",         "bindPort",          "int" },
			{ "keepTunnelOpen",   "keepTunnelOpen",    "bool" },
			{ "maxRetriesAnHour", "maxRetriesAnHour",  "int" },
			{ "minRetryInterval", "minRetryInterval",  "int" },
			{ "fallbackTo",       "fallbackTo",        "string" },
			{ "fallbackTimeoutMs","fallbackTimeoutMs", "int" },
			{ "natTraversal__disableAssistedAddrs", "natTraversal.disableAssistedAddrs", "bool" },
		},
		plugin = {
			type_key = "PlUgIn_type",
			fields = {
				{ "PlUgIn_type",             "type",              "string" },
				{ "PlUgIn_unixPath",         "unixPath",          "string" },
				{ "PlUgIn_username",         "username",          "string" },
				{ "PlUgIn_password",         "password",          "string" },
				{ "PlUgIn_localPath",        "localPath",         "string" },
				{ "PlUgIn_stripPrefix",      "stripPrefix",       "string" },
				{ "PlUgIn_httpUser",         "httpUser",          "string" },
				{ "PlUgIn_httpPassword",     "httpPassword",      "string" },
				{ "PlUgIn_localAddr",        "localAddr",         "string" },
				{ "PlUgIn_crtPath",          "crtPath",           "string" },
				{ "PlUgIn_keyPath",          "keyPath",           "string" },
				{ "PlUgIn_hostHeaderRewrite","hostHeaderRewrite",  "string" },
			},
		},
	}},
}

return frpc
