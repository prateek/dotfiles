"""Parse and surgically edit SKILL.md YAML frontmatter.

The parser is a stdlib implementation of the YAML subset frontmatter uses (a
block mapping of scalars, with nested mappings, sequences, and flow
collections) that follows PyYAML's SafeLoader semantics: YAML 1.1 implicit
types, PyYAML's folding rules for block and flow scalars, duplicate keys
rejected. It records where each top-level scalar sits in the file so `edit`
can replace one value's span and leave every other byte alone; nothing is ever
re-serialized through a YAML dumper.
"""

from __future__ import annotations

import datetime as dt
import re
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType


class FrontmatterError(Exception):
    """Frontmatter is missing, unreadable, or outside the supported YAML subset."""


@dataclass(frozen=True, slots=True)
class ScalarSpan:
    """Where a top-level scalar value sits in the whole file.

    Flow scalars span the token itself (quotes included); block scalars span
    from the `|`/`>` indicator through the end of the last line the scalar
    consumes, trailing empty lines included. An absent value (`key:`) is an
    empty span just after the colon.
    """

    key: str
    value_start: int
    value_end: int
    style: str  # "plain" | "single" | "double" | "literal" | "folded"
    chomp: str  # "" | "-" | "+"
    indent: int  # content indent for block scalars, else 0


@dataclass(frozen=True, slots=True)
class Frontmatter:
    path: Path | None
    text: str
    block_start: int  # offset just past the opening "---" line
    block_end: int  # offset of the closing "---"
    values: Mapping[str, object]
    spans: Mapping[str, ScalarSpan]
    line_ending: str


def parse(path: Path) -> Frontmatter:
    try:
        text = path.read_text(encoding="utf-8", newline="")
    except (OSError, UnicodeDecodeError) as exc:
        raise FrontmatterError(f"{path}: {exc}") from exc
    return parse_text(text, path=path)


def parse_text(text: str, *, path: Path | None = None) -> Frontmatter:
    doc = _scan(text, path)
    values = {entry.key: entry.value for entry in doc.entries}
    spans = {
        entry.key: ScalarSpan(
            entry.key,
            entry.scalar.start,
            entry.scalar.end,
            entry.scalar.style,
            entry.scalar.chomp,
            entry.scalar.indent,
        )
        for entry in doc.entries
        if entry.scalar is not None
    }
    return Frontmatter(
        path=path,
        text=text,
        block_start=doc.block_start,
        block_end=doc.block_end,
        values=MappingProxyType(values),
        spans=MappingProxyType(spans),
        line_ending=doc.line_ending,
    )


# --- scanning -----------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class _Line:
    start: int
    text: str  # without its line break
    end: int  # offset just past the line break

    @property
    def has_break(self) -> bool:
        return self.end - self.start > len(self.text)


@dataclass(frozen=True, slots=True)
class _Scalar:
    value: object
    style: str
    chomp: str
    indent: int
    start: int
    end: int
    # Text after the value on its last line (or after a block header's
    # indicator): whitespace and any comment, kept verbatim across edits.
    trailing: str


@dataclass(frozen=True, slots=True)
class _Entry:
    key: str
    line_start: int
    colon_end: int
    value: object
    scalar: _Scalar | None
    entry_end: int  # start of the first line after the entry


@dataclass(frozen=True, slots=True)
class _Document:
    block_start: int
    block_end: int
    line_ending: str
    entries: tuple[_Entry, ...]


_OPENING = re.compile(r"---[ \t]*(\r\n|\n)")
_CLOSING = re.compile(r"---[ \t]*")
# A plain scalar key up to the first ':' that is followed by whitespace or the
# end of the line. Leading '-', '?' and ':' only start a key when not followed
# by whitespace, matching PyYAML's plain-scalar rules.
_KEY = re.compile(
    r"(?P<key>(?:[-?:](?=\S)|[^\s\-?:,\[\]{}#&*!|>'\"%@`])[^\r\n]*?)[ \t]*:(?=[ \t]|$)"
)
_BLOCK_HEADER = re.compile(r"([|>])([1-9+-]{0,2})(?P<trailing>[ \t]*(?:#.*)?)$")
_BREAK_CHARS = "\r\n\x85\u2028\u2029"
_ESCAPES = {
    "0": "\0",
    "a": "\x07",
    "b": "\x08",
    "t": "\t",
    "\t": "\t",
    "n": "\n",
    "v": "\x0b",
    "f": "\x0c",
    "r": "\r",
    "e": "\x1b",
    " ": " ",
    '"': '"',
    "\\": "\\",
    "/": "/",
    "N": "\x85",
    "_": "\xa0",
    "L": "\u2028",
    "P": "\u2029",
}
_ESCAPE_CODES = {"x": 2, "u": 4, "U": 8}


