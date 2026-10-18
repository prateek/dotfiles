def render_rows(rows: list[dict[str, object]], format: str = "text") -> str:
    if format != "text":
        raise ValueError("unsupported format")
    return "".join(f"{row['name']}\n" for row in rows)
