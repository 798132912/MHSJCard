param(
    [switch] $CreateBackup
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root = Split-Path -Parent $PSScriptRoot
$ExcelDir = Join-Path $Root "design_tables\excel"

$SpreadsheetNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
$OfficeRelNs = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
$PackageRelNs = "http://schemas.openxmlformats.org/package/2006/relationships"
$ContentTypeNs = "http://schemas.openxmlformats.org/package/2006/content-types"

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
        $Reader = [System.IO.StreamReader]::new($Stream, [System.Text.Encoding]::UTF8)
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

function Write-ZipEntryText {
    param(
        [Parameter(Mandatory = $true)] $Zip,
        [Parameter(Mandatory = $true)] [string] $EntryName,
        [Parameter(Mandatory = $true)] [string] $Text
    )

    $Existing = $Zip.GetEntry($EntryName)
    if ($null -ne $Existing) {
        $Existing.Delete()
    }

    $Entry = $Zip.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $Stream = $Entry.Open()
    try {
        $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $Writer = [System.IO.StreamWriter]::new($Stream, $Utf8NoBom)
        try {
            $Writer.Write($Text)
        }
        finally {
            $Writer.Dispose()
        }
    }
    finally {
        $Stream.Dispose()
    }
}

function Load-XmlDocument {
    param([Parameter(Mandatory = $true)] [string] $Text)

    $Document = [xml]$Text
    return $Document
}

function New-NamespaceManager {
    param([Parameter(Mandatory = $true)] [xml] $Document)

    $Ns = [System.Xml.XmlNamespaceManager]::new($Document.NameTable)
    $Ns.AddNamespace("x", $SpreadsheetNs)
    $Ns.AddNamespace("r", $OfficeRelNs)
    $Ns.AddNamespace("pr", $PackageRelNs)
    $Ns.AddNamespace("ct", $ContentTypeNs)
    return $Ns
}

function Save-XmlDocument {
    param([Parameter(Mandatory = $true)] [xml] $Document)

    $Settings = [System.Xml.XmlWriterSettings]::new()
    $Settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $Settings.OmitXmlDeclaration = $false
    $Settings.Indent = $false

    $Stream = [System.IO.MemoryStream]::new()
    $Writer = [System.Xml.XmlWriter]::Create($Stream, $Settings)
    try {
        $Document.Save($Writer)
    }
    finally {
        $Writer.Dispose()
    }

    return $Settings.Encoding.GetString($Stream.ToArray())
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

function Get-ColumnName {
    param([Parameter(Mandatory = $true)] [int] $Index)

    $Number = $Index + 1
    $Name = ""
    while ($Number -gt 0) {
        $Remainder = ($Number - 1) % 26
        $Name = [string][char]([int][char]'A' + $Remainder) + $Name
        $Number = [math]::Floor(($Number - 1) / 26)
    }
    return $Name
}

function Get-SharedStrings {
    param([Parameter(Mandatory = $true)] $Zip)

    $SharedText = Read-ZipEntryText -Zip $Zip -EntryName "xl/sharedStrings.xml"
    $SharedStrings = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($SharedText)) {
        return ,$SharedStrings
    }

    $SharedXml = Load-XmlDocument $SharedText
    foreach ($Item in $SharedXml.SelectNodes("//*[local-name()='si']")) {
        $Text = ""
        foreach ($Part in $Item.SelectNodes(".//*[local-name()='t']")) {
            $Text += $Part.InnerText
        }
        $SharedStrings.Add($Text)
    }

    return ,$SharedStrings
}

function Get-CellText {
    param(
        [Parameter(Mandatory = $true)] $Cell,
        [Parameter(Mandatory = $true)] $SharedStrings
    )

    $Type = $Cell.GetAttribute("t")
    if ($Type -eq "inlineStr") {
        $Text = ""
        foreach ($TextNode in $Cell.SelectNodes(".//*[local-name()='t']")) {
            $Text += $TextNode.InnerText
        }
        return $Text
    }

    $ValueNode = $Cell.SelectSingleNode("./*[local-name()='v']")
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

    return $Raw
}

function Set-CellText {
    param(
        [Parameter(Mandatory = $true)] [xml] $SheetXml,
        [Parameter(Mandatory = $true)] [string] $CellRef,
        [Parameter(Mandatory = $true)] [string] $Text
    )

    $Cell = $SheetXml.SelectSingleNode("//*[local-name()='c' and @r='$CellRef']")
    if ($null -eq $Cell) {
        return $false
    }

    $Cell.SetAttribute("t", "inlineStr")
    $ValueNode = $Cell.SelectSingleNode("./*[local-name()='v']")
    if ($null -ne $ValueNode) {
        [void]$Cell.RemoveChild($ValueNode)
    }
    $InlineNode = $Cell.SelectSingleNode("./*[local-name()='is']")
    if ($null -eq $InlineNode) {
        $InlineNode = $SheetXml.CreateElement("is", $SpreadsheetNs)
        [void]$Cell.AppendChild($InlineNode)
    }
    else {
        $InlineNode.RemoveAll()
    }

    $TextNode = $SheetXml.CreateElement("t", $SpreadsheetNs)
    $TextNode.InnerText = $Text
    [void]$InlineNode.AppendChild($TextNode)
    return $true
}

function Get-SheetShape {
    param(
        [Parameter(Mandatory = $true)] [xml] $SheetXml,
        [Parameter(Mandatory = $true)] $SharedStrings
    )

    $MaxRow = 0
    $MaxCol = -1
    $MaxHeaderCol = -1
    $Headers = @{}

    foreach ($Row in $SheetXml.SelectNodes("//*[local-name()='sheetData']/*[local-name()='row']")) {
        $RowNumber = [int]$Row.GetAttribute("r")
        if ($RowNumber -gt $MaxRow) {
            $MaxRow = $RowNumber
        }

        foreach ($Cell in $Row.SelectNodes("./*[local-name()='c']")) {
            $Ref = $Cell.GetAttribute("r")
            if ([string]::IsNullOrWhiteSpace($Ref)) {
                continue
            }
            $ColIndex = Get-ColumnIndex $Ref
            if ($ColIndex -gt $MaxCol) {
                $MaxCol = $ColIndex
            }
            if ($RowNumber -eq 1) {
                $Headers[$ColIndex] = Get-CellText -Cell $Cell -SharedStrings $SharedStrings
                if ($ColIndex -gt $MaxHeaderCol) {
                    $MaxHeaderCol = $ColIndex
                }
            }
        }
    }

    $ColumnCount = [Math]::Max($MaxCol, $MaxHeaderCol) + 1
    $HeaderList = [System.Collections.Generic.List[string]]::new()
    for ($Index = 0; $Index -lt $ColumnCount; $Index++) {
        $Header = if ($Headers.ContainsKey($Index)) { [string]$Headers[$Index] } else { "Column$($Index + 1)" }
        if ([string]::IsNullOrWhiteSpace($Header)) {
            $Header = "Column$($Index + 1)"
        }
        $HeaderList.Add($Header)
    }

    return @{
        MaxRow = [Math]::Max(1, $MaxRow)
        ColumnCount = [Math]::Max(1, $ColumnCount)
        Headers = $HeaderList
    }
}

function Get-WorkbookSheetName {
    param([Parameter(Mandatory = $true)] $Zip)

    $WorkbookText = Read-ZipEntryText -Zip $Zip -EntryName "xl/workbook.xml"
    if ([string]::IsNullOrWhiteSpace($WorkbookText)) {
        return "Sheet1"
    }

    $WorkbookXml = Load-XmlDocument $WorkbookText
    $SheetNode = $WorkbookXml.SelectSingleNode("//*[local-name()='sheets']/*[local-name()='sheet'][1]")
    if ($null -eq $SheetNode) {
        return "Sheet1"
    }

    $Name = $SheetNode.GetAttribute("name")
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "Sheet1"
    }
    return $Name
}

