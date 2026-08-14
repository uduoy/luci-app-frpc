# 设备架构参考（luci-app-frpc 编译用）

本文汇总本项目实际部署/测试过的设备架构信息，供编译 luci 程序时选择正确的 SDK / 目标架构 / 包格式。

所有设备的 luci 程序本体（`luci-app-frpc`、`luci-app-frps`）均为 **纯 Lua（LuCI）**，通过 `LUCI_PKGARCH:=all` 声明为 `all`（noarch）架构——即**同一份 `.ipk`/`.apk` 可在同包管理器的任意架构上安装**，无需按 CPU 架构分别编译。下方架构信息主要用于：

1. 决定下载哪个 **OpenWrt SDK / buildroot 分支**（22.03 / 24.10 / SNAPSHOT）；
2. 决定包格式（opkg 出 `.ipk`，apk 出 `.apk`，见 `apk-build.md`）；
3. 确认目标机是否还需要配套的 **frpc 二进制**（frpc 是 Go 编译的真实二进制，必须匹配 `DISTRIB_ARCH`，与 luci 包不同）。

> 注：`luci-app-frpc` 的 Makefile 只打包 LuCI 前端与 UCI 配置骨架；真正的 `frpc` 可执行文件来自 frp 官方或设备自带，按 `DISTRIB_ARCH` 选择对应平台的 frpc。

## 设备架构速查表

| 设备 | 访问 IP | 型号 / SoC | `DISTRIB_ARCH` | Target (`DISTRIB_TARGET`) | OpenWrt 版本 | 包格式 | 包管理器 | 当前部署 |
|---|---|---|---|---|---|---|---|---|
| QWRT | 10.10.10.1 | ipq60xx（Qualcomm） | `aarch64_cortex-a53` | `ipq60xx/generic` | 21.02-SNAPSHOT | `.ipk` | opkg | luci-app-frpc `20251216-r8`（toml_gen `f2916243`）/ frpc `0.51.2-1` |
| FanchmWrt（京东云 RE-CP-02） | 10.10.10.2 | MT7621（MediaTek ramips） | `mipsel_24kc` | `ramips/mt7621` | 24.10.4 | `.ipk` | opkg | luci-app-frpc `20251216-r8`（toml_gen `f2916243`） |
| Gemtek W1700K（本机 14052） | 114.132.220.205:14052 | Airoha AN7581 | `aarch64_cortex-a53` | `airoha/an7581` | SNAPSHOT `r35572-8393548d2c` | `.apk` | **apk**（实测 `which apk` 存在，非 opkg） | luci-app-frpc `20251216-r8`（toml_gen `f2916243`）/ frpc `0.70.1` |
| LivingROOM（小米 CR6606/6608/6609） | 114.132.220.205:14040 | MT7621（MediaTek ramips） | `mipsel_24kc` | `ramips/mt7621` | 23.05.0-rc3（Kiddin' 定制 `08.28.2023`） | `.ipk` | opkg | luci-app-frpc `20251216-8`（toml_gen `f2916243`）/ frpc `0.69.1` |
| WRT2208（小米 CR6606/6608/6609） | 114.132.220.205:13045 | MT7621（MediaTek ramips） | `mipsel_24kc` | `ramips/mt7621` | 23.05.0-rc3（"WRT2208 09.15.2023 by du"） | `.ipk` | opkg | luci-app-frpc `20251216-8`（toml_gen `f2916243`）/ frpc `0.69.1`（hold） |

> 五台设备的 `luci-app-frpc` 现已全部统一为 `20251216` 修复版（含 `toml_gen.lua` 合并 `[main]/[server]` 修复，md5=`f2916243`），部署于 2026-08-14。
> frpc 二进制来自各机官方/预装源或同架构拷贝，版本互不相同（0.48.0→0.69.1 / 0.51.2-1 / 0.69.1 / 0.70.1），与本 luci 包无关。
> 注：13045 的 frpc 由 opkg 包 `0.48.0-1` 托管，已手动替换为 0.69.1（从 14040 同架构 mipsel 拷贝）并对 opkg 设 `hold`，避免 `opkg upgrade` 覆盖回旧版；原二进制备份 `/usr/bin/frpc.bak-0.48.0`。

