#!/usr/bin/env python3
"""Local developer analytics dashboard server."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import asc_analytics

ROOT = Path(__file__).resolve().parent
PORT = int(os.environ.get("DASHBOARD_PORT", "4000"))
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

SOURCES = [
    {
        "id": "app",
        "label": "AppAccount",
        "kind": "affiliate",
        "code": "app",
    },
    {
        "id": "download",
        "label": "Lennard TikTok & Insta",
        "kind": "affiliate",
        "code": "download",
    },
    {
        "id": "lennard",
        "label": "Lennard YT",
        "kind": "affiliate",
        "code": "lennard",
    },
    {
        "id": "lm10",
        "label": "Lucas TikTok & YT",
        "kind": "affiliate",
        "code": "lm10",
    },
    {
        "id": "reddit_ads",
        "label": "Reddit Ads",
        "kind": "reddit",
        "code": None,
    },
    {
        "id": "asc_search",
        "label": "App Store Search",
        "kind": "asc_search",
        "code": None,
    },
]

NOTES = [
    "App opens = onboarding_started (proxy tot er een dedicated app_open-event is).",
    "App Store Search: impressions / PP views / clicks / downloads via ASC Analytics API (Source Type = App Store search).",
    "Affiliate clicks = affiliate_stats.clicks (lifetime totals; niet gefilterd op date range).",
    "Affiliate downloads in de periode = attribution_received (niet lifetime affiliate_stats).",
    "Survey views = max(onboarding_step_viewed, onboarding_step_completed) per screen.",
    "Datums zijn UTC-dagen: from inclusief, to inclusief. ASC data kan 1–3 dagen vertraging hebben.",
]

# Canonical survey screens in onboarding order (matches lib/screens/survey.dart).
SURVEY_SCREENS: list[tuple[int, str]] = [
    (0, "intro"),
    (1, "goal"),
    (3, "biggest_challenge"),
    (4, "transformation_proof"),
    (8, "training_experience"),
    (9, "gym_confidence"),
    (10, "training_frequency"),
    (11, "available_days"),
    (12, "split_selection"),
    (13, "week_schedule_preview"),
    (14, "muscle_focus_depth_choice"),
    (15, "muscle_focus_simple"),
    (16, "muscle_priority"),
    (17, "plan_generation"),
    (18, "extra_help_features"),
    (19, "paywall_planned_workouts"),
    (20, "workout_notification_opt_in"),
    (22, "paywall_free_trial_intro"),
    (26, "paywall_guidance"),
    (27, "paywall_purchase"),
]


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        os.environ.setdefault(key, value)


def supabase_config() -> tuple[str | None, str | None]:
    url = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
    key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY")
        or ""
    )
    if not url or not key:
        return None, None
    return url, key


def using_anon_key() -> bool:
    return not (os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()


def supabase_request(
    method: str,
    path: str,
    *,
    params: list[tuple[str, str]] | dict[str, str] | None = None,
    prefer: str | None = None,
    body: dict | None = None,
) -> tuple[int, dict[str, str], bytes]:
    base, key = supabase_config()
    if not base or not key:
        raise RuntimeError(
            "Set SUPABASE_URL and SUPABASE_ANON_KEY (or SERVICE_ROLE_KEY) in DASHBOARD/.env"
        )

    if params is None:
        query = ""
    elif isinstance(params, dict):
        query = f"?{urllib.parse.urlencode(params)}"
    else:
        query = f"?{urllib.parse.urlencode(params)}"

    url = f"{base}{path}{query}"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, dict(resp.headers), resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers), exc.read()


def utc_today() -> date:
    return datetime.now(timezone.utc).date()


def default_range() -> tuple[date, date]:
    """Last 7 UTC days including today."""
    end = utc_today()
    start = end - timedelta(days=6)
    return start, end


def parse_date(value: str | None, field: str) -> date:
    if not value or not DATE_RE.match(value):
        raise ValueError(f"Invalid {field}: expected YYYY-MM-DD")
    return date.fromisoformat(value)


def resolve_range(from_raw: str | None, to_raw: str | None) -> tuple[date, date]:
    if not from_raw and not to_raw:
        return default_range()
    start = parse_date(from_raw, "from")
    end = parse_date(to_raw, "to")
    if end < start:
        raise ValueError("`to` must be on or after `from`")
    if (end - start).days > 366:
        raise ValueError("Date range cannot exceed 366 days")
    return start, end


def range_bounds(start: date, end: date) -> tuple[str, str]:
    """Inclusive calendar days → [from, to) ISO timestamps in UTC."""
    from_iso = datetime(start.year, start.month, start.day, tzinfo=timezone.utc).isoformat()
    to_exclusive = end + timedelta(days=1)
    to_iso = datetime(
        to_exclusive.year, to_exclusive.month, to_exclusive.day, tzinfo=timezone.utc
    ).isoformat()
    return from_iso, to_iso


def count_events(
    *,
    from_iso: str,
    to_iso: str,
    **filters: str,
) -> int:
    params: list[tuple[str, str]] = [
        ("select", "id"),
        ("created_at", f"gte.{from_iso}"),
        ("created_at", f"lt.{to_iso}"),
    ]
    params.extend((k, v) for k, v in filters.items())
    status, headers, body = supabase_request(
        "GET",
        "/rest/v1/analytics_events",
        params=params,
        prefer="count=exact",
    )
    if status >= 400:
        raise RuntimeError(f"analytics_events count failed ({status}): {body.decode()}")
    content_range = headers.get("Content-Range") or headers.get("content-range") or ""
    if "/" in content_range:
        total = content_range.split("/")[-1]
        if total != "*":
            return int(total)
    return 0


def analytics_user_key(row: dict) -> str:
    return str(row.get("analytics_user_id") or row.get("anonymous_id") or "").strip()


def parse_event_created_at(value: str | None) -> datetime | None:
    raw = str(value or "").strip()
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def fetch_analytics_events(
    *,
    select: str,
    from_iso: str,
    to_iso: str,
    event_name: str | None = None,
    platform: str | None = None,
    extra_params: list[tuple[str, str]] | None = None,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    page_size = 1000
    while True:
        params: list[tuple[str, str]] = [
            ("select", select),
            ("created_at", f"gte.{from_iso}"),
            ("created_at", f"lt.{to_iso}"),
            ("limit", str(page_size)),
            ("offset", str(offset)),
        ]
        if event_name:
            params.append(("event_name", f"eq.{event_name}"))
        if platform:
            params.append(("platform", f"eq.{platform}"))
        if extra_params:
            params.extend(extra_params)
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=params,
        )
        if status >= 400:
            raise RuntimeError(
                f"analytics_events fetch failed ({status}): {body.decode()}"
            )
        batch = json.loads(body.decode() or "[]")
        rows.extend(batch)
        if len(batch) < page_size:
            break
        offset += page_size
    return rows


def count_unique_event_users(
    *,
    from_iso: str,
    to_iso: str,
    event_name: str,
    platform: str | None = None,
    **filters: str,
) -> int:
    users: set[str] = set()
    offset = 0
    page_size = 1000
    while True:
        params: list[tuple[str, str]] = [
            ("select", "analytics_user_id,anonymous_id"),
            ("event_name", f"eq.{event_name}"),
            ("created_at", f"gte.{from_iso}"),
            ("created_at", f"lt.{to_iso}"),
            ("limit", str(page_size)),
            ("offset", str(offset)),
        ]
        if platform:
            params.append(("platform", f"eq.{platform}"))
        params.extend((k, v) for k, v in filters.items())
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=params,
        )
        if status >= 400:
            raise RuntimeError(
                f"analytics_events unique user count failed ({status}): {body.decode()}"
            )
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            user_id = analytics_user_key(row)
            if user_id:
                users.add(user_id)
        if len(rows) < page_size:
            break
        offset += page_size
    return len(users)


def count_unique_affiliate_event_users(
    *,
    affiliate_code: str,
    event_name: str,
    from_iso: str,
    to_iso: str,
) -> int:
    users: set[str] = set()
    code = affiliate_code.lower()
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=[
                ("select", "analytics_user_id,anonymous_id,campaign,properties"),
                ("event_name", f"eq.{event_name}"),
                ("created_at", f"gte.{from_iso}"),
                ("created_at", f"lt.{to_iso}"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            raise RuntimeError(
                f"affiliate unique user count failed ({status}): {body.decode()}"
            )
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            campaign = str(row.get("campaign") or "").strip().lower()
            props = row.get("properties") or {}
            prop_code = str(props.get("affiliate_code") or "").strip().lower()
            if campaign != code and prop_code != code:
                continue
            user_id = analytics_user_key(row)
            if user_id:
                users.add(user_id)
        if len(rows) < page_size:
            break
        offset += page_size
    return len(users)


def count_unique_event_users_in_cohort(
    *,
    event_name: str,
    user_ids: set[str],
    from_iso: str,
    to_iso: str,
) -> int:
    if not user_ids:
        return 0
    matched: set[str] = set()
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=[
                ("select", "analytics_user_id,anonymous_id"),
                ("event_name", f"eq.{event_name}"),
                ("created_at", f"gte.{from_iso}"),
                ("created_at", f"lt.{to_iso}"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            raise RuntimeError(
                f"cohort unique user count failed ({status}): {body.decode()}"
            )
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            user_id = analytics_user_key(row)
            if user_id and user_id in user_ids:
                matched.add(user_id)
        if len(rows) < page_size:
            break
        offset += page_size
    return len(matched)


def fetch_affiliate_clicks(codes: list[str]) -> dict[str, int]:
    in_list = "(" + ",".join(codes) + ")"
    status, _, body = supabase_request(
        "GET",
        "/rest/v1/affiliate_stats",
        params={
            "select": "affiliate_code,clicks",
            "affiliate_code": f"in.{in_list}",
        },
    )
    if status >= 400:
        return {}
    rows = json.loads(body.decode() or "[]")
    out: dict[str, int] = {}
    for row in rows:
        code = str(row.get("affiliate_code") or "").strip().lower()
        if code:
            out[code] = int(row.get("clicks") or 0)
    return out


def fetch_reddit_user_ids(to_iso: str) -> set[str]:
    status, _, body = supabase_request(
        "GET",
        "/rest/v1/analytics_events",
        params=[
            ("select", "analytics_user_id,anonymous_id"),
            ("event_name", "eq.reddit_install_attributed"),
            ("created_at", f"lt.{to_iso}"),
        ],
    )
    if status >= 400:
        raise RuntimeError(f"reddit users fetch failed ({status}): {body.decode()}")
    rows = json.loads(body.decode() or "[]")
    users: set[str] = set()
    for row in rows:
        uid = analytics_user_key(row)
        if uid:
            users.add(uid)
    return users


def metric(value: int | None, status: str) -> dict:
    return {"value": value, "status": status}


def empty_asc_row(source: dict, *, status: str = "pending_asc_api") -> dict:
    return {
        "id": source["id"],
        "label": source["label"],
        "impressions": metric(None, status),
        "product_page_views": metric(None, status),
        "clicks": metric(None, status),
        "downloads": metric(None, status),
        "app_opens": metric(None, "unavailable"),
        "paywall_views": metric(None, "unavailable"),
        "subscriptions": metric(None, "unavailable"),
    }


def build_asc_search_row(start: date, end: date) -> dict:
    source = next(s for s in SOURCES if s["id"] == "asc_search")
    if not asc_analytics.asc_configured():
        return empty_asc_row(source, status="pending_asc_api")
    try:
        data = asc_analytics.fetch_app_store_search_metrics(start, end)
        return {
            "id": source["id"],
            "label": source["label"],
            "impressions": metric(int(data["impressions"]), "ok"),
            "product_page_views": metric(int(data["product_page_views"]), "ok"),
            "clicks": metric(int(data["clicks"]), "ok"),
            "downloads": metric(int(data["downloads"]), "ok"),
            "app_opens": metric(None, "unavailable"),
            "paywall_views": metric(None, "unavailable"),
            "subscriptions": metric(None, "unavailable"),
        }
    except asc_analytics.AscPendingError as exc:
        row = empty_asc_row(source, status="pending_asc_api")
        row["asc_message"] = str(exc)
        return row
    except Exception as exc:  # noqa: BLE001
        row = empty_asc_row(source, status="error")
        row["asc_message"] = str(exc)
        return row


def enrich_with_asc_search(sources: list[dict], start: date, end: date) -> list[dict]:
    asc_row = build_asc_search_row(start, end)
    out: list[dict] = []
    for row in sources:
        if row.get("id") == "asc_search":
            out.append(asc_row)
        else:
            out.append(row)
    return out


def placeholder_asc_row() -> dict:
    source = next(s for s in SOURCES if s["id"] == "asc_search")
    return empty_asc_row(source, status="loading")


def with_placeholder_asc(sources: list[dict]) -> list[dict]:
    out: list[dict] = []
    for row in sources:
        if row.get("id") == "asc_search":
            out.append(placeholder_asc_row())
        else:
            out.append(row)
    if not any(r.get("id") == "asc_search" for r in out):
        out.append(placeholder_asc_row())
    return out


def map_rpc_rows(rows: list[dict]) -> list[dict]:
    mapped: list[dict] = []
    for row in rows:
        mapped.append(
            {
                "id": row["source_id"],
                "label": row["source_label"],
                "impressions": metric(
                    row.get("impressions"),
                    row.get("impressions_status") or "unavailable",
                ),
                "product_page_views": metric(
                    row.get("product_page_views"),
                    row.get("product_page_views_status") or "unavailable",
                ),
                "clicks": metric(
                    row.get("clicks"),
                    row.get("clicks_status") or "unavailable",
                ),
                "downloads": metric(
                    row.get("downloads"), row.get("downloads_status") or "ok"
                ),
                "app_opens": metric(
                    row.get("app_opens"), row.get("app_opens_status") or "ok"
                ),
                "paywall_views": metric(
                    row.get("paywall_views"),
                    row.get("paywall_views_status") or "ok",
                ),
                "subscriptions": metric(
                    row.get("subscriptions"),
                    row.get("subscriptions_status") or "ok",
                ),
            }
        )
    return mapped


def build_funnel_via_rpc(from_iso: str, to_iso: str) -> list[dict] | None:
    last_status = 0
    last_msg = ""
    for attempt in range(3):
        try:
            status, _, body = supabase_request(
                "POST",
                "/rest/v1/rpc/dashboard_acquisition_funnel",
                body={"p_from": from_iso, "p_to": to_iso},
            )
        except (TimeoutError, urllib.error.URLError) as exc:
            last_msg = str(exc)
            if attempt < 2:
                time.sleep(0.4 * (attempt + 1))
                continue
            if using_anon_key():
                raise RuntimeError(
                    "Acquisition funnel RPC timed out. Refresh the page."
                ) from exc
            return None

        if status == 404:
            raise RuntimeError(
                "RPC ontbreekt. Run DASHBOARD/sql/dashboard_acquisition_funnel.sql "
                "in de Supabase SQL Editor, daarna Refresh."
            )
        if status < 400:
            rows = json.loads(body.decode() or "[]")
            return map_rpc_rows(rows)

        last_status = status
        msg = body.decode(errors="replace")[:240]
        last_msg = msg
        if "Invalid API key" in msg:
            raise RuntimeError(
                "Supabase API key ongeldig. Gebruik SUPABASE_ANON_KEY of een verse "
                "service_role key uit Project Settings → API."
            )
        if "PGRST202" in msg:
            raise RuntimeError(
                "RPC-signature mismatch. Run DASHBOARD/sql/dashboard_acquisition_funnel.sql "
                "opnieuw in de Supabase SQL Editor."
            )
        if status >= 500 or status == 429:
            if attempt < 2:
                time.sleep(0.4 * (attempt + 1))
                continue
        break

    if using_anon_key():
        raise RuntimeError(
            "Acquisition funnel RPC failed "
            f"(HTTP {last_status}). Refresh the page. "
            "If this keeps happening, re-run "
            "DASHBOARD/sql/dashboard_acquisition_funnel.sql in Supabase."
            + (f" ({last_msg[:100]})" if last_msg else "")
        )
    return None


def build_funnel_via_rest(from_iso: str, to_iso: str) -> list[dict]:
    if using_anon_key():
        raise RuntimeError(
            "Anon key kan analytics niet direct lezen (RLS). "
            "Run DASHBOARD/sql/dashboard_acquisition_funnel.sql in Supabase."
        )
    reddit_users: set[str] | None = None
    affiliate_codes = [s["code"] for s in SOURCES if s["kind"] == "affiliate" and s["code"]]
    affiliate_clicks = fetch_affiliate_clicks(affiliate_codes)
    rows: list[dict] = []

    for source in SOURCES:
        if source["kind"] == "asc_search":
            rows.append(empty_asc_row(source))
            continue

        if source["kind"] == "affiliate":
            code = source["code"]
            assert code is not None
            downloads = count_unique_affiliate_event_users(
                affiliate_code=code,
                event_name="attribution_received",
                from_iso=from_iso,
                to_iso=to_iso,
            )
            app_opens = count_unique_affiliate_event_users(
                affiliate_code=code,
                event_name="onboarding_started",
                from_iso=from_iso,
                to_iso=to_iso,
            )
            paywall_views = count_unique_affiliate_event_users(
                affiliate_code=code,
                event_name="paywall_viewed",
                from_iso=from_iso,
                to_iso=to_iso,
            )
            subscriptions = count_unique_affiliate_event_users(
                affiliate_code=code,
                event_name="purchase_success",
                from_iso=from_iso,
                to_iso=to_iso,
            )
            clicks = affiliate_clicks.get(code, 0)
            rows.append(
                {
                    "id": source["id"],
                    "label": source["label"],
                    "impressions": metric(None, "unavailable"),
                    "product_page_views": metric(None, "unavailable"),
                    "clicks": metric(clicks, "ok"),
                    "downloads": metric(downloads, "ok"),
                    "app_opens": metric(app_opens, "ok"),
                    "paywall_views": metric(paywall_views, "ok"),
                    "subscriptions": metric(subscriptions, "ok"),
                }
            )
            continue

        if source["kind"] == "reddit":
            if reddit_users is None:
                reddit_users = fetch_reddit_user_ids(to_iso)
            downloads = count_unique_event_users(
                from_iso=from_iso,
                to_iso=to_iso,
                event_name="reddit_install_attributed",
            )
            app_opens = count_unique_event_users_in_cohort(
                event_name="onboarding_started",
                user_ids=reddit_users,
                from_iso=from_iso,
                to_iso=to_iso,
            )
            paywall_views = count_unique_event_users_in_cohort(
                event_name="paywall_viewed",
                user_ids=reddit_users,
                from_iso=from_iso,
                to_iso=to_iso,
            )
            subscriptions = count_unique_event_users_in_cohort(
                event_name="purchase_success",
                user_ids=reddit_users,
                from_iso=from_iso,
                to_iso=to_iso,
            )
            rows.append(
                {
                    "id": source["id"],
                    "label": source["label"],
                    "impressions": metric(None, "unavailable"),
                    "product_page_views": metric(None, "unavailable"),
                    "clicks": metric(None, "unavailable"),
                    "downloads": metric(downloads, "ok"),
                    "app_opens": metric(app_opens, "ok"),
                    "paywall_views": metric(paywall_views, "ok"),
                    "subscriptions": metric(subscriptions, "ok"),
                }
            )

    return rows


def error_row(source: dict) -> dict:
    if source["kind"] == "asc_search":
        return empty_asc_row(source)
    return {
        "id": source["id"],
        "label": source["label"],
        "impressions": metric(None, "unavailable"),
        "product_page_views": metric(None, "unavailable"),
        "clicks": metric(None, "unavailable"),
        "downloads": metric(None, "error"),
        "app_opens": metric(None, "error"),
        "paywall_views": metric(None, "error"),
        "subscriptions": metric(None, "error"),
    }


def fetch_survey_step_views(from_iso: str, to_iso: str) -> list[dict[str, Any]]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_survey_step_views",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        return [
            {
                "step_index": int(row["step_index"]),
                "screen": row["screen"],
                "views": int(row.get("views") or 0),
            }
            for row in rows
        ]

    # REST fallback: unique users per step_name.
    screen_users: dict[str, set[str]] = {name: set() for _, name in SURVEY_SCREENS}
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=[
                ("select", "event_name,properties,analytics_user_id,anonymous_id"),
                ("event_name", "in.(onboarding_step_viewed,onboarding_step_completed)"),
                ("created_at", f"gte.{from_iso}"),
                ("created_at", f"lt.{to_iso}"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            break
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            props = row.get("properties") or {}
            name = str(props.get("step_name") or "").strip()
            if name not in screen_users:
                continue
            user_id = analytics_user_key(row)
            if user_id:
                screen_users[name].add(user_id)
        if len(rows) < page_size:
            break
        offset += page_size

    return [
        {
            "step_index": index,
            "screen": name,
            "views": len(screen_users[name]),
        }
        for index, name in SURVEY_SCREENS
    ]


OVERALL_FUNNEL_KEYS = (
    "clicks",
    "downloads",
    "survey_started",
    "survey_ended",
    "paywall_views",
    "plan_selected",
    "subscriptions",
)

OVERALL_EVENT_NAMES = {
    "downloads": "attribution_received",
    "survey_started": "onboarding_started",
    "survey_ended": "onboarding_completed",
    "paywall_views": "paywall_viewed",
    "plan_selected": "paywall_plan_selected",
    "subscriptions": "purchase_success",
}


def empty_overall_funnel() -> dict[str, int]:
    return {key: 0 for key in OVERALL_FUNNEL_KEYS}


def count_affiliate_click_events(
    from_iso: str, to_iso: str, *, platform: str | None = None
) -> int:
    params: list[tuple[str, str]] = [
        ("select", "id"),
        ("occurred_at", f"gte.{from_iso}"),
        ("occurred_at", f"lt.{to_iso}"),
    ]
    if platform:
        params.append(("platform", f"eq.{platform}"))
    status, headers, body = supabase_request(
        "GET",
        "/rest/v1/affiliate_click_events",
        params=params,
        prefer="count=exact",
    )
    if status >= 400:
        return 0
    content_range = headers.get("Content-Range") or headers.get("content-range") or ""
    if "/" in content_range:
        total = content_range.split("/")[-1]
        if total != "*" and total.isdigit():
            return int(total)
    return 0


def fetch_overall_funnel(from_iso: str, to_iso: str) -> dict[str, int]:
    empty = empty_overall_funnel()
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_overall_funnel",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        if not rows:
            return empty
        row = rows[0] if isinstance(rows, list) else rows
        return {key: int(row.get(key) or 0) for key in OVERALL_FUNNEL_KEYS}

    # REST fallback (needs service role under RLS).
    result = dict(empty)
    for key, event_name in OVERALL_EVENT_NAMES.items():
        result[key] = count_unique_event_users(
            from_iso=from_iso,
            to_iso=to_iso,
            event_name=event_name,
        )
    result["clicks"] = count_affiliate_click_events(from_iso, to_iso)
    return result


def _empty_overall_funnel_by_platform() -> list[dict[str, Any]]:
    return [
        {"platform": platform, **empty_overall_funnel()}
        for platform in PLATFORM_FUNNEL_PLATFORMS
    ]


def merge_platform_funnel_into_overall_by_platform(
    overall_by_platform: list[dict[str, Any]],
    platform_funnel: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Fill iOS/Android overall metrics from the platform funnel RPC."""
    pf_map = {
        str(row.get("platform") or "").lower(): row for row in platform_funnel
    }
    by_platform = {
        str(row.get("platform") or "").lower(): dict(row)
        for row in (overall_by_platform or _empty_overall_funnel_by_platform())
    }

    merged: list[dict[str, Any]] = []
    for platform in PLATFORM_FUNNEL_PLATFORMS:
        row = {**empty_overall_funnel(), **by_platform.get(platform, {})}
        row["platform"] = platform
        pf = pf_map.get(platform) or {}
        if pf.get("onboarding_started") is not None:
            row["survey_started"] = int(pf.get("onboarding_started") or 0)
        if pf.get("paywall_views") is not None:
            row["paywall_views"] = int(pf.get("paywall_views") or 0)
        if pf.get("subscriptions") is not None:
            row["subscriptions"] = int(pf.get("subscriptions") or 0)
        if pf.get("plan_selected") is not None:
            row["plan_selected"] = int(pf.get("plan_selected") or 0)
        merged.append(row)
    return merged