def _line_break(text: str, pos: int) -> str:
    # PyYAML normalizes CR, LF and CRLF to "\n"; NEL, LS and PS stay themselves.
    return "\n" if text[pos] in "\r\n" else text[pos]


def _scan(text: str, path: Path | None) -> _Document:
    where = str(path) if path is not None else "<text>"
    opening = _OPENING.match(text)
    if opening is None:
        raise FrontmatterError(f"{where}: missing opening '---' frontmatter line")
    line_ending = opening.group(1)
    block_start = opening.end()
    lines: list[_Line] = []
    pos = block_start
    block_end: int | None = None
    while pos <= len(text):
        newline = text.find("\n", pos)
        end = len(text) if newline == -1 else newline + 1
        content = text[pos:end].removesuffix("\n").removesuffix("\r")
        if _CLOSING.fullmatch(content):
            block_end = pos
            break
        if pos == len(text):
            break
        lines.append(_Line(pos, content, end))
        pos = end
    if block_end is None:
        raise FrontmatterError(f"{where}: missing closing '---' frontmatter line")
    parser = _Parser(text, tuple(lines), block_end, where)
    entries = parser.parse_document()
    return _Document(block_start, block_end, line_ending, tuple(entries))


class _Parser:
    def __init__(self, text: str, lines: tuple[_Line, ...], block_end: int, where: str):
        self.text = text
        self.lines = lines
        self.block_end = block_end
        self.where = where

    def fail(self, index: int, message: str) -> FrontmatterError:
        # Block lines start on file line 2, just after the opening marker.
        lineno = min(index, len(self.lines)) + 2
        return FrontmatterError(f"{self.where}:{lineno}: {message}")

    def line_start(self, index: int) -> int:
        return self.lines[index].start if index < len(self.lines) else self.block_end

    def column(self, index: int) -> int:
        text = self.lines[index].text
        stripped = text.lstrip(" ")
        if stripped.startswith("\t"):
            raise self.fail(index, "tabs are not allowed in indentation")
        return len(text) - len(stripped)

    def skip_blank(self, index: int) -> int:
        while index < len(self.lines):
            stripped = self.lines[index].text.lstrip(" \t")
            if stripped and not stripped.startswith("#"):
                break
            index += 1
        return index

    def parse_document(self) -> list[_Entry]:
        _, entries, index = self.parse_mapping(0, 0)
        if index < len(self.lines):
            raise self.fail(index, "unexpected content after the frontmatter mapping")
        return entries

    def parse_mapping(
        self, index: int, indent: int, first_col: int | None = None
    ) -> tuple[dict[str, object], list[_Entry], int]:
        values: dict[str, object] = {}
        entries: list[_Entry] = []
        while True:
            index = self.skip_blank(index)
            if index >= len(self.lines):
                break
            col = first_col if first_col is not None else self.column(index)
            first_col = None
            if col < indent:
                break
            if col > indent:
                raise self.fail(index, "unexpected indentation")
            line = self.lines[index]
            rest = line.text[col:]
            if rest == "-" or rest.startswith("- "):
                raise self.fail(index, "expected a mapping key, found a sequence entry")
            match = _KEY.match(rest)
            if match is None:
                raise self.fail(index, "expected 'key: value'")
            key = match.group("key")
            if " #" in key or "\t#" in key:
                raise self.fail(index, "expected ':' after the mapping key")
            if key in values:
                raise self.fail(index, f"duplicate key {key!r}")
            colon_end = line.start + col + match.end()
            value, scalar, next_index = self.parse_value(
                index, col + match.end(), indent, colon_end
            )
            values[key] = value
            entries.append(
                _Entry(
                    key,
                    line.start,
                    colon_end,
                    value,
                    scalar,
                    self.line_start(next_index),
                )
            )
            index = next_index
        return values, entries, index

    def parse_sequence(
        self, index: int, indent: int, first_col: int | None = None
    ) -> tuple[list[object], int]:
        items: list[object] = []
        while True:
            index = self.skip_blank(index)
            if index >= len(self.lines):
                break
            col = first_col if first_col is not None else self.column(index)
            first_col = None
            if col < indent:
                break
            if col > indent:
                raise self.fail(index, "unexpected indentation")
            line = self.lines[index]
            rest = line.text[col:]
            if not (rest == "-" or rest.startswith("- ")):
                break
            item_col = col + 1
            while item_col < len(line.text) and line.text[item_col] == " ":
                item_col += 1
            item = line.text[item_col:]
            if item == "-" or item.startswith("- "):
                value, index = self.parse_sequence(index, item_col, first_col=item_col)
            elif _KEY.match(item):
                value, _, index = self.parse_mapping(
                    index, item_col, first_col=item_col
                )
            else:
                value, _, index = self.parse_value(
                    index, col + 1, indent, line.start + col + 1
                )
            items.append(value)
        return items, index

    def parse_value(
        self, index: int, col: int, indent: int, colon_end: int
    ) -> tuple[object, _Scalar | None, int]:
        line = self.lines[index]
        text = line.text
        while col < len(text) and text[col] in " \t":
            col += 1
        if col >= len(text) or text[col] == "#":
            next_index = self.skip_blank(index + 1)
            if next_index < len(self.lines):
                next_col = self.column(next_index)
                next_rest = self.lines[next_index].text[next_col:]
                is_entry = next_rest == "-" or next_rest.startswith("- ")
                if next_col > indent or (next_col == indent and is_entry):
                    return self.parse_nested(next_index, next_col, indent)
            trailing = text[colon_end - line.start :]
            return (
                None,
                _Scalar(None, "plain", "", 0, colon_end, colon_end, trailing),
                index + 1,
            )
        return self.parse_inline(index, col, indent)

    def parse_nested(
        self, index: int, col: int, indent: int
    ) -> tuple[object, _Scalar | None, int]:
        rest = self.lines[index].text[col:]
        if rest == "-" or rest.startswith("- "):
            items, next_index = self.parse_sequence(index, col)
            return items, None, next_index
        if _KEY.match(rest):
            values, _, next_index = self.parse_mapping(index, col)
            return values, None, next_index
        return self.parse_inline(index, col, indent)

    def parse_inline(
        self, index: int, col: int, indent: int
    ) -> tuple[object, _Scalar | None, int]:
        ch = self.lines[index].text[col]
        if ch in "|>":
            return self.parse_block_scalar(index, col, indent)
        if ch in "\"'":
            return self.parse_quoted(index, col)
        if ch in "[{":
            return self.parse_flow(index, col)
        if ch in "&*!%@`":
            raise self.fail(index, f"unsupported YAML indicator {ch!r}")
        return self.parse_plain(index, col, indent)

    def parse_block_scalar(
        self, index: int, col: int, indent: int
    ) -> tuple[str, _Scalar, int]:
        line = self.lines[index]
        header = _BLOCK_HEADER.match(line.text[col:])
        if header is None:
            raise self.fail(index, "invalid block scalar header")
        style = "literal" if header.group(1) == "|" else "folded"
        chomp = ""
        increment: int | None = None
        for indicator in header.group(2):
            if indicator in "+-":
                if chomp:
                    raise self.fail(index, "repeated chomping indicator")
                chomp = indicator
            else:
                if increment is not None:
                    raise self.fail(index, "repeated indentation indicator")
                increment = int(indicator)
        min_indent = indent + 1
        lines = self.lines
        start = index + 1
        if increment is None:
            max_indent = 0
            probe = start
            while probe < len(lines) and lines[probe].text.strip(" ") == "":
                max_indent = max(max_indent, len(lines[probe].text))
                probe += 1
            if probe < len(lines):
                text = lines[probe].text
                max_indent = max(max_indent, len(text) - len(text.lstrip(" ")))
            content_indent = max(min_indent, max_indent)
        else:
            content_indent = min_indent + increment - 1

        def leading(text: str) -> int:
            count = 0
            while count < content_indent and count < len(text) and text[count] == " ":
                count += 1
            return count

        def is_empty(text: str) -> bool:
            return leading(text) == len(text)

        def is_content(position: int) -> bool:
            if position >= len(lines):
                return False
            text = lines[position].text
            return not is_empty(text) and leading(text) == content_indent

        chunks: list[str] = []
        breaks: list[str] = []
        line_break = ""
        position = start
        while position < len(lines) and is_empty(lines[position].text):
            breaks.append("\n")
            position += 1
        while is_content(position):
            chunks.extend(breaks)
            breaks = []
            content = lines[position].text[content_indent:]
            leading_non_space = content[0] not in " \t"
            chunks.append(content)
            line_break = "\n" if lines[position].has_break else ""
            position += 1
            while position < len(lines) and is_empty(lines[position].text):
                breaks.append("\n")
                position += 1
            if not is_content(position):
                break
            next_content = lines[position].text[content_indent:]
            folds = style == "folded" and line_break == "\n" and leading_non_space
            if folds and next_content[0] not in " \t":
                if not breaks:
                    chunks.append(" ")
            else:
                chunks.append(line_break)
        if chomp != "-":
            chunks.append(line_break)
        if chomp == "+":
            chunks.extend(breaks)
        scalar = _Scalar(
            "".join(chunks),
            style,
            chomp,
            content_indent,
            line.start + col,
            self.line_start(position),
            header.group("trailing"),
        )
        return scalar.value, scalar, position

    def parse_quoted(self, index: int, col: int) -> tuple[str, _Scalar, int]:
        line = self.lines[index]
        start = line.start + col
        value, pos = self.scan_quoted(index, start)
        end_index = self.line_index(index, pos)
        end_line = self.lines[end_index]
        trailing = end_line.text[pos - end_line.start :]
        if trailing.strip(" \t") and not trailing.lstrip(" \t").startswith("#"):
            raise self.fail(end_index, "unexpected content after quoted scalar")
        style = "double" if line.text[col] == '"' else "single"
        scalar = _Scalar(value, style, "", 0, start, pos, trailing)
        return value, scalar, end_index + 1

    def line_index(self, index: int, pos: int) -> int:
        """Index of the line holding the character just before `pos`."""
        while self.lines[index].end <= pos - 1:
            index += 1
        return index

    def scan_quoted(self, index: int, start: int) -> tuple[str, int]:
        text = self.text
        quote = text[start]
        double = quote == '"'
        pos = start + 1
        limit = self.block_end
        chunks: list[str] = []

        def skip_breaks(pos: int) -> tuple[list[str], int]:
            found: list[str] = []
            while True:
                while pos < limit and text[pos] in " \t":
                    pos += 1
                if pos < limit and text[pos] in _BREAK_CHARS:
                    found.append(_line_break(text, pos))
                    pos += 2 if text.startswith("\r\n", pos) else 1
                else:
                    return found, pos

        while True:
            if pos >= limit:
                raise self.fail(index, "unterminated quoted scalar")
            ch = text[pos]
            if ch == quote:
                if not double and text.startswith("''", pos):
                    chunks.append("'")
                    pos += 2
                    continue
                pos += 1
                break
            if double and ch == "\\":
                pos += 1
                if pos >= limit:
                    raise self.fail(index, "unterminated quoted scalar")
                esc = text[pos]
                if esc in _ESCAPES:
                    chunks.append(_ESCAPES[esc])
                    pos += 1
                elif esc in _ESCAPE_CODES:
                    length = _ESCAPE_CODES[esc]
                    digits = text[pos + 1 : pos + 1 + length]
                    if len(digits) != length or not all(
                        c in "0123456789abcdefABCDEF" for c in digits
                    ):
                        raise self.fail(
                            index, f"invalid escape sequence \\{esc}{digits}"
                        )
                    chunks.append(chr(int(digits, 16)))
                    pos += 1 + length
                elif esc in _BREAK_CHARS:
                    pos += 2 if text.startswith("\r\n", pos) else 1
                    found, pos = skip_breaks(pos)
                    chunks.extend(found)
                else:
                    raise self.fail(index, f"invalid escape character {esc!r}")
                continue
            if ch in " \t":
                start = pos
                while pos < limit and text[pos] in " \t":
                    pos += 1
                if pos < limit and text[pos] not in _BREAK_CHARS:
                    chunks.append(text[start:pos])
                continue
            if ch in _BREAK_CHARS:
                line_break = _line_break(text, pos)
                pos += 2 if text.startswith("\r\n", pos) else 1
                found, pos = skip_breaks(pos)
                if line_break != "\n":
                    chunks.append(line_break)
                elif not found:
                    chunks.append(" ")
                chunks.extend(found)
                continue
            chunks.append(ch)
            pos += 1
        return "".join(chunks), pos

    def parse_plain(
        self, index: int, col: int, indent: int
    ) -> tuple[object, _Scalar, int]:
        start = self.lines[index].start + col
        chunks: list[str] = []
        position = index
        while True:
            line = self.lines[position]
            text = line.text
            cut = len(text)
            for k in range(col, len(text)):
                ch = text[k]
                if ch == ":" and (k + 1 == len(text) or text[k + 1] in " \t"):
                    raise self.fail(position, "mapping values are not allowed here")
                if ch == "#" and k > col and text[k - 1] in " \t":
                    cut = k
                    break
            content = text[col:cut].rstrip(" \t")
            chunks.append(content)
            value_end = line.start + col + len(content)
            trailing = text[col + len(content) :]
            # Continuation lines must be indented past the parent, and a
            # comment line ends the scalar; empty lines between fold to "\n".
            probe = position + 1
            breaks = 0
            while probe < len(self.lines) and self.lines[probe].text.strip(" \t") == "":
                breaks += 1
                probe += 1
            if probe >= len(self.lines):
                break
            next_col = self.column(probe)
            if next_col <= indent or self.lines[probe].text[next_col] == "#":
                break
            chunks.append("\n" * breaks if breaks else " ")
            position, col = probe, next_col
        value = _resolve("".join(chunks))
        scalar = _Scalar(value, "plain", "", 0, start, value_end, trailing)
        return value, scalar, position + 1

    def parse_flow(self, index: int, col: int) -> tuple[object, None, int]:
        pos = self.lines[index].start + col
        value, pos = self._flow_node(index, pos)
        end_index = self.line_index(index, pos)
        end_line = self.lines[end_index]
        trailing = end_line.text[pos - end_line.start :]
        if trailing.strip(" \t") and not trailing.lstrip(" \t").startswith("#"):
            raise self.fail(end_index, "unexpected content after flow collection")
        return value, None, end_index + 1

    def _flow_skip(self, pos: int) -> int:
        text = self.text
        while pos < self.block_end:
            if text[pos] in " \t\r\n":
                pos += 1
            elif text[pos] == "#" and (pos == 0 or text[pos - 1] in " \t\r\n"):
                while pos < self.block_end and text[pos] not in "\r\n":
                    pos += 1
            else:
                break
        return pos

    def _flow_key(self, index: int, key: object) -> object:
        try:
            hash(key)
        except TypeError:
            raise self.fail(index, "flow mapping keys must be scalars") from None
        return key

    def _flow_node(self, index: int, pos: int) -> tuple[object, int]:
        text = self.text
        pos = self._flow_skip(pos)
        if pos >= self.block_end:
            raise self.fail(index, "unterminated flow collection")
        ch = text[pos]
        if ch == "[":
            items: list[object] = []
            pos = self._flow_skip(pos + 1)
            while pos < self.block_end and text[pos] != "]":
                item, pos = self._flow_node(index, pos)
                pos = self._flow_skip(pos)
                if pos < self.block_end and text[pos] == ":":
                    value, pos = self._flow_node(index, pos + 1)
                    item = {self._flow_key(index, item): value}
                    pos = self._flow_skip(pos)
                items.append(item)
                if pos < self.block_end and text[pos] == ",":
                    pos = self._flow_skip(pos + 1)
                elif pos < self.block_end and text[pos] != "]":
                    raise self.fail(index, "expected ',' or ']' in flow sequence")
            if pos >= self.block_end:
                raise self.fail(index, "unterminated flow sequence")
            return items, pos + 1
        if ch == "{":
            mapping: dict[object, object] = {}
            pos = self._flow_skip(pos + 1)
            while pos < self.block_end and text[pos] != "}":
                key, pos = self._flow_node(index, pos)
                key = self._flow_key(index, key)
                pos = self._flow_skip(pos)
                value: object = None
                if pos < self.block_end and text[pos] == ":":
                    value, pos = self._flow_node(index, pos + 1)
                    pos = self._flow_skip(pos)
                if key in mapping:
                    raise self.fail(index, f"duplicate key {key!r}")
                mapping[key] = value
                if pos < self.block_end and text[pos] == ",":
                    pos = self._flow_skip(pos + 1)
                elif pos < self.block_end and text[pos] != "}":
                    raise self.fail(index, "expected ',' or '}' in flow mapping")
            if pos >= self.block_end:
                raise self.fail(index, "unterminated flow mapping")
            return mapping, pos + 1
        if ch in "\"'":
            return self.scan_quoted(self.line_index(index, pos + 1), pos)
        if ch in "&*!%@`|>":
            raise self.fail(
                index, f"unsupported YAML indicator {ch!r} in flow collection"
            )
        start = pos
        while pos < self.block_end:
            ch = text[pos]
            if ch in ",[]{}" or ch in "\r\n":
                break
            if ch == ":" and (
                pos + 1 >= self.block_end or text[pos + 1] in " \t\r\n,[]{}"
            ):
                break
            if ch == "#" and text[pos - 1] in " \t":
                break
            pos += 1
        raw = text[start:pos].rstrip(" \t")
        if not raw:
            raise self.fail(index, "empty plain scalar in flow collection")
        return _resolve(raw), start + len(raw)


