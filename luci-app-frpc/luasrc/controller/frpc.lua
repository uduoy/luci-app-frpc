-- Copyright 2019 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the MIT License.

local http = require "luci.http"
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"

-- 查看配置文件所需（lazy require，需在 dispatcher 上下文中）
local e=require"nixio.fs"
local t=require"luci.i18n"

module("luci.controller.frpc", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/frpc") then
		return
	end

	entry({"admin", "services", "frpc"},
		firstchild(), _("Frpc")).dependent = false

	entry({"admin", "services", "frpc", "common"},
		cbi("frpc/common"), _("设置"), 1)

	entry({"admin", "services", "frpc", "rules"},
		arcombine(cbi("frpc/rules"), cbi("frpc/rule-detail")),
		_("规则"), 2).leaf = true

	entry({"admin", "services", "frpc", "servers"},
		arcombine(cbi("frpc/servers"), cbi("frpc/server-detail")),
		_("服务器"), 3).leaf = true

	entry({"admin", "services", "frpc", "status"}, call("action_status"))
	
	entry({"admin", "services", "frpc", "configuration"}, call("view_conf"), _("查看配置"), 5).leaf = true
	
	entry({"admin", "services", "frpc", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "services", "frpc", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "services", "frpc", "log"}, cbi("frpc/log"), _("查看日志"), 8).leaf = true
end


function action_status()
	local running = false

	local client = uci:get("frpc", "main", "client_file")
	if client and client ~= "" then
		local file_name = client:match(".*/([^/]+)$") or ""
		if file_name ~= "" then
			running = sys.call("pidof %s >/dev/null" % file_name) == 0
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		running = running
	})
end

function view_conf()
local e=e.readfile("/var/etc/frpc/frpc.main.toml")or""
local example = [[# ===== frp 官方配置示例 (frpc) =====
# 文档: https://gofrp.org/zh-cn/docs/

# [[连接服务端]]
serverAddr = "0.0.0.0"         # 服务端地址(必填)
serverPort = 7000               # 服务端端口(必填)

# [[认证]]
auth.method = "token"           # token / oidc
auth.token = "your_token"       # 鉴权令牌

# [[传输配置]]
[transport]
protocol = "tcp"                # tcp/kcp/quic/websocket
tcpMux = true                   # 启用TCP多路复用

# [[日志配置]]
[log]
to = "/var/log/frpc.log"       # 日志文件路径
level = "info"                  # trace/debug/info/warn/error
maxDays = 3

# ===== 代理示例 =====

# [[TCP代理 — 暴露本地SSH]]
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000

# [[HTTP代理 — 域名访问内网Web]]
# [[proxies]]
# name = "web"
# type = "http"
# localIP = "127.0.0.1"
# localPort = 80
# subdomain = "www"
# customDomains = ["your.domain.com"]

# [[安全TCP — 点对点P2P直连]]
# [[proxies]]
# name = "secret_ssh"
# type = "stcp"
# secretKey = "abc123"
# localIP = "127.0.0.1"
# localPort = 22
]]

local template = require "luci.template"
template.render("frpc/file_viewer",
{title=t.translate("Frpc - 查看配置文件"),content=e, example=example})
end

function get_log()
	luci.http.write(luci.sys.exec("cat /tmp/frpc_log_link.txt"))
end
function clear_log()
	luci.sys.call("true > /tmp/frpc_log_link.txt")
end
