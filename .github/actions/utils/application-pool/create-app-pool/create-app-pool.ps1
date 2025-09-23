##########################################################################
# Crear Application Pool en IIS
# (Los parámetros avanzados del Application Pool deben ser
# configurados con otro script)
##########################################################################

param (
    # Parámetros del Application Pool
    [string]$appPoolName,                           # Nombre del Application Pool
    [string]$managedRuntimeVersion = "",            # Versión de .NET a utilizar
    [string]$managedPipelineMode = "Integrated",    # Modo de pipeline (Integrated o Classic)

    # Parámetros de conexión al servidor IIS
    [string]$ipServer,                              # Dirección IP del servidor IIS
    [string]$sshUser                                # Usuario SSH para conectarse al servidor remoto
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $appPoolName) {
    Write-Error "ipServer, sshUser, y appPoolName deben ser especificados."
    return
}

##########################################################################
# Script remoto para crear el Application Pool
##########################################################################

# Cargamos el script remoto que se ejecutará en el servidor IIS
$remoteScript = @"
echo "Importamos el módulo WebAdministration para gestionar IIS"
try {
    Import-Module WebAdministration
}
catch {
    echo "Error al importar el módulo WebAdministration."
    return
}

echo "Verificar si el Application Pool ya existe..."
try {
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    echo "El Application Pool $appPoolName ya existe."
    echo "Seteando configuración del Application Pool existente..."
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value '$managedRuntimeVersion'
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value '$managedPipelineMode'
    echo "Se configuró el Application Pool $appPoolName con la versión de .NET $managedRuntimeVersion y el modo de canalización $managedPipelineMode."
    return
}
catch {
    echo "No se pudo encontrar el Application Pool $appPoolName."
}

echo "Crear el Application Pool..."
try {
    New-WebAppPool -Name $appPoolName | Out-Null
    echo "Se creó el Application Pool: $appPoolName"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value '$managedRuntimeVersion'
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedPipelineMode" -Value '$managedPipelineMode'
    echo "Se configuró el Application Pool $appPoolName con la versión de .NET $managedRuntimeVersion y el modo de canalización $managedPipelineMode."
    return
} catch {
    echo "Error al crear el Application Pool $appPoolName. Verifique los parámetros e intente nuevamente."
    echo "`$_"
    return
}
"@

##########################################################################
# Cofificación del script
##########################################################################

# Codificar en Base64 para evitar problemas con caracteres especiales
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteScript))

##########################################################################
# Ejecutar el script remoto
##########################################################################

# Ejecutar remotamente, suprimiendo streams de información para no saturar la salida
ssh $sshUser@$ipServer "powershell -EncodedCommand $encodedScript" 2>$null 6>$null