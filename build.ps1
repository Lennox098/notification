# build.ps1 - Script para empaquetar Lambdas y aplicar Terraform automáticamente

Write-Host "=== Iniciando empaquetado de Lambdas ===" -ForegroundColor Cyan

# Definir rutas
$root = Get-Location
$terraformPath = "$root\terraform"

$lambdas = @(
    @{ Name = "send-notifications"; Path = "$root\lambda\send-notifications"; Zip = "$terraformPath\send-notifications.zip" },
    @{ Name = "send-notifications-error"; Path = "$root\lambda\send-notifications-error"; Zip = "$terraformPath\send-notifications-error.zip" }
)

foreach ($lambda in $lambdas) {
    Write-Host "Empaquetando $($lambda.Name)..." -ForegroundColor Yellow

    # Ir a la carpeta de la lambda
    Set-Location $lambda.Path

    # Instalar dependencias (solo producción)
    if (Test-Path "package.json") {
        npm install --production
    }

    # Eliminar .zip anterior si existe
    if (Test-Path $lambda.Zip) {
        Remove-Item $lambda.Zip
    }

    # Crear el zip
    Compress-Archive -Path * -DestinationPath $lambda.Zip -Force

    Write-Host "Lambda $($lambda.Name) empaquetada en $($lambda.Zip)" -ForegroundColor Green
}

# Regresar a terraform
Set-Location $terraformPath

Write-Host "=== Ejecutando Terraform ===" -ForegroundColor Cyan

terraform init
terraform apply -auto-approve

Write-Host "=== Despliegue completado exitosamente ===" -ForegroundColor Green
