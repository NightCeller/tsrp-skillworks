param(
    [Parameter(Mandatory=$true)][string]$CompilerDir,
    [Parameter(Mandatory=$true)][string]$IncludeDir
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$compilerHome = (Resolve-Path $CompilerDir).Path
$includes = (Resolve-Path $IncludeDir).Path
$compiler = Join-Path $compilerHome 'amxxpc.exe'
if (!(Test-Path $compiler)) { throw "amxxpc.exe missing from CompilerDir" }
foreach ($header in @('amxmodx.inc','ApolloRP.inc','ApolloRP_Chat.inc','tsfun.inc','hamsandwich.inc')) {
    if (!(Test-Path (Join-Path $includes $header))) { throw "Required include missing: $header" }
}
$projectIncludes = Join-Path $repo 'addons/amxmodx/scripting/include'
$output = Join-Path $repo 'build/plugins'
New-Item -ItemType Directory -Force $output | Out-Null
$names = @('Skills','Cooking','Computers','Weapons','General','Drugs','Fighting','Law')
Push-Location $compilerHome
try {
    foreach ($name in $names) {
        $source = Join-Path $repo "addons/amxmodx/scripting/ARP_$name.sma"
        $target = Join-Path $output "ARP_$name.amxx"
        if (Test-Path $target) { Remove-Item $target }
        & $compiler $source "-i$projectIncludes" "-i$includes" "-o$target"
        if ($LASTEXITCODE -ne 0 -or !(Test-Path $target)) { throw "Compilation failed: ARP_$name" }
        if ((Get-Item $target).Length -eq 0) { throw "Empty compiled output: ARP_$name" }
    }
} finally { Pop-Location }
Write-Host "Compiled all eight plugins to $output. Nothing installed or published."
