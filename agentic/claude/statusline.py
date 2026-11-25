#!/usr/bin/env python3
# Claude Code status line (run by Claude Code via settings.json `statusLine`).
#
#   Opus medium · windo..al-rc/ [main] · ctx:76k · 5h:11% ~12:30 · week:2% cdx40% · session
#
# Reads status JSON from stdin, prints one line. Never raises.
# Testing: set STATUSLINE_NOW (epoch seconds), then run:
#   python3 agentic/claude/statusline.py < payload.json

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

# ======================= SETTINGS (edit here) =======================
# Colors are ANSI SGR codes: 36 cyan, 32 green, 33 yellow, 31 red.
CFG = {
    # ctx value (tokens in context): cyan up to CtxCyanUpTo (inclusive), green
    # above that until CtxYellowFrom, yellow from CtxYellowFrom up to
    # CtxRedAbove (inclusive), red above it.
    "CtxCyanUpTo": 80000,
    "CtxYellowFrom": 120000,
    "CtxRedAbove": 250000,

    # 5h percentage (rounded used %; the week percents use the Pace* colors
    # below instead): cyan up to PctCyanUpTo
    # (inclusive), green above that until PctYellowFrom, yellow from
    # PctYellowFrom up to (not including) PctRedFrom, red from there.
    "PctCyanUpTo": 25,
    "PctYellowFrom": 50,
    "PctRedFrom": 85,

    # 5h reset time color and week (claude and codex) percent color, by pace:
    #   ratio = (remaining% / minutesLeft) / (100 / totalMinutes)
    # 1.0 = quota is being used exactly at the sustainable rate; above 1 = under
    # pace, below 1 = burning too fast. cyan from PaceCyanFrom (inclusive), green
    # above PaceGreenAbove, yellow from PaceYellowFrom up to PaceGreenAbove
    # (inclusive), red below PaceYellowFrom.
    "PaceCyanFrom": 1.25,
    "PaceGreenAbove": 0.95,
    "PaceYellowFrom": 0.7,

    # 5h window: total length and time left are real minutes.
    "FiveHourTotalMin": 300,

    # Codex usage is fetched from the local Codex app-server in a background
    # process and cached; the server is queried at most once per this many seconds.
    "CodexCacheSec": 60,

    # Weekly window: total length and time left are weighted "working minutes"
    # in WorkTzName. Each minute in [WorkStartHour, WorkEndHour) counts
    # WeekdayWeight on Mon-Fri and WeekendWeight on Sat/Sun; others count 0.
    # Default total = 5*12*60*1.0 + 2*12*60*0.5 = 4320 (derived below).
    "WorkTzName": "America/Sao_Paulo",  # BRT
    "WorkTzOffsetHours": -3,             # UTC offset (h) if lookup fails
    "WorkStartHour": 7,
    "WorkEndHour": 19,
    "WeekdayWeight": 1.0,
    "WeekendWeight": 0.5,
}
# Weekly total derived from the settings above so it can't go stale.
CFG["WeekTotalMin"] = (CFG["WorkEndHour"] - CFG["WorkStartHour"]) * 60 * (
    5 * CFG["WeekdayWeight"] + 2 * CFG["WeekendWeight"])
# ====================================================================

ESC = "\x1b"
MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")


def get(obj, *keys):
    for key in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


def paint(code, value):
    return "%s[%dm%s%s[0m" % (ESC, code, value, ESC)


def ctx_color(tokens):
    if tokens > CFG["CtxRedAbove"]:
        return 31
    if tokens >= CFG["CtxYellowFrom"]:
        return 33
    if tokens <= CFG["CtxCyanUpTo"]:
        return 36
    return 32


def pct_color(percent):
    if percent >= CFG["PctRedFrom"]:
        return 31
    if percent >= CFG["PctYellowFrom"]:
        return 33
    if percent <= CFG["PctCyanUpTo"]:
        return 36
    return 32


