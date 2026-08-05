"""App Store Connect Analytics Reports client for App Store Search metrics."""

from __future__ import annotations

import csv
import gzip
import io
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path
from typing import Any

try:
    import jwt
except ImportError:  # pragma: no cover
    jwt = None  # type: ignore

API_BASE = "https://api.appstoreconnect.apple.com/v1"
SEARCH_SOURCE_TYPES = {
    "app store search",
    "search",  # seen in some report variants / tests
}


class AscConfigError(RuntimeError):
    pass


class AscPendingError(RuntimeError):
    pass


def _root() -> Path:
    return Path(__file__).resolve().parent


def asc_configured() -> bool:
    return bool(
        os.environ.get("ASC_ISSUER_ID")
        and os.environ.get("ASC_KEY_ID")
        and os.environ.get("ASC_APP_ID")
        and os.environ.get("ASC_PRIVATE_KEY_PATH")
    )


def _private_key_path() -> Path:
    raw = os.environ.get("ASC_PRIVATE_KEY_PATH") or ""
    path = Path(raw)
    if not path.is_absolute():
        path = _root() / path
    return path


def _token() -> str:
    if jwt is None:
        raise AscConfigError(
            "PyJWT ontbreekt. Run: cd DASHBOARD && .venv/bin/pip install 'PyJWT[crypto]'"
        )
    issuer = os.environ.get("ASC_ISSUER_ID") or ""
    key_id = os.environ.get("ASC_KEY_ID") or ""
    key_path = _private_key_path()
    if not issuer or not key_id:
        raise AscConfigError("ASC_ISSUER_ID / ASC_KEY_ID ontbreken in DASHBOARD/.env")
    if not key_path.exists():
        raise AscConfigError(f"ASC private key niet gevonden: {key_path}")

    now = int(time.time())
    private_key = key_path.read_text(encoding="utf-8")
    return jwt.encode(
        {
            "iss": issuer,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"alg": "ES256", "kid": key_id, "typ": "JWT"},
    )


def _request(
    method: str,
    path: str,
    *,
    params: dict[str, str] | None = None,
    body: dict[str, Any] | None = None,
    timeout: int = 90,
) -> dict[str, Any]:
    query = f"?{urllib.parse.urlencode(params)}" if params else ""
    url = path if path.startswith("http") else f"{API_BASE}{path}{query}"
    headers = {
        "Authorization": f"Bearer {_token()}",
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"ASC API {method} {path} → {exc.code}: {detail}") from exc


def _paginate(path: str, *, params: dict[str, str] | None = None) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    next_url: str | None = path
    query = dict(params or {})
    while next_url:
        if next_url.startswith("http"):
            page = _request("GET", next_url)
        else:
            page = _request("GET", next_url, params=query)
            query = {}
        items.extend(page.get("data") or [])
        next_url = (page.get("links") or {}).get("next")
    return items


def _cache_dir() -> Path:
    path = _root() / ".cache" / "asc"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _load_json(path: Path) -> Any | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def _save_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload), encoding="utf-8")


def _create_or_get_report_request(app_id: str) -> str:
    cache_path = _cache_dir() / f"report_request_{app_id}.json"
    cached = _load_json(cache_path)
    if isinstance(cached, dict) and cached.get("id"):
        return str(cached["id"])

    try:
        existing = _paginate(
            f"/apps/{app_id}/analyticsReportRequests",
            params={"limit": "20"},
        )
        for req in existing:
            attrs = req.get("attributes") or {}
            if not attrs.get("stoppedDueToInactivity"):
                request_id = str(req["id"])
                _save_json(cache_path, {"id": request_id})
                return request_id
    except RuntimeError:
        pass

    url = f"{API_BASE}/analyticsReportRequests"
    headers = {
        "Authorization": f"Bearer {_token()}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    body = json.dumps(
        {
            "data": {
                "type": "analyticsReportRequests",
                "attributes": {"accessType": "ONGOING"},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                },
            }
        }
    ).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            created = json.loads(resp.read().decode("utf-8"))
            request_id = str(created["data"]["id"])
            _save_json(cache_path, {"id": request_id})
            return request_id
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            existing = _paginate(
                f"/apps/{app_id}/analyticsReportRequests",
                params={"limit": "20"},
            )
            for item in existing:
                attrs = item.get("attributes") or {}
                if not attrs.get("stoppedDueToInactivity"):
                    request_id = str(item["id"])
                    _save_json(cache_path, {"id": request_id})
                    return request_id
            raise AscPendingError(
                "ASC report request bestaat al, maar kon geen actieve request vinden."
            ) from exc
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"ASC create report request → {exc.code}: {detail}") from exc


