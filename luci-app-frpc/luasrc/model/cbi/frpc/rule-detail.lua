-- Copyright 2019 Xingwang Liao <kuoruan@gmail.com> #modify by superzjg@gmail.com 20240811
-- Licensed to the public under the MIT License.

local dsp = require "luci.dispatcher"

local m, s, o

local sid = arg[1]

m = Map("frpc", "%s - %s" % { translate("Frpc"), translate("编辑代理规则") })
m.redirect = dsp.build_url("admin/services/frpc/rules")

if m.uci:get("frpc", sid) ~= "rule" then
	luci.http.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "rule")
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("启用"))

o = s:option(Value, "name", translate("代理名称"), translate("规则的名称不要重复"))
o:value("ssh")
o:value("web")
o:value("dns")
o:value("plugin_")
o:value("secret_")
o:value("p2p_")
o.rmempty = false

o = s:option(Value, "type", translate("类型"))
o:value("tcp", "TCP — 基础TCP端口转发")
o:value("udp", "UDP — UDP端口转发")
o:value("http", "HTTP — HTTP协议代理，支持域名/子域名/路径路由")
o:value("https", "HTTPS — HTTPS协议代理，支持域名路由")
o:value("stcp", "STCP — 安全TCP，需预共享密钥(secretKey)")
o:value("xtcp", "XTCP — P2P直连穿透，需STUN服务器")
o:value("sudp", "SUDP — 安全UDP，需预共享密钥")
o:value("tcpmux", "TCPMUX — TCP多路复用，一个端口代理多个服务")

o = s:option(Value, "PlUgIn_type", translate("插件类型"), translate("插件可对代理流量做协议转换。需与代理类型相匹配：tcp/udp适用unix_domain_socket/http_proxy/socks5/static_file；https适用https2http/https2https/tls2raw"))
o:value("", translate("（空）"))
o:value("unix_domain_socket")
o:value("http_proxy")
o:value("socks5")
o:value("static_file")
o:value("https2http")
o:value("https2https")
o:value("http2https")
o:value("http2http")
o:value("tls2raw")

o = s:option(Value, "unixPath", "%s - %s" % { translate("插件"), translate("Unix域套接字地址") })
o.datatype = "file"
o:depends("PlUgIn_type", "unix_domain_socket")

o = s:option(Value, "username", "%s - %s" % { translate("插件"), translate("用户") })
o:depends("PlUgIn_type", "socks5")

o = s:option(Value, "password", "%s - %s" % { translate("插件"), translate("密码") })
o:depends("PlUgIn_type", "socks5")

o = s:option(Value, "localPath", "%s - %s" % { translate("插件"), translate("本地路径") })
o:depends("PlUgIn_type", "static_file")

o = s:option(Value, "stripPrefix", "%s - %s" % { translate("插件"), translate("去除前缀") })
o:depends("PlUgIn_type", "static_file")

o = s:option(Value, "PlUgIn_httpUser", "%s - %s" % { translate("插件"), translate("HTTP 用户") })
o:depends("PlUgIn_type", "http_proxy")
o:depends("PlUgIn_type", "static_file")

o = s:option(Value, "PlUgIn_httpPassword", "%s - %s" % { translate("插件"), translate("HTTP 密码") })
o:depends("PlUgIn_type", "http_proxy")
o:depends("PlUgIn_type", "static_file")

o = s:option(Value, "localAddr", "%s - %s" % { translate("插件"), translate("本地地址") })
o:depends("PlUgIn_type", "https2http")
o:depends("PlUgIn_type", "https2https")
o:depends("PlUgIn_type", "http2https")
o:depends("PlUgIn_type", "http2http")
o:depends("PlUgIn_type", "tls2raw")

o = s:option(Value, "crtPath", "%s - %s" % { translate("插件"), translate("证书路径") })
o.datatype = "file"
o:depends("PlUgIn_type", "https2http")
o:depends("PlUgIn_type", "https2https")
o:depends("PlUgIn_type", "tls2raw")

o = s:option(Value, "keyPath", "%s - %s" % { translate("插件"), translate("私钥路径") })
o.datatype = "file"
o:depends("PlUgIn_type", "https2http")
o:depends("PlUgIn_type", "https2https")
o:depends("PlUgIn_type", "tls2raw")

o = s:option(Value, "PlUgIn_hostHeaderRewrite", "%s - %s" % { translate("插件"), translate("主机头重写") })
o:depends("PlUgIn_type", "https2http")
o:depends("PlUgIn_type", "https2https")
o:depends("PlUgIn_type", "http2https")
o:depends("PlUgIn_type", "http2http")

o = s:option(Value, "secretKey", translate("安全密钥sk"))
o.password = true
o:depends("type", "stcp")
o:depends("type", "xtcp")
o:depends("type", "sudp")

