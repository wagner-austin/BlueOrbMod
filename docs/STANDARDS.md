# Coding Standards

Standards every change in this workspace adheres to. Adapted per language
from a single set of principles. The Makefile + scripts/guard.ps1 +
scripts/lint.ps1 enforce these mechanically; this doc explains the why.

If a rule isn't mechanically enforceable, document it here and treat it
as load-bearing in code review.

## Universal principles

1. **Reliable, robust, deliberate.** No quick fixes or hacks. Every
   change is properly integrated.
2. **Prevent drift.** Standards apply to every file regardless of
   language; new files inherit the same rules.
3. **Reduce future tech debt.** Today's shortcut becomes tomorrow's
   bug — we fix root causes, not symptoms.
4. **Strict typing everywhere it exists.** No untyped escape hatches.
5. **No fallbacks, no best-effort, no back-compat shims, no legacy
   code paths.** APIs are designed so failure points are clear by
   naming/docs/tests; we don't catch exceptions in core logic to
   recover or soften.
6. **No placeholder code, no duplicates.** Keep the codebase DRY,
   consistent, modular. If two things look the same, factor them.
7. **100% test coverage** (statements + branches) for code that
   logic-runs (scripts, the future launcher, etc.). Test the actual
   code; no mocks, no weak assertions.
8. **Tests use the `_test_hooks` injection pattern.** Production sets
   hooks to real implementations at startup; tests set fakes. No
   conditional branches on "are we in a test?" — just call the hook.
9. **Google-style docs.** Concise summary, then `Args:`/`Returns:`/
   `Raises:` sections with type info. PowerShell uses comment-based
   help with the same content; C# uses XML doc comments; C++ uses
   Doxygen.
10. **make check is the gate.** Anything that doesn't survive
    `make check` doesn't get committed. Anything that doesn't survive
    `make ci` doesn't get pushed.

## Per-language standards

### PowerShell (scripts/, tests/)

- `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
  at the top of every script.
- Every parameter typed: `[string]`, `[int]`, `[switch]`, etc.
  No `[object]` or `$dynamicVar` without an explicit type at assignment.
- Every script uses `[CmdletBinding()]` with parameter validation
  attributes (`[ValidateSet]`, `[ValidateNotNullOrEmpty]`, etc.).
- Comment-based help on every script + every advanced function:
  `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`.
- **No `-ErrorAction SilentlyContinue` in core logic.** It's a
  best-effort smell. Acceptable only at validation boundaries when
  failure is the expected control flow (e.g., probing for an optional
  file's existence, where Test-Path is preferred anyway).
- **No `try/catch` in core logic.** Errors propagate. Boundary code
  (the script's main entry point) may have one outer try/catch for
  formatted error reporting, never to recover.
- `_test_hooks.ps1` pattern: scripts that need DI define module-scoped
  `$script:HookName = $null`. Production calls `Set-Hook-Production`;
  tests call `Set-Hook-Fake`. The script body just calls the hook.
- PSScriptAnalyzer runs in lint with rules from
  `tools/PSScriptAnalyzerSettings.psd1`. Zero warnings allowed.
- Pester tests cover every script. Coverage threshold: 100%
  statements + branches via `Invoke-Pester -CodeCoverage`.

### C++ (DeusExe/, render11/, our patches)

- `<WarningLevel>Level4</WarningLevel>` and
  `<TreatWarningAsError>true</TreatWarningAsError>`.
- Every warning suppression must be either:
  1. ABI-required (matches engine.lib's compile flags) — documented
     in [PATCHES.md](PATCHES.md)
  2. Surgical and targeted (`<DisableSpecificWarnings>`) with the
     specific warning code documented and the reason explained
- No `<ConformanceMode>false</ConformanceMode>`. We compile under
  `/permissive-`.
- No `/Zc:forScope-`, `/Zc:wchar_t-`, etc. Modern compliance is the
  baseline; legacy SDK quirks get patched at the source via files in
  `patches/`.
- No `void*` in our code. Use specific types or templates.
- No `try/catch` swallowing exceptions. UE1 guard/unguard macros are
  the engine's own propagation mechanism and OK to use as
  documented in the SDK.
- Bug fixes in upstream Kentie code (e.g., `FreeSpaceFix.cpp`) are
  real fixes, not workarounds. We commit them to our forks with
  rationale in the message.

### Patches (patches/)

- Each `.patch` is a unified diff against the original SDK file.
- Filename prefix `NN-` for ordering (`01-`, `02-`, ...). Never reuse
  numbers; appending to the sequence is fine.
- Each patch documented in [PATCHES.md](PATCHES.md): what file, why,
  functional impact.
- `setup.ps1` applies patches with `git apply --check` first; if the
  patch is already applied it's detected via reverse-check and
  skipped. Never fail-silent.

### Markdown (docs/, README.md)

- markdownlint with the `tools/markdownlint.json` config.
- Internal links resolve (guard checks them).
- No external links to download URLs without an MD5/SHA pinning
  alongside (so contributors can verify integrity).
- Tables column-aligned where practical.

### YAML (.github/workflows/)

- actionlint validates every workflow.
- All third-party actions pinned to commit SHA, not tag. Renovate or
  manual review for updates.
- No `continue-on-error: true` without a specific documented reason.

## What we explicitly forbid

These never appear in this workspace:

- `# TODO`/`// TODO`/`<!-- TODO -->` without a tracked issue
  reference (`# TODO(#42): ...`). Untracked TODOs are tech debt
  without a return address.
