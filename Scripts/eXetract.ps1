<#
  .SYNOPSIS
  Extracts `.exe` files using 7-Zip.
    
  .DESCRIPTION
  This script searches a source folder for `.exe` files,
  treats each `.exe` as an archive and extracts its contents
  into a separate subfolder with the same name in the target directory.
    
  .REQUIRES
  `7z.exe`, the ommand line version of 7-Zip (https://www.7-zip.org/).
    
  .NOTES
  Version:          1.0
  Author:           ~ mimic ~
  Creation Date:    26 okt 2025
#>

# --- 1. KONFIGURATION (Bitte anpassen) ---

# Pfad zur 7-Zip Kommandozeile (7z.exe)
# Standardpfade sind hier einkommentiert.
$PathTo7zip = "C:\Program Files\7-Zip\7z.exe"
# $PathTo7zip = "C:\Program Files (x86)\7-Zip\7z.exe"

# Quellordner (wo die .exe-Dateien von Lenovo liegen)
$SourceFolder = "C:\temp\Lenovo-Treiber" # <--- ANPASSEN

# Zielordner (wo die entpackten Treiber-Ordner erstellt werden sollen)
$OutputBase = "C:\temp\Extracted-Drivers" # <--- ANPASSEN


# --- 2. SKRIPT-LOGIK (Keine Änderungen nötig) ---

# Prüfen, ob 7z.exe existiert
if (-not (Test-Path $PathTo7zip)) {
    Write-Warning "7-Zip (7z.exe) wurde nicht unter '$PathTo7zip' gefunden."
    Write-Warning "Bitte 7-Zip installieren (https://www.7-zip.org/) und den Pfad im Skript anpassen."
    # Das Skript wird hier absichtlich nicht gestoppt, falls 7z im PATH liegt.
}

# Sicherstellen, dass der Basis-Zielordner existiert
if (-not (Test-Path $OutputBase)) {
    Write-Host "Erstelle Zielordner: $OutputBase" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputBase | Out-Null
}

# Alle .exe-Dateien im Quellordner holen
$driverFiles = Get-ChildItem -Path $SourceFolder -Filter "*.exe"

if ($driverFiles.Count -eq 0) {
    Write-Warning "Keine .exe-Dateien im Quellordner '$SourceFolder' gefunden."
    return
}

Write-Host "Starte Batch-Extraktion für $($driverFiles.Count) Treiber..." -ForegroundColor Green

foreach ($file in $driverFiles) {
    Write-Host "---"
    Write-Host "Verarbeite: $($file.Name)"
    
    # Der Zielordner wird nach der .exe-Datei benannt (ohne .exe)
    $destFolder = Join-Path $OutputBase -ChildPath $file.BaseName
    
    # Erstelle den Ordner (ignoriert Fehler, falls er schon existiert)
    New-Item -ItemType Directory -Path $destFolder -ErrorAction SilentlyContinue | Out-Null
    
    # 7-Zip Argumente:
    # 'x' = Extrahiere mit vollen Pfaden (erhält die Ordnerstruktur im Archiv)
    # '-y' = Ja zu allen Abfragen (z.B. Überschreiben)
    # '-o' = Output-Ordner (Syntax: -o"Pfad" OHNE Leerzeichen dazwischen)
    $arguments = @(
        "x",                 # Extrahiere mit vollen Pfaden
        $file.FullName,      # Quelldatei
        "-o$destFolder",     # Zielordner (Syntax: -oKEINLEERZEICHENpfad)
        "-y"                 # Ja zu allen Abfragen
    )
    
    # Führe 7-Zip aus und warte, bis es fertig ist (kein neues Fenster, keine Shell-Ausgabe)
    try {
        Start-Process -FilePath $PathTo7zip -ArgumentList $arguments -Wait -NoNewWindow -WindowStyle Hidden
        Write-Host "Erfolgreich extrahiert -> $destFolder" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Fehler beim Extrahieren von $($file.Name): $_"
    }
}

Write-Host "---"
Write-Host "Batch-Extraktion abgeschlossen." -ForegroundColor Green