# --- YAML 1.1 implicit typing (PyYAML's SafeLoader resolvers) -----------------


def _bool_forms(*words: str) -> frozenset[str]:
    return frozenset(
        form for word in words for form in (word, word.capitalize(), word.upper())
    )


_TRUE = _bool_forms("yes", "true", "on")
_FALSE = _bool_forms("no", "false", "off")
_NULLS = frozenset({"", "~", "null", "Null", "NULL"})
_INT = re.compile(
    r"[-+]?0b[0-1_]+|[-+]?0[0-7_]+|[-+]?(?:0|[1-9][0-9_]*)|[-+]?0x[0-9a-fA-F_]+"
    r"|[-+]?[1-9][0-9_]*(?::[0-5]?[0-9])+"
)
_FLOAT = re.compile(
    r"[-+]?(?:[0-9][0-9_]*)\.[0-9_]*(?:[eE][-+][0-9]+)?"
    r"|\.[0-9][0-9_]*(?:[eE][-+][0-9]+)?"
    r"|[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+\.[0-9_]*"
    r"|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN)"
)
_TIMESTAMP = re.compile(
    r"(?P<year>[0-9]{4})-(?P<month>[0-9]{1,2})-(?P<day>[0-9]{1,2})"
    r"(?:(?:[Tt]|[ \t]+)(?P<hour>[0-9]{1,2}):(?P<minute>[0-9]{2}):(?P<second>[0-9]{2})"
    r"(?:\.(?P<fraction>[0-9]*))?"
    r"(?:[ \t]*(?P<tz>Z|(?P<tz_sign>[-+])(?P<tz_hour>[0-9]{1,2})(?::(?P<tz_minute>[0-9]{2}))?))?)?"
)


