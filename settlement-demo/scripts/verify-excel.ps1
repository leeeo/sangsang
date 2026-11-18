param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = "Stop"
$excel = $null
$book = $null
$summary = $null
$detail = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.AutomationSecurity = 3
    $book = $excel.Workbooks.Open((Resolve-Path $Path).Path)
    $summary = $book.Worksheets.Item(1)
    $detail = $book.Worksheets.Item(2)
    $excel.CalculateFullRebuild()
    if ($summary.Cells.Item(9, 2).Value2 -ne 149400) {
        throw "Initial settlement differs from 149400 KRW."
    }
    $detail.Cells.Item(2, 4).Value2 = 3
    $excel.CalculateFullRebuild()
    if ($summary.Cells.Item(9, 2).Value2 -ne 161400) {
        throw "Quantity change did not propagate to settlement summary."
    }
    $detail.Cells.Item(2, 4).Value2 = 2
    $detail.Cells.Item(4, 9).Value2 = $detail.Cells.Item(2, 9).Value2
    $excel.CalculateFullRebuild()
    if ($summary.Cells.Item(9, 2).Value2 -ne 174900) {
        throw "Canceled-to-completed change did not propagate to summary."
    }
    # Restore the canceled status using Unicode code points (portable script encoding).
    $detail.Cells.Item(4, 9).Value2 = ([string][char]0xCDE8) + ([string][char]0xC18C)
    $excel.CalculateFullRebuild()
    if ($summary.Cells.Item(9, 2).Value2 -ne 149400) {
        throw "Restored sample total is incorrect."
    }
    foreach ($sheet in @($summary, $detail)) {
        foreach ($cell in $sheet.UsedRange.Cells) {
            if ($cell.Text -match '^#(REF!|VALUE!|DIV/0!|NAME\?|N/A|NUM!|SPILL!|CALC!|NULL!)$') {
                throw "Excel formula error at $($cell.Address())."
            }
        }
    }
    $book.Save()
    Write-Output "EXCEL_PASS: total=149400; quantity_edit=161400; status_edit=174900; formula_errors=0"
}
finally {
    if ($book) { $book.Close($false) }
    if ($excel) { $excel.Quit() }
    foreach ($item in @($detail, $summary, $book, $excel)) {
        if ($item) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($item) }
    }
}
