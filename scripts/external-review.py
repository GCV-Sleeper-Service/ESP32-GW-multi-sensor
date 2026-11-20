#!/usr/bin/env python3
"""Run review B from trusted code and template, reading PR text only as data."""

import base64
import binascii
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

LIMIT_CHARS = 600000
MODELS = {
    "gemini-4-hydrogen": ("LOW", "MEDIUM", "HIGH", "XHIGH"),
    "gemini-4-argon": ("LOW", "MEDIUM", "HIGH"),
    "gemini-4-carbon": ("LOW", "MEDIUM", "HIGH"),
    "claude-opus-5-5": (),
    "claude-sonnet-5-5": (),
}
GITHUB_ORIGIN = "https://api.github.com"
MODEL_ORIGIN = "https://aiplatform.googleapis.com"
GENERATED = {
    "dashboard/sensor_history_multi.h", "dashboard/dashboard.js",
    "dashboard/dashboard.html", "dashboard/dashboard.h", "src/gateway_manifest.h",
}


class Refused(Exception):
    """Input is unsuitable for review; no model request is made."""


class Failed(Exception):
    """A request or output failed; never include credentials in its message."""


def origin(url):
    parsed = urllib.parse.urlsplit(url)
    return parsed.scheme, parsed.hostname, parsed.port or (443 if parsed.scheme == "https" else 80)


class SameOriginRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if origin(req.full_url) != origin(newurl):
            raise Failed("redirect to another origin")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def request(url, token, *, payload=None, accept="application/vnd.github+json",
            turn=None, missing_file=False):
    method = "GET" if payload is None else "POST"
    path = urllib.parse.urlsplit(url).path
    label = f"the model call of turn {turn} failed" if turn else f"GitHub {method} {path}"
    headers = {"Authorization": "Bearer " + token, "Accept": accept}
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.build_opener(SameOriginRedirect()).open(
                req, timeout=600 if turn else 60) as response:
            body = response.read().decode("utf-8")
            return body, response.headers
    except urllib.error.HTTPError as error:
        if missing_file and error.code == 404:
            raise Refused("file not found at the pull request head") from None
        raise Failed(f"{label}: HTTP {error.code}") from None
    except (urllib.error.URLError, OSError, http.client.HTTPException, UnicodeError):
        if not turn and method == "POST":
            raise Failed(f"{label}: no answer; unknown whether the comment was posted") from None
        raise Failed(f"{label}: no answer") from None


def json_request(url, token, **kwargs):
    body, headers = request(url, token, **kwargs)
    try:
        return json.loads(body), headers
    except ValueError:
        raise Failed("request returned no answer in JSON") from None


def endpoint(value, default):
    if value == default:
        return value
    match = re.fullmatch(r"http://127\.0\.0\.1:([0-9]+)", value)
    if match and 1 <= int(match[1]) <= 65535:
        return value
    raise Refused("invalid API origin")


def plain_path(value):
    return bool(re.fullmatch(r"[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*", value)) and all(
        segment not in (".", "..") for segment in value.split("/"))


def inputs():
    values = {key: os.environ.get(key, "") for key in (
        "GITHUB_REPOSITORY", "GITHUB_TOKEN", "ER_PR", "ER_PROMPT_PATH", "ER_REVIEW_PATH",
        "ER_MODEL", "ER_THINKING_LEVEL", "ER_DRY_RUN", "ER_PROJECT_ID", "ER_PROFILE")}
    checks = (
        (re.fullmatch(r"[1-9][0-9]{0,6}", values["ER_PR"]), "PR number"),
        (plain_path(values["ER_PROMPT_PATH"]), "prompt path"),
        (not values["ER_REVIEW_PATH"] or plain_path(values["ER_REVIEW_PATH"]), "review path"),
        (values["ER_MODEL"] in MODELS and bool(MODELS[values["ER_MODEL"]]), "model"),
        (values["ER_THINKING_LEVEL"] in MODELS.get(values["ER_MODEL"], ()), "thinking level"),
        (values["ER_DRY_RUN"] in ("true", "false"), "dry run"),
        (re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", values["ER_PROJECT_ID"]), "project ID"),
        (re.fullmatch(r"[a-z][a-z0-9_]{0,19}", values["ER_PROFILE"]), "profile"),
        (re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", values["GITHUB_REPOSITORY"]), "repository"),
    )
    for valid, name in checks:
        if not valid:
            raise Refused("invalid " + name)
    values["GITHUB_API_URL"] = endpoint(os.environ.get("GITHUB_API_URL", GITHUB_ORIGIN), GITHUB_ORIGIN)
    values["ER_ENDPOINT"] = endpoint(os.environ.get("ER_ENDPOINT", MODEL_ORIGIN), MODEL_ORIGIN)
    return values


def pages(url, token, api):
    items, seen = [], set()
    while url:
        parsed = urllib.parse.urlsplit(url)
        query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
        query = [(key, value) for key, value in query if key != "per_page"]
        query.append(("per_page", "100"))
        url = urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))
        if origin(url) != origin(api):
            raise Failed("next link points to another origin")
        if url in seen:
            raise Failed("next page was already read")
        seen.add(url)
        data, headers = json_request(url, token)
        if not isinstance(data, list):
            raise Failed("GitHub list request returned no answer as a list")
        items.extend(data)
        next_url = None
        for link_header in headers.get_all("Link", []):
            for link in re.split(r",(?=\s*<)", link_header):
                match = re.fullmatch(r"\s*<([^>]+)>(.*)", link, re.S)
                if not match:
                    continue
                relation = re.search(r';\s*rel\s*=\s*(?:"([^"]*)"|([^;\s]+))', match[2], re.I)
                if relation and "next" in (relation[1] or relation[2] or "").split():
                    next_url = urllib.parse.urljoin(url, match[1])
        url = next_url
    return items