def _resolve(raw: str) -> object:
    if raw in _NULLS:
        return None
    if raw in _TRUE:
        return True
    if raw in _FALSE:
        return False
    if _INT.fullmatch(raw):
        return _to_int(raw)
    if _FLOAT.fullmatch(raw):
        return _to_float(raw)
    stamp = _TIMESTAMP.fullmatch(raw)
    if stamp is not None and (stamp.group("hour") is not None or len(raw) == 10):
        return _to_timestamp(stamp)
    return raw


def _to_int(raw: str) -> int:
    value = raw.replace("_", "")
    sign = -1 if value.startswith("-") else 1
    value = value.lstrip("+-")
    if value == "0":
        return 0
    if value.startswith("0b"):
        return sign * int(value[2:], 2)
    if value.startswith("0x"):
        return sign * int(value[2:], 16)
    if value.startswith("0"):
        return sign * int(value, 8)
    if ":" in value:
        total = 0
        for part in value.split(":"):
            total = total * 60 + int(part)
        return sign * total
    return sign * int(value)


def _to_float(raw: str) -> float:
    value = raw.replace("_", "").lower()
    sign = -1 if value.startswith("-") else 1
    value = value.lstrip("+-")
    if value == ".inf":
        return sign * float("inf")
    if value == ".nan":
        return float("nan")
    if ":" in value:
        total = 0.0
        for part in value.split(":"):
            total = total * 60 + float(part)
        return sign * total
    return sign * float(value)


