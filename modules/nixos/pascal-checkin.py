#!/usr/bin/env python3
"""PASCAL 大模型聚合平台（new-api）每日自动签到。

只依赖 Python 标准库，Python 3.8+ 可用。

用法:
    py -3 pascal_checkin.py                  # 执行签到（日常任务用这个）
    py -3 pascal_checkin.py --status         # 只看本月签到情况，不签到
    py -3 pascal_checkin.py --base-url http://127.0.0.1:8765   # 指向测试服务器

Access Token 的读取顺序:
    1. --token-file 指定的文件
    2. 环境变量 PASCAL_ACCESS_TOKEN
    3. 脚本同目录下的 token.txt（默认）

退出码:
    0  签到成功 / 今日已签到
    2  Token 无效、已过期或已撤销（重新生成 token）
    3  Token 缺少权限（需要授权 wallet:write）
    4  网络或服务器异常
    5  本地配置问题（token 文件缺失等）
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

DEFAULT_BASE_URL = "https://ai.pascal-lab.net"
DEFAULT_TIMEOUT = 30

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_TOKEN_FILE = SCRIPT_DIR / "token.txt"
DEFAULT_LOG_FILE = SCRIPT_DIR / "checkin.log"
LOG_KEEP_BYTES = 256 * 1024

EXIT_OK = 0
EXIT_AUTH = 2
EXIT_SCOPE = 3
EXIT_NETWORK = 4
EXIT_CONFIG = 5

ACCESS_TOKEN_HINT = (
    "请在网页端 个人设置 → 访问令牌(Access token) 重新生成一个包含 wallet:write 权限的令牌，"
    "写入 token 文件后重试。"
)


def log(message, log_path=None, echo=True):
    line = "[%s] %s" % (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), message)
    if echo:
        print(line, flush=True)
    if log_path is None:
        return
    try:
        if log_path.exists() and log_path.stat().st_size > LOG_KEEP_BYTES:
            tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-300:]
            log_path.write_text("\n".join(tail) + "\n", encoding="utf-8")
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def http_request(url, method="GET", token=None, timeout=DEFAULT_TIMEOUT):
    """返回 (status, body_text)；网络层错误往上抛。"""
    headers = {"Accept": "application/json", "User-Agent": "pascal-checkin/1.0"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")


def parse_json(body):
    try:
        data = json.loads(body)
        return data if isinstance(data, dict) else {}
    except ValueError:
        return {}


def load_token(args, log_path):
    """按 --token-file → 环境变量 → 脚本目录 token.txt 的顺序取 token。"""
    if args.token_file:
        candidates = [Path(args.token_file)]
    elif os.environ.get("PASCAL_ACCESS_TOKEN"):
        return os.environ["PASCAL_ACCESS_TOKEN"].strip(), None
    else:
        candidates = [DEFAULT_TOKEN_FILE]

    for path in candidates:
        if not path.exists():
            return None, "找不到 token 文件: %s" % path
        text = path.read_text(encoding="utf-8-sig", errors="replace")
        for raw_line in text.splitlines():
            line = raw_line.strip().strip('"').strip("'").strip()
            if line and not line.startswith("#"):
                return line, None
        return None, "token 文件 %s 是空的" % path

    return None, "无法读取 token"


def print_status(data):
    stats = (data.get("data") or {}).get("stats") or {}
    today = "是" if stats.get("checked_in_today") else "否"
    print("今日已签到: %s" % today)
    print("本月签到次数: %s" % stats.get("checkin_count"))
    print("累计签到次数: %s" % stats.get("total_checkins"))
    print("累计获得额度: %s" % stats.get("total_quota"))
    records = stats.get("records") or []
    if records:
        print("本月记录:")
        for item in records:
            print("  %s  +%s" % (item.get("checkin_date"), item.get("quota_awarded")))


def main(argv=None):
    parser = argparse.ArgumentParser(description="PASCAL 平台每日自动签到")
    parser.add_argument("--base-url", default=os.environ.get("PASCAL_BASE_URL", DEFAULT_BASE_URL),
                        help="站点地址，默认 %s" % DEFAULT_BASE_URL)
    parser.add_argument("--token-file", default=None, help="保存 access token 的文件")
    parser.add_argument("--log-file", default=None, help="日志文件，默认与脚本同目录的 checkin.log")
    parser.add_argument("--status", action="store_true", help="只查询本月签到情况，不执行签到")
    parser.add_argument("--quiet", action="store_true", help="不输出到控制台，只写日志")
    args = parser.parse_args(argv)

    base_url = args.base_url.rstrip("/")
    log_path = Path(args.log_file) if args.log_file else DEFAULT_LOG_FILE
    echo = not args.quiet

    token, error = load_token(args, log_path)
    if token is None:
        log("未执行签到：%s" % error, log_path, echo)
        return EXIT_CONFIG
    if not token.startswith("nap_"):
        log("提示：token 不以 nap_ 开头，可能是旧式令牌，继续尝试。", log_path, echo)

    if args.status:
        month = datetime.now().strftime("%Y-%m")
        try:
            status, body = http_request("%s/api/user/checkin?month=%s" % (base_url, month), token=token)
        except (urllib.error.URLError, OSError) as exc:
            log("查询失败（网络错误）: %s" % exc, log_path, echo)
            return EXIT_NETWORK
        data = parse_json(body)
        if status == 401:
            log("查询失败：token 无效或已过期。%s" % ACCESS_TOKEN_HINT, log_path, echo)
            return EXIT_AUTH
        if status == 403:
            log("查询失败：token 缺少权限（wallet:read）。%s" % ACCESS_TOKEN_HINT, log_path, echo)
            return EXIT_SCOPE
        if not data.get("success"):
            log("查询失败：%s" % (data.get("message") or body[:200]), log_path, echo)
            return EXIT_NETWORK
        if echo:
            print_status(data)
        log("签到状态查询成功。", log_path, echo)
        return EXIT_OK

    try:
        status, body = http_request("%s/api/user/checkin" % base_url, method="POST", token=token)
    except (urllib.error.URLError, OSError) as exc:
        log("签到失败（网络错误）: %s" % exc, log_path, echo)
        return EXIT_NETWORK

    data = parse_json(body)
    message = (data.get("message") or "").strip()

    if status == 401:
        log("签到失败(401)：token 无效、已过期或已撤销。%s" % ACCESS_TOKEN_HINT, log_path, echo)
        return EXIT_AUTH
    if status == 403:
        code = data.get("code", "")
        if code == "ACCESS_TOKEN_SCOPE_DENIED":
            log("签到失败(403)：token 缺少 wallet:write 权限。%s" % ACCESS_TOKEN_HINT, log_path, echo)
            return EXIT_SCOPE
        log("签到失败(403,%s)：%s" % (code, message or body[:200]), log_path, echo)
        return EXIT_SCOPE
    if not data:
        log("签到结果无法解析(HTTP %s)：%s" % (status, body[:200]), log_path, echo)
        return EXIT_NETWORK

    if data.get("success"):
        award = (data.get("data") or {}).get("quota_awarded")
        date = (data.get("data") or {}).get("checkin_date")
        log("签到成功：%s 获得额度 %s" % (date or datetime.now().strftime("%Y-%m-%d"), award), log_path, echo)
        return EXIT_OK

    lowered = message.lower()
    if "already checked in" in lowered or "已签到" in message:
        log("今日已签到，无需重复。", log_path, echo)
        return EXIT_OK

    log("签到未完成：%s" % (message or body[:200]), log_path, echo)
    if "turnstile" in lowered:
        log("提示：站点启用了 Turnstile 人机校验，脚本无法通过，需要手工签到。", log_path, echo)
    return EXIT_NETWORK


if __name__ == "__main__":
    sys.exit(main())