def fetch_overall_funnel_by_platform(from_iso: str, to_iso: str) -> list[dict[str, Any]]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_overall_funnel_by_platform",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        by_platform = {
            str(row.get("platform") or "").lower(): row for row in rows if row.get("platform")
        }
        out: list[dict[str, Any]] = []
        for platform in PLATFORM_FUNNEL_PLATFORMS:
            row = by_platform.get(platform) or {}
            out.append(
                {
                    "platform": platform,
                    **{key: int(row.get(key) or 0) for key in OVERALL_FUNNEL_KEYS},
                }
            )
        return out

    if using_anon_key():
        return merge_platform_funnel_into_overall_by_platform(
            _empty_overall_funnel_by_platform(),
            fetch_platform_funnel(from_iso, to_iso),
        )

    out: list[dict[str, Any]] = []
    for platform in PLATFORM_FUNNEL_PLATFORMS:
        result = dict(empty_overall_funnel())
        for key, event_name in OVERALL_EVENT_NAMES.items():
            result[key] = count_unique_event_users(
                from_iso=from_iso,
                to_iso=to_iso,
                event_name=event_name,
                platform=platform,
            )
        result["clicks"] = count_affiliate_click_events(
            from_iso, to_iso, platform=platform
        )
        out.append({"platform": platform, **result})
    return out


