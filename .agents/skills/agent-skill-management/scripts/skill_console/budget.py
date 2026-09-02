"""Claude Code's skill-listing admission, ported as pure functions.

Every function here is deterministic in its arguments: no filesystem, no
environment, no clock. `admit` is a single port of the serializer `per()`; it
also reproduces the /context estimator `J1n()` when called with
`measure=utf16_length`, because the two differ only in how they measure a row.
"""

from __future__ import annotations

import math
import re
import unicodedata
from bisect import bisect_right
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from skill_console import (
    DATE_SUFFIX_RE,
    DECAY_FLOOR,
    DECAY_HALF_LIFE_DAYS,
    ELLIPSIS,
    LEGACY_BYTES_PER_TOKEN_FAMILIES,
    LISTING_JOIN,
    MODEL_FAMILIES,
    MODEL_FAMILY_REGEX_BRANCHES,
    MS_PER_DAY,
    ROW_PREFIX,
    ROW_SEPARATOR,
    WHEN_TO_USE_JOIN,
    Admission,
    BudgetInputs,
    ListingEntry,
    Predicted,
    Rendered,
    RowCost,
    Usage,
)

# --- Bun.stringWidth ---------------------------------------------------------
#
# The serializer's `se()` is `Bun.stringWidth(text, {ambiguousIsNarrow: true})`.
# Bun 1.4.x (src/bun.js/bindings/stringWidth.cpp) decodes UTF-16 dropping lone
# surrogates, cuts the rest into grapheme clusters with a UAX #29 port, and
# charges each cluster either the sum of its code point widths or one of a few
# cluster overrides: a flag pair, a keycap, an emoji with a skin tone or ZWJ,
# or an emoji-presentation sequence (VS16 after a base with the Emoji
# property). The functions below mirror that file; the property tables are
# Unicode 16.0 (UNICODE_VERSION) and were generated from ICU, since
# unicodedata carries neither the Emoji properties nor the grapheme classes.

_ZERO_WIDTH_CATEGORIES = frozenset({"Cc", "Cf", "Mn", "Me"})
_WIDE_EAST_ASIAN = frozenset({"W", "F"})
_SURROGATES = range(0xD800, 0xE000)
_REGIONAL_INDICATORS = range(0x1F1E6, 0x1F200)
_SKIN_TONE_MODIFIERS = range(0x1F3FB, 0x1F400)
_ZWJ = 0x200D
_ZWNJ = 0x200C
_VS15 = 0xFE0E
_VS16 = 0xFE0F
_KEYCAP = 0x20E3
# The two Emoji-property code points below U+203C that VS16 still widens;
# Bun's table clears the emoji bit for everything under U+203C (#, *, 0-9).
_VS16_LATIN1_EMOJI = frozenset({0x00A9, 0x00AE})
_EMOJI_BIT_FLOOR = 0x203C
# Measured departures of Bun's emoji bit from Unicode 16 emoji-data: the four
# CJK-block emoji sit above its BMP early-out, and the seven code points emoji
# 17.0 added are already flagged (they are unassigned in Unicode 16).
_EMOJI_BIT_CLEARED = frozenset({0x3030, 0x303D, 0x3297, 0x3299})
_EMOJI_BIT_ADDED = frozenset(
    {0x1F6D8, 0x1FA8A, 0x1FA8E, 0x1FAC8, 0x1FACD, 0x1FAEA, 0x1FAEF}
)
# Bun caps a cluster's summed width at 1023.
_CLUSTER_WIDTH_CAP = 1023