def pace_color(ratio):
    if ratio >= CFG["PaceCyanFrom"]:
        return 36
    if ratio > CFG["PaceGreenAbove"]:
        return 32
    if ratio >= CFG["PaceYellowFrom"]:
        return 33
    return 31


def tok(value):
    # Python round, like .NET Math.Round, uses banker's rounding for ties.
    if value >= 1000000:
        return "%dM" % round(value / 1e6)
    if value >= 1000:
        return "%dk" % round(value / 1e3)
    return str(round(value))


def short(value):
    value = str(value)
    return value if len(value) <= 12 else value[:5] + ".." + value[-5:]


def work_timezone():
    try:
        from zoneinfo import ZoneInfo
        return ZoneInfo(CFG["WorkTzName"])
    except Exception:
        return timezone(timedelta(hours=CFG["WorkTzOffsetHours"]))


def work_minutes(start, end):
    tz = work_timezone()
    start, end = start.astimezone(tz), end.astimezone(tz)
    if end <= start:
        return 0.0
    total = 0.0
    day = start.date()
    while day <= end.date():
        ws = datetime(day.year, day.month, day.day, CFG["WorkStartHour"], tzinfo=tz)
        we = datetime(day.year, day.month, day.day, CFG["WorkEndHour"], tzinfo=tz)
        left, right = max(ws, start), min(we, end)
        if right > left:
            weight = CFG["WeekendWeight"] if day.weekday() >= 5 else CFG["WeekdayWeight"]
            total += (right - left).total_seconds() / 60.0 * weight
        day += timedelta(days=1)
    return total


def git_branch(directory):
    for args in (("branch", "--show-current"), ("rev-parse", "--short", "HEAD")):
        try:
            result = subprocess.run(("git", "-C", directory) + args,
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                    timeout=2, check=False)
            text = result.stdout.decode("utf-8", "replace").strip()
            if text:
                return text
        except Exception:
            pass
    return ""


def local_format(instant, fmt):
    local = instant.astimezone()
    if fmt == "HH:mm":
        return "%02d:%02d" % (local.hour, local.minute)
    return "%d%s" % (local.day, MONTHS[local.month - 1])


def pace_ratio(used, reset, total_minutes, weighted, now):
    missing = work_minutes(now, reset) if weighted else (reset - now).total_seconds() / 60.0
    return float("inf") if missing <= 0 else ((100 - used) / missing) / (100 / total_minutes)


def limit(label, window, fmt, total_minutes, weighted, now):
    # weighted (week) windows paint the percent by pace and omit the reset date;
    # the 5h window paints the percent by level and shows the reset time by pace.
    output = None
    try:
        if not isinstance(window, dict) or window.get("used_percentage") is None:
            return None
        used = float(window["used_percentage"])
        percent = round(used)
        text = "%d%%" % percent
        reset = None
        if window.get("resets_at") is not None:
            reset = datetime.fromtimestamp(int(window["resets_at"]), timezone.utc)
        ratio = pace_ratio(used, reset, total_minutes, weighted, now) if reset else None
        if weighted:
            color = pace_color(ratio) if ratio is not None else pct_color(percent)
            output = label + ":" + paint(color, text)
        else:
            output = label + ":" + paint(pct_color(percent), text)
            if ratio is not None:
                output += " " + paint(pace_color(ratio), "~" + local_format(reset, fmt))
    except Exception:
        pass
    return output


def codex_rate_limits(line):
    try:
        data = json.loads(line)
    except Exception:
        return None
    for candidate in (data, get(data, "payload"), get(data, "payload", "info")):
        limits = get(candidate, "rate_limits")
        if isinstance(limits, dict):
            return limits
    return None


def cache_dir():
    return os.environ.get("STATUSLINE_CACHE_DIR") or os.path.join(os.path.expanduser("~"), ".claude", "cache")


