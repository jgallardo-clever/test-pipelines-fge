##########################################################################
# Configuración de un proxy inverso para un sitio en IIS usando PowerShell
# Este script configura un proxy inverso para un sitio IIS existente,
# redirigiendo las solicitudes a una URL de destino especificada.
##########################################################################

param (
    # Parámetros del Application Pool
    [string]$siteName,  # Nombre del sitio IIS al que se le aplicará el proxy inverso
    [string]$targetUrl, # URL de destino al que se redirigirán las solicitudes (Debe incluir el esquema, por ejemplo, http:// o https://)

    # Parámetros de conexión al servidor IIS
    [string]$ipServer,  # Dirección IP del servidor IIS
    [string]$sshUser    # Usuario SSH para conectarse al servidor remoto
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $targetUrl) {
    echo "ipServer, sshUser, siteName, and targetUrl must be specified."
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
    echo "Error al importar el módulo WebAdministration. Asegúrese de que IIS esté instalado y el módulo esté disponible."
    return
}

echo "Configurando el proxy inverso para el sitio: '$siteName' hacia el objetivo: '$targetUrl'"

echo "Activamos la funcionalidad de proxy en IIS (Esto sirve para garantizar que ARR esté habilitado)"
try {
    Set-WebConfigurationProperty -Filter "system.webServer/proxy" -Name "enabled" -Value `$true -PSPath "IIS:\"
    echo "Se habilitó la funcionalidad de proxy"
} catch {
    echo "No se pudo habilitar la funcionalidad de proxy. Asegúrese de que el módulo Application Request Routing (ARR) esté instalado."
}

echo "Aseguramos que la sección de rewrite exista en el sitio especificado"
`$sitePath = "IIS:\Sites\$siteName"
echo "Site Path: `$sitePath"

echo "Eliminar cualquier regla existente con el mismo nombre para evitar conflictos"
try {
    Remove-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath `$sitePath -Name "." -AtElement @{name="ReverseProxyRule"} -ErrorAction SilentlyContinue
    echo "Se eliminó la regla existente con el nombre: ReverseProxyRule"
} catch {
    echo "No se encontró ninguna regla existente o se produjo un error al eliminarla."
}

echo "Añadimos la nueva regla de rewrite"
try {
    Add-WebConfigurationProperty -Filter "system.webServer/rewrite/rules" -PSPath `$sitePath -Name "." -Value @{
        name = "ReverseProxyRule"
        stopProcessing = `$true
        match = @{
            url = "(.*)"
        }
        conditions = @{
            logicalGrouping = "MatchAll"
            trackAllCaptures = `$false
        }
        action = @{
            type = "Rewrite"
            url = "$targetUrl/{R:1}"
        }
    }
    echo "Regla de proxy inverso creado satisfactoriamente: ReverseProxyRule"
    echo "Todas las solicitudes a $siteName serán redirigidas a $targetUrl"
} catch {
    echo "Error al crear la regla de proxy inverso: `$_"
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