def _empty_plan_counts() -> dict[str, int]:
    return {"monthly": 0, "quarterly": 0, "yearly": 0, "lifetime": 0}


def _parse_plan_selected_row(row: dict) -> dict[str, dict[str, int]]:
    selected = _empty_plan_counts()
    unique = _empty_plan_counts()
    for plan in selected:
        selected[plan] = int(row.get(plan) or 0)
        unique[plan] = int(row.get(f"unique_{plan}") or 0)
    return {"selected": selected, "unique": unique}


def _empty_subscription_plan_split() -> dict[str, dict[str, int]]:
    empty = {"monthly": 0, "yearly": 0}
    return {
        "total": dict(empty),
        "ios": dict(empty),
        "android": dict(empty),
    }


def _parse_subscription_plan_split_row(row: dict) -> dict[str, dict[str, int]]:
    return {
        "total": {
            "monthly": int(row.get("monthly") or 0),
            "yearly": int(row.get("yearly") or 0),
        },
        "ios": {
            "monthly": int(row.get("ios_monthly") or 0),
            "yearly": int(row.get("ios_yearly") or 0),
        },
        "android": {
            "monthly": int(row.get("android_monthly") or 0),
            "yearly": int(row.get("android_yearly") or 0),
        },
    }


def fetch_subscription_plan_split(from_iso: str, to_iso: str) -> dict[str, dict[str, int]]:
    empty = _empty_subscription_plan_split()
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_subscription_plan_split",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        if not rows:
            return empty
        row = rows[0] if isinstance(rows, list) else rows
        return _parse_subscription_plan_split_row(row)

    counts = _empty_subscription_plan_split()
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=[
                ("select", "properties,platform"),
                ("event_name", "eq.purchase_success"),
                ("created_at", f"gte.{from_iso}"),
                ("created_at", f"lt.{to_iso}"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            break
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            props = row.get("properties") or {}
            plan = str(props.get("selected_plan") or "").strip().lower()
            if plan not in ("monthly", "yearly"):
                continue
            counts["total"][plan] += 1
            platform = str(row.get("platform") or "").strip().lower()
            if platform in counts:
                counts[platform][plan] += 1
        if len(rows) < page_size:
            break
        offset += page_size
    return counts


def fetch_plan_selected(from_iso: str, to_iso: str) -> dict[str, dict[str, int]]:
    empty = {"selected": _empty_plan_counts(), "unique": _empty_plan_counts()}
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_plan_selected",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        if not rows:
            return empty
        row = rows[0] if isinstance(rows, list) else rows
        return _parse_plan_selected_row(row)

    # REST fallback: count paywall_plan_selected by selected_plan (+ unique users).
    selected = _empty_plan_counts()
    unique_users = {plan: set[str]() for plan in selected}
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_events",
            params=[
                ("select", "properties,analytics_user_id,anonymous_id"),
                ("event_name", "eq.paywall_plan_selected"),
                ("created_at", f"gte.{from_iso}"),
                ("created_at", f"lt.{to_iso}"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            break
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            props = row.get("properties") or {}
            plan = str(props.get("selected_plan") or "").strip().lower()
            if plan not in selected:
                continue
            selected[plan] += 1
            user_id = analytics_user_key(row)
            if user_id:
                unique_users[plan].add(user_id)
        if len(rows) < page_size:
            break
        offset += page_size
    return {
        "selected": selected,
        "unique": {plan: len(users) for plan, users in unique_users.items()},
    }


EXCLUDED_MCQ_OUTCOME_STEPS = frozenset({"week_schedule_preview", "transformation_proof"})


def _parse_mcq_outcome_row(row: dict) -> dict[str, Any]:
    subscription_rate = row.get("subscription_rate")
    survey_completion_rate = row.get("survey_completion_rate")
    if survey_completion_rate is None:
        survey_completion_rate = row.get("survey_end_rate")
    users_selected = row.get("users_selected")
    if users_selected is None:
        users_selected = row.get("users_selected_answer")
    return {
        "step_name": str(row.get("step_name") or ""),
        "answer_value": str(row.get("answer_value") or ""),
        "users_selected": int(users_selected or 0),
        "subscription_rate": (
            float(subscription_rate) if subscription_rate is not None else None
        ),
        "survey_completion_rate": (
            float(survey_completion_rate)
            if survey_completion_rate is not None
            else None
        ),
        "subscription_count": int(row.get("subscription_count") or 0),
    }


def fetch_survey_mcq_answer_outcomes(from_iso: str, to_iso: str) -> list[dict[str, Any]]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_survey_mcq_answer_outcomes",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        return [
            parsed
            for row in rows
            if (parsed := _parse_mcq_outcome_row(row))
            and parsed["step_name"] not in EXCLUDED_MCQ_OUTCOME_STEPS
        ]

    # REST fallback: read analytics_survey_mcq_answer_outcomes view (all-time).
    out: list[dict[str, Any]] = []
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "/rest/v1/analytics_survey_mcq_answer_outcomes",
            params=[
                (
                    "select",
                    "step_name,step_index,answer_value,users_selected_answer,"
                    "subscription_rate,survey_end_rate,subscription_count",
                ),
                ("order", "step_index.asc,users_selected_answer.desc"),
                ("limit", str(page_size)),
                ("offset", str(offset)),
            ],
        )
        if status >= 400:
            raise RuntimeError(
                f"survey MCQ outcomes fetch failed ({status}): {body.decode()}"
            )
        rows = json.loads(body.decode() or "[]")
        for row in rows:
            parsed = _parse_mcq_outcome_row(row)
            if parsed["step_name"] in EXCLUDED_MCQ_OUTCOME_STEPS:
                continue
            out.append(parsed)
        if len(rows) < page_size:
            break
        offset += page_size
    return out


def _empty_daily_row(day: date) -> dict[str, Any]:
    return {
        "day": day.isoformat(),
        "onboarding_started": 0,
        "paywall_views": 0,
        "subscriptions": 0,
        "onboarding_to_paywall_pct": None,
        "paywall_to_sub_pct": None,
        "trial_starters_7d": 0,
        "trial_to_sub_after_d3_pct": None,
    }


def _pct(numerator: int, denominator: int) -> float | None:
    if denominator <= 0:
        return None
    return round((numerator / denominator) * 100, 2)


def _enrich_daily_row(
    day: date,
    *,
    onboarding_started: int,
    paywall_views: int,
    subscriptions: int,
    trial_starters_7d: int = 0,
    trial_to_sub_after_d3_pct: float | None = None,
    app_open_total_after_d3: int | None = None,
) -> dict[str, Any]:
    if trial_to_sub_after_d3_pct is None and app_open_total_after_d3 is not None:
        trial_to_sub_after_d3_pct = _pct(app_open_total_after_d3, trial_starters_7d)
    return {
        "day": day.isoformat(),
        "onboarding_started": onboarding_started,
        "paywall_views": paywall_views,
        "subscriptions": subscriptions,
        "onboarding_to_paywall_pct": _pct(paywall_views, onboarding_started),
        "paywall_to_sub_pct": _pct(subscriptions, paywall_views),
        "trial_starters_7d": trial_starters_7d,
        "trial_to_sub_after_d3_pct": trial_to_sub_after_d3_pct,
    }


def _fetch_daily_trial_to_sub_lookup(
    start: date,
    end: date,
) -> dict[str, dict[str, Any]]:
    from_iso, to_iso = range_bounds(start, end)
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_daily_trial_to_sub",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        return {
            str(row.get("day")): row
            for row in rows
            if row.get("day") is not None
        }

    lookup: dict[str, dict[str, Any]] = {}
    for day in _iter_days(start, end):
        window_start = day - timedelta(days=7)
        window_from, window_to = range_bounds(window_start, day)
        metrics = fetch_trial_metrics(window_from, window_to)
        lookup[day.isoformat()] = {
            "trial_starters": metrics.get("trial_starters", {}).get("value") or 0,
            "app_open_total_after_d3": metrics.get("app_open_total_after_d3", {}).get(
                "value"
            )
            or 0,
            "trial_to_sub_pct": metrics.get("trial_to_sub_after_d3", {}).get("value"),
        }
    return lookup


PLATFORM_FUNNEL_PLATFORMS = ("ios", "android")


def _enrich_platform_row(
    platform: str,
    *,
    onboarding_started: int,
    paywall_views: int,
    subscriptions: int,
    plan_selected: int = 0,
) -> dict[str, Any]:
    return {
        "platform": platform,
        "onboarding_started": onboarding_started,
        "paywall_views": paywall_views,
        "subscriptions": subscriptions,
        "plan_selected": plan_selected,
        "onboarding_to_paywall_pct": _pct(paywall_views, onboarding_started),
        "paywall_to_sub_pct": _pct(subscriptions, paywall_views),
    }


def _empty_platform_funnel() -> list[dict[str, Any]]:
    return [
        _enrich_platform_row(p, onboarding_started=0, paywall_views=0, subscriptions=0)
        for p in PLATFORM_FUNNEL_PLATFORMS
    ]


def fetch_platform_funnel(from_iso: str, to_iso: str) -> list[dict[str, Any]]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_platform_funnel",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        by_platform = {
            str(row.get("platform") or "").lower(): row for row in rows if row.get("platform")
        }
        out: list[dict[str, Any]] = []
        for platform in PLATFORM_FUNNEL_PLATFORMS:
            row = by_platform.get(platform) or {}
            out.append(
                _enrich_platform_row(
                    platform,
                    onboarding_started=int(row.get("onboarding_started") or 0),
                    paywall_views=int(row.get("paywall_views") or 0),
                    subscriptions=int(row.get("subscriptions") or 0),
                    plan_selected=int(row.get("plan_selected") or 0),
                )
            )
        return out

    if using_anon_key():
        return _empty_platform_funnel()

    out: list[dict[str, Any]] = []
    for platform in PLATFORM_FUNNEL_PLATFORMS:
        onboarding_started = count_unique_event_users(
            from_iso=from_iso,
            to_iso=to_iso,
            event_name="onboarding_started",
            platform=platform,
        )
        paywall_views = count_unique_event_users(
            from_iso=from_iso,
            to_iso=to_iso,
            event_name="paywall_viewed",
            platform=platform,
        )
        subscriptions = count_unique_event_users(
            from_iso=from_iso,
            to_iso=to_iso,
            event_name="purchase_success",
            platform=platform,
        )
        plan_selected = count_unique_event_users(
            from_iso=from_iso,
            to_iso=to_iso,
            event_name="paywall_plan_selected",
            platform=platform,
        )
        out.append(
            _enrich_platform_row(
                platform,
                onboarding_started=onboarding_started,
                paywall_views=paywall_views,
                subscriptions=subscriptions,
                plan_selected=plan_selected,
            )
        )
    return out