### 实测详情

**QWRT — 10.10.10.1**
- 架构 `aarch64_cortex-a53`，Target `ipq60xx/generic`
- OpenWrt `21.02-SNAPSHOT` → opkg，产物 `.ipk`
- 注意：21.02 较旧，LuCI 依赖可能与新版 `luci.mk` 有差异，编译时建议使用对应 21.02 的 SDK/feed。

**FanchmWrt（京东云 RE-CP-02）— 10.10.10.2**
- 架构 `mipsel_24kc`，Target `ramips/mt7621`
- OpenWrt `24.10.4`（稳定版，最后一个 opkg 版本）→ opkg，产物 `.ipk`
- MT7621 为 mips 小端 24KC，需确认 frpc 二进制提供该架构版本（Go 官方 frp 提供 `mipsle` 构建）。

**Gemtek W1700K — 114.132.220.205:14052**（root 登录实测）
- 型号：`Gemtek W1700K (OpenWrt U-Boot layout)`，board id `gemtek,w1700k-ubi`
- SoC：Airoha **AN7581**，4 核 aarch64 Cortex-A53
- 内存 ~1.8 GB，存储 UBI overlay `/overlay` 349.5M（可用 ~300M）
- 网络：`wan`=192.168.1.2/24（前层为光猫/网关，公网 IP 在 frps 侧），`br-lan`=10.14.14.1/24
- OpenWrt `SNAPSHOT r35572-8393548d2c`，Target `airoha/an7581`
- 已部署 `/usr/bin/frpc`（Go 二进制，14.8M）+ `/etc/init.d/frpc`，frpc 连 `114.132.220.205:7000`
- 包格式：本机当前为 opkg；若改用 **main/SNAPSHOT SDK** 编译则产物为 `.apk`（见 `apk-build.md`）

**LivingROOM（Xiaomi Mi Router CR6606 / CR6608 / CR6609）— 114.132.220.205:14040**
- 主机名：`LivingROOM`
- 型号：`Xiaomi Mi Router CR6606 / CR6608 / CR6609`
- SoC：MediaTek **MT7621**（ver:1 eco:3），Target `ramips/mt7621`
- 架构 `mipsel_24kc`（与 FanchmWrt 同款 MT7621，frpc 取 `mipsle` 构建）
- 固件：`OpenWrt 08.28.2023 by Kiddin'`，LuCI `openwrt-23.05` 分支（`git-25.222.75657-7ce34fe`）
- 内核 `5.15.127`，23.05.0-rc3（实测 `DISTRIB_REVISION=08.28.2023`）
- 23.05 稳定分支 → opkg，产物 `.ipk`
- 与 FanchmWrt 同为 MT7621 / `ramips/mt7621`，编译目标与 frpc 平台可复用其经验。
- **frpc 现状**：`/usr/bin/frpc` 0.69.1（已预装，非本项目产物）。
- **luci-app-frpc 现状**：`20251216-8`（含 `toml_gen` 修复，md5=`f2916243`，2026-08-14 强制重装就位）。

