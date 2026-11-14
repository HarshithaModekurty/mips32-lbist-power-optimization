param([string]$Ghdl = 'ghdl')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force $build | Out-Null
Push-Location $build
try {
  function Invoke-Ghdl([string[]]$Arguments) {
    & $Ghdl @Arguments
    if ($LASTEXITCODE -ne 0) { throw "GHDL failed: $Arguments" }
  }
  foreach ($source in @('rtl/mips32_scan_pkg.vhd','rtl/scan_register_bank.vhd','rtl/mips32_core.vhd','tb/tb_scan_register_bank.vhd','tb/tb_mips32_core.vhd')) {
    Invoke-Ghdl @('-a','--std=08',(Join-Path $root $source))
  }
  Invoke-Ghdl @('-e','--std=08','tb_mips32_core')
  Invoke-Ghdl @('-r','--std=08','tb_mips32_core','--assert-level=error','--wave=core.ghw')
  Invoke-Ghdl @('-e','--std=08','tb_scan_register_bank')
  foreach ($chains in @(1,2,3,4,8,16,32)) {
    Invoke-Ghdl @('-r','--std=08','tb_scan_register_bank',"-gCHAINS=$chains",'--assert-level=error')
  }
  Invoke-Ghdl @('-r','--std=08','tb_scan_register_bank','-gBITS=17','-gCHAINS=3','--assert-level=error')
  Invoke-Ghdl @('-r','--std=08','tb_scan_register_bank','-gBITS=1','-gCHAINS=1','--assert-level=error')
  & $Ghdl --synth --std=08 mips32_core | Out-File -Encoding utf8 (Join-Path $build 'mips32_core_synth.vhd')
  if ($LASTEXITCODE -ne 0) { throw 'GHDL synthesis failed' }
  Write-Output 'PASS GHDL synthesis elaboration (default four-chain core)'
} finally { Pop-Location }
