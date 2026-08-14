-- Copyright 2019 Xingwang Liao <kuoruan@gmail.com> #modify by superzjg@gmail.com 20240810
-- Licensed to the public under the MIT License.

local dsp = require "luci.dispatcher"

local m, s, o

local sid = arg[1]

m = Map("frpc", "%s - %s" % { translate("Frpc"), translate("编辑服务端") })
m.redirect = dsp.build_url("admin/services/frpc/servers")

if m.uci:get("frpc", sid) ~= "server" then
	luci.http.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "server")
s.anonymous = true
s.addremove = false

o = s:option(Value, "alias", translate("别名"))

o = s:option(Value, "serverAddr", translate("服务端地址"), translate("地址或域名（支持IPv6）"))
o.placeholder = "0.0.0.0"

o = s:option(Value, "serverPort", translate("服务端端口"), translate("依据“通信协议“设定的类型进行填写，<font style='color:red'>例如：</font>协议tcp、kcp、quic分别对应frps的“bindPort”、“kcpBindPort”、“quicBindPort”"))
o.datatype = "port"
o.placeholder = "7000"

o = s:option(ListValue, "auth__method", translate("鉴权方式"), translate("留空默认token，若用oidc请使用通用设置 - 高级选项中的 “额外选项” 添加参数"))
o:value("", translate("（空）"))
o:value("token")
o:value("oidc")

o = s:option(Value, "auth__token", translate("鉴权令牌"))
o.password = true
o:depends("auth__method", "")
o:depends("auth__method", "token")

o = s:option(Value, "auth__oidc__issuerURL", translate("OIDC 签发地址"),
	translate("v0.65+: OIDC 身份提供商的 issuer URL，例如 https://oidc.example.com"))
o:depends("auth__method", "oidc")

o = s:option(Value, "auth__oidc__clientID", translate("OIDC 客户端ID"))
o:depends("auth__method", "oidc")

o = s:option(Value, "auth__oidc__clientSecret", translate("OIDC 客户端密钥"))
o.password = true
o:depends("auth__method", "oidc")

o = s:option(Value, "auth__oidc__audience", translate("OIDC 受众"))
o:depends("auth__method", "oidc")

o = s:option(Value, "auth__oidc__scope", translate("OIDC 作用域"),
	translate("空格分隔的 scope 列表，例如 openid profile"))
o:depends("auth__method", "oidc")

o = s:option(Flag, "auth__oidc__skipExpiryCheck", translate("OIDC 跳过过期检查"))
o.enabled = "true"
o.disabled = ""
o:depends("auth__method", "oidc")

o = s:option(Flag, "auth__oidc__skipIssuerValidation", translate("OIDC 跳过签发方校验"))
o.enabled = "true"
o.disabled = ""
o:depends("auth__method", "oidc")

o = s:option(Flag, "auth__oidc__insecureSkipVerify", translate("OIDC 跳过 TLS 验证"),
	translate("跳过 OIDC issuer 的 TLS 证书验证，仅测试环境使用"))
o.enabled = "true"
o.disabled = ""
o:depends("auth__method", "oidc")

o = s:option(ListValue, "auth__oidc__tokenSource__type", translate("tokenSource 类型"),
	translate("v0.66+: 令牌来源类型，file 从文件读取，exec 执行命令获取"))
o:value("", translate("（无）"))
o:value("file")
o:value("exec")
o:depends("auth__method", "oidc")

o = s:option(Value, "auth__oidc__tokenSource__file__path", translate("tokenSource 文件路径"),
	translate("type=file 时令牌文件所在路径"))
o:depends("auth__oidc__tokenSource__type", "file")

o = s:option(Value, "auth__oidc__tokenSource__exec__command", translate("tokenSource 命令"),
	translate("type=exec 时获取令牌的执行命令"))
o:depends("auth__oidc__tokenSource__type", "exec")

o = s:option(Value, "auth__oidc__tokenSource__exec__args", translate("tokenSource 命令参数"),
	translate("type=exec 时命令参数，空格分隔"))
o:depends("auth__oidc__tokenSource__type", "exec")

o = s:option(DynamicList, "auth__oidc__tokenSource__exec__env", translate("tokenSource 环境变量"),
	translate("type=exec 时环境变量，格式 key=value，一行一个"))
o:depends("auth__oidc__tokenSource__type", "exec")

o = s:option(Flag, "transport__tcpMux", translate("关闭 TCP 复用"), translate("Frpc 默认开启 tcpMux。提示：frpc 和 frps 要作相同设置"))
o.enabled = "false"
o.disabled = ""

o = s:option(Value, "transport__tcpMuxKeepaliveInterval", translate("tcpMux心跳检查间隔秒数"))
o:depends("transport__tcpMux", "")
o.datatype = "uinteger"
o.placeholder = "30"

return m
