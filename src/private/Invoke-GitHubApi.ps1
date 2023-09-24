#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


function Invoke-GitHubApi {
    [CmdletBinding(DefaultParameterSetName = "BodyEmpty")]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ $_ -in [System.Net.Http.HttpMethod]::Get, [System.Net.Http.HttpMethod]::Post, [System.Net.Http.HttpMethod]::Put, [System.Net.Http.HttpMethod]::Patch, [System.Net.Http.HttpMethod]::Delete, [System.Net.Http.HttpMethod]::Head, [System.Net.Http.HttpMethod]::Options, [System.Net.Http.HttpMethod]::Trace, [System.Net.Http.HttpMethod]::Connect})]
        [System.Net.Http.HttpMethod] $Method,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Route,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "BodyFields")]
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "BodyFile")]
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "BodyRaw")]
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "BodyJson")]
        [hashtable] $Query = @{},

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = "BodyEmpty")]
        [switch] $Empty,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = "BodyFields")]
        [switch] $Fields,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = "BodyFile")]
        [switch] $File,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = "BodyRaw")]
        [switch] $Raw,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = "BodyJson")]
        [switch] $Json,

        [Parameter(Mandatory = $true, ParameterSetName = "BodyFields")]
        [Parameter(Mandatory = $true, ParameterSetName = "BodyFile")]
        [Parameter(Mandatory = $true, ParameterSetName = "BodyRaw")]
        [Parameter(Mandatory = $true, ParameterSetName = "BodyJson")]
        [Alias("InputObject")]
        $Body,

        [Parameter(Mandatory = $false, Position = 6, ParameterSetName = "BodyJson")]
        [switch] $InputAsArray,

        [Parameter(Mandatory = $false, Position = 7, ParameterSetName = "BodyJson")]
        [switch] $InputCompress,

        [Parameter(Mandatory = $false, Position = 8, ParameterSetName = "BodyJson")]
        [ValidateRange(0, 100)]
        [Nullable[int]] $InputDepth = $null,

        [Parameter(Mandatory = $false, Position = 9, ParameterSetName = "BodyJson")]
        [switch] $InputEnumsAsStrings,

        [Parameter(Mandatory = $false, Position = 10, ParameterSetName = "BodyJson")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -in [System.Enum]::GetNames([Newtonsoft.Json.StringEscapeHandling]) })]
        [Nullable[Newtonsoft.Json.StringEscapeHandling]] $InputEscapeHandling = $null,

        [Parameter(Mandatory = $false, Position = 6, ParameterSetName = "BodyFile")]
        [Parameter(Mandatory = $false, Position = 6, ParameterSetName = "BodyRaw")]
        [ValidateNotNullOrEmpty()]
        [string] $ContentType,

        [Parameter(Mandatory = $false, Position = 11)]
        [ValidateNotNull()]
        [hashtable] $Headers = @{},

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $Hostname = $null,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $jq = $null,

        [Parameter(Mandatory = $false)]
        [switch] $Paginate,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Previews = @(),

        [Parameter(Mandatory = $false, Position = 16)]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [switch] $OutputAsHashtable,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [int]::MaxValue)]
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
        if ($null -ne $ContentType) {
            $headersFinal["Content-Type"] = $ContentType
        }
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
            $outputHandlingCommand.AddCommand("ConvertFrom-Json")

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
        [System.Management.Automation.PSCommand] $commandFinal = $ghCommand.Clone()

        if ($Fields) {
            [hashtable] $BodyFields = $Body -as [hashtable]
            if ($null -eq $BodyFields) {
                throw "Body must be a hashtable when using the Fields parameter."
            }
            foreach ($key in $BodyFields.Keys) {
                $commandFinal = $commandFinal.AddArgument("--raw-field")
                [string] $escapedFieldName = [System.Uri]::EscapeDataString($key)
                [string] $escapedFieldValue = [System.Uri]::EscapeDataString($BodyFields[$key])
                $commandFinal = $commandFinal.AddArgument("${escapedFieldName}=${escapedFieldValue}")
            }
        } elseif ($File) {
            [System.IO.FileInfo] $File = $Body -as [System.IO.FileInfo]
            if ($null -eq $File) {
                throw "Body must be a FileInfo when using the File parameter."
            }
            $commandFinal = $commandFinal.AddArgument("--input")
            $commandFinal = $commandFinal.AddArgument($File.FullName)
        } elseif ($Raw -or $Json) {
            $commandFinal = $commandFinal.AddArgument("--input")
            $commandFinal = $commandFinal.AddArgument("-")

            [System.Management.Automation.PSCommand] $inputHandlingCommand = [System.Management.Automation.PSCommand]::new()

            if ($PSCmdlet.MyInvocation.ExpectingInput) {
                # $input | Invoke-Command $commandFinal
                $inputHandlingCommand = $inputHandlingCommand.AddArgument($input)
            } else {
                # $Body | Invoke-Command $commandFinal
                $inputHandlingCommand = $inputHandlingCommand.AddArgument($Body)
            }

            if ($Json) {
                $inputHandlingCommand = $inputHandlingCommand.AddCommand("ConvertTo-Json")
                if ($InputAsArray) {
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument("-AsArray")
                }

                if ($InputCompress) {
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument("-Compress")
                }

                if ($null -ne $InputDepth) {
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument("-Depth")
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument($InputDepth)
                }

                if ($InputEnumsAsStrings) {
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument("-EnumsAsStrings")
                }

                if ($null -ne $InputEscapeHandling) {
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument("-EscapeHandling")
                    $inputHandlingCommand = $inputHandlingCommand.AddArgument($InputEscapeHandling)
                }
            }

            $commandFinal = $inputHandlingCommand.AddCommand($commandFinal)
        }

        if ($null -ne $outputHandlingCommand) {
            $commandFinal = $commandFinal.AddCommand($outputHandlingCommand)
        }
        Invoke-Command $commandFinal
    }

    End {
    }
}