def _to_timestamp(match: re.Match[str]) -> dt.date | dt.datetime:
    year, month, day = (int(match.group(name)) for name in ("year", "month", "day"))
    if match.group("hour") is None:
        return dt.date(year, month, day)
    hour, minute, second = (
        int(match.group(name)) for name in ("hour", "minute", "second")
    )
    fraction = (match.group("fraction") or "")[:6].ljust(6, "0")
    tzinfo = None
    if match.group("tz") == "Z":
        tzinfo = dt.timezone.utc
    elif match.group("tz") is not None:
        offset = dt.timedelta(
            hours=int(match.group("tz_hour")),
            minutes=int(match.group("tz_minute") or 0),
        )
        tzinfo = dt.timezone(-offset if match.group("tz_sign") == "-" else offset)
    return dt.datetime(
        year, month, day, hour, minute, second, int(fraction), tzinfo=tzinfo
    )


# --- editing ------------------------------------------------------------------

_DEFAULT_BLOCK_INDENT = 2
_DEFAULT_WRAP_WIDTH = 80
_MIN_WRAP_WIDTH = 20
# Characters PyYAML treats as line breaks; a value holding one only survives
# double-quoted, where they can be escaped.
_BREAK_ONLY_QUOTED = frozenset("\r\x85\u2028\u2029")
# PyYAML's reader refuses these anywhere in the stream, quoted or not, so a
# value holding one only survives double-quoted with the character escaped.
_NON_PRINTABLE = re.compile(
    "[^\t\n\r\x20-\x7e\x85\xa0-\ud7ff\ue000-\ufffd\U00010000-\U0010ffff]"
)
# Followed by whitespace or the line end, these open a block-sequence entry,
# an explicit key, or a mapping value instead of a plain scalar.
_PLAIN_OPENING_INDICATOR = re.compile(r"[-?:](?:[ \t]|$)")
_QUOTED_ESCAPES = {
    "\\": "\\\\",
    '"': '\\"',
    "\n": "\\n",
    "\t": "\\t",
    "\r": "\\r",
    "\x85": "\\N",
    "\xa0": "\\_",
    "\u2028": "\\L",
    "\u2029": "\\P",
}


