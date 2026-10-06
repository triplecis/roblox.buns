param(
    [string]$Luau = "luau.exe",
    [string]$Compiler = "luau-compile.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceFiles = @(Get-ChildItem -LiteralPath $projectRoot -Filter "*.lua" -File)
$sourceFiles += @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "games") -Filter "*.lua" -File -Recurse)
$compileFiles = @($sourceFiles.FullName) + @(Join-Path $PSScriptRoot "regression.luau")
& $Compiler --null @compileFiles
if ($LASTEXITCODE -ne 0) { throw "Luau compilation failed." }

# The Luau CLI has no file I/O API. Embed the real sources into the mock harness.
$builder = New-Object System.Text.StringBuilder
[void]$builder.AppendLine("local Sources = {")
foreach ($sourceFile in $sourceFiles) {
    $relativePath = $sourceFile.FullName.Substring($projectRoot.Length + 1).Replace("\", "/")
    $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName)
    if ($sourceText.Contains("]=====]")) { throw "Source contains the test embedding delimiter." }
    [void]$builder.AppendLine('["' + $relativePath + '"] = [=====[' + $sourceText + ']=====],')
}
[void]$builder.AppendLine("}")
[void]$builder.AppendLine("local RunTests = (function()")
[void]$builder.AppendLine([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "regression.luau")))
[void]$builder.AppendLine("end)()")
[void]$builder.AppendLine("RunTests(Sources)")
$temporaryScript = Join-Path ([System.IO.Path]::GetTempPath()) ("roblox-buns-tests-" + [guid]::NewGuid() + ".luau")
try {
    [System.IO.File]::WriteAllText($temporaryScript, $builder.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    & $Luau $temporaryScript
    if ($LASTEXITCODE -ne 0) { throw "Regression tests failed." }
} finally {
    if (Test-Path -LiteralPath $temporaryScript) { Remove-Item -LiteralPath $temporaryScript }
}
