#!/usr/bin/env python3
"""
Static check for THE-10: within each feature module under
packages/ui/lib/src/features/<name>/, enforces Clean Architecture's
Dependency Inversion rule via docs/architecture.md.

Note: the spec's "Presentation -> Application -> Domain -> Data ->
Infrastructure" diagram describes *control flow* (a user tap propagates
top to bottom), not *import direction*. Import direction follows the
Dependency Inversion Principle instead: Domain is the innermost, fully
independent layer (it imports nothing from the other layers); Data
implements/depends on Domain; Application orchestrates Data+Domain;
Presentation depends on Application+Domain. Infrastructure sits alongside
Domain as another foundational, dependency-free layer (platform
primitives), so it also imports nothing from the other feature layers.

A file may only import layers at or below its own rank in FILE_RANK
below (i.e. it may depend on more-fundamental layers, never on more
outer/dependent ones). Exits non-zero and prints every violation found,
so this can run as a CI gate.
"""
import re
import sys
from pathlib import Path

# Higher number = more outer / more dependent. A layer may import any
# layer with an equal-or-lower rank, never a higher one.
LAYER_RANK = {
    "domain": 0,
    "infrastructure": 0,
    "data": 1,
    "application": 2,
    "presentation": 3,
}

IMPORT_RE = re.compile(r"""import\s+['"](\.\./[^'"]+)['"]""")

ROOT = Path(__file__).parent.parent.parent
FEATURES_DIR = ROOT / "packages" / "ui" / "lib" / "src" / "features"


def layer_of_path(path: Path, module_dir: Path) -> str | None:
    try:
        rel = path.relative_to(module_dir)
    except ValueError:
        return None
    if not rel.parts:
        return None
    top = rel.parts[0]
    return top if top in LAYER_RANK else None


def main() -> int:
    if not FEATURES_DIR.exists():
        print(f"No features directory at {FEATURES_DIR} — nothing to check.")
        return 0

    violations = []

    for module_dir in sorted(p for p in FEATURES_DIR.iterdir() if p.is_dir()):
        for layer_name in LAYER_RANK:
            layer_dir = module_dir / layer_name
            if not layer_dir.exists():
                continue
            for dart_file in layer_dir.rglob("*.dart"):
                source_rank = LAYER_RANK[layer_name]
                text = dart_file.read_text(encoding="utf-8")
                for match in IMPORT_RE.finditer(text):
                    import_path = match.group(1)
                    resolved = (dart_file.parent / import_path).resolve()
                    target_layer = layer_of_path(resolved, module_dir.resolve())
                    if target_layer is None or target_layer == layer_name:
                        continue
                    target_rank = LAYER_RANK[target_layer]
                    if target_rank > source_rank:
                        violations.append(
                            f"{dart_file.relative_to(ROOT)}: "
                            f"'{layer_name}' (rank {source_rank}) imports from "
                            f"'{target_layer}' (rank {target_rank}) via '{import_path}'"
                        )

    if violations:
        print("LAYERING VIOLATIONS FOUND:\n")
        for v in violations:
            print(f"  - {v}")
        print(f"\n{len(violations)} violation(s). A lower layer must never import a higher layer.")
        return 1

    print("OK: no Clean Architecture layering violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