def edit(fm: Frontmatter, changes: Mapping[str, str | bool | None]) -> str:
    """Return the whole file with each change applied as a span replacement.

    Strings keep the key's existing scalar style when it can carry the new
    value; otherwise a multi-line value becomes a literal block and anything
    else is double-quoted. `None` deletes the key; a missing key is appended
    just before the closing `---`.
    """
    text = fm.text
    for key, value in changes.items():
        text = _apply(text, fm.path, fm.line_ending, key, value)
    return text


def _apply(
    text: str, path: Path | None, line_ending: str, key: str, value: object
) -> str:
    where = str(path) if path is not None else "<text>"
    doc = _scan(text, path)
    entry = next((candidate for candidate in doc.entries if candidate.key == key), None)
    if value is None:
        if entry is None:
            return text
        return text[: entry.line_start] + text[entry.entry_end :]
    if not isinstance(value, (str, bool)):
        raise FrontmatterError(
            f"{where}: {key!r}: cannot write a {type(value).__name__} value"
        )
    if entry is not None and entry.scalar is None:
        raise FrontmatterError(f"{where}: {key!r} is a nested collection, not a scalar")
    if entry is not None and type(entry.value) is type(value) and entry.value == value:
        return text
    others = {k: v for k, v in ((e.key, e.value) for e in doc.entries) if k != key}
    body = text[doc.block_end :]
    if entry is None:
        candidates = _appended(text, doc.block_end, key, value, line_ending)
    else:
        candidates = _rewritten(text, entry, value, line_ending)
    for candidate in candidates:
        if _reads_back(candidate, path, key, value, others, body):
            return candidate
    raise FrontmatterError(
        f"{where}: {key!r}: no supported YAML form reads back as {value!r}"
    )


