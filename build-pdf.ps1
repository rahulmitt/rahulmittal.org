# Updates the years of experience in the CV page, then renders it to a one-page PDF with headless Chrome. Fails if anything is wrong (F2.3, F2.5).
param([string]$Page = "cv/index.html", [string]$Out = "", [datetime]$Today = (Get-Date))
$ErrorActionPreference = "Stop"
$src = (Resolve-Path $Page).ProviderPath

# Completed years since the page's career-start month. They set the page text, the download link and the PDF name.
$utf8 = New-Object Text.UTF8Encoding($false)
$old = [IO.File]::ReadAllText($src, $utf8)
$m = [regex]::Match($old, '<meta name="career-start" content="(\d{4})-(0[1-9]|1[0-2])">')
if (-not $m.Success) { throw "career-start (YYYY-MM) not found in $Page" }
$months = ($Today.Year - [int]$m.Groups[1].Value) * 12 + $Today.Month - [int]$m.Groups[2].Value
$years = [int][Math]::Floor($months / 12)
if ($years -lt 1) { throw "Computed $years years of experience; check career-start" }
$new = $old
foreach ($pat in '(?<=Architect with )\d+(?= years)', '(?<=Total Exp: )\d+(?= years)', '(?<=over <b>)\d+(?= years)',
    '(?<=href="CV_Rahul_Mittal_)\d+(?=yrs_java\.pdf")') {
  if (-not [regex]::IsMatch($new, $pat)) { throw "Text to update not found in ${Page}: $pat" }
  $new = [regex]::Replace($new, $pat, "$years")
}
if ($new -cne $old) { [IO.File]::WriteAllText($src, $new, $utf8); Write-Output "Updated $Page to $years years" }
if (-not $Out) {
  $dir = Split-Path $src
  Get-ChildItem $dir -Filter "CV_Rahul_Mittal_*yrs_java.pdf" | Remove-Item
  $Out = Join-Path $dir "CV_Rahul_Mittal_${years}yrs_java.pdf"
}

$dst = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw "Chrome not found" }
if (Test-Path $dst) { Remove-Item $dst }
$prof = Join-Path ([IO.Path]::GetTempPath()) ("cvpdf-" + [guid]::NewGuid())
$chromeArgs = @("--headless=new", "--disable-gpu", "--no-first-run", "--no-pdf-header-footer", "--user-data-dir=`"$prof`"",
  "--print-to-pdf=`"$dst`"", "`"$(([Uri]$src).AbsoluteUri)`"")
$p = Start-Process -FilePath $chrome -ArgumentList $chromeArgs -PassThru
if (-not $p.WaitForExit(90000)) { $p.Kill(); throw "Chrome timed out" }
if (-not (Test-Path $dst)) { throw "No PDF was produced" }
if ((Get-Item $dst).Length -lt 50KB) { throw "The PDF is too small" }
$raw = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($dst))
$pages = [regex]::Matches($raw, "/Type\s*/Page\b").Count
if ($pages -ne 1) { throw "Expected 1 page, found $pages" }
foreach ($f in "Tahoma", "Calibri") {
  if ($raw -notmatch "\+$f") { Write-Output "::warning::Font $f is missing, so the PDF may look different" }
}
Write-Output "PDF OK: $(Split-Path $dst -Leaf), $pages page, $((Get-Item $dst).Length) bytes"
