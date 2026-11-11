param(
    [string]$SuiteDirectory = "",
    [string]$SuiteRef = "4dcbceeb0c57f92c8b952021a18cd0f3de67bf15",
    [switch]$UseExistingCheckout
)

# One-time setup: link the Godot XR Suite into demo/addons.
#
# The addons are NOT embedded in this repo. Their single source of truth is
# https://github.com/davtamay/godot-xr-suite — this script clones it next
# to this repo (or reuses an existing checkout), pins it to $SuiteRef, and
# creates directory junctions so the demo project sees the addons.
#
# Bump $SuiteRef to consume a newer suite release. Use "master" to track
# latest during active development.

$SuiteUrl = "https://github.com/davtamay/godot-xr-suite.git"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SuiteDir = if ($SuiteDirectory) { [System.IO.Path]::GetFullPath($SuiteDirectory) } else { Join-Path (Split-Path -Parent $RepoRoot) "godot-xr-suite" }
$LegacySuiteDir = Join-Path (Split-Path -Parent $RepoRoot) "godot-webxr-suite"

if (-not $SuiteDirectory -and -not (Test-Path $SuiteDir) -and (Test-Path $LegacySuiteDir)) {
    Write-Warning "Using legacy checkout path $LegacySuiteDir. Close Godot, then rename it to godot-xr-suite when convenient."
    $SuiteDir = $LegacySuiteDir
}

if ($UseExistingCheckout) {
    if (-not (Test-Path -LiteralPath (Join-Path $SuiteDir ".git"))) {
        throw "Existing suite checkout not found: $SuiteDir"
    }
} else {
    if (-not (Test-Path -LiteralPath $SuiteDir)) {
        git clone $SuiteUrl $SuiteDir
    } else {
        git -C $SuiteDir fetch --tags
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not prepare suite checkout" }
    git -C $SuiteDir checkout $SuiteRef
    if ($LASTEXITCODE -ne 0) { throw "Could not select suite revision $SuiteRef" }
}
$ActualSuiteRef = git -C $SuiteDir rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw "Could not identify suite revision" }

$AddonsDir = Join-Path $RepoRoot "demo\addons"
New-Item -ItemType Directory -Force $AddonsDir | Out-Null

foreach ($a in Get-ChildItem (Join-Path $SuiteDir "addons") -Directory) {
    $link = Join-Path $AddonsDir $a.Name
    if (Test-Path $link) {
        $existing = Get-Item -LiteralPath $link -Force
        if ($existing.LinkType -ne "Junction") {
            throw "Refusing to replace non-junction addon path: $link"
        }
        [System.IO.Directory]::Delete($existing.FullName)
    }
    New-Item -ItemType Junction -Path $link -Target $a.FullName | Out-Null
    Write-Host "linked addons\$($a.Name) -> $($a.FullName)"
}

Write-Host "Done. Suite at $SuiteDir ($ActualSuiteRef)."
