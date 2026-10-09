"""
Helper CLI para auditar y corregir worklogs (registros de tiempo) en Jira Cloud
via REST + API token. Usado por el skill jira-worklog-horarios.

Requiere variables de entorno: JIRA_BASE, JIRA_EMAIL, JIRA_TOKEN
(mismo helper que usa el skill jira-sprint-review).

Nota importante sobre zona horaria: Colombia es -05:00 todo el ano (sin horario
de verano), por eso el offset se hardcodea como "-0500". Jira Cloud EXIGE el
offset sin los dos puntos (p.ej. "-0500", NO "-05:00") o responde 400 Bad
Request con el mensaje "Formato de fecha no valido".

Subcomandos:
  myself
  list        --start YYYY-MM-DD --end YYYY-MM-DD [--account ACCOUNT_ID] [--out archivo.json]
  audit       --start YYYY-MM-DD --end YYYY-MM-DD [--account ACCOUNT_ID]
  update      --key KEY --id ID --start YYYY-MM-DDTHH:MM [--duration "Xh Ym"] [--comment "texto"]
  split       --key KEY --id ID --morning YYYY-MM-DDTHH:MM --morning-duration "Xh Ym"
                          --afternoon YYYY-MM-DDTHH:MM --afternoon-duration "Xh Ym" [--keep-comment]
  create      --key KEY --start YYYY-MM-DDTHH:MM --duration "Xh Ym" [--comment "texto"]
  worklogs-of --account ACCOUNT_ID --date YYYY-MM-DD --keys KEY1,KEY2,...
"""
import os
import sys
import json
import base64
import argparse
import datetime
import urllib.request
import urllib.parse
import urllib.error

TZ = "-0500"
LIMITE_INICIO = datetime.time(7, 30)
LIMITE_FIN = datetime.time(17, 0)
ALMUERZO_INI = datetime.time(13, 0)
ALMUERZO_FIN = datetime.time(14, 0)
DAILY_KEY = "IDR-98"


def _auth():
    base = os.environ["JIRA_BASE"]
    email = os.environ["JIRA_EMAIL"]
    token = os.environ["JIRA_TOKEN"]
    return base, base64.b64encode(f"{email}:{token}".encode()).decode()


def _call(method, url, body=None):
    base, auth = _auth()
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": f"Basic {auth}", "Accept": "application/json",
                 "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
        return json.loads(raw.decode()) if raw else {}


def _with_retry(fn, label, attempts=3):
    for i in range(attempts):
        try:
            return fn()
        except urllib.error.HTTPError as ex:
            body = ex.read().decode()
            print(f"HTTP {ex.code} en {label}: {body}", file=sys.stderr)
            return None
        except Exception as ex:
            print(f"RETRY {label} intento {i+1}: {ex}", file=sys.stderr)
    print(f"FALLO definitivo: {label}", file=sys.stderr)
    return None


def iso(date_str, time_str):
    return f"{date_str}T{time_str}:00.000{TZ}"


