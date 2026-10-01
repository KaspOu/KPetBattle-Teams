"""Runs tests/rematch_import_test.lua with an embedded Lua 5.1 (pip install lupa). Run from the repo root."""
import os
import sys

from lupa.lua51 import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
try:
    lua.execute(open(os.path.join("tests", "import_test.lua"), encoding="utf-8").read().replace("\r\n", "\n"))
except Exception as exc:
    print(exc)
    sys.exit(1)
