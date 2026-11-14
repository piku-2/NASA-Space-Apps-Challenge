"""Check project text encoding and localization using only the standard library."""

from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".gd", ".gdshader", ".tscn", ".tres", ".godot", ".cfg", ".uid",
    ".json", ".md", ".txt", ".yml", ".yaml", ".py", ".svg",
}
TEXT_NAMES = {"Makefile", "LICENSE", ".gitignore", ".gitattributes", ".editorconfig"}


def main() -> int:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT, check=True, capture_output=True,
    )
    errors = []
    documents = {}
    count = 0
    for name in sorted(set(result.stdout.decode("utf-8").split("\0")) - {""}):
        path = ROOT / name
        # Vendor files keep their upstream encoding and formatting conventions.
        if name.startswith(("addons/", ".idea/")) or not path.is_file():
            continue
        if path.suffix not in TEXT_SUFFIXES and path.name not in TEXT_NAMES:
            continue
        count += 1
        try:
            raw = path.read_bytes()
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            errors.append(f"{name}: invalid UTF-8")
            continue
        if raw.startswith(b"\xef\xbb\xbf"):
            errors.append(f"{name}: UTF-8 BOM is not allowed")
        if "\r" in text:
            errors.append(f"{name}: use LF line endings")
        if chr(0xFFFD) in text:
            errors.append(f"{name}: Unicode replacement character found")
        if path.suffix == ".json":
            try:
                documents[name] = json.loads(text)
            except json.JSONDecodeError as exc:
                errors.append(f"{name}: {exc}")

    ja = documents.get("i18n/ja.json")
    en = documents.get("i18n/en.json")
    if not isinstance(ja, dict) or not isinstance(en, dict):
        errors.append("Both localization files must be JSON objects")
    else:
        if ja.keys() != en.keys():
            errors.append(f"Localization keys differ: {sorted(ja.keys() ^ en.keys())}")
        for key in ja.keys() & en.keys():
            if not isinstance(ja[key], str) or not isinstance(en[key], str):
                errors.append(f"{key}: translations must be strings")
            elif Counter(re.findall(r"\{\d+\}", ja[key])) != Counter(
                re.findall(r"\{\d+\}", en[key])
            ):
                errors.append(f"{key}: localization placeholders differ")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: {count} text files; UTF-8, LF, JSON and localization")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