def comment_adf(text):
    if not text:
        return None
    return {"type": "doc", "version": 1,
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": text}]}]}


def comment_text(c):
    if not c:
        return ""
    if isinstance(c, str):
        return c.strip()
    texts = []

    def walk(node):
        if isinstance(node, dict):
            if node.get("type") == "text":
                texts.append(node.get("text", ""))
            for child in node.get("content", []):
                walk(child)
        elif isinstance(node, list):
            for n in node:
                walk(n)

    walk(c)
    return "".join(texts).strip()


def cmd_myself(args):
    base, _ = _auth()
    data = _call("GET", f"{base}/rest/api/3/myself")
    print(json.dumps({
        "accountId": data["accountId"],
        "displayName": data["displayName"],
        "email": data["emailAddress"],
    }, indent=2, ensure_ascii=False))


def _fetch_entries(base, account_id, start_date, end_date_exclusive, keys_filter=None):
    """Devuelve lista de worklogs de account_id en [start_date, end_date_exclusive)."""
    start_ms = int(start_date.timestamp() * 1000)
    end_ms = int(end_date_exclusive.timestamp() * 1000)

    if keys_filter:
        issues = [{"key": k, "fields": {"summary": ""}} for k in keys_filter]
    else:
        jql = (f'worklogAuthor = "{account_id}" AND worklogDate >= "{start_date.date()}" '
               f'AND worklogDate <= "{(end_date_exclusive - datetime.timedelta(days=1)).date()}" ORDER BY key')
        params = urllib.parse.urlencode({"jql": jql, "maxResults": 100, "fields": "summary"})
        search_url = f"{base}/rest/api/3/search/jql?{params}"
        issues = []
        next_token = None
        while True:
            url = search_url + (f"&nextPageToken={next_token}" if next_token else "")
            data = _call("GET", url)
            issues.extend(data.get("issues", []))
            next_token = data.get("nextPageToken")
            if not next_token:
                break

    all_entries = []
    for i in issues:
        key = i["key"]
        summary = i.get("fields", {}).get("summary", "")
        start_at = 0
        while True:
            url = (f"{base}/rest/api/3/issue/{key}/worklog?startedAfter={start_ms}"
                   f"&startedBefore={end_ms}&maxResults=100&startAt={start_at}")
            data = _call("GET", url)
            for w in data["worklogs"]:
                if w["author"]["accountId"] == account_id:
                    all_entries.append({
                        "key": key, "summary": summary, "started": w["started"],
                        "timeSpent": w["timeSpent"], "timeSpentSeconds": w["timeSpentSeconds"],
                        "comment": comment_text(w.get("comment")), "worklogId": w["id"],
                    })
            start_at += len(data["worklogs"])
            if start_at >= data["total"]:
                break

    all_entries.sort(key=lambda e: e["started"])
    return all_entries


def cmd_list(args):
    base, auth = _auth()
    account_id = args.account
    if not account_id:
        me = _call("GET", f"{base}/rest/api/3/myself")
        account_id = me["accountId"]

    start = datetime.datetime.fromisoformat(args.start)
    end_exclusive = datetime.datetime.fromisoformat(args.end) + datetime.timedelta(days=1)

    entries = _fetch_entries(base, account_id, start, end_exclusive)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(entries, f, indent=2, ensure_ascii=False)

    total_seconds = sum(e["timeSpentSeconds"] for e in entries)
    print(f"Total registros: {len(entries)}  |  Total horas: {total_seconds/3600:.2f}")
    for e in entries:
        print(f"{e['started'][:16]} | {e['key']:10s} | {e['timeSpent']:8s} | {e['comment'][:60]}")


def cmd_audit(args):
    base, _ = _auth()
    account_id = args.account
    if not account_id:
        me = _call("GET", f"{base}/rest/api/3/myself")
        account_id = me["accountId"]

    start = datetime.datetime.fromisoformat(args.start)
    end_exclusive = datetime.datetime.fromisoformat(args.end) + datetime.timedelta(days=1)
    entries = _fetch_entries(base, account_id, start, end_exclusive)

    cache_path = args.out or "jira_worklog_audit_cache.json"
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)

    print(f"[cache guardado en {cache_path} -- usalo para los comandos update/split]\n")

    vacias = [e for e in entries if not e["comment"].strip()]
    print(f"=== DESCRIPCIONES VACIAS: {len(vacias)} ===")
    for e in vacias:
        print(f"  {e['started'][:10]} | {e['key']:10s} | {e['timeSpent']:8s} | id={e['worklogId']}")

    print(f"\n=== FIN DE SEMANA ===")
    finde = []
    for e in entries:
        d = datetime.datetime.fromisoformat(e["started"])
        if d.weekday() >= 5:
            finde.append(e)
            print(f"  {e['started'][:10]} ({d.strftime('%A')}) | {e['key']:10s} | {e['timeSpent']:8s}")
    print(f"  Total: {len(finde)}")

    print(f"\n=== FUERA DE 7:30-17:00 O CRUZA ALMUERZO (13:00-14:00) ===")
    n = 0
    for e in entries:
        sdt = datetime.datetime.fromisoformat(e["started"])
        edt = sdt + datetime.timedelta(seconds=e["timeSpentSeconds"])
        st, et = sdt.time(), edt.time()
        problemas = []
        if st < LIMITE_INICIO:
            problemas.append(f"inicia antes de 7:30 ({st.strftime('%H:%M')})")
        if et > LIMITE_FIN and edt.date() == sdt.date():
            problemas.append(f"termina despues de 17:00 ({et.strftime('%H:%M')})")
        if edt.date() != sdt.date():
            problemas.append(f"cruza medianoche, termina {edt.strftime('%Y-%m-%d %H:%M')}")
        if st < ALMUERZO_FIN and et > ALMUERZO_INI:
            problemas.append("cruza el almuerzo 13:00-14:00")
        if problemas:
            n += 1
            print(f"  {e['started'][:10]} | {e['key']:10s} | inicio={st.strftime('%H:%M')} "
                  f"fin={et.strftime('%H:%M')} dur={e['timeSpent']:8s} -> {'; '.join(problemas)}")
    print(f"  Total: {n}")


def cmd_update(args):
    base, _ = _auth()
    started = iso(*args.start.split("T"))
    body = {"started": started}
    if args.duration:
        body["timeSpent"] = args.duration
    if args.comment:
        body["comment"] = comment_adf(args.comment)
    url = f"{base}/rest/api/3/issue/{args.key}/worklog/{args.id}?notifyUsers=false"
    res = _with_retry(lambda: _call("PUT", url, body), f"update {args.key}/{args.id}")
    print("OK" if res is not None else "FALLO", args.key, args.id, "->", started, body.get("timeSpent", ""))