o = s:option(Value, "multiplexer", translate("复用器类型"))
o:value("httpconnect")
o:depends("type", "tcpmux")

o = s:option(Flag, "visitor", translate("作为访客"))
o:depends("type", "stcp")
o:depends("type", "xtcp")
o:depends("type", "sudp")

o = s:option(Value, "localIP", translate("本地 IP"))
o.datatype = "host"
o:depends({visitor="", PlUgIn_type=""})

o = s:option(Value, "localPort", translate("本地端口"))
o:depends({visitor="", PlUgIn_type=""})

o = s:option(Value, "remotePort", translate("远程端口"))
o:depends("type", "tcp")
o:depends("type", "udp")

o = s:option(Value, "serverName", translate("服务端名称"))
o:depends("visitor", "1")

o = s:option(Value, "serverUser", translate("服务端用户"), translate("要访问的 proxy 所属的用户名, 若为空，默认为当前用户"))
o:depends("visitor", "1")

o = s:option(Value, "bindAddr", translate("绑定地址"))
o.datatype = "host"
o:depends("visitor", "1")

o = s:option(Value, "bindPort", translate("绑定端口"))
o:depends("visitor", "1")
o.datatype = "integer"

o = s:option(Value, "allowUsers", translate("允许的访客用户"), translate("若留空，默认只允许同一用户下的 visitor 访问；若指定具体用户，用英文逗号隔开，例如简写为：user1, user2 即可，后台会转换格式"))
o:value("", translate("（空）"))
o:value("*", translate("所有用户"))
o:depends({visitor="", type="xtcp"})
o:depends({visitor="", type="stcp"})
o:depends({visitor="", type="sudp"})

o = s:option(Flag, "keepTunnelOpen", translate("保持隧道打开"), translate("定期检查隧道状态并尝试保持打开。默认关闭"))
o.enabled = "true"
o.disabled = ""
o:depends({visitor="1", type="xtcp"})

o = s:option(Value, "maxRetriesAnHour", translate("每小时尝试次数"))
o:depends("keepTunnelOpen", "true")
o.placeholder = "8"
o.datatype = "integer"

o = s:option(Value, "minRetryInterval", translate("最小重试间隔秒数"))
o:depends("keepTunnelOpen", "true")
o.placeholder = "90"
o.datatype = "integer"

o = s:option(Value, "fallbackTo", translate("回退访客"), translate("v0.60+: 穿透失败时回退到的备选访客名称"))
o:depends("visitor", "1")

o = s:option(Value, "fallbackTimeoutMs", translate("回退超时(毫秒)"), translate("回退超时时间"))
o:depends({visitor="1", fallbackTo="", fallbackTo=nil})
o:depends("fallbackTo", "")
o.datatype = "integer"
o.placeholder = "1000"

o = s:option(Flag, "natTraversal__disableAssistedAddrs", translate("禁用穿透辅助地址"), translate("v0.60+: 禁用NAT穿透时发送本地辅助地址，有助于在复杂网络环境中减少不必要的地址信息泄露"))
o:depends("visitor", "1")
o:depends("type", "stcp")
o:depends("type", "xtcp")
o.enabled = "true"
o.disabled = ""

o = s:option(Value, "httpUser", translate("HTTP 用户"))
o:depends("type", "http")
o:depends("type", "tcpmux")

o = s:option(Value, "httpPassword", translate("HTTP 密码"))
o:depends("type", "http")
o:depends("type", "tcpmux")

o = s:option(Value, "subdomain", translate("子域名"))
o:depends("type", "http")
o:depends("type", "https")
o:depends("type", "tcpmux")

o = s:option(Value, "customDomains", translate("自定义域名列表"))
o:depends("type", "http")
o:depends("type", "https")
o:depends("type", "tcpmux")

o = s:option(Value, "locations", translate("location 配置"), translate("指定具体路径，用英文逗号隔开，例如简写为：/, /pic 即可，后台会转换格式"))
o:depends("type", "http")

o = s:option(Value, "hostHeaderRewrite", translate("主机头重写"))
o:depends("type", "http")
o:depends("type", "https")

o = s:option(Value, "routeByHTTPUser", translate("按HTTP用户路由"), translate("v0.60+: 对指定 HTTP Basic 认证用户名的请求单独路由"))
o:depends("type", "http")
o:depends("type", "tcpmux")

o = s:option(DynamicList, "requestHeaders__set", translate("自定义请求头"), translate("v0.60+: 设置转发到本地服务的HTTP请求头，格式 key: value，一行一条"))
o:depends("type", "http")
o:depends("type", "https")
o.placeholder = "X-Custom-Header: value"

