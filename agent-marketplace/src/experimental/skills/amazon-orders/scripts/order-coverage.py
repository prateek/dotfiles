#!/usr/bin/env python3
"""Summarize amz orders JSON from stdin without disclosing purchase details."""

import argparse
import datetime
import json
import sys


def iso_date(value):
    try:
        parsed = datetime.date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError
        return value
    except (TypeError, ValueError):
        raise argparse.ArgumentTypeError("expected a YYYY-MM-DD date") from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", type=iso_date)
    parser.add_argument("--until", type=iso_date)
    args = parser.parse_args()
    if args.since and args.until and args.since > args.until:
        parser.error("--since must be on or before --until")

    try:
        rows = json.load(sys.stdin)
        if rows is None:
            rows = []
        if not isinstance(rows, list) or any(not isinstance(r, dict) for r in rows):
            raise ValueError
        for row in rows:
            if not isinstance(row.get("id"), str) or not row["id"]:
                raise ValueError
            for field in ("date_iso", "total"):
                if row.get(field) is not None and not isinstance(row[field], str):
                    raise ValueError
            if row.get("date_iso"):
                iso_date(row["date_iso"])
            items = row.get("items")
            if items is None:
                items = []
            if not isinstance(items, list) or any(not isinstance(i, dict) for i in items):
                raise ValueError
            if any(i.get("asin") is not None and not isinstance(i["asin"], str) for i in items):
                raise ValueError
    except (ValueError, TypeError, argparse.ArgumentTypeError):
        parser.error("stdin must be valid amz orders JSON; no input values printed")

    dates = sorted(r["date_iso"] for r in rows if r.get("date_iso"))
    selected = [
        r for r in rows
        if (not args.since and not args.until) or (
            r.get("date_iso")
            and (not args.since or r["date_iso"] >= args.since)
            and (not args.until or r["date_iso"] <= args.until)
        )
    ]
    items = [i for r in selected for i in (r.get("items") or [])]
    result = {
        "stored_orders": len(rows),
        "stored_date_min": dates[0] if dates else None,
        "stored_date_max": dates[-1] if dates else None,
        "undated_orders": sum(not r.get("date_iso") for r in rows),
        "selection_since": args.since,
        "selection_until": args.until,
        "selected_orders": len(selected),
        "selected_items": len(items),
        "orders_missing_total": sum(not r.get("total") for r in selected),
        "orders_missing_items": sum(not r.get("items") for r in selected),
        "items_missing_asin": sum(not i.get("asin") for i in items),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
