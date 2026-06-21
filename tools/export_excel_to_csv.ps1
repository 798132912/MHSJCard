$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root = Split-Path -Parent $PSScriptRoot
$ExcelDir = Join-Path $Root "design_tables\excel"
$CsvDir = Join-Path $Root "data\tables"

if (!(Test-Path -LiteralPath $ExcelDir)) {
    throw "Excel source table directory was not found: $ExcelDir"
}

if (!(Test-Path -LiteralPath $CsvDir)) {
    New-Item -ItemType Directory -Force -Path $CsvDir | Out-Null
}

$Tables = @(
    @{ Excel = "Character.xlsx"; Csv = "Character.csv" },
    @{ Excel = "Card.xlsx"; Csv = "Card.csv" },
    @{ Excel = "CardEffect.xlsx"; Csv = "CardEffect.csv" },
    @{ Excel = "StarterDeck.xlsx"; Csv = "StarterDeck.csv" },
    @{ Excel = "CardPool.xlsx"; Csv = "CardPool.csv" },
    @{ Excel = "Level.xlsx"; Csv = "Level.csv" },
    @{ Excel = "Enemy.xlsx"; Csv = "Enemy.csv" },
    @{ Excel = "EnemyAction.xlsx"; Csv = "EnemyAction.csv" },
    @{ Excel = "EnemyAI.xlsx"; Csv = "EnemyAI.csv" },
    @{ Excel = "Item.xlsx"; Csv = "Item.csv" },
    @{ Excel = "GameConfig.xlsx"; Csv = "GameConfig.csv" },
    @{ Excel = "ResourceConfig.xlsx"; Csv = "ResourceConfig.csv" },
    @{ Excel = "DamageTypeConfig.xlsx"; Csv = "DamageTypeConfig.csv" },
    @{ Excel = "StatusConfig.xlsx"; Csv = "StatusConfig.csv" },
    @{ Excel = "FormConfig.xlsx"; Csv = "FormConfig.csv" },
    @{ Excel = "PileConfig.xlsx"; Csv = "PileConfig.csv" },
    @{ Excel = "TurnPhaseConfig.xlsx"; Csv = "TurnPhaseConfig.csv" },
    @{ Excel = "TargetTypeConfig.xlsx"; Csv = "TargetTypeConfig.csv" },
    @{ Excel = "CardTypeConfig.xlsx"; Csv = "CardTypeConfig.csv" },
    @{ Excel = "EnemyIntentConfig.xlsx"; Csv = "EnemyIntentConfig.csv" }
)

function Read-ZipEntryText {
    param(
        [Parameter(Mandatory = $true)] $Zip,
        [Parameter(Mandatory = $true)] [string] $EntryName
    )

    $Entry = $Zip.GetEntry($EntryName)
    if ($null -eq $Entry) {
        return $null
    }

    $Stream = $Entry.Open()
    try {
        $Reader = New-Object System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8)
        try {
            return $Reader.ReadToEnd()
        }
        finally {
            $Reader.Dispose()
        }
    }
    finally {
        $Stream.Dispose()
    }
}

function Get-ColumnIndex {
    param([Parameter(Mandatory = $true)] [string] $CellRef)

    $Letters = ($CellRef -replace '[0-9]', '')
    $Index = 0
    foreach ($Char in $Letters.ToCharArray()) {
        $Index = ($Index * 26) + ([int][char]$Char - [int][char]'A' + 1)
    }
    return $Index - 1
}

function Convert-CellValueToCsvText {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }

    $Text = [string]$Value
    if ($Text.Contains('"')) {
        $Text = $Text.Replace('"', '""')
    }

    if ($Text.Contains(',') -or $Text.Contains('"') -or $Text.Contains("`n") -or $Text.Contains("`r")) {
        return '"' + $Text + '"'
    }

    return $Text
}

function Test-IsSchemaTypeRow {
    param(
        [Parameter(Mandatory = $true)] $Table,
        [Parameter(Mandatory = $true)] [int] $MaxCol
    )

    $AllowedTypes = @(
        "string",
        "int",
        "float",
        "bool",
        "boolean",
        "number",
        "path"
    )
    $NonEmptyCount = 0

    for ($ColIndex = 0; $ColIndex -lt $MaxCol; $ColIndex++) {
        $Key = "2,$ColIndex"
        if (!$Table.ContainsKey($Key)) {
            continue
        }

        $Value = ([string]$Table[$Key]).Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($Value)) {
            continue
        }

        $NonEmptyCount += 1
        if (
            ($AllowedTypes -notcontains $Value) -and
            ($Value -ne "enum") -and
            (!$Value.StartsWith("ref:")) -and
            (!$Value.EndsWith("()"))
        ) {
            return $false
        }
    }

    return $NonEmptyCount -gt 0
}

function Test-IsEmptyRow {
    param(
        [Parameter(Mandatory = $true)] $Table,
        [Parameter(Mandatory = $true)] [int] $RowNumber,
        [Parameter(Mandatory = $true)] [int] $MaxCol
    )

    for ($ColIndex = 0; $ColIndex -lt $MaxCol; $ColIndex++) {
        $Key = "$RowNumber,$ColIndex"
        if (!$Table.ContainsKey($Key)) {
            continue
        }

        if (![string]::IsNullOrWhiteSpace([string]$Table[$Key])) {
            return $false
        }
    }

    return $true
}

