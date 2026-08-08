# Clean Architecture layering (THE-10)

Every feature module under `packages/ui/lib/src/features/<name>/` has five
layers. The spec's diagram (`Presentation -> Application -> Domain -> Data
-> Infrastructure`) describes **control flow**: a user tap starts in
Presentation and propagates down through Application into Domain/Data/
Infrastructure. **Import direction is not the same thing** and instead
follows the Dependency Inversion Principle: Domain is the innermost,
fully independent layer that everything else is built on top of.

```
Presentation  (outermost — depends on everything below)
     |
Application
     |
    Data
     |
Domain + Infrastructure  (innermost — depend on nothing else in this feature)
```

| Layer | Contains | May import (within this feature) |
|---|---|---|
| `presentation/` | Widgets/screens | application, data, domain, infrastructure |
| `application/` | Riverpod providers / use-cases | data, domain, infrastructure |
| `data/` | Assembles domain objects from repositories | domain, infrastructure, `package:core` repositories |
| `domain/` | Entities specific to this feature's presentation needs | nothing feature-local |
| `infrastructure/` | Platform-specific code (notifications, widgets) | nothing feature-local |

`domain/` and `infrastructure/` are both foundational and dependency-free
by design — `data/` legitimately imports `domain/` (it builds domain
objects), which is *not* a violation even though "domain" is drawn above
"data" in the spec's control-flow diagram. The rule that actually matters,
and the one THE-10 exists to enforce, is: **domain never imports
presentation** (or application, or data) — i.e. business entities stay
free of UI/orchestration/persistence concerns.

## Reference implementation: `home`

`packages/ui/lib/src/features/home/` is the template every other feature
module should copy:

- `domain/home_summary.dart` — the `HomeSummary` entity, pure data, no
  imports from any other layer in this feature.
- `data/home_data_source.dart` — `HomeDataSource` builds a `HomeSummary`
  from `packages/core`'s `ProgressRepository`. Never touches sqflite or any
  platform API directly — that stays inside `packages/core`'s own data
  layer.
- `application/home_providers.dart` — `homeSummaryProvider` exposes the
  `HomeDataSource.load()` use-case to the Presentation layer via Riverpod.
- `infrastructure/home_infrastructure.dart` — currently empty (no
  platform-specific code needed yet for Home); exists so future
  platform-specific home-screen code (e.g. a daily-reminder notification)
  has an obvious, pre-agreed place to live rather than leaking into
  `presentation/`.
- `presentation/home_screen.dart` — the widget. It only ever reads
  `homeSummaryProvider` — it never imports `data/` or talks to a
  repository directly.

## Enforcement

`tools/validator/check_layering.py` statically scans every feature module's
Dart files and fails (non-zero exit) if a more-fundamental layer imports a
more-outer one (e.g. `domain/` importing from `presentation/`, or `data/`
importing from `application/`). Run it locally or in CI:

```
python tools/validator/check_layering.py
```

This is deliberately a small, dependency-free Python script (consistent
with the engineering spec's choice of Python for build/tooling scripts)
rather than a custom Dart analyzer plugin, so it needs no extra pub
packages to run in CI.
