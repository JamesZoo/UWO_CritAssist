"""Sharpen a recipe: strip filler, normalize whitespace, renumber steps."""

from __future__ import annotations

import re
import sys
from pathlib import Path

FILLER_PATTERNS = [
    r"\bjust\b",
    r"\bsimply\b",
    r"\breally\b",
    r"\bvery\b",
    r"\bbasically\b",
    r"\bactually\b",
    r"\bof course\b",
    r"\bgo ahead and\b",
    r"\byou(?:'ll| will) want to\b",
    r"\byou(?:'ll| will) need to\b",
    r"\bmake sure (?:to|that you)\b",
    r"\bbe sure to\b",
    r"\bfeel free to\b",
]

SECTION_HEADERS = {"ingredients", "steps", "instructions", "directions", "method"}

STEP_PREFIX = re.compile(r"^\s*(?:\d+[.)]\s*|[-*]\s+)")


def strip_filler(line: str) -> str:
    out = line
    for pat in FILLER_PATTERNS:
        out = re.sub(pat, "", out, flags=re.IGNORECASE)
    out = re.sub(r"\s{2,}", " ", out).strip()
    out = re.sub(r"\s+([,.;:!?])", r"\1", out)
    if out:
        out = out[0].upper() + out[1:]
    return out


def is_header(line: str) -> str | None:
    stripped = line.strip().rstrip(":").lower()
    return stripped if stripped in SECTION_HEADERS else None


def sharpen(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    section: str | None = None
    step_no = 0

    for raw in lines:
        if not raw.strip():
            if out and out[-1] != "":
                out.append("")
            continue

        header = is_header(raw)
        if header:
            section = header
            step_no = 0
            out.append(f"{header.capitalize()}:")
            continue

        if section in {"steps", "instructions", "directions", "method"}:
            body = STEP_PREFIX.sub("", raw)
            body = strip_filler(body)
            if not body:
                continue
            step_no += 1
            out.append(f"{step_no}. {body}")
        elif section == "ingredients":
            body = re.sub(r"^\s*[-*]\s+", "", raw).strip()
            body = re.sub(r"\s{2,}", " ", body)
            if body:
                out.append(f"- {body}")
        else:
            out.append(strip_filler(raw))

    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) > 1:
        text = Path(argv[1]).read_text()
    else:
        text = sys.stdin.read()
    sys.stdout.write(sharpen(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
