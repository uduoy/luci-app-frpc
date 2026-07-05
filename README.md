# luci-app-frpc / luci-app-frps

OpenWrt LuCI 管理界面 for frp 内网穿透客户端 & 服务端。

## 变更日志 (2025-07-05)

> ⚡ 由 AI vibe coding 辅助完成（DeepSeek V4 Pro via CodeBuddy）

### 架构改进

- **Schema 驱动配置生成**（方案C）：将 init.d 中 260 行 shell 字符串拼接替换为 Lua 模块  
  - `luasrc/tools/toml_gen.lua` — 通用 UCI→TOML Schema 引擎
  - `luasrc/tools/toml_gen_frpc.lua` — frpc Schema 定义 + UCI 文件读取器  
  - `root/usr/lib/lua/frpc/gen.lua` — shell 调用入口
- init.d 从 393 行精简为 192 行
- 修复 Lua 5.1 兼容性问题（移除 goto 语法）

### frpc 二进制更新

- 在线升级至 v0.69.1（原 0.51.3 不支持 TOML）

### 计划但回滚

- Dashboard 概览页 — 回滚（风格与原主题不统一）
- Web UI 布局优化 — 回滚（保留原始 LuCI 主题）

---

## 快速使用

不包含 frp 二进制文件，请自行下载：  
https://github.com/fatedier/frp/releases

按架构下载解压，将可执行文件传到设备任意目录，在 LuCI 界面指定路径。

### IPK 安装

```
opkg install luci-app-frpc_20251216_all.ipk
```

### APK 安装

```
apk add --allow-untrusted luci-app-frpc.apk
```

### 编译

使用 OpenWrt SDK (22.03.7)，放入 `package/` 目录后：

```
make package/luci-app-frpc/compile V=s
```

---

> 注意：仅中文简体。TOML 配置文件格式，frp 版本需 ≥ v0.52.0。

![preview](https://github.com/superzjg/luci-app-frpc_frps/blob/main/luci_frp.jpeg)