def _iter_days(start: date, end: date):
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


TRIAL_WINDOW_DAYS = 3
TRIAL_APP_OPEN_DAY_OFFSETS = (1, 2, 3, 4, 5, 6, 7, 10, 14)
TRIAL_APP_OPEN_AFTER_D3 = timedelta(days=3, minutes=5)
TRIAL_WORKOUT_COUNT_THRESHOLDS: dict[str, int] = {
    "workout_started_trial": 1,
    "workout_2nd_started_trial": 2,
    "workout_3rd_started_trial": 3,
    "workout_5_started_trial": 5,
    "workout_7_started_trial": 7,
    "workout_10_started_trial": 10,
    "workout_15_started_trial": 15,
    "workout_20_started_trial": 20,
}


def _app_open_metric_key(day_offset: int) -> str:
    return f"app_open_d{day_offset}"


def _apply_workout_started_metrics(
    metrics: dict[str, Any],
    exercise_entry_days_by_user: dict[str, set[date]],
) -> None:
    for key, threshold in TRIAL_WORKOUT_COUNT_THRESHOLDS.items():
        metrics[key]["value"] = sum(
            1
            for days in exercise_entry_days_by_user.values()
            if len(days) >= threshold
        )


def _empty_trial_metrics() -> dict[str, Any]:
    metrics: dict[str, Any] = {
        "trial_starters": {"value": 0, "note": "purchase_success"},
        "active_min_d1": {
            "value": None,
            "note": "Geen duration event",
        },
        "active_min_d2": {
            "value": None,
            "note": "Geen duration event",
        },
        "active_min_d3": {
            "value": None,
            "note": "Geen duration event",
        },
        "notification_open_rate": {
            "value": None,
            "note": "Geen notification open event",
        },
    }
    for key, threshold in TRIAL_WORKOUT_COUNT_THRESHOLDS.items():
        metrics[key] = {
            "value": 0,
            "note": f">={threshold} days with exercise_entry_saved",
        }
    for day_offset in TRIAL_APP_OPEN_DAY_OFFSETS:
        metrics[_app_open_metric_key(day_offset)] = {
            "value": 0,
            "note": f"weekplanning_viewed D+{day_offset}",
        }
    metrics["app_open_total_after_d3"] = {
        "value": 0,
        "note": "weekplanning_viewed >= D+3d 5m",
    }
    metrics["trial_to_sub_after_d3"] = {"value": None}
    metrics["plan_generations_completed"] = {
        "value": 0,
        "note": "plan_generation_completed (unique users in range)",
    }
    metrics["no_trial_came_back_after_12h"] = {
        "value": 0,
        "note": (
            "plan_generation_completed; no purchase_success <12h; any event >=12h"
        ),
    }
    metrics["no_trial_trial_after_12h"] = {
        "value": 0,
        "note": (
            "plan_generation_completed; no purchase_success <12h; purchase_success >=12h"
        ),
    }
    return metrics


