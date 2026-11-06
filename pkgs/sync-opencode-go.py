#!/usr/bin/env python3
"""Rebuild the opencode-go entry in pi's models-store.json from opencode's live catalog.

Source of truth: https://opencode.ai/inference/go/v1/models
Target: ~/.pi/agent/models-store.json[opencode-go].models  (pi's Model[] schema)
"""
import json, os, shutil, sys, urllib.request, copy, time

STORE = os.path.expanduser("~/.pi/agent/models-store.json")
LIVE = "https://opencode.ai/inference/go/v1/models"

BASE = {
    "openai-completions": "https://opencode.ai/inference/go/openai/v1",
    "openai-responses": "https://opencode.ai/inference/go/openai/v1",
    "anthropic-messages": "https://opencode.ai/inference/go",
    "google-generative-ai": "https://opencode.ai/inference/go/google/v1beta",
}
API_MAP = {
    "chat-completions": "openai-completions",
    "responses": "openai-responses",
    "messages": "anthropic-messages",
    "generate-content": "google-generative-ai",
}
OPENAI_COMPAT = {"supportsStore": False, "supportsDeveloperRole": False,
                 "supportsStrictMode": True, "maxTokensField": "max_tokens"}
IMG_LIMITS = {"images": {"resize": {"maxWidth": 2000, "maxHeight": 2000,
                                    "maxBytes": 4718592, "jpegQuality": 80}}}
ALL_LEVELS = ["minimal", "low", "medium", "high", "xhigh", "max"]


def fetch_live():
    req = urllib.request.Request(LIVE, headers={"accept": "application/json",
                                                "User-Agent": "pi/0.85.1 (sync-script)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return {m["id"]: m for m in json.load(r)["data"]}


def builtin_path():
    """Resolve pi's baked-in catalog next to whatever `pi` currently is (survives upgrades)."""
    binary = shutil.which("pi") or "/run/current-system/sw/bin/pi"
    pkg = os.path.realpath(binary).split("/bin/")[0]
    return os.path.join(pkg, "lib/node_modules/pi-monorepo/node_modules/@earendil-works/"
                               "pi-ai/dist/providers/data/opencode-go.json")


def builtin_models():
    path = builtin_path()
    if not os.path.exists(path):
        return {}
    out = []

    def walk(o):
        if isinstance(o, dict):
            if "id" in o and "provider" in o:
                out.append(o)
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(json.load(open(path)))
    return {m["id"]: m for m in out}


SUPPORTED = {"openai-completions", "openai-responses", "anthropic-messages"}


def pick_api(live):
    api = API_MAP[next(iter(live["api"]))]
    # opencode-go provider in pi only registers these three APIs; Go's gateway
    # translates between them, so route anything else through chat completions.
    return api if api in SUPPORTED else "openai-completions"


def template(api, siblings):
    """Pick a sibling entry with the same api to inherit compat/thinking shape."""
    for s in siblings:
        if s.get("api") == api:
            return s
    return None


def build(live, existing, fallback):
    api = pick_api(live)
    base = copy.deepcopy(existing or fallback or {})
    cost = live["cost"]["text"]
    inp, out = cost["input"], cost["output"]
    cache = inp.get("cache", {})
    m = base if existing else {}
    m["id"] = live["id"]
    m["name"] = live["name"]
    m["provider"] = "opencode-go"
    m["api"] = api
    m["baseUrl"] = BASE[api]
    m["type"] = "chat"
    m["reasoning"] = bool(live["capabilities"].get("reasoning", {}).get("supported"))
    m["input"] = ["text"] + (["image"] if any(i.startswith("image") for i in live["modalities"]["input"]) else [])
    tiers = (existing or {}).get("cost", {}).get("tiers")
    m["cost"] = {"input": inp["price"], "output": out["price"],
                 "cacheRead": cache.get("read", 0), "cacheWrite": cache.get("write", 0)}
    if tiers:
        m["cost"]["tiers"] = tiers
    m["contextWindow"] = live["limit"]["context"]
    m["maxTokens"] = live["limit"]["output"]
    if "image" in m["input"] and "inputLimits" not in m:
        m["inputLimits"] = copy.deepcopy(IMG_LIMITS)

    if existing:
        # keep compat/thinking shape from the entry that already works; api/baseUrl
        # were just recomputed above so the provider can actually dispatch it
        return m

    # fresh entry: derive compat + thinkingLevelMap from api / advertised efforts
    effort = live["capabilities"].get("reasoning", {}).get("effort")
    if api == "openai-completions":
        m["compat"] = dict(OPENAI_COMPAT)
    elif api == "openai-responses":
        m["compat"] = {"sessionAffinityFormat": "openai-nosession"}
    if effort:
        m["thinkingLevelMap"] = {lvl: (lvl if lvl in effort else None) for lvl in ["off"] + ALL_LEVELS}
        if "none" in effort:
            m["thinkingLevelMap"]["off"] = "none"
    return m


def main():
    if not os.path.exists(STORE):
        print(f"{STORE} 不存在，跳过（这台机器还没用过 pi）")
        return
    live = fetch_live()
    store = json.load(open(STORE))
    entry = store["opencode-go"]
    builtin = builtin_models()
    old = {m["id"]: m for m in entry["models"]}
    known = {**builtin, **old}

    models, added, dropped = [], [], []
    for mid, lm in live.items():
        models.append(build(lm, known.get(mid), template(pick_api(lm), list(known.values()))))
        if mid not in old:
            added.append(mid)
    dropped = sorted(set(old) - set(live))

    entry["models"] = models
    entry["checkedAt"] = int(time.time() * 1000)
    # pi may be reading this file right now; replace atomically and keep 0600.
    tmp = f"{STORE}.tmp"
    with open(tmp, "w") as f:
        json.dump(store, f, indent=2, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, STORE)

    print(f"写入 {len(models)} 个模型（服务端实际在服）")
    print(f"新增 {len(added)}: {', '.join(added) or '-'}")
    print(f"移除 {len(dropped)}: {', '.join(dropped) or '-'}")


if __name__ == "__main__":
    main()
