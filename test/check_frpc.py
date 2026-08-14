#!/usr/bin/env python3
"""luci-app-frpc schema/init.d/CBI 三处一致性静态检查。

验证每个 frpc 配置项在三个位置同步存在：
1. luasrc/tools/toml_gen_frpc.lua (Schema, TOML 生成)
2. root/etc/init.d/frpc        (uci_validate_section 校验)
3. luasrc/model/cbi/frpc/*.lua (LuCI 表单)
运行: python3 test/check_frpc.py   （退出码 0=通过, 1=失败）
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(REPO, "luci-app-frpc")
SCHEMA = os.path.join(APP, "luasrc", "tools", "toml_gen_frpc.lua")
TOMLGEN = os.path.join(APP, "luasrc", "tools", "toml_gen.lua")
INITD = os.path.join(APP, "root", "etc", "init.d", "frpc")
COMMON = os.path.join(APP, "luasrc", "model", "cbi", "frpc", "common.lua")
SERVER_DETAIL = os.path.join(APP, "luasrc", "model", "cbi", "frpc", "server-detail.lua")
RULE_DETAIL = os.path.join(APP, "luasrc", "model", "cbi", "frpc", "rule-detail.lua")


def text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


_failures = []


def check(name, cond):
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        _failures.append(name)


def has(needle, path):
    return needle in text(path)


def schema_has(pattern):
    return re.search(pattern, text(SCHEMA)) is not None


def main():
    # === Task 1: clientID ===
    check("schema global 含 clientID", schema_has(r'\{\s*"clientID",\s*"clientID"'))
    check("init.d 校验 clientID", has("'clientID:string'", INITD))
    check("common.lua 含 clientID 选项", has('"clientID"', COMMON))

    # === Task 2: [store] 持久化存储子表 ===
    check("schema subtables 含 store", schema_has(r'prefix\s*=\s*"store"'))
    check("init.d 校验 store__path", has("'store__path:string'", INITD))
    check("init.d 校验 store__type", has("'store__type:string'", INITD))
    check("init.d 校验 store__localPath", has("'store__localPath:string'", INITD))
    check("common.lua 含 store__path 选项", has('"store__path"', COMMON))

    # === Task 3: auth.oidc OIDC ===
    check("schema 含 auth__oidc__issuerURL", schema_has(r'"auth__oidc__issuerURL"'))
    check("schema 含 auth__oidc__clientSecret", schema_has(r'"auth__oidc__clientSecret"'))
    check("schema 含 auth__oidc__audience", schema_has(r'"auth__oidc__audience"'))
    check("schema 含 auth__oidc__scope", schema_has(r'"auth__oidc__scope"'))
    check("schema 含 auth__oidc__skipExpiryCheck (bool)", schema_has(r'"auth__oidc__skipExpiryCheck".*"bool"'))
    check("schema 含 auth__oidc__insecureSkipVerify (bool)", schema_has(r'"auth__oidc__insecureSkipVerify".*"bool"'))
    check("init.d 校验 auth__oidc__issuerURL", has("'auth__oidc__issuerURL:string'", INITD))
    check("init.d 校验 auth__oidc__clientSecret", has("'auth__oidc__clientSecret:string'", INITD))
    check("init.d 校验 auth__oidc__insecureSkipVerify", has("'auth__oidc__insecureSkipVerify:or(\"true\", \"false\")'", INITD))
    check("server-detail.lua 含 auth__oidc__issuerURL 选项", has('"auth__oidc__issuerURL"', SERVER_DETAIL))

    # === Task 4: auth.oidc.tokenSource (kvarr) ===
    check("schema 含 auth__oidc__tokenSource__type", schema_has(r'"auth__oidc__tokenSource__type"'))
    check("schema 含 auth__oidc__tokenSource__exec__command", schema_has(r'"auth__oidc__tokenSource__exec__command"'))
    check("schema 含 auth__oidc__tokenSource__exec__args", schema_has(r'"auth__oidc__tokenSource__exec__args"'))
    check("schema 含 auth__oidc__tokenSource__exec__env (kvarr)", schema_has(r'"auth__oidc__tokenSource__exec__env".*"kvarr"'))
    check("toml_gen 引擎含 kvarr 处理", has('kvarr', TOMLGEN))
    check("init.d 校验 tokenSource__type", has("'auth__oidc__tokenSource__type:string'", INITD))
    check("init.d 校验 tokenSource__exec__command", has("'auth__oidc__tokenSource__exec__command:string'", INITD))
    check("init.d 校验 tokenSource__exec__args", has("'auth__oidc__tokenSource__exec__args:string'", INITD))
    check("init.d 校验 tokenSource__exec__env", has("'auth__oidc__tokenSource__exec__env:string'", INITD))

    if _failures:
        print("")
        print("FAILED: %d 项" % len(_failures))
        for name in _failures:
            print("  - " + name)
        sys.exit(1)
    print("")
    print("OK: 所有检查通过")


if __name__ == "__main__":
    main()
