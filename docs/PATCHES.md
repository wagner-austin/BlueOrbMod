# SDK Modernization Patches

The Deus Ex SDK from 2000 was written for Visual C++ 6 / VS.NET 2003.
Modern MSVC (v143, VS 2022) enforces stricter C++ conformance and ships
with newer Windows SDKs that have additional static-asserts. The
patches in `patches/` are the minimum changes needed to compile cleanly
under VS 2022 + Windows SDK 10.0.26100.

Each patch is **header-only** — no functional behavior changes. Every
modification is a syntax adjustment that brings the SDK in line with
modern C++ rules without altering generated code.

Patches apply against `games/DeusEx/` (the populated SDK tree) using
`git apply`. They're applied automatically by `scripts/setup.ps1`.

## 01-UnTemplate-typename.patch

**File**: `core/inc/UnTemplate.h` (TMap container internals)

**Issue**: Modern C++ (since C++03) requires the `typename` keyword
when referring to a dependent type inside a template. The SDK omits it
in 7 places where `TTypeInfo<TK>::ConstInitType` and
`TTypeInfo<TI>::ConstInitType` are used as function parameter types
inside template class methods.

**Fix**: prepend `typename` to each occurrence. UT469 (OldUnreal's
modernized UT99 patch) made the same fix.

**Functional impact**: none. `typename` is a syntactic disambiguation
keyword; the compiled code is identical.

## 02-UnObjBas-StaticConstructor.patch

**File**: `core/inc/UnObjBas.h`

**Issue**: The `IMPLEMENT_CLASS(TClass)` macro takes the address of
`TClass::StaticConstructor` to register it with the class system. Old
MSVC allowed implicit address-of on a member function name; modern
MSVC requires explicit `&`.

The SDK already has the corrected form in its non-MSVC fallback path
(`#else` branch) — we just port that fix into the active `_MSC_VER`
branch.

**Fix**: change `(void(UObject::*)())TClass::StaticConstructor` to
`(void(UObject::*)())&TClass::StaticConstructor`.

**Functional impact**: none. Runtime behavior is identical; only the
compile-time syntax is now standards-conformant.

## 03-Window-MemberPointers-ParseToken.patch

**File**: `window/inc/Window.h` (UE1's GUI dialog framework)

**Issue 1**: 22 places use the old "implicit member pointer" syntax,
e.g. `FDelegate(this, (TDelegate)OnCancel)`. Modern MSVC requires the
fully qualified `&Class::Method` form.

**Issue 2**: `ParseToken(*(TCHAR**)&CD->lpData, ...)` passes a non-const
TCHAR* where `ParseToken` expects `const TCHAR*&`. Old MSVC's
const-correctness rules were looser.

**Fixes**:
- All `(TDelegate)Method` → `(TDelegate)&Class::Method` with the class
  name resolved per use site (compiler tells us which class via the
  C3867 error).
- `(TCHAR**)&CD->lpData` → `(const TCHAR**)&CD->lpData`.

**Functional impact**: none — only the compile-time type expressions
change.

## Build configuration patches

Several other modernization changes live directly in our forks
(committed to `wagner-austin/DeusExe` and `wagner-austin/render11`)
since they're build-system, not SDK content:

- Toolset: v140 / v142 → **v143** (VS 2022)
- WindowsTargetPlatformVersion: 10.0.10586 → **10.0.26100**
- Include path prefix: `../games/...` → `../../games/...` (so the SDK
  can live at the workspace root, sibling to both forks)
- Detours include path: `../detours` → `../../detours/src`
- Preprocessor define: `WINDOWS_IGNORE_PACKING_MISMATCH` (the SDK uses
  `pragma pack(4)` for engine struct compatibility; modern winnt.h
  static-asserts default packing — this define silences that without
  changing packing)
- Compiler flags: `/Zc:forScope-`, `/Zc:wchar_t-`, `<ConformanceMode>false</ConformanceMode>`,
  `<TreatWarningAsError>false</TreatWarningAsError>` — relax modern
  C++ conformance for the older SDK style
- res.rc: `#include "afxres.h"` (legacy MFC) →
  `#include "winres.h"` (modern non-MFC equivalent that still defines
  IDC_STATIC etc.)

See the commits on each fork's `master` branch for the exact diffs.

## Maintenance

If an upstream Kentie release adds new files or changes existing ones,
running `setup.ps1 -Force` will:

1. Re-download and re-extract the SDK
2. Re-apply all patches in order

Patches use git's standard `--check` first, so if a patch is already
applied (or partially applied), setup will detect that and either skip
or fail loudly rather than silently corrupting files.

If a patch starts failing because we updated to a newer SDK version,
the fix is to regenerate the patch from the new baseline (using
`diff -u original-file modified-file`) and commit the updated patch
file.
