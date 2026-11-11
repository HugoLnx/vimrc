#!/usr/bin/env python3
# Claude Code status line (run by Claude Code via settings.json `statusLine`).
#
#   Opus medium · windo..al-rc/ [main] · ctx:76k · 5h:11% ~12:30 · week:2% ~7Nov · session
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

    # 5h / week percentage (rounded used %): cyan up to PctCyanUpTo
    # (inclusive), green above that until PctYellowFrom, yellow from
    # PctYellowFrom up to (not including) PctRedFrom, red from there.
    "PctCyanUpTo": 25,
    "PctYellowFrom": 50,
    "PctRedFrom": 85,

    # Reset time/date color, by pace:
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


def limit(label, window, fmt, total_minutes, weighted, now):
    output = None
    try:
        if not isinstance(window, dict) or window.get("used_percentage") is None:
            return None
        used = float(window["used_percentage"])
        percent = round(used)
        output = label + ":" + paint(pct_color(percent), "%d%%" % percent)
        if window.get("resets_at") is not None:
            reset = datetime.fromtimestamp(int(window["resets_at"]), timezone.utc)
            missing = work_minutes(now, reset) if weighted else (reset - now).total_seconds() / 60.0
            ratio = float("inf") if missing <= 0 else ((100 - used) / missing) / (100 / total_minutes)
            output += " " + paint(pace_color(ratio), "~" + local_format(reset, fmt))
    except Exception:
        pass
    return output


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
    if week:
        parts.append(week)
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
    main()
