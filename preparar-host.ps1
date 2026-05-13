# Executar como Administrador
$ErrorActionPreference = "Stop"

function Instalar-Se-Nao-Existir($Nome, $Id) {
    if (winget list --id $Id --source winget) {
        Write-Host "[OK] $Nome já instalado." -ForegroundColor Green
    } else {
        Write-Host "[INSTALANDO] $Nome..." -ForegroundColor Cyan
        winget install --id $Id --source winget --accept-package-agreements --accept-source-agreements
    }
}

Write-Host "--- Verificando Ambiente para Deep-Live-Cam ---" -ForegroundColor Yellow

# 1. Git
Instalar-Se-Nao-Existir "Git" "Git.Git"

# 2. Docker Desktop
Instalar-Se-Nao-Existir "Docker Desktop" "Docker.DockerDesktop"

# 3. WSL2 (Base para o Docker)
if (!(wsl --status 2>$null)) {
    Write-Host "[WSL] Instalando WSL2... O PC precisará reiniciar depois." -ForegroundColor Cyan
    wsl --install
}

# 4. Drivers NVIDIA (Opcional verificar via comando)
if (nvidia-smi) {
    Write-Host "[OK] GPU NVIDIA detectada." -ForegroundColor Green
} else {
    Write-Host "[AVISO] GPU NVIDIA não detectada ou driver ausente. O servidor rodará em CPU (lento)." -ForegroundColor Red
}

Write-Host "`n--- Ambiente Pronto! Reinicie se instalou o Docker agora. ---" -ForegroundColor Magenta