def _apply_trial_derived_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    starters = metrics.get("trial_starters", {}).get("value")
    after_d3 = metrics.get("app_open_total_after_d3", {}).get("value")
    if starters and starters > 0 and after_d3 is not None:
        metrics["trial_to_sub_after_d3"]["value"] = round(
            after_d3 / starters * 100,
            2,
        )
    else:
        metrics["trial_to_sub_after_d3"]["value"] = None
    return metrics


def _trial_metrics_from_rpc_row(row: dict[str, Any]) -> dict[str, Any]:
    metrics = _empty_trial_metrics()
    metrics["trial_starters"]["value"] = int(row.get("trial_starters") or 0)
    for day_offset in TRIAL_APP_OPEN_DAY_OFFSETS:
        key = _app_open_metric_key(day_offset)
        metrics[key]["value"] = int(row.get(key) or 0)
    metrics["app_open_total_after_d3"]["value"] = int(
        row.get("app_open_total_after_d3") or 0
    )
    for key in TRIAL_WORKOUT_COUNT_THRESHOLDS:
        if key == "workout_started_trial":
            metrics[key]["value"] = int(
                row.get(key) or row.get("workout_started_during_trial") or 0
            )
        else:
            metrics[key]["value"] = int(row.get(key) or 0)
    return _apply_trial_derived_metrics(metrics)