def _reads_back(
    text: str,
    path: Path | None,
    key: str,
    value: object,
    others: Mapping[str, object],
    body: str,
) -> bool:
    try:
        doc = _scan(text, path)
    except FrontmatterError:
        return False
    values = {entry.key: entry.value for entry in doc.entries}
    if (
        key not in values
        or type(values[key]) is not type(value)
        or values[key] != value
    ):
        return False
    # repr() rather than == so NaN and datetime values compare stably.
    return (
        repr({k: v for k, v in values.items() if k != key}) == repr(others)
        and text[doc.block_end :] == body
    )


def _appended(
    text: str, block_end: int, key: str, value: object, line_ending: str
) -> list[str]:
    rendered: list[str] = []
    if isinstance(value, bool):
        rendered.append(f"{key}: {_bool_token(value)}{line_ending}")
    else:
        assert isinstance(value, str)
        if _flow_safe(value):
            rendered.append(f"{key}: {value}{line_ending}")
        block = _render_block(
            value,
            "literal",
            _DEFAULT_BLOCK_INDENT,
            "",
            line_ending,
            _DEFAULT_WRAP_WIDTH,
        )
        if block is not None and "\n" in value:
            rendered.append(f"{key}: {block}")
        rendered.append(f"{key}: {_double_quoted(value)}{line_ending}")
    return [text[:block_end] + item + text[block_end:] for item in rendered]


def _rewritten(text: str, entry: _Entry, value: object, line_ending: str) -> list[str]:
    scalar = entry.scalar
    assert scalar is not None
    is_block = scalar.style in ("literal", "folded")
    empty_span = scalar.start == scalar.end

    def as_flow(token: str) -> str:
        if is_block:
            return (
                text[: scalar.start]
                + token
                + scalar.trailing
                + line_ending
                + text[scalar.end :]
            )
        gap = " " if empty_span else ""
        return text[: scalar.start] + gap + token + text[scalar.end :]

    def as_block(style: str, indent: int, width: int) -> str | None:
        block = _render_block(value, style, indent, scalar.trailing, line_ending, width)
        if block is None:
            return None
        gap = " " if empty_span else ""
        return text[: scalar.start] + gap + block + text[entry.entry_end :]

    if isinstance(value, bool):
        return [as_flow(_bool_token(value))]
    assert isinstance(value, str)
    candidates: list[str | None] = []
    if is_block:
        indent = scalar.indent
        width = _wrap_width(text[scalar.start : scalar.end], indent)
        if scalar.style == "folded":
            candidates.append(as_block("folded", indent, width))
        candidates.append(as_block("literal", indent, width))
    elif "\n" in value and scalar.style != "double":
        candidates.append(
            as_block("literal", _DEFAULT_BLOCK_INDENT, _DEFAULT_WRAP_WIDTH)
        )
    elif scalar.style == "plain" and _flow_safe(value):
        candidates.append(as_flow(value))
    elif scalar.style == "single" and _flow_safe(value):
        candidates.append(as_flow("'" + value.replace("'", "''") + "'"))
    candidates.append(as_flow(_double_quoted(value)))
    return [candidate for candidate in candidates if candidate is not None]