function Get-SafeTableName {
    param([Parameter(Mandatory = $true)] [string] $SheetName)

    $Base = ($SheetName -replace '[^A-Za-z0-9_]', '')
    if ([string]::IsNullOrWhiteSpace($Base)) {
        $Base = "Sheet1"
    }
    if ($Base -match '^[0-9]') {
        $Base = "T$Base"
    }
    return "$($Base)Table"
}

function Remove-RecoveryMarker {
    param([Parameter(Mandatory = $true)] [xml] $WorkbookXml)

    $Changed = $false
    foreach ($Node in @($WorkbookXml.SelectNodes("//*[local-name()='fileRecoveryPr']"))) {
        [void]$Node.ParentNode.RemoveChild($Node)
        $Changed = $true
    }
    return $Changed
}

function Remove-SheetTableParts {
    param([Parameter(Mandatory = $true)] [xml] $SheetXml)

    $Changed = $false
    foreach ($Node in @($SheetXml.SelectNodes("//*[local-name()='tableParts']"))) {
        [void]$Node.ParentNode.RemoveChild($Node)
        $Changed = $true
    }

    return $Changed
}

function Remove-SheetTableRelationship {
    param([Parameter(Mandatory = $true)] $Zip)

    $Path = "xl/worksheets/_rels/sheet1.xml.rels"
    $Text = Read-ZipEntryText -Zip $Zip -EntryName $Path
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $Xml = Load-XmlDocument $Text
    foreach ($Node in @($Xml.SelectNodes("//*[local-name()='Relationship' and @Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/table']"))) {
        [void]$Node.ParentNode.RemoveChild($Node)
    }
    Write-ZipEntryText -Zip $Zip -EntryName $Path -Text (Save-XmlDocument $Xml)
}

