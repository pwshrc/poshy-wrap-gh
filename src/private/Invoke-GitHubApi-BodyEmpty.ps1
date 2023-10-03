#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


function Invoke-GitHubApi-BodyEmpty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        # [ValidateScript({ $_ -in [System.Net.Http.HttpMethod]::Get, [System.Net.Http.HttpMethod]::Post, [System.Net.Http.HttpMethod]::Put, [System.Net.Http.HttpMethod]::Patch, [System.Net.Http.HttpMethod]::Delete, [System.Net.Http.HttpMethod]::Head, [System.Net.Http.HttpMethod]::Options, [System.Net.Http.HttpMethod]::Trace, [System.Net.Http.HttpMethod]::Connect})]
        [System.Net.Http.HttpMethod] $Method,

        [Parameter(Mandatory = $true, Position = 1)]
        # [ValidateNotNullOrEmpty()]
        [string] $Route,

        [Parameter(Mandatory = $false, Position = 2)]
        [hashtable] $Query = @{},

        [Parameter(Mandatory = $false, Position = 11)]
        # [ValidateNotNull()]
        [hashtable] $Headers = @{},

        [Parameter(Mandatory = $false)]
        # [ValidateNotNullOrEmpty()]
        [string] $Hostname = $null,

        [Parameter(Mandatory = $false)]
        # [ValidateNotNullOrEmpty()]
        [string] $jq = $null,

        [Parameter(Mandatory = $false)]
        [switch] $Paginate,

        [Parameter(Mandatory = $false)]
        # [ValidateNotNullOrEmpty()]
        [string[]] $Previews = @(),

        [Parameter(Mandatory = $false, Position = 16)]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [switch] $OutputAsHashtable,

        [Parameter(Mandatory = $false)]
        # [ValidateRange(0, [int]::MaxValue)]
        [Nullable[int]] $OutputDepth,

        [Parameter(Mandatory = $false)]
        [switch] $OutputNoEnumerate
    )

    Begin {
        if ($OutputRaw) {
            if ($OutputAsHashtable) {
                throw "OutputRaw and OutputAsHashtable cannot be used together."
            }
            if ($OutputDepth) {
                throw "OutputRaw and OutputDepth cannot be used together."
            }
            if ($OutputNoEnumerate) {
                throw "OutputRaw and OutputNoEnumerate cannot be used together."
            }
        }

        # [PSCommand] $command
        $ghCommand = [System.Management.Automation.PSCommand]::new()
        $ghCommand.AddCommand("gh")
        #     --cache duration        Cache the response, e.g. "3600s", "60m", "1h"
        # -F, --field key=value       Add a typed parameter in key=value format
        # -H, --header key:value      Add a HTTP request header in key:value format
        #     --hostname string       The GitHub hostname for the request (default "github.com")
        # -i, --include               Include HTTP response status line and headers in the output
        #     --input file            The file to use as body for the HTTP request (use "-" to read from standard input)
        # -q, --jq string             Query to select values from the response using jq syntax
        # -X, --method string         The HTTP method for the request (default "GET")
        #     --paginate              Make additional HTTP requests to fetch all pages of results
        # -p, --preview names         GitHub API preview names to request (without the "-preview" suffix)
        # -f, --raw-field key=value   Add a string parameter in key=value format
        #     --silent                Do not print the response body
        # -t, --template string       Format JSON output using a Go template; see "gh help formatting"
        #     --verbose               Include full HTTP request and response in the output

        $ghCommand = $ghCommand.AddArgument("api")

        [System.Text.StringBuilder] $routeFinal = [System.Text.StringBuilder]::new()
        $routeFinal.Append($Route)
        [bool] $firstQueryStringParameter = $true
        foreach ($key in $Query.Keys) {
            if ($firstQueryStringParameter) {
                $routeFinal.Append("?")
                $firstQueryStringParameter = $false
            } else {
                $routeFinal.Append("&")
            }
            $routeFinal.Append([System.Uri]::EscapeDataString($key))
            $routeFinal.Append("=")
            $routeFinal.Append([System.Uri]::EscapeDataString($Query[$key]))
        }
        $ghCommand = $ghCommand.AddArgument($routeFinal.ToString())

        if ($Method -ne [System.Net.Http.HttpMethod]::Get) {
            $ghCommand = $ghCommand.AddArgument("-X")
            $ghCommand = $ghCommand.AddArgument($Method.ToString().ToUpperInvariant())
        }

        [hashtable] $headersFinal = @{
            "Accept" = "application/vnd.github+json";
        } + $headers
        foreach ($headerKey in $headersFinal.Keys) {
            $ghCommand = $ghCommand.AddArgument("--header")
            [string] $escapedHeaderKey = [System.Uri]::EscapeDataString($headerKey)
            [string] $escapedHeaderValue = [System.Uri]::EscapeDataString($headersFinal[$headerKey])
            $ghCommand = $ghCommand.AddArgument("${escapedHeaderKey}: ${escapedHeaderValue}")
        }

        if ($Hostname) {
            $ghCommand = $ghCommand.AddArgument("--hostname")
            $ghCommand = $ghCommand.AddArgument($Hostname)
        }

        if ($jq) {
            $ghCommand = $ghCommand.AddArgument("--jq")
            $ghCommand = $ghCommand.AddArgument($jq)
        }

        if ($Paginate) {
            $ghCommand = $ghCommand.AddArgument("--paginate")
        }

        if ($Previews) {
            $ghCommand = $ghCommand.AddArgument("--preview")
            $ghCommand = $ghCommand.AddArgument($Previews -join ",")
        }

        $outputHandlingCommand = $null -as [System.Management.Automation.PSCommand]
        if (-not $OutputRaw) {
            $outputHandlingCommand = [System.Management.Automation.PSCommand]::new()
            $outputHandlingCommand = $outputHandlingCommand.AddCommand("ConvertFrom-Json")

            if ($OutputAsHashtable) {
                $outputHandlingCommand = $outputHandlingCommand.AddArgument("-AsHashtable")
            }

            if ($OutputDepth) {
                $outputHandlingCommand = $outputHandlingCommand.AddArgument("-Depth")
                $outputHandlingCommand = $outputHandlingCommand.AddArgument($OutputDepth)
            }

            if ($OutputNoEnumerate) {
                $outputHandlingCommand = $outputHandlingCommand.AddArgument("-NoEnumerate")
            }
        }
    }

    Process {
        # https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.command?view=powershellsdk-7.3.0
        # https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscommand?view=powershellsdk-7.3.0
        function AccumulatePSCommand {
            param(
                [System.Management.Automation.PSCommand] $accumulate,
                [System.Management.Automation.Runspaces.Command] $subcommand
            )
            [System.Management.Automation.PSCommand] $result = $accumulate.Clone()
            $result = $result.AddCommand($subcommand.CommandText)
            foreach ($subcommandParameter in $subcommand.Parameters) {
                Write-Host "A parameter!"
                if ($subcommandParameter.IsScript) {
                    $result = $result.AddScript($subcommandParameter.Value, $subcommand.UseLocalScope)
                } else {
                    $result = $result.AddParameter($subcommandParameter.Name, $subcommandParameter.Value)
                }
            }
            if ($subcommand.IsEndOfStatement) {
                $result = $result.AddStatement()
            }
            return $result
        }
        function ExpressCommandPart {
            param(
                [System.Management.Automation.Runspaces.Command] $subcommand,
                [System.Text.StringBuilder] $resultBuilder
            )
            $resultBuilder.Append($subcommand.CommandText)
            foreach ($subcommandParameter in $subcommand.Parameters) {
                $resultBuilder.Append(" ")
                $resultBuilder.Append($subcommandParameter.Name)
                if ($subcommandParameter.Value) {
                    $resultBuilder.Append(" ")
                    $resultBuilder.Append($subcommandParameter.Value)
                }
            }
            if ($subcommand.MergeUnclaimedPreviousCommandResults -ne 0) {
                $resultBuilder.Append(" 2>&1")
            }
        }

        # express them out into a stringbuilder. interleave with pipes and semicolons. (if not is first command in statement, use pipe, unless IsEndOfStatement then instead use semicolon and mark as first command in statement again.)
        [System.Text.StringBuilder] $commandFinal = [System.Text.StringBuilder]::new()
        [bool] $first = $true
        foreach ($command in $ghCommand.Commands) {
            if (-not $first) {
                if ($command.IsEndOfStatement) {
                    $commandFinal.Append("; ")
                    $first = $true
                } else {
                    $commandFinal.Append(" | ")
                }
            }
            ExpressCommandPart -subcommand $command -resultBuilder $commandFinal
            if ($first) {
                $first = $false
            }
        }


        # then invoke-expression the stringbuilder.

        # with these in place, backport changes to original script.

        # if manually expressing the string don't work right, remember that this script here does not need to support the stringifying of the command. (that's just me practicing for later.)
        # instead, we can execute the command against a PowerShell instance and a Runspace.
        # see the examples on the methods, here: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pscommand?view=powershellsdk-7.3.0

        [string] $commandFinalCommandText = ($commandFinal.Commands | Select-Object -ExpandProperty CommandText) -join " | "
        Write-Host "Executing: ${commandFinalCommandText}"
        Invoke-Expression $commandFinalCommandText
    }

    End {
    }
}