def _is_search_source(value: str) -> bool:
    return value.strip().lower() in SEARCH_SOURCE_TYPES


def _parse_tsv(content: str) -> list[dict[str, str]]:
    reader = csv.DictReader(io.StringIO(content), delimiter="\t")
    return [dict(row) for row in reader]


def _download_segment_rows(segment: dict[str, Any]) -> list[dict[str, str]]:
    url = (segment.get("attributes") or {}).get("url")
    if not url:
        return []
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read()
    try:
        content = gzip.decompress(raw).decode("utf-8")
    except OSError:
        content = raw.decode("utf-8")
    return _parse_tsv(content)


def _pick_report(reports: list[dict[str, Any]], *, prefer_detailed: bool = True) -> dict[str, Any]:
    if not reports:
        raise AscPendingError("Geen ASC reports beschikbaar.")
    ranked: list[tuple[int, dict[str, Any]]] = []
    for report in reports:
        name = ((report.get("attributes") or {}).get("name") or "").lower()
        score = 0
        if prefer_detailed and "detailed" in name:
            score += 10
        if "discovery and engagement" in name or "app downloads" in name:
            score += 5
        if "standard" in name:
            score += 1
        ranked.append((score, report))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return ranked[0][1]


def _instances_for_report(report_id: str) -> list[dict[str, Any]]:
    # Prefer DAILY, then any available granularity.
    for granularity in ("DAILY", "WEEKLY", "MONTHLY", None):
        params: dict[str, str] = {"limit": "200"}
        if granularity:
            params["filter[granularity]"] = granularity
        instances = _paginate(f"/analyticsReports/{report_id}/instances", params=params)
        if instances:
            return instances
    return []


def _list_report_request_ids(app_id: str) -> list[str]:
    ids: list[str] = []
    cache_path = _cache_dir() / f"report_request_{app_id}.json"
    cached = _load_json(cache_path)
    if isinstance(cached, dict) and cached.get("id"):
        ids.append(str(cached["id"]))
    snap = _load_json(_cache_dir() / "snapshot_request.json")
    if isinstance(snap, dict) and snap.get("id"):
        ids.append(str(snap["id"]))
    try:
        existing = _paginate(
            f"/apps/{app_id}/analyticsReportRequests",
            params={"limit": "20"},
        )
        for req in existing:
            attrs = req.get("attributes") or {}
            if attrs.get("stoppedDueToInactivity"):
                continue
            request_id = str(req["id"])
            if request_id not in ids:
                # Prefer ONGOING first for recurring data.
                if attrs.get("accessType") == "ONGOING":
                    ids.insert(0, request_id)
                else:
                    ids.append(request_id)
    except RuntimeError:
        pass
    # de-dupe preserve order
    seen: set[str] = set()
    ordered: list[str] = []
    for request_id in ids:
        if request_id not in seen:
            seen.add(request_id)
            ordered.append(request_id)
    return ordered


