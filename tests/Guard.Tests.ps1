#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Tests for scripts/guard.ps1. Validates the rule logic by running
    guard.ps1 against synthetic workspaces written to a temp dir and
    asserting the expected violations are reported.

    These are integration tests by design: guard.ps1 is a script that
    walks a workspace tree, so testing it against real files (in a
    temp dir) is the correct shape. No mocks; we test what the script
    actually does.
#>

BeforeAll {
    $script:Root        = Split-Path -Parent $PSScriptRoot
    $script:GuardScript = Join-Path $Root 'scripts/guard.ps1'

    function Invoke-Guard {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string] $WorkspaceRoot
        )
        # Run guard.ps1 against a synthetic workspace by overriding
        # $PSScriptRoot through a sidecar wrapper. Easiest path:
        # symlink/copy the guard script into the synthetic workspace's
        # scripts/ dir, then invoke it from there so $PSScriptRoot
        # resolves correctly.
        $synthScripts = Join-Path $WorkspaceRoot 'scripts'
        New-Item -ItemType Directory -Force -Path $synthScripts | Out-Null
        Copy-Item -Force $GuardScript (Join-Path $synthScripts 'guard.ps1')

        $stdout = & powershell -NoProfile -ExecutionPolicy Bypass -File `
            (Join-Path $synthScripts 'guard.ps1') 2>&1
        return @{
            Output   = ($stdout -join "`n")
            ExitCode = $LASTEXITCODE
        }
    }

    function New-MinimalWorkspace {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string] $Path)
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $Path 'patches') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $Path 'tools') | Out-Null
        # Minimal docs that satisfy Rule 2 (suppression docs check)
        Set-Content -Path (Join-Path $Path 'docs/PATCHES.md') -Value @'
# PATCHES

StructMemberAlignment, TreatWChar_tAsBuiltInType,
WINDOWS_IGNORE_PACKING_MISMATCH, DisableSpecificWarnings - all
documented as ABI requirements.
'@ -Encoding ASCII
        Set-Content -Path (Join-Path $Path 'docs/DEPENDENCIES.md') -Value '# DEPS' -Encoding ASCII
        # Empty patches dir = nothing to check for Rule 3
    }
}

Describe 'guard.ps1 - rule integration tests' {
    BeforeEach {
        $script:Workspace = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-MinimalWorkspace -Path $script:Workspace
    }

    Context 'Rule 1: untracked TODO/FIXME/HACK/XXX markers' {
        It 'passes when there are no markers' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'Just regular docs.' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'guard passed'
        }

        It 'fails on a bare TODO without issue reference' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'TODO fix this later' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'unscoped marker'
        }

        It 'passes when TODO has issue reference like TODO(#42)' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'TODO(#42): fix this later' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 0
        }

        It 'flags HACK as well as TODO' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'HACK: this is bad' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match "unscoped marker 'HACK'"
        }
    }

    Context 'Rule 6: no best-effort phrasing' {
        It 'passes when no best-effort phrasing exists' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'We propagate failures explicitly.' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 0
        }

        It 'fails when "best-effort" is present in markdown' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'This is a best-effort cleanup.' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'best-effort'
        }

        It 'fails on "best effort" with space too' {
            Set-Content -Path (Join-Path $script:Workspace 'README.md') `
                -Value 'This is a best effort cleanup.' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'best-effort'
        }
    }

    Context 'Rule 4: scripts must have comment-based help' {
        It 'fails when a script in scripts/ lacks .SYNOPSIS' {
            $synthScripts = Join-Path $script:Workspace 'scripts'
            $extraScript  = Join-Path $synthScripts 'extra.ps1'
            New-Item -ItemType Directory -Force -Path $synthScripts | Out-Null
            Set-Content -Path $extraScript -Value 'Write-Host hi' -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'extra.ps1.*\.SYNOPSIS'
        }

        It 'passes when script has both .SYNOPSIS and .DESCRIPTION' {
            $synthScripts = Join-Path $script:Workspace 'scripts'
            $extraScript  = Join-Path $synthScripts 'extra.ps1'
            New-Item -ItemType Directory -Force -Path $synthScripts | Out-Null
            Set-Content -Path $extraScript -Value @'
<#
.SYNOPSIS
    A test script.
.DESCRIPTION
    Does test things.
#>
Write-Host hi
'@ -Encoding ASCII
            $r = Invoke-Guard -WorkspaceRoot $script:Workspace
            $r.ExitCode | Should -Be 0
        }
    }
}
