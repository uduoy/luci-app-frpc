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