def read_file(api_repo, path, head, token):
    obj, _ = json_request(
        f"{api_repo}/contents/{path}?ref={urllib.parse.quote(head, safe='')}", token, missing_file=True)
    if not isinstance(obj, dict) or obj.get("type") != "file" or obj.get("encoding") != "base64":
        raise Refused("requested path is not a base64 file")
    try:
        encoded = obj["content"].replace("\r", "").replace("\n", "")
        raw = base64.b64decode(encoded, validate=True)
    except (KeyError, AttributeError, ValueError, binascii.Error):
        raise Refused("file is not valid base64") from None
    try:
        return raw.decode("utf-8")
    except UnicodeError:
        raise Refused("file is not UTF-8 text") from None


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def block(name, content):
    escaped = re.sub(r"(?m)^<<<", " <<<", content)
    return (f"<<<BEGIN UNTRUSTED DATA: {name} sha256={digest(content)}>>>\n"
            f"{escaped}\n<<<END UNTRUSTED DATA: {name}>>>")


def login_literal(line):
    # Keep the same matching rules as l11_literal in scripts/lint-prompts.sh.
    basic = r"author" r"ization:[\s]*basic[\s]+[\"'`]?[^\s$<{\"`'.*]"
    if re.search(basic, line, re.I):
        return True
    pattern = r'''(?:^|[^a-zA-Z0-9_-])(-u|--user)(?:\s+|=)?("[^"]*"|'[^']*'|[^\s"'|;&)]+)'''
    for match in re.finditer(pattern, line):
        value = match[2]
        if value.startswith(('"', "'")):
            value = value[1:]
        value = value.rstrip("\"'`")
        if ":" not in value:
            continue
        user, password = value.split(":", 1)
        if re.fullmatch(r"[A-Za-z0-9._@-]+", user):
            return True
        if user.startswith(("$", "<")) and password and not password.startswith(("$", "<")):
            return True
    return False


def screen(name, text, *, diff=False, answer=False):
    for number, line in enumerate(text.splitlines(), 1):
        if diff and line.startswith(("+", "-", " ")):
            line = line[1:]
        if login_literal(line):
            error = Failed if answer else Refused
            raise error(f"{name} line {number}: login literal")


def filter_diff(text):
    kept, omitted = [], []
    for section in re.split(r"(?m)(?=^diff --git )", text):
        first = section.split("\n", 1)[0]
        match = re.fullmatch(r"diff --git a/(.+) b/(.+)", first)
        if match and match[1] in GENERATED and match[2] in GENERATED:
            omitted.append(match[1])
        else:
            kept.append(section)
    return "".join(kept), omitted


def review_location(comment):
    line = comment.get("line")
    original = comment.get("original_line")
    if comment.get("subject_type") == "file" or (line is None and original is None):
        return "file"
    if line is None:
        return f"outdated, original line {original}"
    if comment.get("start_line") is not None:
        return f"lines {comment['start_line']} to {line}"
    return f"line {line}"