function Get-SharedStrings {
    param([Parameter(Mandatory = $true)] $Zip)

    $SharedText = Read-ZipEntryText -Zip $Zip -EntryName "xl/sharedStrings.xml"
    $SharedStrings = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($SharedText)) {
        return ,$SharedStrings
    }

    [xml]$SharedXml = $SharedText
    $Items = $SharedXml.SelectNodes("//*[local-name()='si']")
    foreach ($Item in $Items) {
        $Parts = $Item.SelectNodes(".//*[local-name()='t']")
        $Value = ""
        foreach ($Part in $Parts) {
            $Value += $Part.InnerText
        }
        $SharedStrings.Add($Value)
    }

    return ,$SharedStrings
}

function Get-CellText {
    param(
        [Parameter(Mandatory = $true)] $Cell,
        [Parameter(Mandatory = $true)] $SharedStrings
    )

    $Type = $Cell.GetAttribute("t")
    $ValueNode = $Cell.SelectSingleNode("./*[local-name()='v']")

    if ($Type -eq "inlineStr") {
        $TextNode = $Cell.SelectSingleNode(".//*[local-name()='t']")
        if ($null -eq $TextNode) { return "" }
        return $TextNode.InnerText
    }

    if ($null -eq $ValueNode) {
        return ""
    }

    $Raw = $ValueNode.InnerText

    if ($Type -eq "s") {
        $Index = [int]$Raw
        if ($Index -ge 0 -and $Index -lt $SharedStrings.Count) {
            return $SharedStrings[$Index]
        }
        return ""
    }

    if ($Type -eq "b") {
        if ($Raw -eq "1") { return "TRUE" }
        return "FALSE"
    }

    return $Raw
}

function Export-XlsxFirstSheetToCsv {
    param(
        [Parameter(Mandatory = $true)] [string] $XlsxPath,
        [Parameter(Mandatory = $true)] [string] $CsvPath
    )

    $Zip = [System.IO.Compression.ZipFile]::OpenRead($XlsxPath)
    try {
        $SharedStrings = Get-SharedStrings -Zip $Zip
        $SheetText = Read-ZipEntryText -Zip $Zip -EntryName "xl/worksheets/sheet1.xml"
        if ([string]::IsNullOrWhiteSpace($SheetText)) {
            throw "The workbook has no xl/worksheets/sheet1.xml: $XlsxPath"
        }

        [xml]$SheetXml = $SheetText
        $Rows = $SheetXml.SelectNodes("//*[local-name()='sheetData']/*[local-name()='row']")
        $Table = @{}
        $MaxRow = 0
        $MaxCol = 0

        foreach ($Row in $Rows) {
            $RowNumber = [int]$Row.GetAttribute("r")
            if ($RowNumber -gt $MaxRow) { $MaxRow = $RowNumber }

            $Cells = $Row.SelectNodes("./*[local-name()='c']")
            foreach ($Cell in $Cells) {
                $Ref = $Cell.GetAttribute("r")
                if ([string]::IsNullOrWhiteSpace($Ref)) { continue }

                $ColIndex = Get-ColumnIndex -CellRef $Ref
                if (($ColIndex + 1) -gt $MaxCol) { $MaxCol = $ColIndex + 1 }

                $Text = Get-CellText -Cell $Cell -SharedStrings $SharedStrings
                $Table["$RowNumber,$ColIndex"] = $Text
            }
        }

        $SkipSchemaRows = Test-IsSchemaTypeRow -Table $Table -MaxCol $MaxCol
        $Lines = New-Object System.Collections.Generic.List[string]
        for ($RowNumber = 1; $RowNumber -le $MaxRow; $RowNumber++) {
            if ($SkipSchemaRows -and ($RowNumber -eq 2 -or $RowNumber -eq 3)) {
                continue
            }
            if ($RowNumber -gt 1 -and (Test-IsEmptyRow -Table $Table -RowNumber $RowNumber -MaxCol $MaxCol)) {
                continue
            }
            $Cells = New-Object System.Collections.Generic.List[string]
            for ($ColIndex = 0; $ColIndex -lt $MaxCol; $ColIndex++) {
                $Key = "$RowNumber,$ColIndex"
                $Value = if ($Table.ContainsKey($Key)) { $Table[$Key] } else { "" }
                $Cells.Add((Convert-CellValueToCsvText $Value))
            }
            $Lines.Add(($Cells -join ","))
        }

        $Utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllLines($CsvPath, $Lines, $Utf8Bom)
    }
    finally {
        $Zip.Dispose()
    }
}

foreach ($Table in $Tables) {
    $ExcelPath = Join-Path $ExcelDir $Table.Excel
    $CsvPath = Join-Path $CsvDir $Table.Csv

    if (!(Test-Path -LiteralPath $ExcelPath)) {
        Write-Warning "Skipped missing source table: $ExcelPath"
        continue
    }

    Write-Host "Export $($Table.Excel) -> data\tables\$($Table.Csv)"
    Export-XlsxFirstSheetToCsv -XlsxPath $ExcelPath -CsvPath $CsvPath
}