- `FIXME`/`XXX`/`HACK` markers anywhere. If something is broken
  enough to need a marker, fix it.
- "Best effort" in docstrings or comments. We either succeed or fail
  with a clear error.
- Catching an exception just to log + continue. Either the caller
  cares (propagate) or doesn't (don't catch).
- Type-erasing escape hatches (`Any` / `object` / `dynamic` / cast
  to `void*`).
- Disabled tests (`@pytest.mark.skip`, `It -Skip`, etc.) without a
  tracked issue reference.
- Suppressed lints without rationale comments (`# noqa`,
  `// suppress`, `<DisableSpecificWarnings>` without a docs entry).

## When standards conflict with reality

Some constraints come from binary compatibility we can't change
(see [DEPENDENCIES.md](DEPENDENCIES.md) for the engine.lib ABI
requirements). When that happens:

1. The constraint goes in [PATCHES.md](PATCHES.md) or
   [DEPENDENCIES.md](DEPENDENCIES.md) with a complete explanation of
   *why* it's load-bearing and what would have to change to remove
   it.
2. The constraint goes in our build configuration with a comment
   pointing to the docs entry.
3. The guard script (`scripts/guard.ps1`) verifies that every
   suppression in the build config has a corresponding docs entry.

This way, standards exceptions are documented, audited, and
actionable — never invisible.

## Adding new standards

When we add a new language (the WPF launcher in C#, possibly TypeScript
for tooling), its standards go here as a new "Per-language standards"
subsection, with:

1. The strict equivalent of the `_test_hooks` DI pattern.
2. The lint tool we use (and its config file in `tools/`).
3. The 100% test coverage threshold and how it's measured.
4. What's forbidden specifically for that language.

We hold every language to the same level of rigor. Specifically:

- **C# (WPF launcher, future):** nullable enabled in csproj, strict
  mode, no `dynamic`, no `object` casts on data we own, no
  swallowed `catch`, JSON parsed via `System.Text.Json` with
  `[JsonRequired]` properties and a custom strict converter when
  recursive types appear.
- **TypeScript (future tooling):** strict mode in tsconfig, no
  `any`, no `as unknown as` casts, no `@ts-ignore`. Vitest with
  coverage thresholds at 100%.
- **Python (only if we ever add Python — currently none):** the
  full set of Python rules from the broader project standards
  (TypedDict with encode/decode, Protocol-based DI, no `Any`,
  `_test_hooks.py` pattern, etc.).

Every language addition gets the equivalent enforcement: lint
tool wired into `make lint`, coverage threshold wired into
`make coverage`, guard rules in `scripts/guard.ps1`.