o = s:option(DynamicList, "responseHeaders__set", translate("自定义响应头"), translate("v0.60+: 设置返回给客户端的HTTP响应头，格式 key: value，一行一条"))
o:depends("type", "http")
o.placeholder = "X-Custom-Header: value"

o = s:option(Value, "transport__bandwidthLimit", translate("带宽限流大小"), translate("单位为 MB 或 KB，例如：3MB"))
o = s:option(ListValue, "transport__bandwidthLimitMode", translate("带宽限流类型"), translate("留空默认：client"))
o:value("", translate("（空）"))
o:value("server")
o:value("client")

o = s:option(Flag, "transport__useEncryption", translate("使用加密"), translate("更安全，但消耗更多系统资源，默认关闭。注意：frp全局默认启用TLS加密，若未禁用，除xtcp外，此处不应开启（重复加密）"))
o.enabled = "true"
o.disabled = ""
o.default = o.disabled

o = s:option(Flag, "transport__useCompression", translate("使用压缩"), translate("降低数据流量，但消耗更多系统资源，默认关闭"))
o.enabled = "true"
o.disabled = ""
o.default = o.disabled

o = s:option(ListValue, "transport__proxyProtocolVersion", translate("代理协议版本"))
o:value("", translate("（无）"))
o:value("v1")
o:value("v2")
o:depends("type", "tcp")
o:depends("type", "http")
o:depends("type", "https")
o:depends({type="stcp", visitor=""})
o:depends({type="xtcp", visitor=""})
o:depends("type", "tcpmux")

o = s:option(Value, "loadBalancer__group", translate("负载均衡分组名"))
o:depends("type", "tcp")
o:depends("type", "http")
o:depends("type", "tcpmux")

o = s:option(Value, "loadBalancer__groupKey", translate("负载均衡分组密钥"))
o:depends("type", "tcp")
o:depends("type", "http")
o:depends("type", "tcpmux")

o = s:option(ListValue, "healthCheck__type", "%s - %s" % { translate("健康检查"), translate("类型") })
o:value("", translate("（空）"))
o:value("tcp", "TCP")
o:value("http", "HTTP")
o:depends("type", "tcp")
o:depends("type", "http")

o = s:option(Value, "healthCheck__path", "%s - %s" % { translate("健康检查"), translate("http接口路径") })
o:depends("healthCheck__type", "http")

o = s:option(Value, "healthCheck__timeoutSeconds", "%s - %s" % { translate("健康检查"), translate("超时秒数") })
o.datatype = "uinteger"
o.placeholder = "3"
o:depends("healthCheck__type", "tcp")
o:depends("healthCheck__type", "http")

o = s:option(Value, "healthCheck__maxFailed", "%s - %s" % { translate("健康检查"), translate("最大失败次数") })
o.datatype = "uinteger"
o.placeholder = "3"
o:depends("healthCheck__type", "tcp")
o:depends("healthCheck__type", "http")

o = s:option(Value, "healthCheck__intervalSeconds", "%s - %s" % { translate("健康检查"), translate("间隔秒数") })
o.datatype = "uinteger"
o.placeholder = "10"
o:depends("healthCheck__type", "tcp")
o:depends("healthCheck__type", "http")

o = s:option(DynamicList, "healthCheck__httpHeaders", "%s - %s" % { translate("健康检查"), translate("自定义HTTP头") },
	translate("v0.60+: HTTP健康检查时附加的自定义头，格式 key: value，一行一条"))
o:depends("healthCheck__type", "http")
o.placeholder = "Authorization: Bearer xxx"

o = s:option(DynamicList, "metadatas", translate("代理元数据"),
	translate("v0.60+: 代理级别元数据，格式 key=value，可在服务端基于元数据路由"))
o.placeholder = "env = production"

o = s:option(DynamicList, "annotations", translate("注解"),
	translate("v0.60+: 仅为信息展示，不影响功能，格式 key=value"))
o.placeholder = "desc = SSH tunnel"

o = s:option(Flag, "natTraversal__disableAssistedAddrs", translate("禁用穿透辅助地址"), translate("v0.60+: 禁用NAT穿透时发送本地辅助地址(非访客模式)"))
o:depends("visitor", "")
o:depends("type", "stcp")
o:depends("type", "xtcp")
o.enabled = "true"
o.disabled = ""

o = s:option(DynamicList, "extra_options", translate("额外选项 1"),
	translate("点击添加列表1，写入 [[proxies]] 或 [[visitors]] 末尾，一行一条，格式错误可能无法启动服务"))
o.placeholder = "option = value"
o = s:option(DynamicList, "extra_options_plugin", translate("额外选项 2"),
	translate("点击添加列表2，写入插件功能 [proxies.plugin] 末尾..."))
o.placeholder = "option = value"

return m
