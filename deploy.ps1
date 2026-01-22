# deploy.ps1 - Carga .env y ejecuta el deploy del bridge
# Uso: .\deploy.ps1
# La wallet TECNICO_KEY debe tener ETH en Base Sepolia

$ErrorActionPreference = "Stop"

$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
    Write-Error "No se encuentra .env en la raiz del proyecto. Crea .env con TECNICO_KEY=0x..."
}

# Cargar .env en la sesión de PowerShell
Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $idx = $line.IndexOf("=")
        if ($idx -gt 0) {
            $key = $line.Substring(0, $idx).Trim()
            $val = $line.Substring($idx + 1).Trim()
            if ($val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Trim('"') }
            if ($val.StartsWith("'") -and $val.EndsWith("'")) { $val = $val.Trim("'") }
            [Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
    }
}

if (-not $env:TECNICO_KEY) {
    Write-Error "TECNICO_KEY no está definida en .env. Añade: TECNICO_KEY=0x..."
}

Write-Host "Desplegando en Base Sepolia..." -ForegroundColor Cyan
forge script script/Deploy.s.sol:QubicDeployScript `
    --rpc-url "https://sepolia.base.org" `
    --broadcast `
    --private-key $env:TECNICO_KEY
