param(
	[ValidateSet("Web", "APK", "All")]
	[string]$Target = "All",
	[string]$Project = (Join-Path $PSScriptRoot "..\demo"),
	[string]$WebEditor = "",
	[string]$AndroidEditor = ""
)

$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path -LiteralPath $Project).Path
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates"
$webOutput = Join-Path $projectPath "build\verify\web\index.html"
$apkOutput = Join-Path $projectPath "build\android\universal\GodotXR-universal-debug.apk"
$gradleApk = Join-Path $projectPath "android\build\build\outputs\apk\standard\debug\android_debug.apk"

$knownEditors = @(
	"C:\Users\davta\Documents\Godot_WebGPU\bin\godot.windows.editor.x86_64.console.exe",
	"C:\Users\davta\Documents\Godot R&D\_tools\Godot-4.8-dev2\Godot_v4.8-dev2_win64_console.exe"
) | Where-Object { Test-Path -LiteralPath $_ }


function Get-EditorInfo([string]$Path) {
	$version = (& $Path --version | Select-Object -First 1).Trim()
	$match = [regex]::Match($version, "^\d+\.\d+\.(?:dev\d*|stable)")
	if (-not $match.Success) {
		throw "Cannot derive the template directory from '$version' ($Path)."
	}
	[pscustomobject]@{
		Path = $Path
		Version = $version
		TemplateTag = $match.Value
		TemplateDir = Join-Path $templateRoot $match.Value
	}
}


function Find-Editor([ValidateSet("Web", "APK")][string]$ForTarget, [string]$ExplicitPath) {
	$candidates = @()
	if ($ExplicitPath) {
		$candidates += $ExplicitPath
	}
	$candidates += $knownEditors
	foreach ($candidate in ($candidates | Select-Object -Unique)) {
		if (-not (Test-Path -LiteralPath $candidate)) {
			continue
		}
		$info = Get-EditorInfo $candidate
		if ($ForTarget -eq "Web") {
			if (Test-Path -LiteralPath (Join-Path $info.TemplateDir "web_nothreads_release.zip")) {
				return $info
			}
		} else {
			$debugTemplate = Join-Path $info.TemplateDir "android_debug.apk"
			$sourceTemplate = Join-Path $info.TemplateDir "android_source.zip"
			if ((Test-Path -LiteralPath $debugTemplate) -and (Test-Path -LiteralPath $sourceTemplate)) {
				return $info
			}
		}
	}
	throw "No $ForTarget editor with matching export templates was found."
}


function Get-ApkSigner {
	$androidSdk = if ($env:ANDROID_HOME) {
		$env:ANDROID_HOME
	} elseif ($env:ANDROID_SDK_ROOT) {
		$env:ANDROID_SDK_ROOT
	} else {
		Join-Path $env:LOCALAPPDATA "Android\Sdk"
	}
	$signer = Get-ChildItem -LiteralPath (Join-Path $androidSdk "build-tools") -Directory |
		Sort-Object Name -Descending |
		ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
		Where-Object { Test-Path -LiteralPath $_ } |
		Select-Object -First 1
	if (-not $signer) {
		throw "Android apksigner was not found."
	}
	return $signer
}


function Test-SignedApk([string]$Path, [string]$Signer) {
	if (-not (Test-Path -LiteralPath $Path)) {
		return $false
	}
	& $Signer verify --verbose $Path *> $null
	return $LASTEXITCODE -eq 0
}


function Export-Web {
	$editor = Find-Editor "Web" $WebEditor
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $webOutput) | Out-Null
	Write-Output "Web: $($editor.Version)"
	Write-Output "Templates: $($editor.TemplateDir)"
	# The WebGPU editor needs its real RenderingDevice; --headless selects the
	# dummy driver and cannot bake/export the WebGPU shaders.
	& $editor.Path --path $projectPath --export-release Web $webOutput
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $webOutput)) {
		throw "Web export failed."
	}
	Write-Output "Web export: $webOutput"
}


function Export-Apk {
	$editor = Find-Editor "APK" $AndroidEditor
	$signer = Get-ApkSigner
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $apkOutput) | Out-Null

	$installedBuildVersion = Join-Path $projectPath "android\.build_version"
	if (Test-Path -LiteralPath $installedBuildVersion) {
		$buildTag = (Get-Content -LiteralPath $installedBuildVersion -Raw).Trim()
		if ($buildTag -ne $editor.TemplateTag) {
			throw "Project Gradle template is '$buildTag', but selected editor needs '$($editor.TemplateTag)'. Run that editor once with --install-android-build-template after preserving any custom android/ changes."
		}
	}

	Write-Output "APK: $($editor.Version)"
	Write-Output "Templates: $($editor.TemplateDir)"
	$before = if (Test-Path -LiteralPath $gradleApk) {
		(Get-Item -LiteralPath $gradleApk).LastWriteTimeUtc
	} else {
		[datetime]::MinValue
	}
	$targetBefore = if (Test-Path -LiteralPath $apkOutput) {
		(Get-Item -LiteralPath $apkOutput).LastWriteTimeUtc
	} else {
		[datetime]::MinValue
	}
	$process = Start-Process -FilePath $editor.Path `
		-ArgumentList @("--headless", "--path", $projectPath, "--export-debug", "UniversalXRAPK", $apkOutput) `
		-WorkingDirectory $projectPath -WindowStyle Hidden -PassThru
	$deadline = (Get-Date).AddMinutes(4)
	$verifiedSource = ""
	while ((Get-Date) -lt $deadline) {
		Start-Sleep -Seconds 3
		if ((Test-Path -LiteralPath $gradleApk) -and
			(Get-Item -LiteralPath $gradleApk).LastWriteTimeUtc -gt $before -and
			(Test-SignedApk $gradleApk $signer)) {
			$verifiedSource = $gradleApk
			break
		}
		if ($process.HasExited -and
			(Test-Path -LiteralPath $apkOutput) -and
			(Get-Item -LiteralPath $apkOutput).LastWriteTimeUtc -gt $targetBefore -and
			(Test-SignedApk $apkOutput $signer)) {
			$verifiedSource = $apkOutput
			break
		}
		if ($process.HasExited) {
			break
		}
	}
	if (-not $process.HasExited) {
		Stop-Process -Id $process.Id
		$process.WaitForExit()
	}
	if (-not $verifiedSource) {
		throw "APK export did not produce a signed artifact."
	}
	if ($verifiedSource -ne $apkOutput) {
		Copy-Item -LiteralPath $verifiedSource -Destination $apkOutput -Force
	}

	$validator = Join-Path $projectPath "addons\godot_universal_xr_apk\tools\validate_universal_xr_apk.ps1"
	& $validator -Apk $apkOutput
	if ($LASTEXITCODE -ne 0) {
		throw "Universal APK validation failed."
	}
	Write-Output "APK export: $apkOutput"
}


if ($Target -in @("Web", "All")) {
	Export-Web
}
if ($Target -in @("APK", "All")) {
	Export-Apk
}
