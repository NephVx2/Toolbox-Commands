#Requires -Version 5.1
<#
.SYNOPSIS
    Toolbox-SystemCommands_Win11 - Lanceur graphique de commandes systeme Windows.

.DESCRIPTION
    Interface graphique (WinForms, theme sombre) permettant de lancer en un clic les commandes
    de maintenance systeme les plus courantes (SFC, DISM, CHKDSK, reseau, Windows Update),
    chacune dans sa propre fenetre de console (cmd.exe /k).

    L'application s'auto-eleve au demarrage (memes droits admin necessaires pour la plupart
    des commandes ci-dessous). Les fenetres console lancees ensuite heritent de ce niveau
    d'elevation, donc aucun re-prompt UAC par bouton.

    Une confirmation (Oui/Non) est demandee avant le lancement des commandes marquees comme
    sensibles (impact sur l'etat systeme, redemarrage necessaire, etc.).

    Chaque lancement est journalise dans :
    Desktop\Rapports_Maintenance\ToolboxCommandes\Historique.log

    Categories repliables (clic sur l'en-tete), favoris persistants (etoile), export HTML
    de l'historique disponible depuis la barre superieure.

.NOTES
    Auteur   : Nephren
    Version  : 2.2.0
    Usage    : Clic droit > Executer avec PowerShell, ou .\Toolbox-SystemCommands_Win11.ps1
               -SelfTest : execute la batterie de tests internes (integrite du catalogue de
               commandes, fonctions requises, regressions connues) sans ouvrir l'interface
               graphique ni demander l'elevation admin.

    Convention de suite : ce script suit les memes conventions que le reste de la suite de
    maintenance (rapports dans Desktop\Rapports_Maintenance\<Sous-dossier>, parametre
    -SelfTest). Pour la signature Authenticode, passer ce script dans
    Manage-ScriptSignatures.ps1 (CN=Nephren PowerShell Code Signing) comme les 13 autres
    scripts de la suite.

    v1.1.1 : passage a un FlowLayoutPanel pour la liste des boutons (au lieu d'un
    positionnement manuel en pixels) afin de corriger un bug d'affichage ou seul le premier
    bouton apparaissait ; la barre de recherche est aussi deplacee dans un panneau dedie
    en Dock=Top pour eviter qu'elle soit recouverte par la liste (Dock=Fill).

    v1.1.2 : fonctions Invoke-ConsoleCommand / Write-CommandLog / Update-Filter declarees en
    portee globale (les gestionnaires d'evenements WinForms ne voyaient pas les fonctions en
    portee script) ; remplacement de wmic (retire depuis Windows 11 24H2) par Get-CimInstance ;
    echappement des pipes non echappes qui etaient casses par cmd.exe.

    v1.2.0 : ajout du parametre -SelfTest (20 assertions).

    v1.3.0 : le journal (Historique.log) est enrichi avec le nom de la machine,
    l'utilisateur et la version Windows sur chaque ligne (utile pour centraliser des
    journaux issus de plusieurs machines). -SelfTest passe a 23 assertions.

    v1.4.0 : categories repliables (clic sur l'en-tete de categorie) ; favoris persistants
    (etoile a gauche de chaque commande, sauvegardes dans Favoris.txt, filtre "Favoris
    uniquement") ; export HTML de l'historique (bouton dans la barre superieure).
    Renommage de Update-Filter en Update-Visibility (gere desormais recherche + favoris +
    categories repliees). -SelfTest passe a 29 assertions.

    v1.4.1 : remplacement de "DNS configure par interface" (Get-DnsClientServerAddress, qui
    ne detecte pas l'interception WFP transparente de l'app NextDNS Desktop) par le test
    officiel NextDNS (curl.exe -L https://test.nextdns.io), qui reflete le comportement reel
    du trafic DNS plutot que la configuration declaree de l'interface.

    v1.4.2 : "DNS configure par interface" reintegree en plus du test NextDNS (les deux sont
    complementaires : la premiere reste utile en diagnostic generique sur une machine sans
    NextDNS ou avec un autre resolveur).

    v1.4.3 : correction de "Top processus RAM" - un $_ non echappe dans la chaine de commande
    etait interpole par notre propre script au moment de la construction du catalogue (au lieu
    d'etre transmis a la commande enfant), cassant la syntaxe PowerShell resultante. Ajout
    d'une assertion -SelfTest de regression scannant le code source du catalogue pour
    detecter toute future interpolation dollar-underscore non echappee. -SelfTest passe a
    30 assertions.

    v1.4.4 : correction de "Peripheriques en erreur" - Get-PnpDevice -Status Error leve une
    erreur bloquante (ObjectNotFound) quand aucun peripherique ne correspond, au lieu de
    retourner un resultat vide. Remplace par un filtrage Where-Object apres coup, avec un
    message clair si aucun peripherique n'est en erreur.

    v2.0.0 : refonte architecturale majeure.
    - Catalogue de commandes extrait dans Commands.psd1 (fichier de donnees externe, doit
      rester a cote du script). Le champ Cmd y est desormais TOUJOURS en guillemets simples,
      ce qui elimine structurellement toute la classe de bugs d'interpolation ($_, $err, etc.)
      rencontree en v1.4.3/v1.4.4 : plus besoin d'echappement au cas par cas.
    - Chargement via Import-PowerShellDataFile, avec gestion d'erreur (message clair si le
      fichier est absent ou invalide, plutot qu'un plantage).
    - Export JSON de l'historique (bouton "Export JSON"), en plus de l'export HTML existant.
      Les deux partagent desormais une fonction commune Get-HistoryEntries (parsing du log).
    - -SelfTest passe a 34 assertions (verification de la presence et du bon chargement de
      Commands.psd1, absence de Cmd en guillemets doubles dans le catalogue externe,
      fonctions Get-HistoryEntries/Export-HistoryJson definies).

    v2.1.0 : capture de $global:winInfo corrigee (Win32_OperatingSystem.Caption + registre
    DisplayVersion/UBR plutot que ProductName - bug Microsoft connu et jamais corrige, cette
    cle de registre reste figee sur "Windows 10 [Edition]" meme sur une installation Windows
    11 a jour). Journalisation du PID du processus lance (Start-Process -PassThru) dans
    Historique.log et les deux exports (HTML/JSON) ; Get-HistoryEntries reste compatible avec
    les lignes de log ecrites avant ce changement (segment PID=... optionnel dans la regex de
    parsing). Raccourci Ctrl+F pour focus direct sur la recherche. Clic droit sur une commande
    -> "Copier la commande" (presse-papiers). Nouvelle assertion de regression detectant tout
    guillemet double dans le contenu d'un champ Cmd, meme correctement encadre de guillemets
    simples (cf. bug "Latence disque en temps reel" du 01/08/2026, HRESULT 0x80041017 :
    guillemets doubles mal geres par cmd.exe une fois empaquetes dans le /k title ... && de
    Invoke-ConsoleCommand). -SelfTest passe a 36 assertions.

    v2.2.0 : nouveau bouton d'aide optionnel ("?") sur chaque commande, alimente par un
    nouveau champ Help (facultatif) dans Commands.psd1. Reserve visuellement sur TOUTES les
    lignes pour garder un alignement constant, mais actif (cyan, cliquable, ouvre une
    MessageBox avec le texte d'explication) uniquement si la commande possede ce champ ;
    grise et desactive sinon. Bouton principal reduit de 366 a 334px pour faire la place.
    Premiere commande equipee : "Etat virtualisation materielle (Hyperviseur / VBS)"
    (explication detaillee de Credential Guard / HVCI / System Guard / SMM Firmware
    Measurement). -SelfTest passe a 37 assertions.
#>

param(
    [switch]$SelfTest
)

# ============================================================
# REGION: AUTO-ELEVATION
# ============================================================
if (-not $SelfTest) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
        )
        exit
    }
}
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# Journalisation - Desktop\Rapports_Maintenance\ToolboxCommandes\Historique.log
# ------------------------------------------------------------
$global:logDir = Join-Path $env:USERPROFILE "Desktop\Rapports_Maintenance\ToolboxCommandes"
if (-not (Test-Path $global:logDir)) {
    New-Item -Path $global:logDir -ItemType Directory -Force | Out-Null
}
$global:logFile = Join-Path $global:logDir "Historique.log"

# Contexte machine, capture unique au demarrage (evite de re-interroger le registre a chaque commande)
$global:machineName = $env:COMPUTERNAME
$global:userName    = $env:USERNAME
try {
    # ProductName (registre) reste fige sur "Windows 10 [Edition]" meme sur Windows 11 a jour :
    # bug Microsoft connu et jamais corrige (confirme sur learn.microsoft.com). Caption de
    # Win32_OperatingSystem, elle, est fiable ; DisplayVersion (registre) l'est aussi.
    $winReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $osCaption = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
    $global:winInfo = "$osCaption $($winReg.DisplayVersion)".Trim()
} catch {
    $global:winInfo = "Windows (version inconnue)"
}

# ------------------------------------------------------------
# Favoris - persistes dans Desktop\Rapports_Maintenance\ToolboxCommandes\Favoris.txt
# ------------------------------------------------------------
$global:favFile = Join-Path $global:logDir "Favoris.txt"
$global:favorites = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
if (Test-Path $global:favFile) {
    foreach ($favLine in (Get-Content -Path $global:favFile -Encoding UTF8)) {
        if (-not [string]::IsNullOrWhiteSpace($favLine)) {
            [void]$global:favorites.Add($favLine.Trim())
        }
    }
}

# Etat de repli des categories (Group -> $true si repliee)
$global:collapsedGroups = @{}

# ------------------------------------------------------------
# Journalise une commande lancee
# ------------------------------------------------------------
function global:Write-CommandLog {
    param(
        [string]$Title,
        [string]$Command,
        [int]$ProcessId = 0
    )
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $pidPart = if ($ProcessId -gt 0) { "PID=$ProcessId" } else { "PID=?" }
    $entry = "[$timestamp] PC=$($global:machineName) | User=$($global:userName) | Win=$($global:winInfo) | $pidPart | $Title -> $Command"
    Add-Content -Path $global:logFile -Value $entry -Encoding UTF8
}

# ------------------------------------------------------------
# Lance une commande dans une nouvelle fenetre console persistante.
# Si $Confirm est vrai, demande une confirmation Oui/Non avant de lancer.
# ------------------------------------------------------------
function global:Invoke-ConsoleCommand {
    param(
        [string]$Title,
        [string]$Command,
        [string]$Desc,
        [bool]$Confirm
    )

    if ($Confirm) {
        $message = "$Desc`n`nConfirmer le lancement de :`n$Title ?"
        $result = [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Confirmation requise",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    $escapedTitle = $Title -replace '"', ''
    # -PassThru : recupere l'objet process (donc son PID) sans attendre sa fin, ce qui reste
    # compatible avec /k (fenetre laissee ouverte indefiniment pour lire le resultat).
    $proc = Start-Process cmd.exe -ArgumentList "/k title $escapedTitle && $Command" -PassThru
    Write-CommandLog -Title $Title -Command $Command -ProcessId $proc.Id
}

# ------------------------------------------------------------
# Sauvegarde la liste des favoris sur disque
# ------------------------------------------------------------
function global:Save-Favorites {
    $global:favorites | Set-Content -Path $global:favFile -Encoding UTF8
}

# ------------------------------------------------------------
# Parse Historique.log en une liste d'objets structures.
# Fonction partagee entre l'export HTML et l'export JSON.
# ------------------------------------------------------------
function global:Get-HistoryEntries {
    if (-not (Test-Path $global:logFile)) {
        return @()
    }

    $lines = Get-Content -Path $global:logFile -Encoding UTF8
    $rows = foreach ($line in $lines) {
        # Le segment PID=... est optionnel dans la regex pour rester compatible avec les
        # lignes ecrites avant son introduction (Historique.log existant, pas de migration
        # de format necessaire).
        if ($line -match '^\[(?<date>[^\]]+)\] PC=(?<pc>.+?) \| User=(?<user>.+?) \| Win=(?<win>.+?) \| (?:PID=(?<pid>\d+|\?) \| )?(?<title>.+?) -> (?<cmd>.+)$') {
            [PSCustomObject]@{
                Date  = $Matches.date.Trim()
                PC    = $Matches.pc.Trim()
                User  = $Matches.user.Trim()
                Win   = $Matches.win.Trim()
                PID   = if ($Matches.pid) { $Matches.pid.Trim() } else { "" }
                Title = $Matches.title.Trim()
                Cmd   = $Matches.cmd.Trim()
            }
        }
    }
    return @($rows)
}

# ------------------------------------------------------------
# Exporte l'historique (Historique.log) en rapport HTML theme sombre
# et l'ouvre dans le navigateur par defaut.
# ------------------------------------------------------------
function global:Export-History {
    $rows = Get-HistoryEntries
    if ($rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Aucun historique a exporter pour le moment.",
            "Export historique",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $htmlRows = foreach ($r in $rows) {
        "<tr><td>$($r.Date)</td><td>$($r.PC)</td><td>$($r.User)</td><td>$($r.Win)</td><td>$($r.PID)</td><td>$($r.Title)</td><td><code>$($r.Cmd)</code></td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Historique - Toolbox Commandes Systeme</title>
<style>
  body { background:#18181a; color:#e5e5e7; font-family: 'Segoe UI', Arial, sans-serif; padding:24px; }
  h1 { color:#00c8ff; font-size:20px; margin-bottom:4px; }
  .meta { color:#888; font-size:12px; margin-bottom:16px; }
  table { border-collapse: collapse; width:100%; }
  th, td { padding:8px 12px; border-bottom:1px solid #333; text-align:left; font-size:13px; vertical-align:top; }
  th { color:#00c8ff; text-transform:uppercase; font-size:11px; letter-spacing:0.05em; background:#0f0f11; position:sticky; top:0; }
  tr:hover { background:#242428; }
  code { color:#ffbe5a; font-family: Consolas, monospace; font-size:12px; }
</style>
</head>
<body>
  <h1>Historique - Toolbox Commandes Systeme</h1>
  <div class="meta">Genere le $(Get-Date -Format "dd/MM/yyyy HH:mm:ss") - $($rows.Count) entree(s)</div>
  <table>
    <tr><th>Date</th><th>PC</th><th>Utilisateur</th><th>Windows</th><th>PID</th><th>Commande</th><th>Detail</th></tr>
    $($htmlRows -join "`n")
  </table>
</body>
</html>
"@


    $htmlPath = Join-Path $global:logDir "Historique.html"
    Set-Content -Path $htmlPath -Value $html -Encoding UTF8
    Start-Process $htmlPath
}

# ------------------------------------------------------------
# Exporte l'historique (Historique.log) en JSON structure, exploitable
# par un futur script d'agregation multi-machines (meme logique que les
# baselines JSON du reste de la suite).
# ------------------------------------------------------------
function global:Export-HistoryJson {
    $rows = Get-HistoryEntries
    if ($rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Aucun historique a exporter pour le moment.",
            "Export historique",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $jsonPath = Join-Path $global:logDir "Historique.json"
    $rows | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
    Start-Process $jsonPath
}

# ------------------------------------------------------------
# Catalogue des commandes - charge depuis Commands.psd1 (doit se trouver
# dans le meme dossier que ce script). Voir Commands.psd1 pour le format
# et les conventions (notamment : toujours des guillemets simples pour Cmd).
# ------------------------------------------------------------
$global:catalogPath = Join-Path $PSScriptRoot "Commands.psd1"
$commandGroups = [ordered]@{}
$global:catalogLoadError = $null

if (-not (Test-Path $global:catalogPath)) {
    $global:catalogLoadError = "Fichier Commands.psd1 introuvable a cote du script (chemin attendu : $global:catalogPath)."
} else {
    try {
        $catalogData = Import-PowerShellDataFile -Path $global:catalogPath -ErrorAction Stop
        foreach ($cat in $catalogData.Categories) {
            $commandGroups[$cat.Name] = $cat.Commands
        }
    } catch {
        $global:catalogLoadError = "Echec du chargement de Commands.psd1 : $($_.Exception.Message)"
    }
}

if ($global:catalogLoadError -and -not $SelfTest) {
    [System.Windows.Forms.MessageBox]::Show(
        $global:catalogLoadError,
        "Erreur de chargement du catalogue",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

# ------------------------------------------------------------
# Met a jour la visibilite des lignes de commande selon :
#  - le texte de recherche ($global:searchBox)
#  - le filtre "favoris uniquement" ($global:favOnlyCheck)
#  - l'etat de repli de chaque categorie ($global:collapsedGroups)
# Le FlowLayoutPanel se charge lui-meme de re-empiler les elements
# visibles sans laisser de trous. Fonction globale car appelee depuis
# des gestionnaires d'evenements WinForms.
# ------------------------------------------------------------
function global:Update-Visibility {
    $filterLower  = ""
    if ($global:searchBox) { $filterLower = $global:searchBox.Text.Trim().ToLowerInvariant() }
    $filterActive = $filterLower -ne ""

    $favOnly = $false
    if ($global:favOnlyCheck) { $favOnly = $global:favOnlyCheck.Checked }

    $groupHasMatch = @{}

    foreach ($entry in $global:layoutItems) {
        if ($entry.Type -ne "Button") { continue }

        $matchesSearch = (-not $filterActive) -or ($entry.Search -like "*$filterLower*")
        $matchesFav    = (-not $favOnly) -or $global:favorites.Contains($entry.Label)
        $groupCollapsed = [bool]$global:collapsedGroups[$entry.Group]

        $matchesFilters = $matchesSearch -and $matchesFav
        if ($matchesFilters) { $groupHasMatch[$entry.Group] = $true }

        # Une categorie repliee masque ses commandes, sauf si une recherche ou le filtre
        # favoris est actif (dans ce cas on affiche quand meme les resultats pertinents).
        $overrideCollapse = $filterActive -or $favOnly
        $entry.Control.Visible = $matchesFilters -and (-not $groupCollapsed -or $overrideCollapse)
    }

    foreach ($entry in $global:layoutItems) {
        if ($entry.Type -ne "Header") { continue }
        $entry.Control.Visible = [bool]$groupHasMatch[$entry.Group]
        $collapsed = [bool]$global:collapsedGroups[$entry.Group]
        $arrow = if ($collapsed) { "+" } else { "-" }
        $entry.Control.Text = "[$arrow] $($entry.Group)"
    }
}

# ============================================================
# REGION: SELFTEST
# 37 assertions sur l'integrite du catalogue de commandes et les
# fonctions requises. Ne necessite pas les droits admin, n'ouvre pas
# l'interface graphique.
# ============================================================
if ($SelfTest) {
    $script:testTotal = 0
    $script:testPass   = 0

    function Test-Assertion {
        param([string]$Name, [bool]$Condition)
        $script:testTotal++
        if ($Condition) {
            $script:testPass++
            Write-Host "  [PASS] $Name" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $Name" -ForegroundColor Red
        }
    }

    Write-Host "=== SelfTest Toolbox-SystemCommands_Win11 ===" -ForegroundColor Cyan

    $allCommands = foreach ($grp in $commandGroups.Keys) { $commandGroups[$grp] }

    # --- Integrite structurelle du catalogue ---
    Test-Assertion "Le catalogue de commandes n'est pas vide" ($commandGroups.Count -gt 0)

    $categoriesVides = $commandGroups.Keys | Where-Object { $commandGroups[$_].Count -eq 0 }
    Test-Assertion "Chaque categorie contient au moins une commande" ($categoriesVides.Count -eq 0)

    Test-Assertion "Au moins 20 commandes au total" ($allCommands.Count -ge 20)

    $labelsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Label) }
    Test-Assertion "Tous les labels sont renseignes" ($labelsVides.Count -eq 0)

    $cmdsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Cmd) }
    Test-Assertion "Toutes les commandes ont un Cmd renseigne" ($cmdsVides.Count -eq 0)

    $descsVides = $allCommands | Where-Object { [string]::IsNullOrWhiteSpace($_.Desc) }
    Test-Assertion "Toutes les commandes ont une Desc renseignee" ($descsVides.Count -eq 0)

    $confirmManquant = $allCommands | Where-Object { $null -eq $_.Confirm }
    Test-Assertion "Toutes les commandes ont un flag Confirm defini" ($confirmManquant.Count -eq 0)

    $labelsDupliques = $allCommands.Label | Group-Object | Where-Object { $_.Count -gt 1 }
    Test-Assertion "Aucun label duplique" ($labelsDupliques.Count -eq 0)

    # --- Regressions connues ---
    $pipeNonEchappe = $allCommands | Where-Object { ($_.Cmd -replace '\^\|', '') -match '\|' }
    Test-Assertion "Aucun pipe non echappe dans les commandes (regression cmd.exe)" ($pipeNonEchappe.Count -eq 0)

    $usesWmic = $allCommands | Where-Object { $_.Cmd -match '(?i)\bwmic\b' }
    Test-Assertion "Aucune commande n'utilise wmic (retire depuis Windows 11 24H2)" ($usesWmic.Count -eq 0)

    # --- Catalogue externe (Commands.psd1) ---
    Test-Assertion "Fichier Commands.psd1 present a cote du script" (Test-Path $global:catalogPath)
    Test-Assertion "Au moins une commande possede un champ Help (bouton '?')" (($allCommands | Where-Object { $_.Help }).Count -gt 0)
    Test-Assertion "Commands.psd1 charge sans erreur" (-not $global:catalogLoadError)

    # Regression : le champ Cmd doit toujours etre en guillemets simples ('...'), jamais en
    # guillemets doubles ("..."), pour garantir qu'aucune variable ($_, $err, etc.) n'y soit
    # jamais interpolee par erreur (cf. bug "Top processus RAM" du 30/07/2026, corrige
    # structurellement par ce choix de convention plutot que par un echappement au cas par cas).
    $catalogRaw = Get-Content -Path $global:catalogPath -Raw -ErrorAction SilentlyContinue
    $cmdEnGuillemetsDoubles = $false
    if ($catalogRaw) {
        $cmdEnGuillemetsDoubles = $catalogRaw -match 'Cmd\s*=\s*"'
    }
    Test-Assertion "Tous les champs Cmd de Commands.psd1 sont en guillemets simples (regression)" (-not $cmdEnGuillemetsDoubles)

    # Regression : meme un Cmd correctement encadre de guillemets simples ne doit jamais
    # contenir de guillemet double en son contenu (ex: -Filter "Name='_Total'") - cf. bug
    # "Latence disque en temps reel" du 01/08/2026 (HRESULT 0x80041017, guillemets doubles
    # mal geres par cmd.exe une fois empaquetes dans le /k title ... && de Invoke-ConsoleCommand).
    # Prefer Where-Object avec guillemets simples plutot qu'un filtre WQL/-Filter necessitant
    # des guillemets doubles.
    $cmdAvecGuillemetsDoublesInternes = $false
    if ($catalogRaw) {
        $cmdLines = $catalogRaw -split "`r?`n" | Where-Object { $_ -match "^\s*Cmd\s*=\s*'" }
        $cmdAvecGuillemetsDoublesInternes = [bool]($cmdLines | Where-Object { $_ -match '"' })
    }
    Test-Assertion "Aucun guillemet double dans le contenu des commandes Cmd (regression cmd.exe)" (-not $cmdAvecGuillemetsDoublesInternes)

    Test-Assertion "Fonction Get-HistoryEntries definie" ([bool](Get-Command Get-HistoryEntries -ErrorAction SilentlyContinue))
    Test-Assertion "Fonction Export-HistoryJson definie" ([bool](Get-Command Export-HistoryJson -ErrorAction SilentlyContinue))

    # --- Commandes sensibles : confirmation toujours active ---
    $labelsSensibles = @(
        "CHKDSK C: /f /r (au reboot)",
        "Reset Winsock",
        "Reset pile TCP/IP",
        "Reset composants WU",
        "Redemarrer le PC",
        "Eteindre le PC"
    )
    foreach ($labelSensible in $labelsSensibles) {
        $entree = $allCommands | Where-Object { $_.Label -eq $labelSensible }
        Test-Assertion "Confirmation active pour : $labelSensible" ($entree -and $entree.Confirm -eq $true)
    }

    # --- Fonctions requises ---
    Test-Assertion "Fonction Invoke-ConsoleCommand definie" ([bool](Get-Command Invoke-ConsoleCommand -ErrorAction SilentlyContinue))
    Test-Assertion "Fonction Write-CommandLog definie" ([bool](Get-Command Write-CommandLog -ErrorAction SilentlyContinue))
    Test-Assertion "Write-CommandLog accepte le parametre ProcessId (PID logge)" ((Get-Command Write-CommandLog).Parameters.ContainsKey('ProcessId'))
    Test-Assertion "Fonction Update-Visibility definie" ([bool](Get-Command Update-Visibility -ErrorAction SilentlyContinue))
    Test-Assertion "Fonction Save-Favorites definie" ([bool](Get-Command Save-Favorites -ErrorAction SilentlyContinue))
    Test-Assertion "Fonction Export-History definie" ([bool](Get-Command Export-History -ErrorAction SilentlyContinue))

    # --- Journalisation ---
    Test-Assertion "Dossier de log accessible ou cree" (Test-Path $global:logDir)
    Test-Assertion "Chemin du fichier de log valide" (-not [string]::IsNullOrWhiteSpace($global:logFile))
    Test-Assertion "Nom de machine capture" (-not [string]::IsNullOrWhiteSpace($global:machineName))
    Test-Assertion "Nom d'utilisateur capture" (-not [string]::IsNullOrWhiteSpace($global:userName))
    Test-Assertion "Version Windows capturee" (-not [string]::IsNullOrWhiteSpace($global:winInfo))

    # --- Favoris ---
    Test-Assertion "Chemin du fichier favoris valide" (-not [string]::IsNullOrWhiteSpace($global:favFile))
    Test-Assertion "Structure des favoris initialisee (HashSet)" ($null -ne $global:favorites)

    # --- Auto-elevation ---
    try {
        $null = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $principalOk = $true
    } catch {
        $principalOk = $false
    }
    Test-Assertion "Verification WindowsPrincipal fonctionnelle (auto-elevation)" $principalOk

    Write-Host ""
    if ($script:testPass -eq $script:testTotal) {
        Write-Host "TOUS LES TESTS SONT PASSES ($($script:testPass)/$($script:testTotal))" -ForegroundColor Green
        exit 0
    } else {
        $echecs = $script:testTotal - $script:testPass
        Write-Host "$echecs test(s) echoue(s) sur $($script:testTotal) ($($script:testPass) reussis)" -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# Construction de l'interface
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Toolbox Commandes Systeme - Nephren"
$form.Size          = New-Object System.Drawing.Size(470, 780)
$form.StartPosition = "CenterScreen"
$form.BackColor     = [System.Drawing.Color]::FromArgb(24,24,27)
$form.ForeColor     = [System.Drawing.Color]::White
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox   = $false

# KeyPreview = $true : la fenetre recoit les evenements clavier avant les controles
# enfants, necessaire pour intercepter Ctrl+F ou que le focus se trouve.
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F) {
        $global:searchBox.Focus()
        $global:searchBox.SelectAll()
        $e.SuppressKeyPress = $true
    }
})

# ------------------------------------------------------------
# Barre superieure : recherche + export + filtre favoris
# Dans son propre panneau Dock=Top pour ne jamais etre recouverte
# par la liste (Dock=Fill).
# ------------------------------------------------------------
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Dock = "Top"
$topBar.Height = 78
$topBar.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)
$form.Controls.Add($topBar)

$global:searchBox = New-Object System.Windows.Forms.TextBox
$global:searchBox.Location = New-Object System.Drawing.Point(10, 8)
$global:searchBox.Width = 210
$global:searchBox.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$global:searchBox.ForeColor = [System.Drawing.Color]::White
$global:searchBox.BorderStyle = "FixedSingle"
$global:searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$topBar.Controls.Add($global:searchBox)

$searchHint = New-Object System.Windows.Forms.Label
$searchHint.Text = "Rechercher une commande..."
$searchHint.ForeColor = [System.Drawing.Color]::FromArgb(120,120,125)
$searchHint.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$searchHint.Location = New-Object System.Drawing.Point(14, 11)
$searchHint.AutoSize = $true
$searchHint.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$topBar.Controls.Add($searchHint)
$searchHint.BringToFront()

$global:searchBox.Add_GotFocus({ $searchHint.Visible = $false })
$global:searchBox.Add_LostFocus({ if ($global:searchBox.Text -eq "") { $searchHint.Visible = $true } })

$exportJsonBtn = New-Object System.Windows.Forms.Button
$exportJsonBtn.Text = "Export JSON"
$exportJsonBtn.Location = New-Object System.Drawing.Point(228, 7)
$exportJsonBtn.Width = 90
$exportJsonBtn.Height = 24
$exportJsonBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$exportJsonBtn.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$exportJsonBtn.FlatStyle = "Flat"
$exportJsonBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
$exportJsonBtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$exportJsonBtn.Add_Click({ Export-HistoryJson })
$topBar.Controls.Add($exportJsonBtn)

$exportBtn = New-Object System.Windows.Forms.Button
$exportBtn.Text = "Export HTML"
$exportBtn.Location = New-Object System.Drawing.Point(322, 7)
$exportBtn.Width = 100
$exportBtn.Height = 24
$exportBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
$exportBtn.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$exportBtn.FlatStyle = "Flat"
$exportBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
$exportBtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$exportBtn.Add_Click({ Export-History })
$topBar.Controls.Add($exportBtn)

$global:favOnlyCheck = New-Object System.Windows.Forms.CheckBox
$global:favOnlyCheck.Text = "Favoris uniquement"
$global:favOnlyCheck.Location = New-Object System.Drawing.Point(10, 42)
$global:favOnlyCheck.AutoSize = $true
$global:favOnlyCheck.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
$global:favOnlyCheck.Add_CheckedChanged({ Update-Visibility })
$topBar.Controls.Add($global:favOnlyCheck)

$catHint = New-Object System.Windows.Forms.Label
$catHint.Text = "Clic sur une categorie pour la replier"
$catHint.ForeColor = [System.Drawing.Color]::FromArgb(120,120,125)
$catHint.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$catHint.Location = New-Object System.Drawing.Point(180, 44)
$catHint.AutoSize = $true
$topBar.Controls.Add($catHint)

# ------------------------------------------------------------
# Zone de description fixe en bas (se met a jour au survol)
# ------------------------------------------------------------
$descPanel = New-Object System.Windows.Forms.Panel
$descPanel.Dock = "Bottom"
$descPanel.Height = 130
$descPanel.BackColor = [System.Drawing.Color]::FromArgb(18,18,20)
$form.Controls.Add($descPanel)

$descTitle = New-Object System.Windows.Forms.Label
$descTitle.Text = "Survolez une commande..."
$descTitle.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
$descTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$descTitle.Location = New-Object System.Drawing.Point(10, 6)
$descTitle.AutoSize = $true
$descPanel.Controls.Add($descTitle)

$descLabel = New-Object System.Windows.Forms.Label
$descLabel.Text = "Les explications de chaque commande s'affichent ici."
$descLabel.ForeColor = [System.Drawing.Color]::FromArgb(210,210,215)
$descLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$descLabel.Location = New-Object System.Drawing.Point(10, 26)
$descLabel.Size = New-Object System.Drawing.Size(445, 95)
$descPanel.Controls.Add($descLabel)

# Tooltip natif en secours (utile si navigation au clavier / Tab)
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 15000
$toolTip.InitialDelay = 400
$toolTip.ReshowDelay  = 200

# ------------------------------------------------------------
# Liste des commandes : FlowLayoutPanel (empilement automatique,
# gere nativement le masquage des elements filtres sans trou)
# ------------------------------------------------------------
$flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$flowPanel.Dock = "Fill"
$flowPanel.FlowDirection = "TopDown"
$flowPanel.WrapContents = $false
$flowPanel.AutoScroll = $true
$flowPanel.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)
$flowPanel.Padding = New-Object System.Windows.Forms.Padding(6)
$form.Controls.Add($flowPanel)
$flowPanel.BringToFront()

# Table de correspondance pour le filtre : chaque entree = {Control, Group, Search, Type, Label}
$global:layoutItems = New-Object System.Collections.Generic.List[object]

foreach ($group in $commandGroups.Keys) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "[-] $group"
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.AutoSize = $true
    $lbl.Margin = New-Object System.Windows.Forms.Padding(4,10,4,4)
    $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
    $flowPanel.Controls.Add($lbl)

    $groupNameCopy = $group
    $lbl.Add_Click({
        if (-not $global:collapsedGroups.ContainsKey($groupNameCopy)) {
            $global:collapsedGroups[$groupNameCopy] = $false
        }
        $global:collapsedGroups[$groupNameCopy] = -not $global:collapsedGroups[$groupNameCopy]
        Update-Visibility
    }.GetNewClosure())

    $global:layoutItems.Add([PSCustomObject]@{
        Type    = "Header"
        Control = $lbl
        Group   = $group
        Search  = $null
        Label   = $null
    })

    foreach ($item in $commandGroups[$group]) {
        # Ligne = petit panneau horizontal contenant [etoile] + [bouton commande]
        $row = New-Object System.Windows.Forms.FlowLayoutPanel
        $row.FlowDirection = "LeftToRight"
        $row.WrapContents = $false
        $row.AutoSize = $true
        $row.AutoSizeMode = "GrowAndShrink"
        $row.Margin = New-Object System.Windows.Forms.Padding(4,2,4,2)
        $row.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)

        $labelCopy   = $item.Label
        $cmdCopy     = $item.Cmd
        $descCopy    = $item.Desc
        $confirmCopy = [bool]$item.Confirm

        $starBtn = New-Object System.Windows.Forms.Button
        $starBtn.Width = 28
        $starBtn.Height = 32
        $starBtn.Margin = New-Object System.Windows.Forms.Padding(0,0,4,0)
        $starBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
        $starBtn.FlatStyle = "Flat"
        $starBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
        $starBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        if ($global:favorites.Contains($labelCopy)) {
            $starBtn.Text = "*"
            $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
        } else {
            $starBtn.Text = "o"
            $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(110,110,115)
        }
        $toolTip.SetToolTip($starBtn, "Ajouter/retirer des favoris")
        $starBtn.Add_Click({
            if ($global:favorites.Contains($labelCopy)) {
                [void]$global:favorites.Remove($labelCopy)
                $starBtn.Text = "o"
                $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(110,110,115)
            } else {
                [void]$global:favorites.Add($labelCopy)
                $starBtn.Text = "*"
                $starBtn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
            }
            Save-Favorites
            Update-Visibility
        }.GetNewClosure())
        $row.Controls.Add($starBtn)

        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $item.Label
        $btn.Width = 334
        $btn.Height = 32
        $btn.Margin = New-Object System.Windows.Forms.Padding(0)
        $btn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(10,0,0,0)

        # Alerte visuelle si confirmation requise
        if ($item.Confirm) {
            $btn.ForeColor = [System.Drawing.Color]::FromArgb(255,190,90)
        }

        $btn.Add_Click({
            Invoke-ConsoleCommand -Title $labelCopy -Command $cmdCopy -Desc $descCopy -Confirm $confirmCopy
        }.GetNewClosure())

        # Met a jour la zone de description fixe au survol
        $btn.Add_MouseEnter({
            $descTitle.Text = $labelCopy
            $descLabel.Text = $descCopy
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0,200,255)
            $btn.FlatAppearance.BorderSize = 2
        }.GetNewClosure())
        $btn.Add_MouseLeave({
            $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
            $btn.FlatAppearance.BorderSize = 1
        }.GetNewClosure())

        # Tooltip natif en secours (focus clavier / accessibilite)
        $toolTip.SetToolTip($btn, $descCopy)

        # Clic droit : copier la commande brute dans le presse-papiers (reutilisation
        # ailleurs, script ou terminal direct, sans avoir a la retaper).
        $copyMenu = New-Object System.Windows.Forms.ContextMenuStrip
        $copyItem = New-Object System.Windows.Forms.ToolStripMenuItem "Copier la commande"
        $copyItem.Add_Click({
            [System.Windows.Forms.Clipboard]::SetText($cmdCopy)
        }.GetNewClosure())
        [void]$copyMenu.Items.Add($copyItem)
        $btn.ContextMenuStrip = $copyMenu

        $row.Controls.Add($btn)

        # Bouton d'aide optionnel ("?") : reserve sur CHAQUE ligne pour garder un
        # alignement constant sur toute la liste, mais actif/clair uniquement si la
        # commande possede un champ Help dans Commands.psd1 - sinon grise et desactive.
        $helpCopy = $item.Help
        $helpBtn = New-Object System.Windows.Forms.Button
        $helpBtn.Text = "?"
        $helpBtn.Width = 28
        $helpBtn.Height = 32
        $helpBtn.Margin = New-Object System.Windows.Forms.Padding(4,0,0,0)
        $helpBtn.FlatStyle = "Flat"
        $helpBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        if ($helpCopy) {
            $helpBtn.BackColor = [System.Drawing.Color]::FromArgb(38,38,42)
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(0,200,255)
            $helpBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(60,60,65)
            $toolTip.SetToolTip($helpBtn, "Plus d'explications")
            $helpBtn.Add_Click({
                [System.Windows.Forms.MessageBox]::Show(
                    $helpCopy,
                    $labelCopy,
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }.GetNewClosure())
        } else {
            $helpBtn.BackColor = [System.Drawing.Color]::FromArgb(28,28,31)
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(50,50,55)
            $helpBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(38,38,42)
            $helpBtn.Enabled = $false
        }
        $row.Controls.Add($helpBtn)

        $flowPanel.Controls.Add($row)

        $global:layoutItems.Add([PSCustomObject]@{
            Type    = "Button"
            Control = $row
            Group   = $group
            Search  = ("$labelCopy $descCopy").ToLowerInvariant()
            Label   = $labelCopy
        })
    }
}

$global:searchBox.Add_TextChanged({ Update-Visibility })

Update-Visibility

[System.Windows.Forms.Application]::Run($form)
