################################################################
# Script para crear una web application de un sitio de IIS
################################################################

param(
    [string]$siteName,
    [string]$appName,
    [string]$physicalPath,
    [string]$applicationPool,

    # Parámetros de conexión al servidor IIS
    [string]$ipServer,                  # Dirección IP del servidor IIS
    [string]$sshUser                    # Usuario SSH para conectarse al servidor remoto
)

##########################################################################
# Validación de parámetros
##########################################################################

# Si no se especifica ipServer ni sshUser, se cancela la ejecución
if (-not $ipServer -or -not $sshUser -or -not $siteName -or -not $appName -or -not $physicalPath -or -not $applicationPool) {
    echo "ipServer, sshUser, siteName, appName, physicalPath, y applicationPool deben ser especificados."
    return
}

##########################################################################
# Script remoto para crear el Application Pool
##########################################################################

# Cargamos el script remoto que se ejecutará en el servidor IIS
$remoteScript = @"
echo "Dar acceso a IIS_IUSRS al directorio de la aplicación..."
try {
    icacls '$physicalPath' /grant 'IIS_IUSRS:(OI)(CI)M'
} catch {
    echo "Error al establecer permisos en $physicalPath. Asegúrese de que la ruta exista y sea accesible."
    return
}

Import-Module WebAdministration

echo "Verificar si el sitio existe..."
if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
    echo "El sitio '$siteName' no existe."
    exit
}
echo "Verificar si la aplicación ya existe..."
if (Get-WebApplication -Site $siteName | findstr '$appName') {
    echo "La aplicación '$appName' ya existe en el sitio '$siteName'."
    exit
}

echo "Crear la aplicación..."
try {
  New-WebApplication -Site $siteName -Name $appName -PhysicalPath '$physicalPath' -ApplicationPool $applicationPool
  echo "Aplicación '$appName' creada en el sitio '$siteName' con éxito."
}
catch {
  echo "Error al crear la aplicación '$appName' en el sitio '$siteName'."
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