def review_comment(comment):
    entry = (f"{comment['id']} {comment['user']['login']} on {comment['path']} "
             f"{review_location(comment)} side {comment.get('side')} commit {comment.get('commit_id')} "
             f"original commit {comment.get('original_commit_id')}")
    if comment.get("in_reply_to_id") is not None:
        entry += f" reply to {comment['in_reply_to_id']}"
    return entry + ": " + (comment.get("body") or "")


def position(pr):
    return pr["head"]["sha"], pr["base"]["sha"], pr["base"]["ref"]


def confirm_position(url, token, initial):
    latest, _ = json_request(url, token)
    old, new = position(initial), position(latest)
    if old != new:
        raise Failed(f"the pull request moved: head {old[0]} -> {new[0]}, "
                     f"base commit {old[1]} -> {new[1]}, base branch {old[2]} -> {new[2]}")


def template():
    text = (Path(__file__).resolve().parent.parent / "Docs/templates/external-review-template.md").read_text(
        encoding="utf-8")
    blocks = {}
    for name in ("System", "Turn 1", "Turn 2", "Turn 3"):
        match = re.search(r"^## " + re.escape(name) + r"\n\n```text\n(.*?)\n```$", text, re.M | re.S)
        if not match:
            raise Failed("trusted template block missing")
        blocks[name] = match[1]
    return blocks


def clean(text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"&#(?:0*47|x0*2f);|&sol;", "/", text, flags=re.I)
    text = re.sub(r"@|&#(?:0*64|x0*40);|&commat;", "(at)", text, flags=re.I)
    return "\n".join(
        "› " + line if re.match(r"^[ \t>\-*+]*(?:[0-9]+[.)])?[ \t]*/", line) else line
        for line in text.split("\n"))


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as stream:
            stream.write(text + "\n")


