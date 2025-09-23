##########################################################################
# Creación de un sitio IIS básico de IIS usando PowerShell
# (Los parámetros avanzados del sitio deben ser configurados con otro
# script).
##########################################################################

param (
    # Parámetros del Application Pool
    [string]$siteName,                  # Nombre del sitio IIS a crear    
    [string]$appPoolName,               # Nombre del Application Pool para el sitio
    [string]$sitePath,                  # Ruta física al directorio del sitio
    [string]$ipAddress = "*",           # Dirección IP en la que escuchará el sitio
    [int]$port = 80,                    # Puerto que escuchará el sitio
    [string]$hostHeader = "localhost",  # Dominio o encabezado del sitio

    # Parámetros de conexión al servidor IIS
    [string]$ipServer,                  # Dirección IP del servidor IIS
    [string]$sshUser                    # Usuario SSH para conectarse al servidor remoto
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $appPoolName -or -not $sitePath) {
    echo "ipServer, sshUser, siteName, appPoolName, y sitePath deben ser especificados."
    return
}

##########################################################################
# Script remoto para crear el Application Pool
##########################################################################

# Cargamos el script remoto que se ejecutará en el servidor IIS
$remoteScript = @"
echo "Dar acceso a IIS_IUSRS al directorio del sitio..."
try {
    icacls '$sitePath' /grant 'IIS_IUSRS:(OI)(CI)M'
} catch {
    echo "Error al establecer permisos en $sitePath. Asegúrese de que la ruta exista y sea accesible."
    return
}

echo "Importamos el módulo WebAdministration para gestionar IIS..."
try {
    Import-Module WebAdministration
} catch {
    echo "Error al importar el módulo WebAdministration. Asegúrese de que IIS esté instalado y el módulo esté disponible."
    return
}

echo "Verificando si el Application Pool $appPoolName existe..."
try{
    Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue | Out-Null
    echo "El Application Pool $appPoolName ya existe."
} catch {
    echo "El Application Pool $appPoolName no existe."
    return
}

echo "Verificando si el sitio IIS $siteName existe..."
try {
    echo "Validando si el sitio $siteName ya existe..."
    `$exists = Get-Website -Name $siteName -ErrorAction SilentlyContinue
    echo "Resultado validacion: `$exists"
    if(`$exists -ne `$null) {
        echo "El sitio $siteName ya existe, aplicando configuración nueva."
        try {
            Set-ItemProperty "IIS:\Sites\$siteName" -Name applicationPool -Value '$appPoolName'
            Set-ItemProperty "IIS:\Sites\$siteName" -Name physicalPath -Value '$sitePath'
            Set-ItemProperty "IIS:\Sites\$siteName" -Name bindings -Value @{protocol="http";bindingInformation="$ipAddress`:$port`:$hostHeader"}
            echo "Configuración del sitio $siteName actualizada correctamente."
            return
        } catch {
            echo "Error al actualizar la configuración del sitio $siteName. Verifique los parámetros e intente nuevamente."
            echo "`$_"
            return
        }  
    }

    echo "Creamos el sitio IIS"
    try {
        New-Website -Name '$siteName' -ApplicationPool '$appPoolName' -PhysicalPath '$sitePath' -IPAddress '$ipAddress' -Port '$port' -HostHeader '$hostHeader'
        echo "Se creó el sitio: $siteName con el Application Pool: $appPoolName"
    } catch {
        echo "Error al crear el sitio $siteName. Verifique los parámetros e intente nuevamente."
        echo "`$_"
        return
    }
} catch {
    echo "Ocurrió un error: `$_"
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