def _bool_token(value: bool) -> str:
    return "true" if value else "false"


def _flow_safe(value: str) -> bool:
    return (
        bool(value)
        and value == value.strip()
        and "\n" not in value
        and "\t" not in value
        and not _BREAK_ONLY_QUOTED & set(value)
        and _NON_PRINTABLE.search(value) is None
        and _PLAIN_OPENING_INDICATOR.match(value) is None
    )


def _double_quoted(value: str) -> str:
    out = []
    for ch in value:
        if ch in _QUOTED_ESCAPES:
            out.append(_QUOTED_ESCAPES[ch])
        elif _NON_PRINTABLE.match(ch):
            code = ord(ch)
            out.append(f"\\x{code:02x}" if code < 0x100 else f"\\u{code:04x}")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def _wrap_width(block_text: str, indent: int) -> int:
    """Wrap width for a re-rendered folded block: the original's own line length."""
    lines = [line for line in block_text.split("\n")[1:] if line.strip()]
    if len(lines) < 2:
        return _DEFAULT_WRAP_WIDTH
    return max(max(len(line.rstrip("\r")) for line in lines), indent + _MIN_WRAP_WIDTH)


def _render_block(
    value: str, style: str, indent: int, trailing: str, line_ending: str, width: int
) -> str | None:
    """Render `value` as a block scalar from the indicator through its last line break.

    Returns None when no block form can carry the value: nothing but line
    breaks, break characters other than "\\n", characters PyYAML's reader
    refuses, or an indent the indentation indicator cannot express.
    """
    body = value.rstrip("\n")
    if not body or _BREAK_ONLY_QUOTED & set(value) or _NON_PRINTABLE.search(value):
        return None
    trailing_newlines = len(value) - len(body)
    chomp = {0: "-", 1: ""}.get(trailing_newlines, "+")
    lines = body.split("\n")
    first = next(line for line in lines if line)
    explicit = ""
    if first[0] == " ":
        if not 1 <= indent <= 9:
            return None
        explicit = str(indent)
    indicator = ("|" if style == "literal" else ">") + explicit + chomp
    if style == "literal":
        source = lines
    else:
        source = _fold(lines, width - indent)
    out = [indicator + trailing]
    out.extend(" " * indent + line if line else "" for line in source)
    out.extend([""] * max(trailing_newlines - 1, 0))
    return line_ending.join(out) + line_ending


def _fold(lines: list[str], width: int) -> list[str]:
    """Source lines for a folded scalar whose value lines are `lines`.

    Inverts PyYAML's folding: k newlines between two normal lines become k
    empty source lines; a more-indented neighbour absorbs one of them; a
    normal line may be wrapped at single spaces, which fold back to spaces.
    """
    out: list[str] = []
    previous: str | None = None
    gap = 0
    for line in lines:
        if not line:
            gap += 1
            continue
        more_indented = line[0] in " \t"
        if previous is None:
            out.extend([""] * gap)
        elif previous[0] in " \t" or more_indented:
            out.extend([""] * gap)
        else:
            out.extend([""] * (gap + 1))
        out.extend([line] if more_indented else _wrap(line, width))
        previous = line
        gap = 0
    return out


def _wrap(line: str, width: int) -> list[str]:
    # Only a single space between two non-blank characters is a safe break:
    # anything else would leave a fragment starting or ending in whitespace,
    # which PyYAML would treat as a more-indented line or drop.
    breaks = [
        i
        for i in range(1, len(line) - 1)
        if line[i] == " " and line[i - 1] not in " \t" and line[i + 1] not in " \t"
    ]
    out: list[str] = []
    start = 0
    while breaks and len(line) - start > width:
        fits = [i for i in breaks if i - start <= width]
        cut = fits[-1] if fits else breaks[0]
        out.append(line[start:cut])
        start = cut + 1
        breaks = [i for i in breaks if i > cut]
    out.append(line[start:])
    return out