def run():
    env = inputs()
    token = env["GITHUB_TOKEN"]
    api_repo = f"{env['GITHUB_API_URL']}/repos/{env['GITHUB_REPOSITORY']}"
    pr_url = f"{api_repo}/pulls/{env['ER_PR']}"
    pr, _ = json_request(pr_url, token)
    head, base, base_ref = position(pr)
    diff, _ = request(pr_url, token, accept="application/vnd.github.diff")
    files = pages(pr_url + "/files", token, env["GITHUB_API_URL"])
    reviews = pages(pr_url + "/reviews", token, env["GITHUB_API_URL"])
    review_comments = pages(pr_url + "/comments", token, env["GITHUB_API_URL"])
    comment_url = f"{api_repo}/issues/{env['ER_PR']}/comments"
    comments = pages(comment_url, token, env["GITHUB_API_URL"])
    prompt = read_file(api_repo, env["ER_PROMPT_PATH"], head, token)
    review = read_file(api_repo, env["ER_REVIEW_PATH"], head, token) if env["ER_REVIEW_PATH"] else None
    if len(files) < pr["changed_files"]:
        raise Refused("incomplete file list")
    screen("diff", diff, diff=True)
    filtered, omitted = filter_diff(diff)
    changed = "\n".join(
        f"renamed {item['previous_filename']} -> {item['filename']}" if item["status"] == "renamed"
        else f"{item['status']} {item['filename']}" for item in files)
    screen("pr-metadata", pr["title"])
    metadata = json.dumps({"number": pr["number"], "title": pr["title"], "state": pr["state"],
                           "base_ref": base_ref, "base_sha": base, "head": head}, ensure_ascii=False)
    data1 = [("agent-prompt", prompt)]
    if review is not None:
        data1.append(("review-file", review))
    data2 = [
        ("pr-metadata", metadata), ("pr-body", pr.get("body") or ""), ("changed-files", changed),
        ("diff", filtered),
        ("reviews", "\n\n".join(f"{item['user']['login']} {item['state']}: {item.get('body') or ''}" for item in reviews)),
        ("review-comments", "\n\n".join(review_comment(item) for item in review_comments)),
        ("comments", "\n\n".join(f"{item['user']['login']}: {item.get('body') or ''}" for item in comments)),
    ]
    for name, content in data1 + data2:
        screen(name, content, diff=name == "diff")
    wrapped1 = [block(name, content) for name, content in data1]
    wrapped2 = [block(name, content) for name, content in data2]
    size = sum(map(len, wrapped1 + wrapped2))
    if size > LIMIT_CHARS:
        raise Refused(f"input of {size} characters exceeds the limit of {LIMIT_CHARS}")
    tpl = template()
    confirm_position(pr_url, token, pr)
    contents, answers, usages = [], [], []
    model_url = (f"{env['ER_ENDPOINT']}/v1/projects/{env['ER_PROJECT_ID']}/locations/global/"
                 f"publishers/google/models/{env['ER_MODEL']}:generateContent")
    for turn in range(1, 4):
        text = tpl[f"Turn {turn}"]
        if turn in (1, 2):
            text += "\n\n" + "\n\n".join(wrapped1 if turn == 1 else wrapped2)
        contents.append({"role": "user", "parts": [{"text": text}]})
        try:
            result = subprocess.run(["gcloud", "auth", "print-access-token"],
                                    capture_output=True, text=True, timeout=60, check=True)
        except (OSError, subprocess.SubprocessError):
            raise Failed("gcloud auth print-access-token failed") from None
        access_token = result.stdout.strip()
        if not access_token:
            raise Failed("gcloud auth print-access-token failed")
        answer, _ = json_request(model_url, access_token, turn=turn, payload={
            "systemInstruction": {"parts": [{"text": tpl["System"]}]}, "contents": contents,
            "generationConfig": {"thinkingConfig": {"thinkingLevel": env["ER_THINKING_LEVEL"]}},
        })
        if not answer.get("candidates"):
            reason = answer.get("promptFeedback", {}).get("blockReason") or "no reason given"
            raise Failed(f"no answer (blocked: {reason})")
        candidate = answer["candidates"][0]
        if candidate.get("finishReason") != "STOP":
            raise Failed(f"the model stopped with {candidate.get('finishReason', 'no reason given')}")
        content = candidate.get("content", {})
        for part in content.get("parts", []):
            screen(f"turn {turn}", part.get("text", ""), answer=True)
        visible = "".join(part.get("text", "") for part in content.get("parts", []) if not part.get("thought"))
        if not visible.strip():
            raise Failed(f"turn {turn}: no answer")
        screen(f"turn {turn}", visible, answer=True)
        answers.append(visible)
        contents.append(content)
        usage = answer.get("usageMetadata") or {}
        usages.append(tuple(usage.get(key, 0) or 0 for key in (
            "promptTokenCount", "candidatesTokenCount", "thoughtsTokenCount")))
    def counts(values):
        return f"prompt {values[0]}, output {values[1]}, thinking {values[2]}"
    tokens = "; ".join(f"turn {n}: {counts(values)}" for n, values in enumerate(usages, 1))
    tokens += "; total: " + counts(tuple(sum(values[i] for values in usages) for i in range(3)))
    dry = env["ER_DRY_RUN"] == "true"
    review_field = f"`{env['ER_REVIEW_PATH']}` sha256 `{digest(review)}`" if review is not None else "none"
    omitted_field = ", ".join(f"`{path}`" for path in omitted) or "none"
    header = (
        f"## Review B - runner: {env['ER_MODEL']}, thinking {env['ER_THINKING_LEVEL']}"
        + (" (dry run)" if dry else "") + "\n\n"
        "| Field | Value |\n|---|---|\n"
        f"| Pull request | #{pr['number']}, head `{head}`, base `{base_ref}` at `{base}` |\n"
        f"| Profile | {env['ER_PROFILE']} |\n"
        f"| Model version | {answer.get('modelVersion', '')} |\n"
        f"| Tokens | {tokens} |\n"
        f"| Agent prompt | `{env['ER_PROMPT_PATH']}` sha256 `{digest(prompt)}` |\n"
        f"| Review file | {review_field} |\n"
        f"| Generated files left out | {omitted_field} |"
    )
    output = clean(header + "\n\n" + "\n\n".join(
        f"### Turn {n}\n\n{text}" for n, text in enumerate(answers, 1)))
    if len((output + "\n").encode("utf-8")) > 1000000:
        summary(clean(header))
        raise Failed("too long for the run summary")
    summary(output)
    if not dry:
        comment = clean(header + "\n\n" + answers[2])
        if len(comment) > 65000:
            raise Failed("the comment is too long")
        confirm_position(pr_url, token, pr)
        request(comment_url, token, payload={"body": comment})


def main():
    try:
        run()
        return 0
    except (Refused, Failed) as error:
        prefix, code = ("refused", 2) if isinstance(error, Refused) else ("failed", 1)
        message = f"external-review: {prefix}: " + " ".join(str(error).splitlines())
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        message, code = "external-review: failed: invalid response or local I/O failure", 1
    print(message, file=sys.stderr)
    try:
        summary(message)
    except OSError:
        pass
    return code


if __name__ == "__main__":
    sys.exit(main())