def _load_category_rows(
    *,
    report_request_ids: list[str],
    category: str,
) -> list[dict[str, str]]:
    last_error: Exception | None = None
    for report_request_id in report_request_ids:
        cache_path = _cache_dir() / f"rows_{category}_{report_request_id}.json"
        cached = _load_json(cache_path)
        if isinstance(cached, dict) and cached.get("cached_at"):
            age = time.time() - float(cached["cached_at"])
            if age < 6 * 3600 and isinstance(cached.get("rows"), list) and cached["rows"]:
                return cached["rows"]

        try:
            reports = _paginate(
                f"/analyticsReportRequests/{report_request_id}/reports",
                params={"filter[category]": category, "limit": "50"},
            )
            if not reports:
                continue
            report = _pick_report(reports, prefer_detailed=True)
            report_id = str(report["id"])
            instances = _instances_for_report(report_id)
            if not instances:
                last_error = AscPendingError(
                    f"ASC reports bestaan voor {category}, maar instances zijn nog leeg "
                    "(Apple genereert ze na de eerste request, vaak 2–24u)."
                )
                continue

            rows: list[dict[str, str]] = []
            for instance in instances:
                instance_id = str(instance["id"])
                segments = _paginate(
                    f"/analyticsReportInstances/{instance_id}/segments",
                    params={"limit": "50"},
                )
                for segment in segments:
                    rows.extend(_download_segment_rows(segment))

            if rows:
                _save_json(
                    cache_path,
                    {
                        "cached_at": time.time(),
                        "rows": rows,
                        "report_id": report_id,
                        "report_name": (report.get("attributes") or {}).get("name"),
                    },
                )
                return rows
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            continue

    if last_error:
        raise last_error
    raise AscPendingError(
        f"Geen ASC data voor {category}. Wacht tot Apple report instances klaarzet."
    )


def _in_date_range(day: str, start: date, end: date) -> bool:
    try:
        d = date.fromisoformat(day[:10])
    except ValueError:
        return False
    return start <= d <= end


def fetch_app_store_search_metrics(start: date, end: date) -> dict[str, Any]:
    """Return impressions / PP views / clicks / downloads for Source Type = Search."""
    if not asc_configured():
        raise AscConfigError(
            "ASC credentials ontbreken (ASC_ISSUER_ID, ASC_KEY_ID, ASC_APP_ID, ASC_PRIVATE_KEY_PATH)."
        )

    app_id = os.environ["ASC_APP_ID"].strip()
    # Ensure at least one ONGOING request exists / is cached.
    _create_or_get_report_request(app_id)
    report_request_ids = _list_report_request_ids(app_id)
    if not report_request_ids:
        raise AscPendingError("Geen ASC analytics report request gevonden.")

    engagement_rows = _load_category_rows(
        report_request_ids=report_request_ids,
        category="APP_STORE_ENGAGEMENT",
    )
    commerce_rows = _load_category_rows(
        report_request_ids=report_request_ids,
        category="COMMERCE",
    )

    impressions = 0
    page_views = 0
    clicks = 0
    downloads = 0
    days_with_data: set[str] = set()

    for row in engagement_rows:
        day = (row.get("Date") or "").strip()
        if not day or not _in_date_range(day, start, end):
            continue
        if not _is_search_source(row.get("Source Type") or ""):
            continue
        event = (row.get("Event") or "").strip()
        count = int(float(row.get("Counts") or row.get("Count") or 0))
        days_with_data.add(day[:10])
        if event == "Impression":
            impressions += count
        elif event == "Page view":
            page_views += count
        elif event == "Tap":
            clicks += count

    for row in commerce_rows:
        day = (row.get("Date") or "").strip()
        if not day or not _in_date_range(day, start, end):
            continue
        source = row.get("Source Type") or ""
        if source and not _is_search_source(source):
            continue
        # If Source Type missing on commerce rows, skip — don't mix all sources.
        if not source:
            continue
        download_type = (row.get("Download Type") or row.get("Event") or "").strip()
        count = int(float(row.get("Counts") or row.get("Count") or 0))
        if download_type in {"First-time download", "Redownload"}:
            downloads += count
            days_with_data.add(day[:10])

    return {
        "impressions": impressions,
        "product_page_views": page_views,
        "clicks": clicks,
        "downloads": downloads,
        "days": sorted(days_with_data),
        "source_type": "App Store search",
    }