**WRT2208（Xiaomi Mi Router CR6606 / CR6608 / CR6609）— 114.132.220.205:13045**
- 主机名：`WRT2208`，board id `xiaomi,mi-router-cr660x`
- 型号：`Xiaomi Mi Router CR6606 / CR6608 / CR6609`
- SoC：MediaTek **MT7621**，Target `ramips/mt7621`
- 架构 `mipsel_24kc`（与 FanchmWrt / LivingROOM 同款 MT7621，frpc 取 `mipsle` 构建）
- 固件：`OpenWrt 09.15.2023 by du`（自编译），LuCI `openwrt-23.05` 分支（`git-...`）
- 内核 `5.15.127`，23.05.0-rc3（实测 `DISTRIB_REVISION=09.15.2023`）
- 23.05 稳定分支 → opkg，产物 `.ipk`
- **frpc 现状**：`/usr/bin/frpc` 0.69.1（由 14040 同架构 mipsel 二进制拷贝替换原 0.48.0，opkg 已 `hold`；备份 `/usr/bin/frpc.bak-0.48.0`）。
- **luci-app-frpc 现状**：`20251216-8`（含 `toml_gen` 修复，md5=`f2916243`，2026-08-14 由 14040 修复版文件同步 + uhttpd restart 就位）。
- **SSH**：ed25519 公钥已加入 `/etc/dropbear/authorized_keys`（1 行，权限 600）。`/etc/shells` 已含 `/bin/bash`，无 14040 那种 shell 坑，公钥登录直接生效（`ssh -i ~/.ssh/id_ed25519 root@114.132.220.205 -p 13045`）。

#### 14040 SSH 登录坑（已解决，2026-08-14）

根因：`/etc/shells` 只有 `/bin/ash`，**缺少 `/bin/bash`**，而 root 的 shell 是 `/bin/bash`
→ Dropbear 启动会话时检查 shell 合法性，判定为 invalid shell，**直接拒绝登录（密码/公钥都拒）**。

修复（用 `du` 用户的 NOPASSWD sudo，或先修 shells 后用 root 密码 `823036` 登录）：

```sh
echo "/bin/bash" >> /etc/shells     # 追加后无需重启 dropbear，立即生效
```

修复后两套可用登录方式：

| 用户 | 密码 | 方式 |
|---|---|---|
| root | `823036` | ✅ SSH（shell 修复后） |
| du | `Abcd1234!` | ✅ SSH（有 NOPASSWD sudo） |

公钥：`/etc/dropbear/authorized_keys` 已含本机 `workbuddy@mac`(ed25519) 及原有 `root@armbian`/`Termius` 两枚；
权限 `600`、owner `root`。**公钥添加本身无需重启 dropbear**（每次连接实时读取 authorized_keys），
唯独改 `/etc/shells` 或 `/etc/config/dropbear` 才需 `service dropbear restart`。

## 编译决策树

```
目标机 OpenWrt 版本?
├─ 21.02 / 22.03 / 23.05 / 24.10  → 用对应分支 SDK → opkg → .ipk
└─ main / SNAPSHOT                → 用 SNAPSHOT SDK → apk  → .apk
                                        （Makefile 无需改，见 apk-build.md）

luci-app-frpc / luci-app-frps 本身是 all 架构，与 DISTRIB_ARCH 无关；
只有 frpc 二进制需匹配 DISTRIB_ARCH：
  aarch64_cortex-a53 → frpc linux_arm64
  mipsel_24kc        → frpc linux_mipsle
```

## 关键提醒

1. **luci 包 = `all` 架构**：`LUCI_PKGARCH:=all` 使 luci 前端包不区分 CPU，一张 `.ipk`/`.apk` 通吃。
2. **frpc 二进制 ≠ luci 包**：frpc 是 Go 原生二进制，必须按 `DISTRIB_ARCH` 取对应平台（arm64 / mipsle / 等），否则无法运行。
3. **包格式只看 OpenWrt 分支**：24.10 及更早 = `.ipk`；main/SNAPSHOT = `.apk`。同一 luci 源码两种格式均可出，无需改动 Makefile。
4. **SDK 选择看 Target**：下载 SDK 时按 `DISTRIB_TARGET`（如 `airoha/an7581`、`ramips/mt7621`、`ipq60xx/generic`）定位，而非只看架构字符串。

## SSH 访问

所有设备 `root` 登录，密码 `823036`（10.10.10.1 / .2 / 14052 / 14040 同密码，除非固件单独改过）。
各机 SSH 服务端类型不同（OpenWrt 原版用 **Dropbear**，部分定制固件用 **OpenSSH**），加密算法支持参差不齐，需注意老算法兼容。

