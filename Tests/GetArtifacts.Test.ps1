[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock/callback parameters must match function signatures')]
param()

Get-Module Github-Helper | Remove-Module -Force
Import-Module (Join-Path $PSScriptRoot '..\Actions\Github-Helper.psm1' -Resolve)
$errorActionPreference = "Stop"; $ProgressPreference = "SilentlyContinue"; Set-StrictMode -Version 2.0

Describe 'GetArtifacts Tests' {
    BeforeAll {
        . (Join-Path $PSScriptRoot "..\Actions\AL-Go-Helper.ps1")

        function MockArtifact {
            param([string] $name, [int] $runId = 1)
            [PSCustomObject]@{
                name = $name
                expired = $false
                archive_download_url = "https://example.com/artifacts/$name"
                workflow_run = [PSCustomObject]@{ id = $runId }
            }
        }
    }

    It 'Retries a page after a transient error' {
        $artifacts = @(
            (MockArtifact 'proj1-main-Apps-1.0.0.0'),
            (MockArtifact 'proj1-main-BuildOutput-1.0.0.0')
        )
        $script:calls = 0
        Mock InvokeWebRequest -ModuleName Github-Helper -ParameterFilter { $Uri -like '*actions/artifacts*page=1*' } -MockWith {
            $script:calls++
            if ($script:calls -eq 1) { throw 'Response status code does not indicate success: 500 (Internal Server Error).' }
            [PSCustomObject]@{ Content = ([PSCustomObject]@{ total_count = $artifacts.Count; artifacts = $artifacts } | ConvertTo-Json -Depth 5) }
        }
        Mock Start-Sleep { } -ModuleName Github-Helper

        $result = GetArtifacts -token 'tok' -api_url 'https://api.github.com' -repository 'test/repo' -mask 'Apps' -branch 'main' -projects 'proj1' -version '1.0.0.0' 3>$null 6>$null

        $script:calls | Should -Be 2
        @($result).name | Should -Be 'proj1-main-Apps-1.0.0.0'
    }
}
