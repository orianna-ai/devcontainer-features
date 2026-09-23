"""Run one Jev Ultrafast browser goal and print what it did as JSON.

Jev Ultrafast ships a library and a local inspector, not a goal-to-result command, so this is the
command: it takes a start URL and a goal, drives a browser until TypeSafe's Jev chooses DONE or
BLOCKED, and writes one JSON object to stdout. Progress goes to stderr, one line per decision.
With --jsonl, progress goes to stdout instead as one {"event": "step", ...} object per decision,
followed by the result as {"event": "result", ...}, so a caller can stream the run.

The browser is a fresh headless Chromium with a throwaway profile, unless BU_CDP_URL or BU_CDP_WS
names one to attach to instead. Browser Harness state lives in a temporary directory, so
concurrent runs never share a daemon.
"""

import argparse
import glob
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

_CHROME_NAMES = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable", "chrome")


def _chrome() -> str:
    """Find a Chrome or Chromium binary, preferring an explicit JEV_ULTRAFAST_CHROME."""
    explicit = os.environ.get("JEV_ULTRAFAST_CHROME")
    if explicit:
        return explicit
    browsers = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/usr/local/share/ms-playwright")
    for pattern in ("chromium-*/chrome-linux*/chrome", "chromium_headless_shell-*/chrome-*/*headless_shell"):
        matches = sorted(glob.glob(os.path.join(browsers, pattern)), reverse=True)
        if matches:
            return matches[0]
    for name in _CHROME_NAMES:
        found = shutil.which(name)
        if found:
            return found
    raise SystemExit("jev-ultrafast: no Chrome or Chromium found; set JEV_ULTRAFAST_CHROME")


def _launch(profile: Path, timeout: float) -> tuple[subprocess.Popen, str]:
    """Start headless Chromium on an ephemeral debugging port and return its HTTP endpoint.

    Chromium's sandbox is kept whenever the environment supports it. Root always needs
    ``--no-sandbox``, and so does a container without user namespaces, where a sandboxed launch
    exits at once. In those cases the launch retries unsandboxed and says so on stderr.
    ``JEV_ULTRAFAST_NO_SANDBOX=1`` skips the sandboxed attempt.
    """
    if os.geteuid() == 0 or os.environ.get("JEV_ULTRAFAST_NO_SANDBOX") == "1":
        return _start(profile, timeout, sandbox=False)
    try:
        return _start(profile, timeout, sandbox=True)
    except _SandboxUnavailable:
        print("jev-ultrafast: chromium's sandbox is unavailable here; running without it", file=sys.stderr)
        shutil.rmtree(profile, ignore_errors=True)
        return _start(profile, timeout, sandbox=False)


class _SandboxUnavailable(Exception):
    pass


def _start(profile: Path, timeout: float, *, sandbox: bool) -> tuple[subprocess.Popen, str]:
    process = subprocess.Popen(
        [
            _chrome(),
            "--headless=new",
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=0",
            f"--user-data-dir={profile}",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-dev-shm-usage",
            "--window-size=1120,780",
            *([] if sandbox else ["--no-sandbox"]),
            "about:blank",
        ],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    port_file = profile / "DevToolsActivePort"
    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            if process.poll() is not None:
                if sandbox:
                    raise _SandboxUnavailable()
                raise SystemExit(f"jev-ultrafast: chromium exited with {process.returncode} before it was ready")
            if port_file.exists():
                port = port_file.read_text().split("\n", 1)[0].strip()
                if port:
                    return process, f"http://127.0.0.1:{port}"
            time.sleep(0.05)
        raise SystemExit("jev-ultrafast: chromium did not open a debugging port in time")
    except BaseException:
        # The caller only owns the browser once this returns, so every other exit stops it here,
        # including the children of a leader that has already died.
        _stop(process)
        raise


def _stop(process: subprocess.Popen) -> None:
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=5)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


_ACTION_KEYS = ("action", "kind", "operation", "text", "url", "page_changed", "elapsed_ms")


def _action(entry: dict) -> dict:
    return {k: entry[k] for k in _ACTION_KEYS if k in entry}


def main() -> int:
    parser = argparse.ArgumentParser(prog="jev-ultrafast", description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--url", required=True, help="Page to start on.")
    parser.add_argument(
        "--goal", action="append", required=True, help="Natural-language goal. Repeat for an ordered list."
    )
    parser.add_argument("--max-text", type=int, default=4000, help="Characters of final page text to print.")
    parser.add_argument("--startup-timeout", type=float, default=30, help="Seconds to wait for Chromium.")
    parser.add_argument("--jsonl", action="store_true", help="Stream steps and the result as JSON lines.")
    args = parser.parse_args()

    # A caller that gives up sends SIGTERM; exit through the finally blocks so the browser this run
    # launched, which lives in its own session, is stopped too.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(128 + signal.SIGTERM))

    if not os.environ.get("TYPESAFE_API_KEY"):
        raise SystemExit("jev-ultrafast: TYPESAFE_API_KEY is not set")

    work = Path(tempfile.mkdtemp(prefix="jev-ultrafast-"))
    browser = None
    try:
        # Browser Harness reads these at import, so they must be set before jev_ultrafast loads.
        os.environ["BH_HOME"] = str(work / "harness")
        os.environ["BU_NAME"] = f"jev-{os.getpid()}"
        os.environ.setdefault("BH_TELEMETRY", "0")
        if not (os.environ.get("BU_CDP_URL") or os.environ.get("BU_CDP_WS")):
            browser, os.environ["BU_CDP_URL"] = _launch(work / "profile", args.startup_timeout)

        from browser_harness.admin import restart_daemon
        from jev_ultrafast import Agent

        try:
            with Agent(args.url, args.goal) as agent:
                error = None
                try:
                    for state in agent.run():
                        last = state["history"][-1] if state["history"] else {}
                        if args.jsonl:
                            step = {
                                "event": "step",
                                "status": state["status"],
                                "elapsed_ms": state["elapsed_ms"],
                                "url": state["page"].get("url"),
                                "action": _action(last) if last else None,
                            }
                            print(json.dumps(step, ensure_ascii=False), flush=True)
                        else:
                            print(
                                f"{state['elapsed_ms']:>6} ms  {state['status']:<8} {last.get('action', '')}",
                                file=sys.stderr,
                                flush=True,
                            )
                except (RuntimeError, ValueError) as e:
                    # Budgets, provider failures and an unsettled page end a run by raising; report
                    # what was done up to that point rather than a traceback.
                    error = f"{type(e).__name__}: {e}"
                state = agent.snapshot()
                page = state["page"]
                result = {
                    "status": "blocked" if error else state["status"],
                    "error": error,
                    "elapsed_ms": state["elapsed_ms"],
                    "url": page.get("url"),
                    "title": page.get("title"),
                    "text": (page.get("text") or "")[: args.max_text],
                    "actions": [_action(h) for h in state["history"]],
                    "decisions": len(state["decisions"]),
                    "text_calls": len(state["text_calls"]),
                }
        finally:
            restart_daemon(os.environ["BU_NAME"])
    finally:
        if browser is not None:
            _stop(browser)
        shutil.rmtree(work, ignore_errors=True)

    print(json.dumps({"event": "result", **result} if args.jsonl else result, ensure_ascii=False))
    return 0 if result["status"] == "done" else 2


if __name__ == "__main__":
    sys.exit(main())
