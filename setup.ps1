# One-time setup: link the XR addon suite into demo/addons.
#
# The addons are NOT embedded in this repo. Their single source of truth is
# https://github.com/davtamay/godot-webxr-suite — this script clones it next
# to this repo (or reuses an existing checkout), pins it to $SuiteRef, and
# creates directory junctions so the demo project sees the addons.
#
# Bump $SuiteRef to consume a newer suite release. Use "master" to track
# latest during active development.

$SuiteRef = "v1.6.1"
$SuiteUrl = "https://github.com/davtamay/godot-webxr-suite.git"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SuiteDir = Join-Path (Split-Path -Parent $RepoRoot) "godot-webxr-suite"

if (-not (Test-Path $SuiteDir)) {
    git clone $SuiteUrl $SuiteDir
} else {
    git -C $SuiteDir fetch --tags
}
git -C $SuiteDir checkout $SuiteRef

$AddonsDir = Join-Path $RepoRoot "demo\addons"
New-Item -ItemType Directory -Force $AddonsDir | Out-Null

foreach ($a in Get-ChildItem (Join-Path $SuiteDir "addons") -Directory) {
    $link = Join-Path $AddonsDir $a.Name
    if (Test-Path $link) { cmd /c "rmdir `"$link`"" }
    New-Item -ItemType Junction -Path $link -Target $a.FullName | Out-Null
    Write-Host "linked addons\$($a.Name) -> $($a.FullName)"
}

Write-Host "Done. Suite at $SuiteDir ($SuiteRef)."