def fetch_no_trial_plan_metrics(from_iso: str, to_iso: str) -> tuple[int, int, int]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_no_trial_plan_stats",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        if rows:
            row = rows[0] if isinstance(rows, list) else rows
            return (
                int(row.get("plan_generations_completed") or 0),
                int(row.get("no_trial_came_back_after_12h") or 0),
                int(row.get("no_trial_trial_after_12h") or 0),
            )
    return _compute_no_trial_plan_metrics(from_iso, to_iso)


def _apply_no_trial_plan_metrics(
    metrics: dict[str, Any],
    from_iso: str,
    to_iso: str,
) -> dict[str, Any]:
    try:
        plan_completed, came_back, trial_after = fetch_no_trial_plan_metrics(
            from_iso, to_iso
        )
        metrics["plan_generations_completed"]["value"] = plan_completed
        metrics["no_trial_came_back_after_12h"]["value"] = came_back
        metrics["no_trial_trial_after_12h"]["value"] = trial_after
    except Exception:  # noqa: BLE001
        metrics["plan_generations_completed"]["value"] = 0
        metrics["no_trial_came_back_after_12h"]["value"] = 0
        metrics["no_trial_trial_after_12h"]["value"] = 0
    return metrics


def _compute_no_trial_plan_metrics(from_iso: str, to_iso: str) -> tuple[int, int, int]:
    plan_rows = fetch_analytics_events(
        select="analytics_user_id,anonymous_id,created_at",
        from_iso=from_iso,
        to_iso=to_iso,
        event_name="plan_generation_completed",
    )
    plan_by_user: dict[str, datetime] = {}
    for row in plan_rows:
        user_id = analytics_user_key(row)
        created_at = parse_event_created_at(row.get("created_at"))
        if not user_id or created_at is None:
            continue
        existing = plan_by_user.get(user_id)
        if existing is None or created_at < existing:
            plan_by_user[user_id] = created_at

    if not plan_by_user:
        return 0, 0, 0

    event_from_iso = min(plan_by_user.values()).isoformat()
    event_to_iso = datetime.now(timezone.utc).isoformat()
    event_rows = fetch_analytics_events(
        select="analytics_user_id,anonymous_id,created_at,event_name",
        from_iso=event_from_iso,
        to_iso=event_to_iso,
        event_name=None,
    )

    purchases_within_12h: set[str] = set()
    purchases_after_12h: set[str] = set()
    any_event_after_12h: set[str] = set()

    for row in event_rows:
        user_id = analytics_user_key(row)
        created_at = parse_event_created_at(row.get("created_at"))
        plan_completed_at = plan_by_user.get(user_id)
        if not user_id or created_at is None or plan_completed_at is None:
            continue

        if created_at >= plan_completed_at + timedelta(hours=12):
            any_event_after_12h.add(user_id)
            if row.get("event_name") == "purchase_success":
                purchases_after_12h.add(user_id)
            continue

        if (
            row.get("event_name") == "purchase_success"
            and created_at >= plan_completed_at
        ):
            purchases_within_12h.add(user_id)

    came_back = 0
    trial_after = 0
    for user_id in plan_by_user:
        if user_id in purchases_within_12h:
            continue
        if user_id in any_event_after_12h:
            came_back += 1
        if user_id in purchases_after_12h:
            trial_after += 1
    return len(plan_by_user), came_back, trial_after