function Remove-TableContentType {
    param([Parameter(Mandatory = $true)] $Zip)

    $Path = "[Content_Types].xml"
    $Text = Read-ZipEntryText -Zip $Zip -EntryName $Path
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $Xml = Load-XmlDocument $Text
    $Changed = $false
    foreach ($Override in @($Xml.SelectNodes("//*[local-name()='Override' and starts-with(@PartName, '/xl/tables/')]"))) {
        [void]$Override.ParentNode.RemoveChild($Override)
        $Changed = $true
    }
    Write-ZipEntryText -Zip $Zip -EntryName $Path -Text (Save-XmlDocument $Xml)
}

function Remove-TableEntries {
    param([Parameter(Mandatory = $true)] $Zip)

    foreach ($Entry in @($Zip.Entries | Where-Object { $_.FullName -like "xl/tables/*" })) {
        $Entry.Delete()
    }
}

function Repair-Workbook {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $BackupPath = "$Path.bak"
    if ($CreateBackup -and !(Test-Path -LiteralPath $BackupPath)) {
        Copy-Item -LiteralPath $Path -Destination $BackupPath
    }

    $Zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $SharedStrings = Get-SharedStrings -Zip $Zip
        $SheetText = Read-ZipEntryText -Zip $Zip -EntryName "xl/worksheets/sheet1.xml"
        if ([string]::IsNullOrWhiteSpace($SheetText)) {
            Write-Warning "Skipped workbook without sheet1.xml: $Path"
            return
        }

        $SheetXml = Load-XmlDocument $SheetText

        if ((Split-Path -Leaf $Path) -eq "Character.xlsx") {
            [void](Set-CellText -SheetXml $SheetXml -CellRef "P4" -Text "Player_1_Original.png")
        }

        $Shape = Get-SheetShape -SheetXml $SheetXml -SharedStrings $SharedStrings
        $LastColumnName = Get-ColumnName ($Shape.ColumnCount - 1)
        $Range = "A1:$LastColumnName$($Shape.MaxRow)"
        $Dimension = $SheetXml.SelectSingleNode("//*[local-name()='dimension']")
        if ($null -ne $Dimension) {
            $Dimension.SetAttribute("ref", $Range)
        }

        [void](Remove-SheetTableParts -SheetXml $SheetXml)
        Write-ZipEntryText -Zip $Zip -EntryName "xl/worksheets/sheet1.xml" -Text (Save-XmlDocument $SheetXml)

        Remove-SheetTableRelationship -Zip $Zip
        Remove-TableContentType -Zip $Zip
        Remove-TableEntries -Zip $Zip

        $WorkbookText = Read-ZipEntryText -Zip $Zip -EntryName "xl/workbook.xml"
        if (![string]::IsNullOrWhiteSpace($WorkbookText)) {
            $WorkbookXml = Load-XmlDocument $WorkbookText
            [void](Remove-RecoveryMarker -WorkbookXml $WorkbookXml)
            Write-ZipEntryText -Zip $Zip -EntryName "xl/workbook.xml" -Text (Save-XmlDocument $WorkbookXml)
        }

        Write-Host "Repaired $(Split-Path -Leaf $Path): $Range (table object removed)"
    }
    finally {
        $Zip.Dispose()
    }
}

if (!(Test-Path -LiteralPath $ExcelDir)) {
    throw "Excel source table directory was not found: $ExcelDir"
}

foreach ($File in Get-ChildItem -Path $ExcelDir -Filter "*.xlsx" | Sort-Object Name) {
    Repair-Workbook -Path $File.FullName
}
