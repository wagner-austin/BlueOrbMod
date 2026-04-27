# PSScriptAnalyzer rules for BlueOrbMod scripts.
# Strict baseline. Every rule is on by default; we opt OUT of the few
# that conflict with our chosen style. Anything we opt out of must be
# justified here.
#
# See docs/STANDARDS.md for the standards these rules enforce.
#
# To run manually:
#   Invoke-ScriptAnalyzer -Settings tools/PSScriptAnalyzerSettings.psd1 -Path scripts/ -Recurse
@{
    Severity     = @('Error', 'Warning', 'Information')

    IncludeRules = @('*')

    ExcludeRules = @(
        # We use Write-Host intentionally for user-facing build output
        # (status, OK/FAIL banners, colored progress). PSScriptAnalyzer
        # prefers Write-Output; that's wrong for our use case where the
        # user is reading the console as the script runs and the output
        # isn't meant to flow into a pipeline.
        'PSAvoidUsingWriteHost'
    )

    Rules = @{
        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }

        PSUseConsistentWhitespace = @{
            Enable          = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $true
            CheckSeparator  = $true
            CheckPipe       = $true
        }
    }
}
