#Requires -Version 5.1
<#
.SYNOPSIS
  Menu-driven Pump CLI using charmbracelet/gum, or direct commands.

.DESCRIPTION
  Install gum: winget install charmbracelet.gum
  https://github.com/charmbracelet/gum

.EXAMPLE
  .\scripts\pump-cli.ps1
  .\scripts\pump-cli.ps1 deploy
  .\scripts\pump-cli.ps1 launch -Name "My Coin" -Symbol MCOIN -BuyEth 0.01
  .\scripts\pump-cli.ps1 list
  .\scripts\pump-cli.ps1 sell -Token 0x... -AmountWei 1000000000000000000
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet("menu", "deploy", "launch", "list", "sell", "help")]
  [string]$Command = "menu",

  [string]$Name,
  [string]$Symbol,
  [string]$BuyEth = "0",
  [string]$Token,
  [string]$AmountWei,
  [string]$Network = "leo"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

# Gum prompts used to hard-code .env.example-like defaults and set $env:* before Node, so dotenv would not override them.
function Get-DotEnvVar {
  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [Parameter(Mandatory = $true)][string]$ProjectRoot
  )
  $path = Join-Path $ProjectRoot ".env"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  foreach ($line in Get-Content -LiteralPath $path) {
    $t = $line.Trim()
    if ($t.Length -eq 0 -or $t.StartsWith("#")) { continue }
    $eq = $t.IndexOf("=")
    if ($eq -lt 1) { continue }
    $k = $t.Substring(0, $eq).Trim()
    if ($k -ne $Key) { continue }
    $v = $t.Substring($eq + 1).Trim()
    if ($v.Length -ge 2) {
      $fc = $v[0]
      $lc = $v[$v.Length - 1]
      if (($fc -eq '"' -and $lc -eq '"') -or ($fc -eq "'" -and $lc -eq "'")) {
        $v = $v.Substring(1, $v.Length - 2)
      }
    }
    return $v
  }
  return $null
}

function Get-LaunchDefault {
  param(
    [string]$ProcessEnvName,
    [string]$DotEnvKey,
    [string]$ProjectRoot,
    [string]$Fallback
  )
  $fromShell = [Environment]::GetEnvironmentVariable($ProcessEnvName, "Process")
  if ($fromShell -and $fromShell.Trim()) { return $fromShell.Trim() }
  $fromFile = Get-DotEnvVar -Key $DotEnvKey -ProjectRoot $ProjectRoot
  if ($fromFile -and $fromFile.Trim()) { return $fromFile.Trim() }
  return $Fallback
}

# 4-char ticker from name (ASCII letters/digits only). No npm lib needed for the CLI walkthrough.
function Get-SymbolFromName {
  param([string]$Name)
  $chars = [System.Text.RegularExpressions.Regex]::Matches($Name, '[A-Za-z0-9]').Value
  $alnum = ($chars -join '').ToUpperInvariant()
  if ($alnum.Length -eq 0) { return "TKN0" }
  if ($alnum.Length -ge 4) { return $alnum.Substring(0, 4) }
  return ($alnum + ("X" * (4 - $alnum.Length))).Substring(0, 4)
}

function Test-Gum {
  return [bool](Get-Command gum -ErrorAction SilentlyContinue)
}

function Assert-Gum {
  if (-not (Test-Gum)) {
    Write-Host "Install gum: winget install charmbracelet.gum" -ForegroundColor Red
    Write-Host "https://github.com/charmbracelet/gum" -ForegroundColor Yellow
    exit 1
  }
}

function Invoke-Hardhat([string]$RelScript, [string[]]$PassToScript) {
  $runner = Join-Path $Root "scripts\run-hardhat.cjs"
  Push-Location $Root
  try {
    if ($PassToScript -and $PassToScript.Count -gt 0) {
      & node $runner run $RelScript --network $Network -- @PassToScript
    }
    else {
      & node $runner run $RelScript --network $Network
    }
  }
  finally {
    Pop-Location
  }
}