def fetch_trial_metrics(from_iso: str, to_iso: str) -> dict[str, Any]:
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_trial_stats",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        if rows:
            row = rows[0] if isinstance(rows, list) else rows
            metrics = _trial_metrics_from_rpc_row(row)
            return _apply_no_trial_plan_metrics(metrics, from_iso, to_iso)

    metrics = _empty_trial_metrics()
    if status >= 400:
        metrics["trial_starters"]["note"] = (
            f"RPC failed ({status}). Using REST fallback."
            if not using_anon_key()
            else f"RPC failed ({status}). Using REST fallback (anon key)."
        )

    try:
        cohort_rows = fetch_analytics_events(
            select="analytics_user_id,anonymous_id,created_at,properties",
            from_iso=from_iso,
            to_iso=to_iso,
            event_name="purchase_success",
        )
    except Exception as exc:  # noqa: BLE001
        metrics["trial_starters"]["note"] = (
            f"Trial stats unavailable: {exc}. Re-run dashboard_trial_stats.sql"
        )
        return _apply_no_trial_plan_metrics(metrics, from_iso, to_iso)

    has_trial_flag = any(
        (row.get("properties") or {}).get("has_free_trial_offer") is not None
        for row in cohort_rows
    )

    trial_starts_by_user: dict[str, datetime] = {}
    for row in cohort_rows:
        props = row.get("properties") or {}
        if has_trial_flag and props.get("has_free_trial_offer") is not True:
            continue
        user_id = analytics_user_key(row)
        created_at = parse_event_created_at(row.get("created_at"))
        if not user_id or created_at is None:
            continue
        existing = trial_starts_by_user.get(user_id)
        if existing is None or created_at < existing:
            trial_starts_by_user[user_id] = created_at

    if not trial_starts_by_user:
        return _apply_no_trial_plan_metrics(metrics, from_iso, to_iso)

    metrics["trial_starters"]["value"] = len(trial_starts_by_user)

    latest_app_open_end = max(trial_starts_by_user.values()) + timedelta(days=15)
    latest_trial_end = max(trial_starts_by_user.values()) + timedelta(days=TRIAL_WINDOW_DAYS)
    app_open_metric_map = {
        _app_open_metric_key(day_offset): day_offset
        for day_offset in TRIAL_APP_OPEN_DAY_OFFSETS
    }
    event_to_metric: dict[str, dict[str, Any]] = {
        "weekplanning_viewed": app_open_metric_map,
    }
    matched_by_metric: dict[str, set[str]] = {
        metric_key: set()
        for metric_map in event_to_metric.values()
        for metric_key in metric_map
    }
    matched_by_metric["app_open_total_after_d3"] = set()
    exercise_entry_days_by_user: dict[str, set[date]] = {}

    event_from_iso = min(trial_starts_by_user.values()).isoformat()
    event_to_iso = max(latest_trial_end, latest_app_open_end).isoformat()
    for event_name, metric_map in event_to_metric.items():
        rows = fetch_analytics_events(
            select="analytics_user_id,anonymous_id,created_at",
            from_iso=event_from_iso,
            to_iso=event_to_iso,
            event_name=event_name,
        )
        for row in rows:
            user_id = analytics_user_key(row)
            created_at = parse_event_created_at(row.get("created_at"))
            trial_start = trial_starts_by_user.get(user_id)
            if not user_id or created_at is None or trial_start is None:
                continue
            if created_at >= trial_start + TRIAL_APP_OPEN_AFTER_D3:
                matched_by_metric["app_open_total_after_d3"].add(user_id)
            created_day = created_at.astimezone(timezone.utc).date()
            trial_day = trial_start.astimezone(timezone.utc).date()
            for metric_key, window in metric_map.items():
                if isinstance(window, int):
                    if created_day == trial_day + timedelta(days=window):
                        matched_by_metric[metric_key].add(user_id)
                    continue
                start_offset_days, end_offset_days = window
                window_start = trial_start + timedelta(days=start_offset_days)
                window_end = trial_start + timedelta(days=end_offset_days)
                if window_start <= created_at < window_end:
                    matched_by_metric[metric_key].add(user_id)

    exercise_to_iso = datetime.now(timezone.utc).isoformat()
    exercise_rows = fetch_analytics_events(
        select="analytics_user_id,anonymous_id,created_at",
        from_iso=event_from_iso,
        to_iso=exercise_to_iso,
        event_name="exercise_entry_saved",
    )
    for row in exercise_rows:
        user_id = analytics_user_key(row)
        created_at = parse_event_created_at(row.get("created_at"))
        trial_start = trial_starts_by_user.get(user_id)
        if not user_id or created_at is None or trial_start is None:
            continue
        if created_at < trial_start:
            continue
        exercise_entry_days_by_user.setdefault(user_id, set()).add(
            created_at.astimezone(timezone.utc).date()
        )

    for metric_key, matched_users in matched_by_metric.items():
        metrics[metric_key]["value"] = len(matched_users)

    _apply_workout_started_metrics(metrics, exercise_entry_days_by_user)

    return _apply_no_trial_plan_metrics(
        _apply_trial_derived_metrics(metrics),
        from_iso,
        to_iso,
    )