def _ranges(*pairs: tuple[int, int]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    starts, ends = zip(*pairs, strict=True)
    return tuple(starts), tuple(ends)


def _in_ranges(code: int, table: tuple[tuple[int, ...], tuple[int, ...]]) -> bool:
    starts, ends = table
    index = bisect_right(starts, code) - 1
    return index >= 0 and code <= ends[index]


# Hangul jungseong and jongseong (and their extended blocks) are Lo with East
# Asian width N, but Bun's table gives them zero width: they only ever render
# combined with the leading consonant.
_HANGUL_ZERO_WIDTH_RANGES = _ranges((0x1160, 0x11FF), (0xD7B0, 0xD7FF))
# Where Bun's generated width table departs from the category/East-Asian-width
# rule above: Indic spacing vowel signs and a few Lo signs at zero, the
# interlinear-annotation, Kaithi and Egyptian format controls at one, and the
# unassigned code points whose width the table fills from the surrounding
# block. The generator's rule for these is not recoverable from unicodedata,
# so the ranges are Bun 1.4.0's table read back through `Bun.stringWidth`
# over every code point (see UNICODE_PROVENANCE).
_ZERO_WIDTH_OVERRIDE_RANGES = _ranges(
    (0x093B, 0x093B), (0x093E, 0x0940), (0x0949, 0x094C), (0x0980, 0x0980), (0x0982, 0x0982),
    (0x09BA, 0x09BB), (0x09BE, 0x09C0), (0x09C5, 0x09CC), (0x09D1, 0x09D7), (0x0A00, 0x0A00),
    (0x0A3A, 0x0A3B), (0x0A3E, 0x0A40), (0x0A43, 0x0A46), (0x0A49, 0x0A4A), (0x0A52, 0x0A57),
    (0x0A62, 0x0A63), (0x0A80, 0x0A80), (0x0ABA, 0x0ABB), (0x0ABE, 0x0AC0), (0x0AC6, 0x0AC6),
    (0x0AC9, 0x0ACC), (0x0AD1, 0x0AD7), (0x0B00, 0x0B00), (0x0B02, 0x0B02), (0x0B3A, 0x0B3B),
    (0x0B3E, 0x0B3E), (0x0B40, 0x0B40), (0x0B45, 0x0B4C), (0x0B51, 0x0B54), (0x0B57, 0x0B57),
    (0x0B80, 0x0B81), (0x0BBA, 0x0BBC), (0x0BBE, 0x0BBF), (0x0BC1, 0x0BCC), (0x0BD1, 0x0BD7),
    (0x0BE2, 0x0BE3), (0x0C01, 0x0C02), (0x0C3A, 0x0C3B), (0x0C41, 0x0C45), (0x0C49, 0x0C49),
    (0x0C51, 0x0C54), (0x0C57, 0x0C57), (0x0C80, 0x0C80), (0x0C82, 0x0C82), (0x0CBA, 0x0CBB),
    (0x0CBE, 0x0CBE), (0x0CC0, 0x0CC5), (0x0CC7, 0x0CCB), (0x0CD1, 0x0CD7), (0x0D02, 0x0D02),
    (0x0D3A, 0x0D3A), (0x0D3E, 0x0D40), (0x0D45, 0x0D4C), (0x1ACF, 0x1AFF), (0x2065, 0x2065),
    (0x20F1, 0x20FF), (0x10EFA, 0x10EFB), (0x11B60, 0x11B60), (0x11B62, 0x11B64), (0x11B66, 0x11B66),
    (0x1E6E3, 0x1E6E3), (0x1E6E6, 0x1E6E6), (0x1E6EE, 0x1E6EF), (0x1E6F5, 0x1E6F5), (0xE0000, 0xE0000),
    (0xE0002, 0xE001F),
)
_NARROW_OVERRIDE_RANGES = _ranges(
    (0x0890, 0x0891), (0xFFF9, 0xFFFB), (0x110BD, 0x110BD), (0x110CD, 0x110CD), (0x13430, 0x1343F),
)
_WIDE_OVERRIDE_RANGES = _ranges(
    (0x16FF2, 0x16FF6), (0x187F8, 0x187FF), (0x18D09, 0x18D1E), (0x18D80, 0x18DF2), (0x1F6D8, 0x1F6D8),
    (0x1FA8A, 0x1FA8A), (0x1FA8E, 0x1FA8E), (0x1FAC8, 0x1FAC8), (0x1FACD, 0x1FACD), (0x1FAEA, 0x1FAEA),
    (0x1FAEF, 0x1FAEF),
)
_HANGUL_L_RANGES = _ranges((0x1100, 0x115F), (0xA960, 0xA97C))
_HANGUL_V_RANGES = _ranges((0x1160, 0x11A7), (0xD7B0, 0xD7C6))
_HANGUL_T_RANGES = _ranges((0x11A8, 0x11FF), (0xD7CB, 0xD7FB))
_HANGUL_SYLLABLES = range(0xAC00, 0xD7A4)
_HANGUL_SYLLABLE_T_COUNT = 28
# Lo code points that UAX #29 lists as SpacingMark.
_SPACING_MARK_EXTRA = frozenset({0x0E33, 0x0EB3})

_EMOJI_RANGES = _ranges(
    (0x203C, 0x203C), (0x2049, 0x2049), (0x2122, 0x2122), (0x2139, 0x2139), (0x2194, 0x2199),
    (0x21A9, 0x21AA), (0x231A, 0x231B), (0x2328, 0x2328), (0x23CF, 0x23CF), (0x23E9, 0x23F3),
    (0x23F8, 0x23FA), (0x24C2, 0x24C2), (0x25AA, 0x25AB), (0x25B6, 0x25B6), (0x25C0, 0x25C0),
    (0x25FB, 0x25FE), (0x2600, 0x2604), (0x260E, 0x260E), (0x2611, 0x2611), (0x2614, 0x2615),
    (0x2618, 0x2618), (0x261D, 0x261D), (0x2620, 0x2620), (0x2622, 0x2623), (0x2626, 0x2626),
    (0x262A, 0x262A), (0x262E, 0x262F), (0x2638, 0x263A), (0x2640, 0x2640), (0x2642, 0x2642),
    (0x2648, 0x2653), (0x265F, 0x2660), (0x2663, 0x2663), (0x2665, 0x2666), (0x2668, 0x2668),
    (0x267B, 0x267B), (0x267E, 0x267F), (0x2692, 0x2697), (0x2699, 0x2699), (0x269B, 0x269C),
    (0x26A0, 0x26A1), (0x26A7, 0x26A7), (0x26AA, 0x26AB), (0x26B0, 0x26B1), (0x26BD, 0x26BE),
    (0x26C4, 0x26C5), (0x26C8, 0x26C8), (0x26CE, 0x26CF), (0x26D1, 0x26D1), (0x26D3, 0x26D4),
    (0x26E9, 0x26EA), (0x26F0, 0x26F5), (0x26F7, 0x26FA), (0x26FD, 0x26FD), (0x2702, 0x2702),
    (0x2705, 0x2705), (0x2708, 0x270D), (0x270F, 0x270F), (0x2712, 0x2712), (0x2714, 0x2714),
    (0x2716, 0x2716), (0x271D, 0x271D), (0x2721, 0x2721), (0x2728, 0x2728), (0x2733, 0x2734),
    (0x2744, 0x2744), (0x2747, 0x2747), (0x274C, 0x274C), (0x274E, 0x274E), (0x2753, 0x2755),
    (0x2757, 0x2757), (0x2763, 0x2764), (0x2795, 0x2797), (0x27A1, 0x27A1), (0x27B0, 0x27B0),
    (0x27BF, 0x27BF), (0x2934, 0x2935), (0x2B05, 0x2B07), (0x2B1B, 0x2B1C), (0x2B50, 0x2B50),
    (0x2B55, 0x2B55), (0x3030, 0x3030), (0x303D, 0x303D), (0x3297, 0x3297), (0x3299, 0x3299),
    (0x1F004, 0x1F004), (0x1F0CF, 0x1F0CF), (0x1F170, 0x1F171), (0x1F17E, 0x1F17F), (0x1F18E, 0x1F18E),
    (0x1F191, 0x1F19A), (0x1F1E6, 0x1F1FF), (0x1F201, 0x1F202), (0x1F21A, 0x1F21A), (0x1F22F, 0x1F22F),
    (0x1F232, 0x1F23A), (0x1F250, 0x1F251), (0x1F300, 0x1F321), (0x1F324, 0x1F393), (0x1F396, 0x1F397),
    (0x1F399, 0x1F39B), (0x1F39E, 0x1F3F0), (0x1F3F3, 0x1F3F5), (0x1F3F7, 0x1F4FD), (0x1F4FF, 0x1F53D),
    (0x1F549, 0x1F54E), (0x1F550, 0x1F567), (0x1F56F, 0x1F570), (0x1F573, 0x1F57A), (0x1F587, 0x1F587),
    (0x1F58A, 0x1F58D), (0x1F590, 0x1F590), (0x1F595, 0x1F596), (0x1F5A4, 0x1F5A5), (0x1F5A8, 0x1F5A8),
    (0x1F5B1, 0x1F5B2), (0x1F5BC, 0x1F5BC), (0x1F5C2, 0x1F5C4), (0x1F5D1, 0x1F5D3), (0x1F5DC, 0x1F5DE),
    (0x1F5E1, 0x1F5E1), (0x1F5E3, 0x1F5E3), (0x1F5E8, 0x1F5E8), (0x1F5EF, 0x1F5EF), (0x1F5F3, 0x1F5F3),
    (0x1F5FA, 0x1F64F), (0x1F680, 0x1F6C5), (0x1F6CB, 0x1F6D2), (0x1F6D5, 0x1F6D7), (0x1F6DC, 0x1F6E5),
    (0x1F6E9, 0x1F6E9), (0x1F6EB, 0x1F6EC), (0x1F6F0, 0x1F6F0), (0x1F6F3, 0x1F6FC), (0x1F7E0, 0x1F7EB),
    (0x1F7F0, 0x1F7F0), (0x1F90C, 0x1F93A), (0x1F93C, 0x1F945), (0x1F947, 0x1F9FF), (0x1FA70, 0x1FA7C),
    (0x1FA80, 0x1FA89), (0x1FA8F, 0x1FAC6), (0x1FACE, 0x1FADC), (0x1FADF, 0x1FAE9), (0x1FAF0, 0x1FAF8),
)
_EXTENDED_PICTOGRAPHIC_RANGES = _ranges(
    (0x00A9, 0x00A9), (0x00AE, 0x00AE), (0x203C, 0x203C), (0x2049, 0x2049), (0x2122, 0x2122),
    (0x2139, 0x2139), (0x2194, 0x2199), (0x21A9, 0x21AA), (0x231A, 0x231B), (0x2328, 0x2328),
    (0x2388, 0x2388), (0x23CF, 0x23CF), (0x23E9, 0x23F3), (0x23F8, 0x23FA), (0x24C2, 0x24C2),
    (0x25AA, 0x25AB), (0x25B6, 0x25B6), (0x25C0, 0x25C0), (0x25FB, 0x25FE), (0x2600, 0x2605),
    (0x2607, 0x2612), (0x2614, 0x2685), (0x2690, 0x2705), (0x2708, 0x2712), (0x2714, 0x2714),
    (0x2716, 0x2716), (0x271D, 0x271D), (0x2721, 0x2721), (0x2728, 0x2728), (0x2733, 0x2734),
    (0x2744, 0x2744), (0x2747, 0x2747), (0x274C, 0x274C), (0x274E, 0x274E), (0x2753, 0x2755),
    (0x2757, 0x2757), (0x2763, 0x2767), (0x2795, 0x2797), (0x27A1, 0x27A1), (0x27B0, 0x27B0),
    (0x27BF, 0x27BF), (0x2934, 0x2935), (0x2B05, 0x2B07), (0x2B1B, 0x2B1C), (0x2B50, 0x2B50),
    (0x2B55, 0x2B55), (0x3030, 0x3030), (0x303D, 0x303D), (0x3297, 0x3297), (0x3299, 0x3299),
    (0x1F000, 0x1F0FF), (0x1F10D, 0x1F10F), (0x1F12F, 0x1F12F), (0x1F16C, 0x1F171), (0x1F17E, 0x1F17F),
    (0x1F18E, 0x1F18E), (0x1F191, 0x1F19A), (0x1F1AD, 0x1F1E5), (0x1F201, 0x1F20F), (0x1F21A, 0x1F21A),
    (0x1F22F, 0x1F22F), (0x1F232, 0x1F23A), (0x1F23C, 0x1F23F), (0x1F249, 0x1F3FA), (0x1F400, 0x1F53D),
    (0x1F546, 0x1F64F), (0x1F680, 0x1F6FF), (0x1F774, 0x1F77F), (0x1F7D5, 0x1F7FF), (0x1F80C, 0x1F80F),
    (0x1F848, 0x1F84F), (0x1F85A, 0x1F85F), (0x1F888, 0x1F88F), (0x1F8AE, 0x1F8FF), (0x1F90C, 0x1F93A),
    (0x1F93C, 0x1F945), (0x1F947, 0x1FAFF), (0x1FC00, 0x1FFFD),
)
_EMOJI_MODIFIER_BASE_RANGES = _ranges(
    (0x261D, 0x261D), (0x26F9, 0x26F9), (0x270A, 0x270D), (0x1F385, 0x1F385), (0x1F3C2, 0x1F3C4),
    (0x1F3C7, 0x1F3C7), (0x1F3CA, 0x1F3CC), (0x1F442, 0x1F443), (0x1F446, 0x1F450), (0x1F466, 0x1F478),
    (0x1F47C, 0x1F47C), (0x1F481, 0x1F483), (0x1F485, 0x1F487), (0x1F48F, 0x1F48F), (0x1F491, 0x1F491),
    (0x1F4AA, 0x1F4AA), (0x1F574, 0x1F575), (0x1F57A, 0x1F57A), (0x1F590, 0x1F590), (0x1F595, 0x1F596),
    (0x1F645, 0x1F647), (0x1F64B, 0x1F64F), (0x1F6A3, 0x1F6A3), (0x1F6B4, 0x1F6B6), (0x1F6C0, 0x1F6C0),
    (0x1F6CC, 0x1F6CC), (0x1F90C, 0x1F90C), (0x1F90F, 0x1F90F), (0x1F918, 0x1F91F), (0x1F926, 0x1F926),
    (0x1F930, 0x1F939), (0x1F93C, 0x1F93E), (0x1F977, 0x1F977), (0x1F9B5, 0x1F9B6), (0x1F9B8, 0x1F9B9),
    (0x1F9BB, 0x1F9BB), (0x1F9CD, 0x1F9CF), (0x1F9D1, 0x1F9DD), (0x1FAC3, 0x1FAC5), (0x1FAF0, 0x1FAF8),
)
_OTHER_GRAPHEME_EXTEND_RANGES = _ranges(
    (0x09BE, 0x09BE), (0x09D7, 0x09D7), (0x0B3E, 0x0B3E), (0x0B57, 0x0B57), (0x0BBE, 0x0BBE),
    (0x0BD7, 0x0BD7), (0x0CC0, 0x0CC0), (0x0CC2, 0x0CC2), (0x0CC7, 0x0CC8), (0x0CCA, 0x0CCB),
    (0x0CD5, 0x0CD6), (0x0D3E, 0x0D3E), (0x0D57, 0x0D57), (0x0DCF, 0x0DCF), (0x0DDF, 0x0DDF),
    (0x1715, 0x1715), (0x1734, 0x1734), (0x1B35, 0x1B35), (0x1B3B, 0x1B3B), (0x1B3D, 0x1B3D),
    (0x1B43, 0x1B44), (0x1BAA, 0x1BAA), (0x1BF2, 0x1BF3), (0x200C, 0x200C), (0x302E, 0x302F),
    (0xA953, 0xA953), (0xA9C0, 0xA9C0), (0xFF9E, 0xFF9F), (0x111C0, 0x111C0), (0x11235, 0x11235),
    (0x1133E, 0x1133E), (0x1134D, 0x1134D), (0x11357, 0x11357), (0x113B8, 0x113B8), (0x113C2, 0x113C2),
    (0x113C5, 0x113C5), (0x113C7, 0x113C9), (0x113CF, 0x113CF), (0x114B0, 0x114B0), (0x114BD, 0x114BD),
    (0x115AF, 0x115AF), (0x116B6, 0x116B6), (0x11930, 0x11930), (0x1193D, 0x1193D), (0x11F41, 0x11F41),
    (0x16FF0, 0x16FF1), (0x1D165, 0x1D166), (0x1D16D, 0x1D172), (0xE0020, 0xE007F),
)
_SPACING_MARK_EXCLUDED_RANGES = _ranges(
    (0x102B, 0x102C), (0x1038, 0x1038), (0x1062, 0x1064), (0x1067, 0x106D), (0x1083, 0x1083),
    (0x1087, 0x108C), (0x108F, 0x108F), (0x109A, 0x109C), (0x1A61, 0x1A61), (0x1A63, 0x1A64),
    (0xAA7B, 0xAA7B), (0xAA7D, 0xAA7D), (0x11720, 0x11721),
)
_PREPEND_RANGES = _ranges(
    (0x0600, 0x0605), (0x06DD, 0x06DD), (0x070F, 0x070F), (0x0890, 0x0891), (0x08E2, 0x08E2),
    (0x0D4E, 0x0D4E), (0x110BD, 0x110BD), (0x110CD, 0x110CD), (0x111C2, 0x111C3), (0x113D1, 0x113D1),
    (0x1193F, 0x1193F), (0x11941, 0x11941), (0x11A3A, 0x11A3A), (0x11A84, 0x11A89), (0x11D46, 0x11D46),
    (0x11F02, 0x11F02),
)

# Grapheme break classes, Bun's enum minus the Indic conjunct classes: no code
# point maps to them here, and GB9c can only change a width when a conjunct is
# followed by VS16 or a keycap, which is documented as a residual divergence.
_GB_OTHER, _GB_PREPEND, _GB_RI, _GB_SPACING_MARK = range(4)
_GB_L, _GB_V, _GB_T, _GB_LV, _GB_LVT = range(4, 9)
_GB_ZWJ, _GB_ZWNJ, _GB_EXT_PICT, _GB_EMOJI_MOD_BASE, _GB_EMOJI_MOD, _GB_EXTEND = range(9, 15)
_STATE_DEFAULT, _STATE_RI, _STATE_EXT_PICT = range(3)
_GB_EXTENDS = frozenset({_GB_EXTEND, _GB_ZWNJ})
_GB_PICTOGRAPHIC = frozenset({_GB_EXT_PICT, _GB_EMOJI_MOD_BASE})
_GB_EXT_PICT_SEQUENCE = _GB_EXTENDS | _GB_PICTOGRAPHIC | {_GB_ZWJ, _GB_EMOJI_MOD}


def _codepoint_width(code: int) -> int:
    """Bun's per-code-point column width with ambiguous characters narrow."""
    if code < 0x80:
        return 1 if 0x20 <= code < 0x7F else 0
    if _in_ranges(code, _ZERO_WIDTH_OVERRIDE_RANGES):
        return 0
    if _in_ranges(code, _NARROW_OVERRIDE_RANGES):
        return 1
    if _in_ranges(code, _WIDE_OVERRIDE_RANGES):
        return 2
    char = chr(code)
    if unicodedata.category(char) in _ZERO_WIDTH_CATEGORIES or _in_ranges(
        code, _HANGUL_ZERO_WIDTH_RANGES
    ):
        return 0
    return 2 if unicodedata.east_asian_width(char) in _WIDE_EAST_ASIAN else 1


def _has_emoji_bit(code: int) -> bool:
    if code in _EMOJI_BIT_ADDED:
        return True
    if code < _EMOJI_BIT_FLOOR or code in _EMOJI_BIT_CLEARED:
        return False
    return _in_ranges(code, _EMOJI_RANGES)


def _break_class(code: int) -> int:
    if code < 0x80:
        return _GB_OTHER
    if code == _ZWJ:
        return _GB_ZWJ
    if code == _ZWNJ:
        return _GB_ZWNJ
    if code in _REGIONAL_INDICATORS:
        return _GB_RI
    if code in _SKIN_TONE_MODIFIERS:
        return _GB_EMOJI_MOD
    if code in _HANGUL_SYLLABLES:
        return _GB_LV if (code - _HANGUL_SYLLABLES.start) % _HANGUL_SYLLABLE_T_COUNT == 0 else _GB_LVT
    if _in_ranges(code, _HANGUL_L_RANGES):
        return _GB_L
    if _in_ranges(code, _HANGUL_V_RANGES):
        return _GB_V
    if _in_ranges(code, _HANGUL_T_RANGES):
        return _GB_T
    category = unicodedata.category(chr(code))
    if category in ("Mn", "Me") or _in_ranges(code, _OTHER_GRAPHEME_EXTEND_RANGES):
        return _GB_EXTEND
    if _in_ranges(code, _PREPEND_RANGES):
        return _GB_PREPEND
    if (category == "Mc" and not _in_ranges(code, _SPACING_MARK_EXCLUDED_RANGES)) or code in _SPACING_MARK_EXTRA:
        return _GB_SPACING_MARK
    if _in_ranges(code, _EMOJI_MODIFIER_BASE_RANGES):
        return _GB_EMOJI_MOD_BASE
    if _in_ranges(code, _EXTENDED_PICTOGRAPHIC_RANGES):
        return _GB_EXT_PICT
    return _GB_OTHER


def _grapheme_break(gb1: int, gb2: int, state: int) -> tuple[bool, int]:
    """`computeGraphemeBreakNoControl`: (break before gb2?, next state)."""
    if state == _STATE_RI and (gb1 != _GB_RI or gb2 != _GB_RI):
        state = _STATE_DEFAULT
    elif state == _STATE_EXT_PICT and (
        gb1 not in _GB_EXT_PICT_SEQUENCE or gb2 not in _GB_EXT_PICT_SEQUENCE
    ):
        state = _STATE_DEFAULT
    # GB6, GB7, GB8: Hangul syllable sequences.
    if gb1 == _GB_L and gb2 in (_GB_L, _GB_V, _GB_LV, _GB_LVT):
        return False, state
    if gb1 in (_GB_LV, _GB_V) and gb2 in (_GB_V, _GB_T):
        return False, state
    if gb1 in (_GB_LVT, _GB_T) and gb2 == _GB_T:
        return False, state
    # GB9a, GB9b.
    if gb2 == _GB_SPACING_MARK or gb1 == _GB_PREPEND:
        return False, state
    # GB11: emoji ZWJ and emoji modifier sequences.
    if gb1 in _GB_PICTOGRAPHIC:
        if gb2 in _GB_EXTENDS or gb2 == _GB_ZWJ:
            return False, _STATE_EXT_PICT
        if gb1 == _GB_EMOJI_MOD_BASE and gb2 == _GB_EMOJI_MOD:
            return False, _STATE_EXT_PICT
    elif state == _STATE_EXT_PICT:
        if (gb1 in _GB_EXTENDS or gb1 == _GB_EMOJI_MOD) and (gb2 in _GB_EXTENDS or gb2 == _GB_ZWJ):
            return False, state
        if gb1 == _GB_ZWJ and gb2 in _GB_PICTOGRAPHIC:
            return False, _STATE_DEFAULT
        state = _STATE_DEFAULT
    # GB12, GB13: regional indicators pair up from the left.
    if gb1 == _GB_RI and gb2 == _GB_RI:
        if state == _STATE_DEFAULT:
            return False, _STATE_RI
        return True, _STATE_DEFAULT
    # GB9.
    if gb2 in _GB_EXTENDS or gb2 == _GB_ZWJ:
        return False, state
    return True, state


def _cluster_width(codes: Sequence[int]) -> int:
    """`GraphemeState::width()` for one cluster."""
    first = codes[0]
    base_width = _codepoint_width(first)
    emoji_base = first >= 0x80 and _has_emoji_bit(first)
    if any(code in _REGIONAL_INDICATORS for code in codes):
        return 2 if len(codes) >= 2 else 1
    if _KEYCAP in codes:
        return 2
    if emoji_base and (_ZWJ in codes or any(code in _SKIN_TONE_MODIFIERS for code in codes)):
        return 2
    # Variation selectors only count after the first code point of a cluster.
    vs16 = _VS16 in codes[1:]
    if vs16 or _VS15 in codes[1:]:
        if base_width == 2 or (vs16 and (emoji_base or first in _VS16_LATIN1_EMOJI)):
            return 2
        return base_width
    return min(sum(_codepoint_width(code) for code in codes), _CLUSTER_WIDTH_CAP)


def display_width(text: str) -> int:
    """`Bun.stringWidth(text, {ambiguousIsNarrow: true})`. Governs cost."""
    if text.isascii():
        return sum(1 for char in text if " " <= char < "\x7f")
    width = 0
    cluster: list[int] = []
    previous = _GB_OTHER
    state = _STATE_DEFAULT
    for char in text:
        code = ord(char)
        if code in _SURROGATES:
            continue
        current = _break_class(code)
        if cluster:
            breaks, state = _grapheme_break(previous, current, state)
            if breaks:
                width += _cluster_width(cluster)
                cluster = []
        cluster.append(code)
        previous = current
    if cluster:
        width += _cluster_width(cluster)
    return width


# Combining marks, format characters, and lone surrogates: the classes where a
# Python reimplementation of Bun.stringWidth cannot be trusted to agree.
_WRITE_UNSAFE_CATEGORIES = frozenset({"Mn", "Me", "Cf", "Cs"})

# JS regexes use ASCII \d; Python's would also accept other scripts' digits.
_DATE_SUFFIX = re.compile(DATE_SUFFIX_RE, re.ASCII)
_ONE_M_SUFFIX = re.compile(r"\[1m\]$", re.IGNORECASE)
_ID_SEPARATORS = re.compile(r"[._]")
_FAMILY_REGEX_BRANCHES = {
    after: (re.compile(pattern, re.ASCII), result)
    for after, pattern, result in MODEL_FAMILY_REGEX_BRANCHES
}

# The string forms JS Number() accepts, then the grouped-digit fallback the
# binary's env parser tries when Number() yields NaN.
_JS_DECIMAL = re.compile(
    r"[+-]?(?:(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?|Infinity)", re.ASCII
)
_JS_RADIX_LITERALS = (
    (re.compile(r"0[xX][0-9a-fA-F]+"), 16),
    (re.compile(r"0[oO][0-7]+"), 8),
    (re.compile(r"0[bB][01]+"), 2),
)
_GROUPED_DIGITS = re.compile(
    r"[+-]?\d{1,3}([_,\u00A0\u202F ])\d{3}(?:\1\d{3})*", re.ASCII
)
_GROUP_SEPARATORS = re.compile(r"[_,\u00A0\u202F ]")
_GROUPED_DIGITS_MAX_LEN = 32

_CONTEXT_CELL_MIN_TOKENS = 20
_COMPACT_UNITS = (("b", 10**9), ("m", 10**6), ("k", 10**3))

Measure = Callable[[str], int]


def utf16_length(text: str) -> int:
    """JS `.length`: UTF-16 code units. Governs the description cap."""
    return sum(2 if ord(char) > 0xFFFF else 1 for char in text)


def _model_family(model_id: str) -> str:
    """`s_()` without its provider-id catalog branches.

    The catalog resolves the same family for every id that contains a family
    literal, which is every id Anthropic, Bedrock, Vertex, or Foundry issue.
    """
    lowered = model_id.lower()
    for family in MODEL_FAMILIES:
        if family in lowered:
            return family
        branch = _FAMILY_REGEX_BRANCHES.get(family)
        if branch is not None and branch[0].search(lowered):
            return branch[1]
    return _DATE_SUFFIX.sub("", lowered)


def normalize_model_id(model_id: str) -> str:
    """The key `gf()` looks up: family, then the `[1m]` and `[._]` rewrites.

    Bare aliases (`opus`, `sonnet`, ...) resolve against live account state the
    console cannot see; callers must reject them before reaching this point.
    """
    return _ID_SEPARATORS.sub("-", _ONE_M_SUFFIX.sub("", _model_family(model_id)))


def bytes_per_token(model_id: str) -> int:
    """`gf()`: 4 for the legacy families, 3 for everything newer."""
    if not model_id:
        return 4
    return 4 if normalize_model_id(model_id) in LEGACY_BYTES_PER_TOKEN_FAMILIES else 3


def _js_number(text: str) -> float | None:
    """`Number(text)` for string input; None where JS yields NaN."""
    stripped = text.strip()
    if stripped == "":
        return 0.0
    if _JS_DECIMAL.fullmatch(stripped):
        return float(stripped)
    for pattern, base in _JS_RADIX_LITERALS:
        if pattern.fullmatch(stripped):
            return float(int(stripped[2:], base))
    return None


def parse_env_budget(raw: str | None) -> int | float | None:
    """`Zx(SLASH_COMMAND_TOOL_CHAR_BUDGET)`: the JS number, or None where it is NaN.

    The binary uses that number as the budget without rounding, so `0.5` and
    `Infinity` come back as floats; integral values come back as int only
    because JS does not distinguish the two. `budget_chars` applies the same
    truthiness test the binary does, so zero means unset and negative values
    are used verbatim.
    """
    if raw is None:
        return None
    value = _js_number(raw)
    if value is None:
        stripped = raw.strip()
        if len(stripped) <= _GROUPED_DIGITS_MAX_LEN and _GROUPED_DIGITS.fullmatch(
            stripped
        ):
            value = float(_GROUP_SEPARATORS.sub("", stripped))
    if value is None or math.isnan(value):
        return None
    if math.isfinite(value) and value.is_integer():
        return int(value)
    return value


def budget_chars(inputs: BudgetInputs) -> int | float:
    """`iTe()`: a truthy env override wins; else floor(window * b/t * fraction), min 1."""
    if inputs.env_budget:
        return inputs.env_budget
    return max(
        1, math.floor(inputs.context_window * inputs.bytes_per_token * inputs.fraction)
    )


def _budget_from_env(inputs: BudgetInputs) -> bool:
    return inputs.env_budget is not None and inputs.env_budget > 0


def listing_text(description: str, when_to_use: str | None) -> str:
    """`XOe()`: an empty `when_to_use` is falsy in JS and adds nothing."""
    if when_to_use:
        return f"{description}{WHEN_TO_USE_JOIN}{when_to_use}"
    return description


def _utf16_slice(text: str, units: int) -> str:
    """JS `text.slice(0, units)`; a cut inside a surrogate pair keeps the high half."""
    encoded = text.encode("utf-16-le", "surrogatepass")
    return encoded[: 2 * max(units, 0)].decode("utf-16-le", "surrogatepass")


def cap_description(text: str, max_desc_chars: int) -> tuple[str, bool]:
    """`I7o()`: over the cap, keep `max_desc_chars - 1` UTF-16 units plus an ellipsis."""
    if utf16_length(text) <= max_desc_chars:
        return text, False
    return _utf16_slice(text, max_desc_chars - 1) + ELLIPSIS, True


def rank(usage: Usage | None, now_ms: int) -> float:
    """`HLe()`: usage count halved every seven days, floored at 0.1, age unclamped."""
    if usage is None:
        return 0.0
    age_days = (now_ms - usage.last_used_at_ms) / MS_PER_DAY
    try:
        decay = 0.5 ** (age_days / DECAY_HALF_LIFE_DAYS)
    except OverflowError:
        decay = math.inf
    return usage.usage_count * max(decay, DECAY_FLOOR)


def _row_texts(entry: ListingEntry, max_desc_chars: int) -> tuple[str, str, bool]:
    capped_text, capped = cap_description(entry.listing_text, max_desc_chars)
    full_row = f"{ROW_PREFIX}{entry.name}{ROW_SEPARATOR}{capped_text}"
    name_only_row = f"{ROW_PREFIX}{entry.name}"
    return full_row, name_only_row, capped


def row_cost(
    entry: ListingEntry,
    index: int,
    *,
    max_desc_chars: int,
    measure: Measure = display_width,
) -> RowCost:
    """Costs for one row; `width_divergent` compares both measures over the full row."""
    full_row, name_only_row, capped = _row_texts(entry, max_desc_chars)
    full_cost = measure(full_row)
    name_only_cost = measure(name_only_row)
    return RowCost(
        name=entry.name,
        index=index,
        name_only_cost=name_only_cost,
        full_cost=full_cost,
        upgrade_cost=full_cost - name_only_cost,
        capped=capped,
        width_divergent=display_width(full_row) != utf16_length(full_row),
    )


@dataclass(frozen=True, slots=True)
class _Simulation:
    budget: int | float
    budget_from_env: bool
    mode: str
    demand_chars: int
    rendered_chars: int
    all_pinned: bool
    costs: tuple[RowCost, ...]
    full_rows: tuple[str, ...]
    shown_full: tuple[bool, ...]


def _simulate(
    entries: Sequence[ListingEntry], inputs: BudgetInputs, measure: Measure
) -> _Simulation:
    """`per()` over indices. Forced name-only rows never expand, even when pinned."""
    budget = budget_chars(inputs)
    from_env = _budget_from_env(inputs)
    count = len(entries)
    costs = tuple(
        row_cost(entry, index, max_desc_chars=inputs.max_desc_chars, measure=measure)
        for index, entry in enumerate(entries)
    )
    full_rows = tuple(_row_texts(entry, inputs.max_desc_chars)[0] for entry in entries)
    forced = frozenset(
        index for index, entry in enumerate(entries) if entry.forced_name_only
    )

    def charged_as_listed(index: int) -> int:
        return (
            costs[index].name_only_cost if index in forced else costs[index].full_cost
        )

    if count == 0:
        return _Simulation(budget, from_env, "fits", 0, 0, False, costs, full_rows, ())

    # The separator term is charged once here and once in the baseline; it never
    # grows during admission.
    separators = count - 1
    demand = sum(charged_as_listed(index) for index in range(count)) + separators
    expanded = frozenset(range(count)) - forced

    if demand <= budget:
        shown = tuple(index in expanded for index in range(count))
        return _Simulation(
            budget, from_env, "fits", demand, demand, False, costs, full_rows, shown
        )

    pinned = forced | frozenset(
        index for index, entry in enumerate(entries) if entry.protected
    )
    candidates = [index for index in range(count) if index not in pinned]
    if not candidates:
        shown = tuple(index in expanded for index in range(count))
        return _Simulation(
            budget, from_env, "priority", demand, demand, True, costs, full_rows, shown
        )

    baseline = (
        sum(
            charged_as_listed(index) if index in pinned else costs[index].name_only_cost
            for index in range(count)
        )
        + separators
    )
    # The walk keeps the binary's own arithmetic (`j = d - U; j -= fe`), which
    # matters when an env budget is fractional; the rendered total is summed
    # separately so it stays an exact integer.
    headroom = budget - baseline
    rendered = baseline
    # JS sorts the ascending index list with a stable comparator, so equal ranks
    # keep listing order; Python's reverse sort preserves stability the same way.
    candidates.sort(key=lambda index: entries[index].rank, reverse=True)
    admitted: set[int] = set()
    for index in candidates:
        cost = costs[index].upgrade_cost
        if cost <= headroom:
            admitted.add(index)
            headroom -= cost
            rendered += cost
    shown = tuple(
        index in expanded and (index in pinned or index in admitted)
        for index in range(count)
    )
    return _Simulation(
        budget, from_env, "priority", demand, rendered, False, costs, full_rows, shown
    )


def admit(
    entries: Sequence[ListingEntry],
    inputs: BudgetInputs,
    *,
    measure: Measure = display_width,
) -> Admission:
    """Simulate admission. `measure=utf16_length` reproduces the /context estimator.

    Duplicate names are charged separately, as the binary would; the `rendered`
    mapping keeps the last occurrence. Dedupe belongs to `inventory.entries_for`.
    """
    sim = _simulate(entries, inputs, measure)
    rendered = {
        entry.name: Rendered.FULL if shown else Rendered.NAME_ONLY
        for entry, shown in zip(entries, sim.shown_full, strict=True)
    }
    return Admission(
        mode=sim.mode,
        budget=sim.budget,
        budget_from_env=sim.budget_from_env,
        demand_chars=sim.demand_chars,
        rendered_chars=sim.rendered_chars,
        headroom_chars=sim.budget - sim.rendered_chars,
        all_pinned=sim.all_pinned,
        costs=sim.costs,
        rendered=rendered,
        full=tuple(
            entry.name
            for entry, shown in zip(entries, sim.shown_full, strict=True)
            if shown
        ),
        name_only=tuple(
            entry.name
            for entry, shown in zip(entries, sim.shown_full, strict=True)
            if not shown
        ),
        capped=tuple(cost.name for cost in sim.costs if cost.capped),
    )


def render_listing(entries: Sequence[ListingEntry], inputs: BudgetInputs) -> str:
    """The exact `skill_listing` attachment text; empty for an empty listing."""
    if not entries:
        return ""
    sim = _simulate(entries, inputs, display_width)
    lines = [
        full_row if shown else f"{ROW_PREFIX}{entry.name}"
        for entry, full_row, shown in zip(
            entries, sim.full_rows, sim.shown_full, strict=True
        )
    ]
    return LISTING_JOIN.join(lines)


def _round_half_up(value: Decimal) -> int:
    """JS `Math.round` for non-negative values; Python's `round` is banker's."""
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def _compact_number(value: int) -> str:
    """`$n()`: en-US compact notation, one fraction digit, trailing `.0` dropped."""
    for unit, divisor in _COMPACT_UNITS:
        if value >= divisor:
            scaled = (Decimal(value) / Decimal(divisor)).quantize(
                Decimal("0.1"), rounding=ROUND_HALF_UP
            )
            return f"{scaled}{unit}".replace(".0", "", 1)
    return str(value)


def context_cell(cost: int, bytes_per_token: int) -> str:
    """`Fx(Wc(row, b/t))`: the per-skill cell /context prints for a `cost`-char row."""
    tokens = _round_half_up(Decimal(cost) / Decimal(bytes_per_token))
    if tokens < _CONTEXT_CELL_MIN_TOKENS:
        return "< 20"
    return "~" + _compact_number(_round_half_up(Decimal(tokens) / Decimal(10)) * 10)


def write_safe(text: str) -> tuple[bool, str]:
    """Whether the console may write `text` as a description: (ok, reason).

    Accepts newlines and BMP code points that stand alone at width one, which
    covers everything already in the repo. Refuses controls (they would reach a
    YAML plain scalar and, for ESC and the C1 set, start an escape sequence
    Bun strips), the cluster-forming classes, and anything wide or zero-width,
    so the cost of written text never depends on grapheme rules.
    """
    for offset, char in enumerate(text):
        if char == "\n":
            continue
        code = ord(char)
        label = f"U+{code:04X} at offset {offset}"
        if code > 0xFFFF:
            return False, f"{label} is outside the Basic Multilingual Plane"
        category = unicodedata.category(char)
        if category == "Cc":
            return False, f"{label} is a control character (only newline is allowed)"
        if category in _WRITE_UNSAFE_CATEGORIES:
            return (
                False,
                f"{label} is a {category} (combining mark, format, or surrogate)",
            )
        if unicodedata.east_asian_width(char) in _WIDE_EAST_ASIAN:
            return False, f"{label} is East Asian wide"
        if _codepoint_width(code) != 1:
            return False, f"{label} is zero-width"
    return True, ""


def diff_admissions(before: Admission, after: Admission) -> Predicted:
    """The witness for a decisions document.

    `newly_admitted` and `newly_dropped` range over rows listed both before and
    after, in the after listing's order; the two `*_name_only` counts cover rows
    that left or joined the listing, so the name-only invariant closes.
    """
    before_names = set(before.rendered)
    after_names = set(after.rendered)
    common = before_names & after_names
    after_order = [cost.name for cost in after.costs]

    newly_admitted = tuple(
        name
        for name in after_order
        if name in common
        and before.rendered[name] is Rendered.NAME_ONLY
        and after.rendered[name] is Rendered.FULL
    )
    newly_dropped = tuple(
        name
        for name in after_order
        if name in common
        and before.rendered[name] is Rendered.FULL
        and after.rendered[name] is Rendered.NAME_ONLY
    )
    removed_name_only = sum(
        1
        for name in before_names - after_names
        if before.rendered[name] is Rendered.NAME_ONLY
    )
    added_name_only = sum(
        1
        for name in after_names - before_names
        if after.rendered[name] is Rendered.NAME_ONLY
    )
    return Predicted(
        cap_chars=after.budget,
        mode_before=before.mode,
        mode_after=after.mode,
        demand_before=before.demand_chars,
        demand_after=after.demand_chars,
        rendered_before=before.rendered_chars,
        rendered_after=after.rendered_chars,
        full_before=len(before.full),
        full_after=len(after.full),
        name_only_before=len(before.name_only),
        name_only_after=len(after.name_only),
        newly_admitted=newly_admitted,
        newly_dropped=newly_dropped,
        added_name_only=added_name_only,
        removed_name_only=removed_name_only,
    )