function Invoke-TokenListGum {
  $runner = Join-Path $Root "scripts\run-hardhat.cjs"
  $tmpCsv = [System.IO.Path]::GetTempFileName()
  $env:PUMP_LIST_FORMAT = "csv"
  try {
    Push-Location $Root
    # Start-Process -ArgumentList does not quote paths with spaces — breaks under "...\Code Workspaces\...".
    # Use ProcessStartInfo.Arguments with a quoted script path (same rules as cmd.exe).
    $nodeExe = (Get-Command node -ErrorAction Stop).Source
    $netArg = if ($Network -match '\s') { "`"$Network`"" } else { $Network }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $nodeExe
    $psi.Arguments = "`"$runner`" run scripts/listTokens.ts --network $netArg"
    $psi.WorkingDirectory = $Root
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    try {
      $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
      $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    }
    catch { }

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($stderr -and $stderr.Trim()) {
      Write-Host $stderr.TrimEnd()
    }
    if ($p.ExitCode -ne 0) {
      exit $p.ExitCode
    }

    $trim = if ($stdout) { $stdout.Trim() } else { "" }
    if ($trim -eq "" -or $trim -eq "token,name,symbol,creator") {
      gum style --foreground 240 "No TokenLaunched events for this factory."
      return
    }

    $utf8 = New-Object System.Text.UTF8Encoding $false
    $normalized = ($trim -replace "`r`n", "`n").TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($tmpCsv, $normalized, $utf8)

    # Without --print, gum table is an interactive row picker ("1/2 navigate…") and often looks empty in some terminals.
    $gumExe = (Get-Command gum -ErrorAction Stop).Source
    $gPsi = New-Object System.Diagnostics.ProcessStartInfo
    $gPsi.FileName = $gumExe
    $gPsi.Arguments = "table --print --border rounded -f `"$tmpCsv`""
    $gPsi.UseShellExecute = $false
    $gPsi.CreateNoWindow = $false
    $gProc = New-Object System.Diagnostics.Process
    $gProc.StartInfo = $gPsi
    [void]$gProc.Start()
    $gProc.WaitForExit()
    if ($gProc.ExitCode -ne 0) {
      $gPsi.Arguments = "table --print -f `"$tmpCsv`""
      $gProc2 = New-Object System.Diagnostics.Process
      $gProc2.StartInfo = $gPsi
      [void]$gProc2.Start()
      $gProc2.WaitForExit()
      if ($gProc2.ExitCode -ne 0) {
        Write-Host "gum table failed; raw CSV:" -ForegroundColor Yellow
        Write-Host $trim
      }
    }
  }
  finally {
    Remove-Item Env:PUMP_LIST_FORMAT -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpCsv -ErrorAction SilentlyContinue
    Pop-Location
  }
}

function Show-Help {
  @"
pump-cli.ps1 [command] [options]

  (no args)     Interactive gum menu (default)
  deploy        Deploy factory (+ mock router if UNISWAP_V2_ROUTER unset)
  launch        Launch token; use -Name -Symbol -BuyEth or gum prompts in menu
  list          List tokens (TokenLaunched events)
  sell          Sell to curve; -Token -AmountWei

  -Network leo  (default)  Override Hardhat network name

CLI examples (no menu):
  .\scripts\pump-cli.ps1 launch -Name "Meme" -Symbol MEME -BuyEth 0
  node scripts/run-hardhat.cjs run scripts/launchToken.ts --network leo -- --name Meme --symbol MEME --buy 0.01

Requires PRIVATE_KEY in .env under project root.
"@ | Write-Host
}

if ($Command -eq "help") {
  Show-Help
  exit 0
}

if ($Command -eq "deploy") {
  Invoke-Hardhat "scripts/deployLeo.ts"
  exit $LASTEXITCODE
}