def fetch_daily_conversions(start: date, end: date) -> list[dict[str, Any]]:
    """Per-day conversion inputs (+ computed %). Prefers dedicated RPC."""
    from_iso, to_iso = range_bounds(start, end)
    trial_by_day = _fetch_daily_trial_to_sub_lookup(start, end)
    status, _, body = supabase_request(
        "POST",
        "/rest/v1/rpc/dashboard_daily_conversions",
        body={"p_from": from_iso, "p_to": to_iso},
    )
    if status < 400:
        rows = json.loads(body.decode() or "[]")
        by_day = {
            str(row.get("day")): row
            for row in rows
            if row.get("day") is not None
        }
        out: list[dict[str, Any]] = []
        for day in _iter_days(start, end):
            row = by_day.get(day.isoformat()) or {}
            trial = trial_by_day.get(day.isoformat()) or {}
            trial_starters = int(trial.get("trial_starters") or 0)
            trial_pct = trial.get("trial_to_sub_pct")
            out.append(
                _enrich_daily_row(
                    day,
                    onboarding_started=int(row.get("onboarding_started") or 0),
                    paywall_views=int(row.get("paywall_views") or 0),
                    subscriptions=int(row.get("subscriptions") or 0),
                    trial_starters_7d=trial_starters,
                    trial_to_sub_after_d3_pct=(
                        float(trial_pct) if trial_pct is not None else None
                    ),
                    app_open_total_after_d3=int(
                        trial.get("app_open_total_after_d3") or 0
                    ),
                )
            )
        return out

    # Fallback: reuse overall funnel RPC once per UTC day (works with anon key).
    from concurrent.futures import ThreadPoolExecutor

    days = list(_iter_days(start, end))

    def _one(day: date) -> dict[str, Any]:
        day_from, day_to = range_bounds(day, day)
        trial = trial_by_day.get(day.isoformat()) or {}
        trial_starters = int(trial.get("trial_starters") or 0)
        trial_pct = trial.get("trial_to_sub_pct")
        try:
            overall = fetch_overall_funnel(day_from, day_to)
            return _enrich_daily_row(
                day,
                onboarding_started=int(overall.get("survey_started") or 0),
                paywall_views=int(overall.get("paywall_views") or 0),
                subscriptions=int(overall.get("subscriptions") or 0),
                trial_starters_7d=trial_starters,
                trial_to_sub_after_d3_pct=(
                    float(trial_pct) if trial_pct is not None else None
                ),
                app_open_total_after_d3=int(trial.get("app_open_total_after_d3") or 0),
            )
        except Exception:  # noqa: BLE001
            row = _empty_daily_row(day)
            row["trial_starters_7d"] = trial_starters
            row["trial_to_sub_after_d3_pct"] = (
                float(trial_pct) if trial_pct is not None else None
            )
            return row

    workers = min(8, max(1, len(days)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(_one, days))


def build_payload(from_raw: str | None, to_raw: str | None) -> dict[str, Any]:
    """Fast payload: Supabase metrics only. ASC Search is loaded via /api/asc-search."""
    from concurrent.futures import ThreadPoolExecutor

    error = None
    mode = "rest"
    survey_steps: list[dict[str, Any]] = [
        {"step_index": i, "screen": n, "views": 0} for i, n in SURVEY_SCREENS
    ]
    plan_selected = {
        "selected": _empty_plan_counts(),
        "unique": _empty_plan_counts(),
    }
    subscription_plan_split = _empty_subscription_plan_split()
    survey_mcq_outcomes: list[dict[str, Any]] = []
    overall = empty_overall_funnel()
    overall_by_platform: list[dict[str, Any]] = _empty_overall_funnel_by_platform()
    platform_funnel: list[dict[str, Any]] = _empty_platform_funnel()
    daily_conversions: list[dict[str, Any]] = []
    trial_metrics = _empty_trial_metrics()
    try:
        start, end = resolve_range(from_raw, to_raw)
        from_iso, to_iso = range_bounds(start, end)

        def _sources() -> tuple[list[dict], str]:
            rows = build_funnel_via_rpc(from_iso, to_iso)
            if rows is None:
                if using_anon_key():
                    raise RuntimeError(
                        "Acquisition funnel RPC unavailable. Refresh the page."
                    )
                return with_placeholder_asc(build_funnel_via_rest(from_iso, to_iso)), "rest"
            return with_placeholder_asc(rows), "rpc"

        with ThreadPoolExecutor(max_workers=8) as pool:
            fut_sources = pool.submit(_sources)
            fut_survey = pool.submit(fetch_survey_step_views, from_iso, to_iso)
            fut_plans = pool.submit(fetch_plan_selected, from_iso, to_iso)
            fut_plan_split = pool.submit(fetch_subscription_plan_split, from_iso, to_iso)
            fut_mcq = pool.submit(fetch_survey_mcq_answer_outcomes, from_iso, to_iso)
            fut_overall = pool.submit(fetch_overall_funnel, from_iso, to_iso)
            fut_overall_platform = pool.submit(
                fetch_overall_funnel_by_platform, from_iso, to_iso
            )
            fut_platform = pool.submit(fetch_platform_funnel, from_iso, to_iso)
            fut_daily = pool.submit(fetch_daily_conversions, start, end)
            fut_trial = pool.submit(fetch_trial_metrics, from_iso, to_iso)
            sources, mode = fut_sources.result()
            try:
                survey_steps = fut_survey.result()
            except Exception as survey_exc:  # noqa: BLE001
                error = f"Survey steps: {survey_exc}"
            try:
                plan_selected = fut_plans.result()
            except Exception as plan_exc:  # noqa: BLE001
                if error is None:
                    error = f"Plan selected: {plan_exc}"
            try:
                subscription_plan_split = fut_plan_split.result()
            except Exception as plan_split_exc:  # noqa: BLE001
                if error is None:
                    error = f"Subscription plan split: {plan_split_exc}"
            try:
                survey_mcq_outcomes = fut_mcq.result()
            except Exception as mcq_exc:  # noqa: BLE001
                if error is None:
                    error = f"Survey MCQ outcomes: {mcq_exc}"
            try:
                overall = fut_overall.result()
            except Exception as overall_exc:  # noqa: BLE001
                if error is None:
                    error = f"Overall funnel: {overall_exc}"
            try:
                overall_by_platform = fut_overall_platform.result()
            except Exception as overall_platform_exc:  # noqa: BLE001
                if error is None:
                    error = f"Overall funnel by platform: {overall_platform_exc}"
            try:
                platform_funnel = fut_platform.result()
            except Exception as platform_exc:  # noqa: BLE001
                if error is None:
                    error = f"Platform funnel: {platform_exc}"
            try:
                daily_conversions = fut_daily.result()
            except Exception as daily_exc:  # noqa: BLE001
                if error is None:
                    error = f"Daily conversions: {daily_exc}"
            try:
                trial_metrics = fut_trial.result()
            except Exception as trial_exc:  # noqa: BLE001
                if error is None:
                    error = f"Trial metrics: {trial_exc}"

            overall_by_platform = merge_platform_funnel_into_overall_by_platform(
                overall_by_platform,
                platform_funnel,
            )

        range_info = {
            "from": start.isoformat(),
            "to": end.isoformat(),
            "from_iso": from_iso,
            "to_iso": to_iso,
        }
    except Exception as exc:  # noqa: BLE001 — surface to UI
        error = str(exc)
        mode = "error"
        sources = with_placeholder_asc([error_row(s) for s in SOURCES if s["kind"] != "asc_search"])
        start, end = default_range()
        from_iso, to_iso = range_bounds(start, end)
        range_info = {
            "from": start.isoformat(),
            "to": end.isoformat(),
            "from_iso": from_iso,
            "to_iso": to_iso,
        }

    return {
        "overall": overall,
        "overall_by_platform": overall_by_platform,
        "platform_funnel": platform_funnel,
        "sources": sources,
        "survey_steps": survey_steps,
        "plan_selected": plan_selected,
        "subscription_plan_split": subscription_plan_split,
        "survey_mcq_outcomes": survey_mcq_outcomes,
        "daily_conversions": daily_conversions,
        "trial_metrics": trial_metrics,
        "mode": mode,
        "error": error,
        "configured": supabase_config()[0] is not None,
        "asc_configured": asc_analytics.asc_configured(),
        "asc_deferred": True,
        "range": range_info,
    }


def build_asc_payload(from_raw: str | None, to_raw: str | None) -> dict[str, Any]:
    try:
        start, end = resolve_range(from_raw, to_raw)
        row = build_asc_search_row(start, end)
        message = row.pop("asc_message", None)
        return {
            "source": row,
            "asc_message": message,
            "asc_configured": asc_analytics.asc_configured(),
            "range": {
                "from": start.isoformat(),
                "to": end.isoformat(),
            },
            "error": None,
        }
    except Exception as exc:  # noqa: BLE001
        source = next(s for s in SOURCES if s["id"] == "asc_search")
        return {
            "source": empty_asc_row(source, status="error"),
            "asc_message": str(exc),
            "asc_configured": asc_analytics.asc_configured(),
            "range": None,
            "error": str(exc),
        }


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in {"/api/funnel", "/api/asc-search"}:
            qs = urllib.parse.parse_qs(parsed.query)
            from_raw = (qs.get("from") or [None])[0]
            to_raw = (qs.get("to") or [None])[0]
            if parsed.path == "/api/funnel":
                payload = build_payload(from_raw, to_raw)
            else:
                payload = build_asc_payload(from_raw, to_raw)
            raw = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        return super().do_GET()

    def log_message(self, fmt: str, *args) -> None:
        print(f"[dashboard] {self.address_string()} - {fmt % args}")


def main() -> None:
    load_dotenv(ROOT / ".env")
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Analytics dashboard: http://127.0.0.1:{PORT}")
    if supabase_config()[0] is None:
        print("Warning: DASHBOARD/.env missing SUPABASE_URL / SUPABASE_ANON_KEY")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