def parse_codex_rate_limits(result):
    # app-server `account/rateLimits/read` result -> {"used", "resets_at"} for
    # the weekly (10080 min) window, or None.
    snapshots = []
    if isinstance(get(result, "rateLimits"), dict):
        snapshots.append(result["rateLimits"])
    by_id = get(result, "rateLimitsByLimitId")
    if isinstance(by_id, dict):
        snapshots.extend(x for x in by_id.values() if isinstance(x, dict))
    for snapshot in snapshots:
        for name in ("primary", "secondary"):
            window = snapshot.get(name)
            if (isinstance(window, dict) and window.get("windowDurationMins") == 10080
                    and window.get("usedPercent") is not None and window.get("resetsAt") is not None):
                return {"used": float(window["usedPercent"]), "resets_at": int(window["resetsAt"])}
    return None


def codex_live_query():
    # Ask the local Codex app-server (JSON-RPC over stdio) for live usage.
    import shutil
    import threading
    binary = shutil.which("codex")
    if not binary:
        return None
    proc = subprocess.Popen([binary, "app-server"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    timer = threading.Timer(15, proc.kill)
    timer.start()
    try:
        for message in ({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                         "params": {"clientInfo": {"name": "claude-statusline", "version": "1"}}},
                        {"jsonrpc": "2.0", "method": "initialized"},
                        {"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"}):
            proc.stdin.write((json.dumps(message) + "\n").encode())
            proc.stdin.flush()
        while True:
            line = proc.stdout.readline()
            if not line:
                return None
            reply = json.loads(line)
            if reply.get("id") == 2:
                return parse_codex_rate_limits(reply.get("result"))
    finally:
        timer.cancel()
        proc.kill()


def refresh_codex():
    # --refresh-codex mode: query Codex and write the cache atomically. Never raises.
    try:
        found = codex_live_query()
        if not found:
            return
        found["fetched_at"] = int(now_time().timestamp())
        directory = cache_dir()
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, "codex-usage.json")
        temp = "%s.%d.tmp" % (path, os.getpid())
        with open(temp, "w") as handle:
            json.dump(found, handle)
        os.replace(temp, path)
    except Exception:
        pass


def read_codex_cache():
    try:
        with open(os.path.join(cache_dir(), "codex-usage.json")) as handle:
            data = json.load(handle)
        if float(data["used"]) >= 0 and int(data["resets_at"]) > 0 and float(data["fetched_at"]) > 0:
            return data
    except Exception:
        pass
    return None


def codex_cache_due(cache, now):
    return cache is None or now.timestamp() - float(cache["fetched_at"]) >= CFG["CodexCacheSec"]


def spawn_codex_refresh():
    # Detached background refresh; a lock file stops concurrent spawns for 30s.
    try:
        directory = cache_dir()
        os.makedirs(directory, exist_ok=True)
        lock = os.path.join(directory, "codex-usage.lock")
        if os.path.exists(lock) and datetime.now().timestamp() - os.path.getmtime(lock) < 30:
            return
        with open(lock, "w"):
            pass
        flags = {}
        if os.name == "nt":
            flags["creationflags"] = 0x00000008 | 0x00000200 | 0x08000000  # DETACHED, NEW_GROUP, NO_WINDOW
        else:
            flags["start_new_session"] = True
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "--refresh-codex"],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, **flags)
    except Exception:
        pass


def codex_week(now):
    # Weekly Codex window: (used_percent, reset datetime) or None. Never raises.
    # Live value comes from a cache refreshed in the background (CodexCacheSec);
    # session logs are the fallback when there is no cache.
    try:
        cache = read_codex_cache()
        if codex_cache_due(cache, now) and os.environ.get("STATUSLINE_CODEX_REFRESH") != "0":
            spawn_codex_refresh()
        if cache:
            reset = datetime.fromtimestamp(int(cache["resets_at"]), timezone.utc)
            return (0.0 if reset <= now else float(cache["used"])), reset
    except Exception:
        pass
    return codex_week_from_logs(now)


