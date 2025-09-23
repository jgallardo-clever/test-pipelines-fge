##########################################################################
# Configurar documento por defecto en IIS
##########################################################################

param (
    [string]$siteName,
    [string]$defaultDocument,

    [string]$ipServer,
    [string]$sshUser
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $defaultDocument) {
    Write-Error "ipServer, sshUser, siteName, and defaultDocument must be specified."
    return
}

##########################################################################
# Script remoto para crear el Application Pool
##########################################################################

# Cargamos el script remoto que se ejecutará en el servidor IIS
$remoteScript = @"
try {
    Add-WebConfigurationProperty -Filter 'system.webServer/defaultDocument/files' -PSPath 'IIS:\Sites\$siteName' -AtIndex 0 -Name 'Collection' -Value '$defaultDocument'
    Write-Host "Documento por defecto configurado satisfactoriamente: $defaultDocument"
} catch {
    Write-Error "Error al configurar el documento por defecto: `$_"
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