> **生效规则**：向 `authorized_keys` 追加/修改公钥**无需重启** dropbear（每次新连接实时读取文件）。
> 只有改 `/etc/config/dropbear`（端口、RootPasswordAuth 等）或修 shell 合法性（见 14040 shells 坑）时才需 `service dropbear restart`。
> 注意：dropbear 解析 `authorized_keys` 是"首个损坏行即中断后续"，若某行格式错建议把目标 key 置顶。

### 客户端老算法兼容（本地 OpenSSH 10.2 默认已禁用老算法）

老 Dropbear / 老 OpenSSH 只认以下算法，客户端连接时必须显式开启，否则 `Permission denied` / `no matching ... type found`：

```bash
ssh -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o Ciphers=+aes128-cbc \
    root@<IP>
```

首次连接（或用 sshpass 推送公钥时）加 `-o StrictHostKeyChecking=accept-new` 自动接受新指纹。

### 公钥部署

本机管理公钥有两枚，按设备 SSH 服务端能力选用：

**RSA 4096**（兼容性最好，老 Dropbear 可能不支持 → 见下方 14040 说明）

- 私钥：`~/.ssh/id_rsa`
- 指纹：`SHA256:SOmwJjjuY4h7mb0n5wY3WAseqvGbF/4e1BDJhbX5kUc`（comment `youdu@router-admin`）

```text
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDj8hlmCuESQfJfTUABVrVCOnINIC8eWHEFfWEpuPXksqQ99dMJrU74XAJgU7puqDj/BjCHDSfrqrRMvWeCfpEYE1s3/z08JhPTJ00/D8NEoYKTSJ9jF4GHv+pnwwJgdsFRL5xKWKLkbEAbGsiH/4Jn7XHQrEjAMXnE0hgQ8IJmVqoZELYUf+wRSW+BArz+VKd4dIMUGIfW6yfTqnd3hHmGA3RiHoCOb6Amdld3LI7cgfevlxtvX+CEgRkTEY/y0HqmsaFrh39jdfl6619K69qRE12yAHVmZ8wNe+a3wCEhkt0eTsM4oVJj4rUkvyaK+aj9/FXKZmJYthBBvb5B28xhUBJ65/TYjjp6FxqLjP9zM5WmBP5Vn2PtP9sJD35K7Jr2Pc1ln9sk3MUj7mzujUrXaA9l90FCFSJ1eKALn+nrq+Jp0ct/A8elqO0PxhcdSa7HHBu6euBMt61z79ukTnEOXyM++MEAfkwqGhrkXtVr/B6yC6SeIFDDcSm27K/fVort+uu0MpHl98GNWV82/1w7+1jQu4R1wM91t9OD5BNDArirC0b1oerEdtS6qXI0nWLofxDwpmbrd9I6Kai6LAUdrNwsVfhjIxWSvwBPzQu8dNpZYhjIqvLvc/Z5SYIlfu313i57SEmi6oGOCYxWHH6eHcUBiPvjXad7MvgO+YaOEw== youdu@router-admin
```

**ed25519**（老 Dropbear / 小米 Kiddin' 固件优先用此枚，实测 14040 认 ed25519 但拒 RSA）

