"""Extract selected MQL function bodies for native regression adapters."""
import re


def extract_function(source, name):
    match = re.search(r"^[A-Za-z_]\w*\s+" + re.escape(name) + r"\s*\(", source, re.M)
    if match is None:
        raise AssertionError(f"Missing MQL function: {name}")
    # Comments and quoted strings must not alter the function's brace depth.
    masked = re.sub(
        r'''//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' ''',
        lambda found: " " * len(found.group(0)),
        source,
        flags=re.S | re.X,
    )
    opening = masked.index("{", match.start())
    depth = 1
    end = opening + 1
    while depth:
        depth += (masked[end] == "{") - (masked[end] == "}")
        end += 1
    body = source[match.start():end]
    return re.sub(
        r"\b(const\s+)?([A-Za-z_]\w*)\s*&\s*(\w+)\[\]",
        lambda found: f"{found.group(1) or ''}std::vector<{found.group(2)}>& {found.group(3)}",
        body,
    )