def codex_week_from_logs(now):
    # Latest weekly (10080 min) Codex window from its session logs:
    # returns (used_percent, reset datetime) or None. Never raises.
    try:
        root = os.path.join(os.environ.get("CODEX_HOME") or os.path.join(os.path.expanduser("~"), ".codex"),
                            "sessions")
        days = []
        for year in os.listdir(root):
            for month in os.listdir(os.path.join(root, year)):
                for day in os.listdir(os.path.join(root, year, month)):
                    days.append((year, month, day))
        days.sort(reverse=True)
        for year, month, day in days[:8]:
            folder = os.path.join(root, year, month, day)
            files = [os.path.join(folder, n) for n in os.listdir(folder)
                     if n.startswith("rollout-") and n.endswith(".jsonl")]
            files.sort(key=os.path.getmtime, reverse=True)
            for path in files:
                with open(path, "rb") as handle:
                    handle.seek(0, os.SEEK_END)
                    size = handle.tell()
                    handle.seek(max(0, size - 262144))
                    lines = handle.read().decode("utf-8", "replace").splitlines()
                for line in reversed(lines):
                    if '"rate_limits"' not in line:
                        continue
                    limits = codex_rate_limits(line)
                    for name in ("primary", "secondary"):
                        window = get(limits, name)
                        if not isinstance(window, dict) or window.get("window_minutes") != 10080:
                            continue
                        if window.get("used_percent") is None:
                            continue
                        used = float(window["used_percent"])
                        if window.get("resets_at") is not None:
                            reset = datetime.fromtimestamp(int(window["resets_at"]), timezone.utc)
                        elif window.get("resets_in_seconds") is not None:
                            reset = now + timedelta(seconds=float(window["resets_in_seconds"]))
                        else:
                            continue
                        return (0.0 if reset <= now else used), reset
        return None
    except Exception:
        return None


def codex_limit(now):
    try:
        found = codex_week(now)
        if not found:
            return None
        used, reset = found
        ratio = pace_ratio(used, reset, CFG["WeekTotalMin"], True, now)
        return "cdx" + paint(pace_color(ratio), "%d%%" % round(used))
    except Exception:
        return None


def now_time():
    override = os.environ.get("STATUSLINE_NOW")
    return datetime.fromtimestamp(int(override), timezone.utc) if override else datetime.now(timezone.utc)


def build(payload, now):
    parts = []
    model = get(payload, "model", "display_name")
    if model:
        effort = get(payload, "effort", "level")
        parts.append(str(model) + ((" " + str(effort)) if effort else ""))
    directory = get(payload, "workspace", "current_dir") or get(payload, "cwd")
    if directory:
        directory = str(directory)
        name = os.path.basename(os.path.normpath(directory))
        segment = short(name) + "/"
        branch = git_branch(directory)
        if branch:
            segment += " [" + short(branch) + "]"
        parts.append(segment)
    tokens = get(payload, "context_window", "total_input_tokens")
    if not tokens:
        usage = get(payload, "context_window", "current_usage")
        if usage:
            try:
                tokens = sum(float(usage.get(x) or 0) for x in
                             ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
            except Exception:
                tokens = 0
    try:
        tokens = float(tokens)
    except Exception:
        tokens = 0
    parts.append("ctx:" + (paint(ctx_color(tokens), tok(tokens)) if tokens > 0 else "--"))
    limits = get(payload, "rate_limits")
    five = limit("5h", get(limits, "five_hour"), "HH:mm", CFG["FiveHourTotalMin"], False, now)
    week = limit("week", get(limits, "seven_day"), "dMMM", CFG["WeekTotalMin"], True, now)
    if five:
        parts.append(five)
    codex = codex_limit(now)
    if week or codex:
        parts.append(" ".join(x for x in (week or "week:--", codex) if x))
    session = get(payload, "session_name")
    if session:
        parts.append(str(session))
    return " · ".join(parts)


def main():
    output = ""
    try:
        try:
            payload = json.loads(sys.stdin.buffer.read().decode("utf-8"))
        except Exception:
            payload = {}
        output = build(payload, now_time())
    except Exception:
        pass
    try:
        sys.stdout.buffer.write(output.encode("utf-8", "replace"))
    except Exception:
        pass


if __name__ == "__main__":
    if "--refresh-codex" in sys.argv[1:]:
        refresh_codex()
    else:
        main()