- 私钥：`~/.ssh/id_ed25519`
- 指纹：`SHA256:emZE6vb0ZCwoX8G2EPk0Fv8vod/hxVY3YWDdIOQUrJo`（comment `workbuddy@mac`）

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSqXTqVUqfy8d13ww4khb0uSQHK0J6Lz9LdJqkFgXuQ workbuddy@mac
```

> 注：以上为部署用管理公钥，写入文档便于各机统一分发；私钥仅存于本机，勿外泄。

按服务端类型把公钥推到对应路径：

- **Dropbear（OpenWrt 原版）** → `/etc/dropbear/authorized_keys`（注意不是 `~/.ssh/`）：

  ```bash
  PUB=$(cat ~/.ssh/id_ed25519.pub)   # 老 Dropbear 用 ed25519；若确认支持 RSA 才用 id_rsa.pub
  sshpass -p '823036' ssh -o StrictHostKeyChecking=accept-new \
    -o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa -o Ciphers=+aes128-cbc \
    root@<IP> "echo '$PUB' >> /etc/dropbear/authorized_keys; chmod 600 /etc/dropbear/authorized_keys; echo OK"
  ```

- **OpenSSH / 定制固件** → `~/.ssh/authorized_keys`（OpenSSH 强制权限，否则忽略）：

  ```bash
  PUB=$(cat ~/.ssh/id_rsa.pub)
  sshpass -p '823036' ssh -o StrictHostKeyChecking=accept-new root@<IP> \
    "mkdir -p ~/.ssh && echo '$PUB' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo OK"
  ```

### known_hosts 固化（消除 MITM 警告）

设备重刷/重置后 host key 会变（如 14052 曾报 `REMOTE HOST IDENTIFICATION HAS CHANGED`）。先清旧记录再重新接受：

```bash
ssh-keygen -R '[114.132.220.205]:14052'
ssh-keygen -R '[114.132.220.205]:14040'
ssh-keygen -R '10.10.10.1'
ssh-keygen -R '10.10.10.2'
ssh-keyscan -p 14052 114.132.220.205 >> ~/.ssh/known_hosts
ssh-keyscan -p 14040 114.132.220.205 >> ~/.ssh/known_hosts
ssh-keyscan 10.10.10.1 >> ~/.ssh/known_hosts
ssh-keyscan 10.10.10.2 >> ~/.ssh/known_hosts
```

### `~/.ssh/config` 模板（按 host 分组，免带长串算法参数）

```ssh
Host qwrt
    HostName 10.10.10.1
    User root
    KexAlgorithms +diffie-hellman-group1-sha1
    HostKeyAlgorithms +ssh-rsa
    Ciphers +aes128-cbc

Host fanchm
    HostName 10.10.10.2
    User root
    KexAlgorithms +diffie-hellman-group1-sha1
    HostKeyAlgorithms +ssh-rsa
    Ciphers +aes128-cbc

Host gemtek
    HostName 114.132.220.205
    Port 14052
    User root
    KexAlgorithms +diffie-hellman-group1-sha1
    HostKeyAlgorithms +ssh-rsa
    Ciphers +aes128-cbc

Host livingroom
    HostName 114.132.220.205
    Port 14040
    User root
    # 若为较新 OpenSSH 可省略老算法；若为老 Dropbear 则补上上面三行
```

### 公钥部署分工

- **10.10.10.1 / 10.10.10.2**：由本机自动化脚本批量部署（Dropbear 路径，ed25519）。
- **114.132.220.205:14052（Gemtek）**：apk 包管理器；用户已加公钥，host key 曾变更需先 `ssh-keygen -R`。
- **114.132.220.205:14040（LivingROOM）**：✅ **已打通**（2026-08-14，先修 `/etc/shells` 缺 `/bin/bash` 坑，再公钥登录生效）。
  - 该机 Dropbear **认 ed25519、拒 RSA**（老算法兼容参数也救不了 RSA），务必用 `workbuddy@mac`(ed25519) 公钥。
  - 免密登录：`ssh -i ~/.ssh/id_ed25519 root@114.132.220.205 -p 14040`
- **114.132.220.205:13045（WRT2208）**：✅ **已打通**（2026-08-14，ed25519 公钥生效，`/etc/shells` 已含 `/bin/bash` 无坑）。
  - 免密登录：`ssh -i ~/.ssh/id_ed25519 root@114.132.220.205 -p 13045`
  - 当前 luci-app-frpc 为老版 `git-24.217...`，待重装修复版（同 14040 mipsel ipk）。