def cmd_split(args):
    base, _ = _auth()
    entries = json.load(open(args.cache, encoding="utf-8")) if args.cache else None
    comment = None
    if args.keep_comment:
        if not entries:
            print("ERROR: --keep-comment requiere --cache con el worklog original", file=sys.stderr)
            sys.exit(1)
        match = [e for e in entries if e["key"] == args.key and e["worklogId"] == args.id]
        if not match:
            print("ERROR: no se encontro el worklogId en el cache", file=sys.stderr)
            sys.exit(1)
        comment = match[0]["comment"]

    m_date, m_time = args.morning.split("T")
    a_date, a_time = args.afternoon.split("T")

    url_put = f"{base}/rest/api/3/issue/{args.key}/worklog/{args.id}?notifyUsers=false"
    body_put = {"started": iso(m_date, m_time), "timeSpent": args.morning_duration}
    res = _with_retry(lambda: _call("PUT", url_put, body_put), f"split-manana {args.key}/{args.id}")
    print("OK" if res is not None else "FALLO", args.key, args.id, "MANANA ->", body_put["started"], body_put["timeSpent"])
    if res is None:
        return

    url_post = f"{base}/rest/api/3/issue/{args.key}/worklog?notifyUsers=false"
    body_post = {"started": iso(a_date, a_time), "timeSpent": args.afternoon_duration}
    if comment:
        body_post["comment"] = comment_adf(comment)
    res2 = _with_retry(lambda: _call("POST", url_post, body_post), f"split-tarde {args.key}")
    if res2 is not None:
        print("OK", args.key, "id nuevo=", res2["id"], "TARDE ->", body_post["started"], body_post["timeSpent"])
    else:
        print("FALLO", args.key, "TARDE")


def cmd_create(args):
    base, _ = _auth()
    d, t = args.start.split("T")
    body = {"started": iso(d, t), "timeSpent": args.duration}
    if args.comment:
        body["comment"] = comment_adf(args.comment)
    url = f"{base}/rest/api/3/issue/{args.key}/worklog?notifyUsers=false"
    res = _with_retry(lambda: _call("POST", url, body), f"create {args.key}")
    if res is not None:
        print("OK", args.key, "id=", res["id"], "->", body["started"], args.duration)
    else:
        print("FALLO", args.key)


def cmd_worklogs_of(args):
    base, _ = _auth()
    start = datetime.datetime.fromisoformat(args.date)
    end = start + datetime.timedelta(days=1)
    keys = args.keys.split(",")
    entries = _fetch_entries(base, args.account, start, end, keys_filter=keys)
    print(json.dumps(entries, indent=2, ensure_ascii=False))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("myself").set_defaults(func=cmd_myself)

    sp = sub.add_parser("list")
    sp.add_argument("--start", required=True)
    sp.add_argument("--end", required=True)
    sp.add_argument("--account")
    sp.add_argument("--out")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser("audit")
    sp.add_argument("--start", required=True)
    sp.add_argument("--end", required=True)
    sp.add_argument("--account")
    sp.add_argument("--out")
    sp.set_defaults(func=cmd_audit)

    sp = sub.add_parser("update")
    sp.add_argument("--key", required=True)
    sp.add_argument("--id", required=True)
    sp.add_argument("--start", required=True, help="YYYY-MM-DDTHH:MM")
    sp.add_argument("--duration")
    sp.add_argument("--comment")
    sp.set_defaults(func=cmd_update)

    sp = sub.add_parser("split")
    sp.add_argument("--key", required=True)
    sp.add_argument("--id", required=True)
    sp.add_argument("--morning", required=True, help="YYYY-MM-DDTHH:MM")
    sp.add_argument("--morning-duration", required=True)
    sp.add_argument("--afternoon", required=True, help="YYYY-MM-DDTHH:MM")
    sp.add_argument("--afternoon-duration", required=True)
    sp.add_argument("--keep-comment", action="store_true")
    sp.add_argument("--cache", help="json de 'audit'/'list', requerido con --keep-comment")
    sp.set_defaults(func=cmd_split)

    sp = sub.add_parser("create")
    sp.add_argument("--key", required=True)
    sp.add_argument("--start", required=True, help="YYYY-MM-DDTHH:MM")
    sp.add_argument("--duration", required=True)
    sp.add_argument("--comment")
    sp.set_defaults(func=cmd_create)

    sp = sub.add_parser("worklogs-of")
    sp.add_argument("--account", required=True)
    sp.add_argument("--date", required=True)
    sp.add_argument("--keys", required=True, help="KEY1,KEY2,...")
    sp.set_defaults(func=cmd_worklogs_of)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