if ($Command -eq "launch") {
  $prompted = $false
  if (-not $Name) {
    Assert-Gum
    $defName = Get-LaunchDefault -ProcessEnvName "TOKEN_NAME" -DotEnvKey "TOKEN_NAME" -ProjectRoot $Root -Fallback "My Meme"
    $Name = gum input --placeholder "Token name" --value $defName
    $prompted = $true
  }
  if (-not $Symbol) {
    $symGuess = Get-SymbolFromName $Name
    if ($prompted) {
      $Symbol = gum input --placeholder "Symbol (4 chars; generated from name)" --value $symGuess
    }
    else {
      $Symbol = $symGuess
    }
  }
  if ($prompted) {
    $defBuy = Get-LaunchDefault -ProcessEnvName "INITIAL_BUY_ETH" -DotEnvKey "INITIAL_BUY_ETH" -ProjectRoot $Root -Fallback "0"
    $BuyEth = gum input --placeholder "First buy: ETH as decimal (0=none, 0.01=small). NOT wei" --value $defBuy
  }
  elseif (-not $PSBoundParameters.ContainsKey("BuyEth")) {
    $fromEnv = Get-LaunchDefault -ProcessEnvName "INITIAL_BUY_ETH" -DotEnvKey "INITIAL_BUY_ETH" -ProjectRoot $Root -Fallback "0"
    $BuyEth = $fromEnv
  }
  $env:TOKEN_NAME = $Name
  $env:TOKEN_SYMBOL = $Symbol
  $env:INITIAL_BUY_ETH = $BuyEth
  try {
    Invoke-Hardhat "scripts/launchToken.ts"
  }
  finally {
    Remove-Item Env:TOKEN_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:TOKEN_SYMBOL -ErrorAction SilentlyContinue
    Remove-Item Env:INITIAL_BUY_ETH -ErrorAction SilentlyContinue
  }
  exit $LASTEXITCODE
}

if ($Command -eq "list") {
  if (Test-Gum) {
    Invoke-TokenListGum
  }
  else {
    Invoke-Hardhat "scripts/listTokens.ts"
  }
  exit $LASTEXITCODE
}

if ($Command -eq "sell") {
  if (-not $Token -or -not $AmountWei) {
    Assert-Gum
    if (-not $Token) { $Token = gum input --placeholder "PumpToken address (0x...)" }
    if (-not $AmountWei) { $AmountWei = gum input --placeholder "Amount (wei, 18 decimals)" --value "1000000000000000000" }
  }
  Invoke-Hardhat "scripts/sellToken.ts" @("--token", $Token, "--amount", $AmountWei)
  exit $LASTEXITCODE
}

# --- menu mode ---
Assert-Gum

while ($true) {
  gum style --foreground 212 --border double --padding "0 2" --margin "1" "Pump CLI ($Network)"
  $sel = gum choose --header "Choose an action" `
    "Deploy factory" `
    "Launch token" `
    "List tokens" `
    "Sell tokens" `
    "Help" `
    "Exit"

  switch ($sel) {
    "Deploy factory" {
      Invoke-Hardhat "scripts/deployLeo.ts"
    }
    "Launch token" {
      $defName = Get-LaunchDefault -ProcessEnvName "TOKEN_NAME" -DotEnvKey "TOKEN_NAME" -ProjectRoot $Root -Fallback "My Meme"
      $defBuy = Get-LaunchDefault -ProcessEnvName "INITIAL_BUY_ETH" -DotEnvKey "INITIAL_BUY_ETH" -ProjectRoot $Root -Fallback "0"
      $n = gum input --placeholder "Token name" --value $defName
      $s = gum input --placeholder "Symbol (4 chars; from name)" --value (Get-SymbolFromName $n)
      $b = gum input --placeholder "First buy: ETH decimal (0=none). Not wei" --value $defBuy
      $env:TOKEN_NAME = $n
      $env:TOKEN_SYMBOL = $s
      $env:INITIAL_BUY_ETH = $b
      try {
        Invoke-Hardhat "scripts/launchToken.ts"
      }
      finally {
        Remove-Item Env:TOKEN_NAME -ErrorAction SilentlyContinue
        Remove-Item Env:TOKEN_SYMBOL -ErrorAction SilentlyContinue
        Remove-Item Env:INITIAL_BUY_ETH -ErrorAction SilentlyContinue
      }
    }
    "List tokens" {
      Invoke-TokenListGum
    }
    "Sell tokens" {
      $tok = gum input --placeholder "PumpToken address (0x...)"
      $amt = gum input --placeholder "Amount (wei)" --value "1000000000000000000"
      Invoke-Hardhat "scripts/sellToken.ts" @("--token", $tok, "--amount", $amt)
    }
    "Help" { Show-Help }
    "Exit" { break }
    default { break }
  }

  if ($sel -ne "Exit") {
    gum confirm "Back to menu?"
    if ($LASTEXITCODE -ne 0) { break }
  }
}
