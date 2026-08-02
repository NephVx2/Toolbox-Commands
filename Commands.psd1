# ==============================================================================
# Commands.psd1 - Catalogue des commandes pour Toolbox-SystemCommands_Win11.ps1
# ==============================================================================
# Fichier de donnees PowerShell (charge via Import-PowerShellDataFile, en mode
# "restricted language" : aucune variable, aucune execution de code n'est
# possible ici, uniquement des litteraux (chaines, nombres, $true/$false,
# tableaux @(), tables de hachage @{})).
#
# IMPORTANT - Champ "Cmd" :
# Toujours utiliser des GUILLEMETS SIMPLES ('...') pour le champ Cmd, jamais
# des guillemets doubles ("..."). Les guillemets simples ne sont JAMAIS
# interpoles par PowerShell : un $_ , $err ou toute autre variable y reste
# strictement litteral et sera transmis tel quel a la commande enfant. C'est
# ce qui a corrige plusieurs bugs historiques (v1.4.3 : $_ non echappe dans
# "Top processus RAM" ; v1.4.4-like risques similaires). Ne jamais revenir a
# des guillemets doubles pour Cmd, meme pour un besoin ponctuel.
# Si le texte contient lui-meme un guillemet simple (ex: Where-Object Status
# -eq 'Error'), le doubler : '' (deux guillemets simples consecutifs).
#
# Chaque commande : Label (texte du bouton), Cmd (commande executee),
# Desc (explication affichee), Confirm (demande une confirmation Oui/Non
# avant de lancer, $true/$false).
# ==============================================================================
@{
    Categories = @(
        @{
            Name = "Integrite systeme"
            Commands = @(
                @{ Label = "SFC /scannow"
                   Cmd   = 'sfc /scannow'
                   Desc  = "Verifie l'integrite de tous les fichiers systeme proteges et remplace automatiquement les versions corrompues par une copie saine (cache local). Duree : 10-20 min."
                   Confirm = $false }
                @{ Label = "SFC /verifyonly"
                   Cmd   = 'sfc /verifyonly'
                   Desc  = "Meme verification que /scannow mais sans rien corriger : plus rapide, utile pour juste diagnostiquer avant d'agir."
                   Confirm = $false }
                @{ Label = "DISM CheckHealth"
                   Cmd   = 'DISM /Online /Cleanup-Image /CheckHealth'
                   Desc  = "Verification rapide (quelques secondes) qui indique si l'image Windows (le magasin de composants) est marquee comme corrompue, sans scan approfondi."
                   Confirm = $false }
                @{ Label = "DISM ScanHealth"
                   Cmd   = 'DISM /Online /Cleanup-Image /ScanHealth'
                   Desc  = "Scan approfondi du magasin de composants Windows (WinSxS) pour detecter une corruption. Plus long que CheckHealth (5-10 min), mais plus fiable."
                   Confirm = $false }
                @{ Label = "DISM RestoreHealth"
                   Cmd   = 'DISM /Online /Cleanup-Image /RestoreHealth'
                   Desc  = "Repare le magasin de composants en telechargeant les fichiers sains via Windows Update. A lancer si ScanHealth signale une corruption. Necessite une connexion internet."
                   Confirm = $false }
                @{ Label = "DISM StartComponentCleanup"
                   Cmd   = 'DISM /Online /Cleanup-Image /StartComponentCleanup'
                   Desc  = "Purge les anciennes versions de composants (mises a jour remplacees, etc.) dans WinSxS pour liberer de l'espace disque. Sans risque, ne touche pas aux composants actifs."
                   Confirm = $false }
                @{ Label = "Repair-WindowsImage RestoreHealth (PS)"
                   Cmd   = 'powershell -NoExit -Command Repair-WindowsImage -Online -RestoreHealth'
                   Desc  = "Equivalent PowerShell natif de DISM RestoreHealth. Meme resultat, juste une autre commande si tu prefes rester en contexte PowerShell."
                   Confirm = $false }
                @{ Label = "Points de restauration existants"
                   Cmd   = 'powershell -NoExit -Command try { Get-ComputerRestorePoint ^| Select-Object SequenceNumber,Description,CreationTime,RestorePointType ^| Format-Table -AutoSize } catch { Write-Host ''Aucun point de restauration trouve (protection systeme probablement desactivee sur C:).'' -ForegroundColor Yellow }'
                   Desc  = "Liste les points de restauration systeme disponibles. Utile a consulter avant de lancer une operation risquee (CHKDSK /f, DISM RestoreHealth, Reset Winsock/TCP-IP...) pour savoir si un retour arriere est possible. Message clair si la protection systeme est desactivee sur C:, plutot qu'une erreur bloquante."
                   Confirm = $false }
                @{ Label = "Creer un point de restauration"
                   Cmd   = 'powershell -NoExit -Command try { Checkpoint-Computer -Description ''Toolbox_manuel'' -RestorePointType ''MODIFY_SETTINGS''; Write-Host ''Point de restauration demande.'' -ForegroundColor Green } catch { Write-Host ''Echec : la protection systeme (System Restore) est probablement desactivee sur C:.'' -ForegroundColor Red }'
                   Desc  = "Cree un point de restauration avant une manipulation risquee. Non destructif, aucune confirmation necessaire. Attention : Windows limite nativement la creation a un point toutes les 24h (SystemRestorePointCreationFrequency) - un appel repete dans cette fenetre est silencieusement ignore par Windows lui-meme, pas un bug de cette commande."
                   Confirm = $false }
            )
        }
        @{
            Name = "Disque"
            Commands = @(
                @{ Label = "CHKDSK C: (lecture seule)"
                   Cmd   = 'chkdsk C:'
                   Desc  = "Analyse le systeme de fichiers du disque C: SANS rien corriger et sans demonter le volume. Sans danger, s'execute immediatement."
                   Confirm = $false }
                @{ Label = "CHKDSK C: /scan"
                   Cmd   = 'chkdsk C: /scan'
                   Desc  = "Scan en ligne du volume (le disque reste utilisable pendant l'analyse) qui signale les erreurs trouvees, sans les corriger ni necessiter de redemarrage."
                   Confirm = $false }
                @{ Label = "CHKDSK C: /f /r (au reboot)"
                   Cmd   = 'chkdsk C: /f /r'
                   Desc  = "ATTENTION : programme une verification ET reparation complete du disque (secteurs defectueux inclus) au PROCHAIN REDEMARRAGE. Le PC redemarrera en mode texte et l'operation peut prendre 30 min a plusieurs heures selon la taille du disque."
                   Confirm = $true
                   Help  = "Ce que fait exactement cette commande : /f verifie et corrige les erreurs du systeme de fichiers (entrees corrompues, index de fichiers incoherents) ; /r fait tout ce que /f fait PLUS un scan physique de chaque secteur du disque pour reperer les secteurs defectueux et migrer les donnees concernees. Comme le disque C: est en cours d'utilisation par Windows lui-meme, l'operation ne peut pas se faire a chaud : elle est programmee via le registre (BootExecute) et se declenche au redemarrage suivant, avant meme que Windows ne charge.`n`nCe que ca implique concretement : le PC redemarre en mode texte noir et blanc (pas d'interface graphique), l'ecran affiche une progression en pourcentage par etape (4 a 5 etapes selon le systeme de fichiers), et la machine est INUTILISABLE pendant toute la duree - pas d'autre usage possible en parallele. Duree tres variable : quelques minutes sur un petit SSD sain, plusieurs heures sur un gros disque avec beaucoup de secteurs a verifier ou des erreurs a corriger.`n`nSi tu changes d'avis : au tout debut du redemarrage, Windows affiche un compte a rebours de quelques secondes avec la possibilite d'appuyer sur une touche pour annuler l'operation programmee - a saisir cette fenetre precise, une fois le scan reellement demarre il vaut mieux le laisser terminer plutot que de forcer un arret (risque d'aggraver une corruption en cours de reparation)." }
                @{ Label = "fsutil dirty query C:"
                   Cmd   = 'fsutil dirty query C:'
                   Desc  = "Indique si le volume C: est marque 'dirty', c'est-a-dire si un CHKDSK est deja planifie au prochain demarrage. Pratique pour verifier avant de relancer /f /r."
                   Confirm = $false }
                @{ Label = "Optimize-Volume ReTrim (SSD)"
                   Cmd   = 'powershell -NoExit -Command Optimize-Volume -DriveLetter C -ReTrim -Verbose'
                   Desc  = "Envoie la commande TRIM au SSD pour l'informer des blocs libres a effacer en interne (maintien des performances long terme). Adapte a un SSD comme tes Samsung 860 EVO / Micron, pas a un HDD."
                   Confirm = $false }
                @{ Label = "Etat SMART des disques"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_DiskDrive ^| Select-Object Model,Status,Size ^| Format-Table -AutoSize'
                   Desc  = "Affiche pour chaque disque physique son modele, sa taille et son statut SMART ('OK' si sain). Premiere alerte simple en cas de disque en fin de vie. (Remplace wmic, retire par defaut depuis Windows 11 24H2)."
                   Confirm = $false }
                @{ Label = "Etat disques detaille"
                   Cmd   = 'powershell -NoExit -Command Get-PhysicalDisk ^| Select-Object FriendlyName,MediaType,Size,HealthStatus,OperationalStatus ^| Format-Table -AutoSize'
                   Desc  = "Vue plus complete que le statut SMART simple : type de media (SSD/HDD detecte automatiquement), taille, et surtout HealthStatus + OperationalStatus qui distinguent un disque degrade mais fonctionnel d'un disque en panne franche."
                   Confirm = $false }
                @{ Label = "Latence disque en temps reel"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk ^| Where-Object { $_.Name -eq ''_Total'' } ^| Select-Object Name,AvgDisksecPerTransfer,AvgDiskQueueLength,PercentDiskTime ^| Format-List'
                   Desc  = "Mesure instantanee de la performance disque sous la charge actuelle (pas la sante SMART, voir 'Etat disques detaille' pour ca) : AvgDisksecPerTransfer = latence moyenne par operation (un SSD sain est generalement bien en dessous de 0,005s), AvgDiskQueueLength = operations en attente (proche de 0-1 = sain), PercentDiskTime = % du temps ou le disque est sollicite. Utilise une classe WMI (noms de proprietes fixes en anglais) plutot que Get-Counter, dont les chemins de compteurs sont localises et auraient echoue sur une machine Windows en francais."
                   Confirm = $false }
            )
        }
        @{
            Name = "Reseau"
            Commands = @(
                @{ Label = "Flush DNS"
                   Cmd   = 'ipconfig /flushdns'
                   Desc  = "Vide le cache DNS local. Utile apres un changement de serveur DNS (ex: NextDNS) ou en cas de resolution de nom incorrecte/obsolete."
                   Confirm = $false }
                @{ Label = "Afficher config IP complete"
                   Cmd   = 'ipconfig /all'
                   Desc  = "Affiche en detail la configuration reseau de toutes les interfaces : adresses IP, passerelle, serveurs DNS, adresses MAC, bail DHCP."
                   Confirm = $false }
                @{ Label = "Reset Winsock"
                   Cmd   = 'netsh winsock reset'
                   Desc  = "ATTENTION : reinitialise la pile Winsock (catalogue des protocoles reseau). A utiliser en cas de probleme de connectivite persistant. NECESSITE UN REDEMARRAGE pour prendre effet."
                   Confirm = $true
                   Help  = "Le catalogue Winsock est la liste ordonnee des 'fournisseurs de services' (LSP - Layered Service Providers) que Windows utilise pour chaque connexion reseau : c'est la couche juste au-dessus de la carte reseau elle-meme, avant que les applications ne voient les donnees. Certains logiciels (VPN, certains antivirus avec 'bouclier reseau', logiciels de controle parental) s'inserent dans cette chaine - et un LSP mal desinstalle ou corrompu peut casser TOUTE la connectivite internet, meme si la carte reseau elle-meme fonctionne parfaitement.`n`nCe que fait la commande : reconstruit ce catalogue a son etat par defaut Windows, en retirant tous les LSP tiers qui s'y etaient inseres.`n`nCe que ca implique concretement : si tu utilises un VPN, un antivirus avec filtrage reseau actif, ou tout logiciel qui s'accroche a la pile reseau, il faudra probablement le reinstaller ou le reactiver apres coup - son propre LSP aura ete efface avec le reste. Ne resout PAS un probleme materiel (carte reseau defectueuse, cable, pilote) ni un probleme de routeur/box - uniquement les problemes situes dans cette couche logicielle Windows precise." }
                @{ Label = "Reset pile TCP/IP"
                   Cmd   = 'netsh int ip reset'
                   Desc  = "ATTENTION : reinitialise completement la configuration TCP/IP a son etat par defaut (equivalent a reinstaller la pile reseau). A utiliser en dernier recours. NECESSITE UN REDEMARRAGE."
                   Confirm = $true
                   Help  = "Different de 'Reset Winsock' (qui vise le catalogue des LSP) : celle-ci reinitialise le protocole TCP/IP lui-meme - le mecanisme qui decoupe et achemine les donnees sur le reseau. C'est une couche plus profonde et plus large que Winsock.`n`nCe que ca implique concretement : toute configuration reseau personnalisee sur tes interfaces (adresse IP statique, serveurs DNS manuels, passerelle personnalisee, parametres avances comme la taille de fenetre TCP) est remise a zero et repasse en configuration automatique (DHCP). Si tu avais configure une IP fixe ou des DNS personnalises (un fournisseur DNS tiers configure manuellement, par exemple), il faudra les reconfigurer apres coup. Sans effet sur le materiel (carte reseau, pilote) - uniquement la configuration logicielle du protocole.`n`nA utiliser seulement si 'Reset Winsock' n'a pas suffi a resoudre le probleme - c'est un outil plus radical, pas la premiere chose a essayer." }
                @{ Label = "Renouveler bail IP"
                   Cmd   = 'ipconfig /release && ipconfig /renew'
                   Desc  = "Libere puis redemande une adresse IP aupres du serveur DHCP. Utile si l'IP actuelle semble en conflit ou perimee."
                   Confirm = $false }
                @{ Label = "Connexions actives (netstat)"
                   Cmd   = 'netstat -ano'
                   Desc  = "Liste toutes les connexions reseau actives avec le PID du processus associe. Utile pour identifier ce qui communique sur le reseau en ce moment."
                   Confirm = $false }
                @{ Label = "Table ARP"
                   Cmd   = 'arp -a'
                   Desc  = "Affiche la table de correspondance IP <-> adresse MAC pour les appareils recemment contactes sur le reseau local."
                   Confirm = $false }
                @{ Label = "Test NextDNS (test.nextdns.io)"
                   Cmd   = 'curl.exe -L https://test.nextdns.io'
                   Desc  = "Test officiel NextDNS : verifie si le trafic DNS de la machine passe reellement par NextDNS (interception WFP de l'app desktop y compris), le protocole utilise (DoH/DoT/DoQ) et le point de presence le plus proche. 'status: ok' = actif, 'status: unconfigured' = pas utilise actuellement."
                   Confirm = $false }
                @{ Label = "DNS configure par interface"
                   Cmd   = 'powershell -NoExit -Command Get-DnsClientServerAddress ^| Format-Table -AutoSize'
                   Desc  = "Affiche le ou les serveurs DNS declares sur chaque interface reseau. Utile en diagnostic generique (machine sans NextDNS, autre resolveur) ; ne detecte pas une interception transparente type app NextDNS Desktop (voir Test NextDNS ci-dessus dans ce cas)."
                   Confirm = $false }
                @{ Label = "Etat des adaptateurs reseau"
                   Cmd   = 'powershell -NoExit -Command Get-NetAdapter ^| Format-Table -AutoSize'
                   Desc  = "Liste les interfaces reseau avec leur etat (Up/Down) et leur vitesse de liaison."
                   Confirm = $false }
                @{ Label = "Cache DNS actuel"
                   Cmd   = 'ipconfig /displaydns'
                   Desc  = "Affiche le contenu actuel du cache DNS local, entree par entree, avant de decider de le vider avec Flush DNS. Utile pour reperer precisement une entree perimee ou incorrecte."
                   Confirm = $false }
                @{ Label = "Reseaux Wifi enregistres"
                   Cmd   = 'netsh wlan show profiles'
                   Desc  = "Liste les profils Wifi enregistres sur la machine, sans afficher les mots de passe (il faut l'option 'key=clear' explicite pour ca, absente ici par securite). Renvoie une erreur normale si le service Wifi (wlansvc) est desactive ou si aucun adaptateur sans fil n'est present."
                   Confirm = $false }
                @{ Label = "Vitesse Wifi actuelle"
                   Cmd   = 'netsh wlan show interfaces'
                   Desc  = "Affiche l'etat de la connexion Wifi active : signal, bande (2,4/5 GHz), debit de liaison actuel. Complementaire a 'Reseaux Wifi enregistres' (qui liste les profils connus, pas la connexion en cours). Message d'erreur normal si aucune interface sans fil active."
                   Confirm = $false }
                @{ Label = "Adresse IP publique"
                   Cmd   = 'curl.exe -s https://api.ipify.org'
                   Desc  = "Affiche l'adresse IP publique actuelle de la machine, via une requete HTTPS vers le service tiers api.ipify.org (meme principe de requete externe que 'Test NextDNS' ci-dessus). Utile apres un changement de config reseau ou de VPN pour confirmer par quelle IP tu sors reellement."
                   Confirm = $false }
            )
        }
        @{
            Name = "Windows Update"
            Commands = @(
                @{ Label = "Reset composants WU"
                   Cmd   = 'net stop wuauserv && net stop bits && ren %windir%\SoftwareDistribution SoftwareDistribution.bak && net start wuauserv && net start bits'
                   Desc  = "ATTENTION : arrete les services Windows Update, renomme le dossier de cache des mises a jour (il sera regenere vide) puis relance les services. Resout la plupart des blocages de Windows Update mais efface l'historique de telechargement en cours."
                   Confirm = $true
                   Help  = "Le dossier SoftwareDistribution est le cache local de Windows Update : les fichiers de mise a jour deja telecharges (partiellement ou completement) et les metadonnees du catalogue. C'est souvent la cause d'un Windows Update bloque ou qui boucle sur une erreur : un fichier corrompu dans ce cache empeche la suite du processus.`n`nCe que fait la commande, etape par etape : arrete les deux services concernes (wuauserv = Windows Update lui-meme, bits = le service de transfert en arriere-plan utilise pour les telechargements), renomme le dossier existant en .bak (il n'est PAS supprime, juste mis de cote), puis relance les services - Windows recree alors automatiquement un dossier SoftwareDistribution vide et repart de zero.`n`nCe que ca implique concretement : toute mise a jour en cours de telechargement doit recommencer entierement depuis le debut (pas de reprise partielle). Les mises a jour DEJA installees ne sont pas affectees. L'ancien dossier .bak reste sur le disque et prend de la place - tu peux le supprimer manuellement plus tard une fois confirme que tout fonctionne a nouveau normalement, sinon il s'accumule au fil des utilisations repetees de cette commande." }
                @{ Label = "Analyser le magasin de composants"
                   Cmd   = 'DISM /Online /Cleanup-Image /AnalyzeComponentStore'
                   Desc  = "Analyse le dossier WinSxS et indique si un nettoyage (StartComponentCleanup) est recommande, avec l'espace recuperable estime."
                   Confirm = $false }
                @{ Label = "Forcer un scan Windows Update"
                   Cmd   = 'UsoClient StartScan'
                   Desc  = "Declenche un scan immediat de disponibilite des mises a jour, sans toucher aux services ni au cache. Plus leger qu'un reset complet."
                   Confirm = $false }
                @{ Label = "Reset Microsoft Store"
                   Cmd   = 'wsreset.exe'
                   Desc  = "Vide le cache du Microsoft Store (aucune fenetre ne s'affiche, l'app se ferme puis se rouvre au bout de quelques secondes). Corrige les blocages de telechargement/mise a jour d'apps Store."
                   Confirm = $false }
                @{ Label = "Dernieres mises a jour installees"
                   Cmd   = 'powershell -NoExit -Command Get-HotFix ^| Sort-Object InstalledOn -Descending ^| Select-Object -First 10 ^| Format-Table -AutoSize'
                   Desc  = "Liste les 10 dernieres mises a jour Windows installees avec leur date. Pratique pour verifier ce qui a change juste avant l'apparition d'un probleme."
                   Confirm = $false }
                @{ Label = "Commande Regedit Windows Update"
                   Cmd   = 'powershell -NoExit -Command $key = ''HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate''; if (Test-Path $key) { Get-ItemProperty $key ^| Format-List * } else { Write-Host ''Cle de policy Windows Update absente (aucune strategie appliquee).'' -ForegroundColor Yellow }'
                   Desc  = "Affiche toutes les valeurs de registre sous la cle de policy Windows Update, pour verifier qu'une modification (GPO, script, reglage manuel) est bien active. Message clair si la cle n'existe pas sur la machine (aucune strategie appliquee), plutot qu'une erreur bloquante."
                   Confirm = $false }
                @{ Label = "Historique des erreurs Windows Update"
                   Cmd   = 'powershell -NoExit -Command try { Get-WinEvent -FilterHashtable @{LogName=''Microsoft-Windows-WindowsUpdateClient/Operational'';Level=2} -MaxEvents 10 ^| Select-Object TimeCreated,Id,Message ^| Format-List } catch { Write-Host ''Aucune erreur Windows Update trouvee dans le journal.'' -ForegroundColor Green }'
                   Desc  = "Liste les 10 dernieres erreurs (niveau Erreur uniquement) du journal Windows Update, avec leur message complet. Complementaire a 'Dernieres mises a jour installees' : celle-la dit ce qui a reussi, celle-ci dit ce qui a echoue et pourquoi. Message clair si aucune erreur n'est trouvee, plutot qu'une erreur bloquante sur un journal vide."
                   Confirm = $false }
            )
        }
        @{
            Name = "Performance"
            Commands = @(
                @{ Label = "Top processus CPU"
                   Cmd   = 'powershell -NoExit -Command Get-Process ^| Sort-Object CPU -Descending ^| Select-Object -First 15 Name,CPU,Id ^| Format-Table -AutoSize'
                   Desc  = "Liste les 15 processus consommant le plus de CPU depuis leur lancement. Utile pour reperer ce qui ralentit la machine sur le moment."
                   Confirm = $false }
                @{ Label = "Top processus RAM"
                   Cmd   = 'powershell -NoExit -Command Get-Process ^| Sort-Object WS -Descending ^| Select-Object -First 15 Name,@{N=''RAM(MB)'';E={[math]::Round($_.WS/1MB)}},Id ^| Format-Table -AutoSize'
                   Desc  = "Liste les 15 processus consommant le plus de memoire vive. Pratique pour traquer une fuite memoire ou une appli trop gourmande."
                   Confirm = $false }
                @{ Label = "Applications au demarrage"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_StartupCommand ^| Select-Object Name,Command,Location ^| Format-Table -AutoSize'
                   Desc  = "Liste les programmes configures pour se lancer automatiquement au demarrage de Windows. Utile pour reperer ce qui ralentit le boot."
                   Confirm = $false }
                @{ Label = "Temps de demarrage detaille"
                   Cmd   = 'powershell -NoExit -Command try { Get-WinEvent -FilterHashtable @{LogName=''Microsoft-Windows-Diagnostics-Performance/Operational'';Id=100} -MaxEvents 5 ^| Select-Object TimeCreated,Message ^| Format-List } catch { Write-Host ''Aucun evenement de temps de demarrage trouve dans le journal.'' -ForegroundColor Yellow }'
                   Desc  = "Affiche la duree detaillee des 5 derniers demarrages Windows via le journal Diagnostics-Performance, complementaire a 'Applications au demarrage' qui liste plutot ce qui se lance. Message clair si le journal ne contient aucun evenement correspondant, plutot qu'une erreur bloquante (meme logique defensive que le fix historique sur Get-PnpDevice)."
                   Confirm = $false }
                @{ Label = "Score global du PC (WinSAT)"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_WinSAT ^| Select-Object CPUScore,D3DScore,DiskScore,GraphicsScore,MemoryScore,WinSPRLevel,@{N=''Etat'';E={switch($_.WinSATAssessmentState){0{''Inconnu''};1{''Valide''};2{''Invalide (materiel modifie)''};3{''Non disponible''};4{''Invalide''};default{''Inconnu''}}}} ^| Format-List'
                   Desc  = "Scores WinSAT par composant (CPU, D3D=3D/gaming, Disque, Graphics=rendu 2D bureau, Memoire) plus le score global WinSPRLevel (= le plus bas des sous-scores, le vrai goulot d'etranglement). Champ 'Etat' traduit en clair : 'Valide' signifie une evaluation a jour et coherente avec le materiel actuel. Sur une config hybride Intel/NVIDIA, un ecart entre D3DScore et GraphicsScore est normal (deux puces graphiques differentes sollicitees). Ne se met a jour automatiquement que rarement (depuis Windows 8.1) - relancer 'winsat formal' manuellement apres un changement materiel majeur si le score semble incoherent ou si Etat n'est pas 'Valide'."
                   Confirm = $false }
                @{ Label = "Erreurs systeme recentes"
                   Cmd   = 'powershell -NoExit -Command try { Get-WinEvent -FilterHashtable @{LogName=''System'';Level=1,2} -MaxEvents 10 ^| Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message ^| Format-List } catch { Write-Host ''Aucune erreur/critique recente trouvee dans le journal System.'' -ForegroundColor Green }'
                   Desc  = "Liste les 10 derniers evenements de niveau Critique ou Erreur du journal System. Complement leger et rapide, pas un remplacement d'Analyze-WindowsLogs (qui reste l'outil de reference pour une vraie analyse avec badges MITRE, detection de pics, filtrage des sources bruyantes connues). Message clair si aucun evenement correspondant n'est trouve."
                   Confirm = $false }
                @{ Label = "Applications au demarrage (taches planifiees)"
                   Cmd   = 'powershell -NoExit -Command Get-ScheduledTask ^| Where-Object { $_.State -eq ''Ready'' -and $_.Triggers.CimClass.CimClassName -contains ''MSFT_TaskLogonTrigger'' } ^| Select-Object TaskName,TaskPath ^| Format-Table -AutoSize'
                   Desc  = "Liste les taches planifiees configurees pour se lancer a la connexion. Complementaire a 'Applications au demarrage' (qui ne couvre que le dossier Demarrage et les cles Run du registre) : beaucoup de logiciels (mises a jour, agents divers) utilisent plutot une tache planifiee, un angle mort courant si on ne regarde que l'un ou l'autre."
                   Confirm = $false }
                @{ Label = "Etat virtualisation materielle (Hyperviseur / VBS)"
                   Cmd   = 'powershell -NoExit -Command $hv = if ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent) { ''Oui'' } else { ''Non'' }; Write-Host (''Hyperviseur present : '' + $hv) -ForegroundColor Green; try { $dg = Get-CimInstance -Namespace ''root\Microsoft\Windows\DeviceGuard'' -ClassName Win32_DeviceGuard -ErrorAction Stop; Write-Host (''VirtualizationBasedSecurityStatus (VBS) : '' + $dg.VirtualizationBasedSecurityStatus + '' (0=VBS desactive, 1=configure mais pas demarre, 2=actif)'') -ForegroundColor Green; Write-Host (''SecurityServicesConfigured : '' + ($dg.SecurityServicesConfigured -join '', '') + '' (0=aucun, 1=Credential Guard, 2=HVCI/integrite memoire, 3=System Guard, 4=SMM Firmware Measurement)'') -ForegroundColor Green; Write-Host (''SecurityServicesRunning : '' + ($dg.SecurityServicesRunning -join '', '') + '' (0=aucun, 1=Credential Guard, 2=HVCI/integrite memoire, 3=System Guard, 4=SMM Firmware Measurement)'') -ForegroundColor Green } catch { Write-Host ''Info VBS (Device Guard) non disponible sur cette edition/version de Windows.'' -ForegroundColor Yellow }'
                   Desc  = "Indique si un hyperviseur (Hyper-V, VBS...) tourne actuellement (Oui/Non), l'etat natif de VirtualizationBasedSecurityStatus (VBS) avec sa legende, et le detail des services de securite configures et actifs par-dessus (Credential Guard, HVCI, System Guard...). Important : VirtualizationBasedSecurityStatus=2 confirme seulement que la couche VBS de base tourne, pas que HVCI (valeur 2 dans SecurityServicesRunning) en fait partie - les deux sont independants, la premiere est un niveau (0/1/2), les deux autres sont des listes d'identifiants de services distincts (pas une echelle). System Guard Secure Launch (valeur 3) peut etre absent sur du materiel avec un firmware anterieur a 2019 (echec typique de liaison PCR 7), meme si VBS et HVCI eux-memes peuvent tourner normalement. Message clair si la classe DeviceGuard n'existe pas sur cette edition de Windows, plutot qu'une erreur bloquante."
                   Confirm = $false
                   Help  = "SecurityServicesConfigured / SecurityServicesRunning ne sont PAS une echelle de niveau : chaque numero designe un service DIFFERENT, plusieurs peuvent apparaitre en meme temps (ex: '1, 2' = Credential Guard ET HVCI actifs ensemble).`n`n1 = Credential Guard`nIsole le processus qui gere les identifiants Windows (mots de passe en cache, tickets Kerberos) dans un conteneur virtualise separe. Protege contre le vol d'identifiants (pass-the-hash). Cible surtout les machines jointes a un domaine d'entreprise - peu utile en usage personnel.`n`n2 = HVCI / Integrite de la memoire`nVerifie que le code execute en mode noyau est signe et non modifie. Bloque l'injection de code malveillant via un pilote compromis.`n`n3 = System Guard Secure Launch`nVerifie cryptographiquement, via le TPM et une mesure materielle du demarrage (DRTM), que le firmware n'a pas ete altere avant meme que VBS ne demarre. Peut etre absent sur du materiel avec un firmware anterieur a 2019 (echec typique de liaison PCR 7), independamment de l'etat de VBS/HVCI.`n`n4 = SMM Firmware Measurement`nSurveille le SMM (System Management Mode), un mode CPU ultra-privilegie utilise par le firmware, historiquement cible par des rootkits tres furtifs. Plutot oriente entreprise/materiel certifie." }
                @{ Label = "Desactiver Memory Integrity (HVCI)"
                   Cmd   = 'reg add HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity /v Enabled /t REG_DWORD /d 0 /f'
                   Desc  = "ATTENTION : desactive Memory Integrity (HVCI), la protection qui isole le noyau Windows contre les rootkits/malwares bas niveau. Meme bascule que Windows Security > Securite de l'appareil > Isolation du noyau > Integrite de la memoire, via le registre. NECESSITE UN REDEMARRAGE pour prendre effet - rien ne change avant le prochain reboot. But : recuperer les quelques pourcents de FPS perdus (environ 8% de moyenne mesuree sur du materiel recent, variable selon le jeu) sur du jeu solo sans anti-triche qui exige HVCI actif. Reactivable avec 'Reactiver Memory Integrity (HVCI)' juste en dessous. N'affecte pas VBS dans son ensemble : Credential Guard et les autres services restent inchanges."
                   Confirm = $true
                   Help  = "Mecanisme precis : HVCI s'appuie sur l'hyperviseur pour empecher qu'une meme page de memoire soit a la fois modifiable ET executable en meme temps - une technique qui bloque une large classe d'exploits cherchant a injecter du code malveillant directement dans le noyau Windows via un pilote vulnerable ou compromis.`n`nCe que ca engendre concretement en le desactivant : le noyau redevient protege uniquement par les mecanismes plus anciens (signature de pilotes classique, sans la verification renforcee par l'hyperviseur). Le risque reel reste mesure : ca ne rend pas la machine vulnerable en soi, ca retire une couche de defense en profondeur specifiquement efficace contre les attaques niveau noyau - qui restent rares en usage personnel compare a du phishing ou des malwares classiques deja bloques par Defender.`n`nLa cle de registre ne prend effet qu'au prochain redemarrage - lancer cette commande seule, sans redemarrer, ne change rien immediatement. Le catalogue contient 'Reactiver Memory Integrity (HVCI)' juste en dessous pour revenir en arriere, avec le meme besoin de redemarrage." }
                @{ Label = "Reactiver Memory Integrity (HVCI)"
                   Cmd   = 'reg add HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity /v Enabled /t REG_DWORD /d 1 /f'
                   Desc  = "Reactive Memory Integrity (HVCI) apres un test de performance gaming, restaurant la protection contre les rootkits/malwares bas niveau. NECESSITE UN REDEMARRAGE pour prendre effet. A lancer une fois le test de FPS termine, pour ne pas laisser la machine sans cette protection plus longtemps que necessaire."
                   Confirm = $true
                   Help  = "Remet la meme cle de registre a sa valeur active (Enabled=1). Comme pour la desactivation, rien ne change avant le prochain redemarrage - la protection reste absente jusque-la, meme apres avoir lance cette commande. Sans effet secondaire ni perte de donnees : c'est une bascule reversible a l'identique, pas une reinstallation ou une reparation." }
                @{ Label = "Desactiver VBS (Virtualization-Based Security)"
                   Cmd   = 'reg add HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f'
                   Desc  = "ATTENTION : desactive VBS dans son ensemble (la couche hyperviseur de base sur laquelle HVCI et les autres services de securite reposent), pas juste HVCI seul. Ca revient a empecher l'hyperviseur de se charger au demarrage (aucun gain supplementaire a couper l'hyperviseur separement via bcdedit). NECESSITE UN REDEMARRAGE pour prendre effet. Casse ou desactive Hyper-V, WSL2, l'acceleration VMware/VirtualBox, les emulateurs Android et Docker Desktop si ces outils sont utilises sur la machine. Gain potentiel plus large que HVCI seul (jusqu'a 15% mesure sur certaines taches selon Tom's Hardware), mais une bonne partie de cet ecart est deja capturee par la desactivation de HVCI seule - teste et compare avant de conclure a un vrai gain supplementaire. Reactivable avec 'Reactiver VBS' juste en dessous."
                   Confirm = $true
                   Help  = "Mecanisme precis : cette cle coupe la couche hyperviseur elle-meme (basee sur les extensions VT-x du CPU), le socle sur lequel VBS et donc HVCI reposent tous les deux. Sans cette fondation, aucun service de securite qui en depend ne peut fonctionner, quel que soit son propre reglage individuel.`n`nCe que ca engendre concretement, au-dela de HVCI : contrairement a la desactivation de HVCI seul (qui ne touche qu'un service precis), celle-ci retire la possibilite meme d'utiliser Hyper-V, WSL2, l'acceleration materielle de VMware/VirtualBox, les emulateurs Android (type BlueStacks en mode hardware) ou Docker Desktop - ces outils ont besoin de l'hyperviseur pour fonctionner et refuseraient simplement de demarrer tant que VBS est coupe. Verifie si l'un de ces usages est actif sur la machine avant de desactiver.`n`nPoint de vigilance trouve dans des retours d'autres utilisateurs (pas garanti sur toutes les machines) : sur certaines configurations, ce reglage se reactive tout seul apres redemarrage a cause d'une politique de groupe ou d'un verrouillage constructeur - plus frequent sur une machine jointe a un domaine d'entreprise. Si le reglage ne 'tient' pas apres redemarrage, ce serait le signal a creuser plutot qu'un signe que la commande a echoue." }
                @{ Label = "Reactiver VBS (Virtualization-Based Security)"
                   Cmd   = 'reg add HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f'
                   Desc  = "Reactive VBS dans son ensemble apres un test de performance gaming, restaurant la fondation sur laquelle HVCI et les autres protections reposent. NECESSITE UN REDEMARRAGE pour prendre effet. Si HVCI etait actif avant la desactivation de VBS, il redevient actif automatiquement (sa propre cle de registre n'est pas touchee par cette commande)."
                   Confirm = $true
                   Help  = "Remet la cle EnableVirtualizationBasedSecurity a 1, restaurant l'hyperviseur et donc la possibilite pour VBS/HVCI de fonctionner a nouveau. Comme pour HVCI seul, aucun effet avant le prochain redemarrage. Puisque la cle HVCI elle-meme (Scenarios\\HypervisorEnforcedCodeIntegrity) n'est pas touchee par cette commande, l'etat d'avant (actif ou non) revient automatiquement une fois VBS de nouveau disponible - pas besoin de relancer 'Reactiver Memory Integrity (HVCI)' separement si tu ne l'avais pas explicitement desactive de son cote." }
            )
        }
        @{
            Name = "Pilotes / Materiel"
            Commands = @(
                @{ Label = "Peripheriques en erreur"
                   Cmd   = 'powershell -NoExit -Command $err = Get-PnpDevice ^| Where-Object Status -eq ''Error''; if ($err) { $err ^| Format-Table -AutoSize } else { Write-Host ''Aucun peripherique en erreur detecte.'' -ForegroundColor Green }'
                   Desc  = "Liste les peripheriques signales en erreur dans le Gestionnaire de peripheriques (pilote manquant ou defaillant). Diagnostic rapide, sans lancer tout Check-Drivers. Affiche un message si aucun n'est en erreur (au lieu de planter, comportement connu de -Status Error sur un resultat vide)."
                   Confirm = $false }
                @{ Label = "Etat GPU NVIDIA (nvidia-smi)"
                   Cmd   = 'nvidia-smi'
                   Desc  = "Affiche l'etat du GPU NVIDIA : temperature, utilisation, memoire VRAM utilisee, version du pilote. Necessite que nvidia-smi soit dans le PATH (installe avec le pilote NVIDIA)."
                   Confirm = $false }
                @{ Label = "GPU detectes (Intel + NVIDIA)"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_VideoController ^| Select-Object Name,DriverVersion,AdapterRAM ^| Format-Table -AutoSize'
                   Desc  = "Liste les GPU detectes par Windows, utile sur une config hybride Intel HD 630 + NVIDIA GTX 1050 pour voir lesquels sont exposes. Attention : AdapterRAM est un champ WMI limite a 32 bits, qui peut afficher une valeur incorrecte ou negative sur une carte avec 4 Go de VRAM ou plus (limitation connue, pas un bug de cette commande) - pour la VRAM reelle de la carte NVIDIA, se fier plutot a 'Etat GPU NVIDIA (nvidia-smi)' ci-dessus."
                   Confirm = $false }
                @{ Label = "Info BIOS / carte mere"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_BIOS ^| Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate ^| Format-List'
                   Desc  = "Affiche le fabricant, la version et la date de sortie du BIOS/UEFI actuellement installe. Pratique pour verifier rapidement avant de comparer avec la derniere version disponible sur le site ASUS."
                   Confirm = $false }
                @{ Label = "RAM installee (barrettes)"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_PhysicalMemory ^| Select-Object Manufacturer,@{N=''Capacite(Go)'';E={[math]::Round($_.Capacity/1GB,1)}},Speed,DeviceLocator ^| Format-Table -AutoSize'
                   Desc  = "Liste chaque barrette de RAM installee avec sa capacite (convertie en Go, pas en octets bruts), sa frequence reelle (MHz) et son slot (DeviceLocator). Utile pour verifier combien de slots sont occupes sur les 16 Gio, et si la frequence reelle correspond a ce qui est attendu (parfois inferieure au XMP/JEDEC max sans profil active)."
                   Confirm = $false }
                @{ Label = "Pilotes recemment installes"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_PnPSignedDriver ^| Where-Object { $_.DriverDate } ^| Sort-Object DriverDate -Descending ^| Select-Object -First 15 DeviceName,DriverVersion,DriverDate ^| Format-Table -AutoSize'
                   Desc  = "Liste les 15 pilotes les plus recemment installes, tries par date. Complementaire a 'Peripheriques en erreur' : celle-ci dit ce qui ne va pas maintenant, celle-la aide a corriger un probleme recent avec une mise a jour de pilote qui vient de se produire."
                   Confirm = $false }
                @{ Label = "Peripheriques USB connectes"
                   Cmd   = 'powershell -NoExit -Command Get-PnpDevice -PresentOnly ^| Where-Object { $_.InstanceId -like ''USB\*'' } ^| Select-Object FriendlyName,Status,Class ^| Sort-Object Class ^| Format-Table -AutoSize'
                   Desc  = "Liste tout ce qui est actuellement connecte sur le bus USB (filtre sur l'InstanceId, pas seulement la classe 'USB'), donc inclut aussi bien les hubs que les souris, claviers ou disques externes branches en USB - contrairement a un filtre par Class qui manquerait la plupart des peripheriques USB reels."
                   Confirm = $false }
                @{ Label = "Peripheriques audio"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_SoundDevice ^| Select-Object Name,Manufacturer,Status ^| Format-Table -AutoSize'
                   Desc  = "Liste les peripheriques audio detectes (carte son integree, casque/DAC USB, etc.) avec leur statut. Rien d'autre dans le catalogue ne couvrait l'audio jusqu'ici, alors que les soucis de pilote son sont frequents."
                   Confirm = $false }
            )
        }
        @{
            Name = "Securite rapide"
            Commands = @(
                @{ Label = "Etat Windows Defender"
                   Cmd   = 'powershell -NoExit -Command Get-MpComputerStatus ^| Format-List AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated,QuickScanAge'
                   Desc  = "Vue rapide de l'etat de Windows Defender (protection active, date de la derniere signature, age du dernier scan rapide), sans lancer l'audit complet Check-Security."
                   Confirm = $false }
                @{ Label = "Verification Services"
                   Cmd   = 'powershell -NoExit -Command Get-Service DiagTrack,dmwappushservice,DoSvc,WerSvc,CDPSvc,WSearch ^| Select-Object Name,Status,StartType ^| Format-Table -AutoSize'
                   Desc  = "Verifie l'etat (Running/Stopped) et le mode de demarrage de six services cles lies a la telemetrie et au tracking (DiagTrack, dmwappushservice, Delivery Optimization, Windows Error Reporting, Connected Devices Platform, Windows Search). Utile pour confirmer qu'un durcissement (registre, GPO) est bien effectif au niveau des services eux-memes."
                   Confirm = $false }
                @{ Label = "Verification Pare-feu"
                   Cmd   = 'powershell -NoExit -Command Get-NetFirewallProfile ^| Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction ^| Format-Table -AutoSize; netsh advfirewall show allprofiles state; Get-Service MpsSvc ^| Select-Object Name,Status ^| Format-Table -AutoSize'
                   Desc  = "Verifie l'etat du pare-feu Windows sur trois niveaux : profils actifs (Domaine/Prive/Public), politique reelle par defaut via netsh (plus fiable que 'NotConfigured' de Get-NetFirewallProfile qui peut etre trompeur), et etat du service sous-jacent MpsSvc. Les trois doivent etre coherents pour confirmer une protection reellement active."
                   Confirm = $false }
                @{ Label = "Etat Secure Boot / TPM"
                   Cmd   = 'powershell -NoExit -Command try { $sb = Confirm-SecureBootUEFI; Write-Host ''Secure Boot :'' $sb } catch { Write-Host ''Secure Boot : non applicable (mode BIOS Legacy, pas UEFI).'' -ForegroundColor Yellow }; Get-Tpm ^| Select-Object TpmPresent,TpmReady,TpmEnabled ^| Format-Table -AutoSize'
                   Desc  = "Verifie rapidement l'etat de Secure Boot et du TPM sans lancer tout Check-Security. Message clair si la machine est en BIOS Legacy plutot qu'une erreur bloquante (Confirm-SecureBootUEFI echoue sur un systeme non-UEFI). TpmPresent = False signale l'absence de puce TPM active ou fonctionnelle sur la machine - a rapprocher d'un eventuel FAIL BitLocker structurel si c'est le cas, plutot qu'a corriger via cette seule commande."
                   Confirm = $false }
                @{ Label = "Comptes locaux et administrateurs"
                   Cmd   = 'powershell -NoExit -Command Get-LocalUser ^| Select-Object Name,Enabled,LastLogon ^| Format-Table -AutoSize; Get-LocalGroupMember -SID ''S-1-5-32-544'' ^| Select-Object Name,PrincipalSource ^| Format-Table -AutoSize'
                   Desc  = "Liste les comptes locaux (actifs/desactives, dernier logon) puis les membres du groupe Administrateurs via son SID fixe (S-1-5-32-544) plutot que son nom localise - fonctionne donc identiquement sur une machine Windows en anglais ou en francais. Verifie qu'aucun compte inattendu n'a les droits admin, meme logique que le controle RID-500 de Check-Security."
                   Confirm = $false }
                @{ Label = "Tentatives de connexion echouees"
                   Cmd   = 'powershell -NoExit -Command try { Get-WinEvent -FilterHashtable @{LogName=''Security'';Id=4625} -MaxEvents 10 ^| Select-Object TimeCreated,Message ^| Format-List } catch { Write-Host ''Aucune tentative de connexion echouee trouvee dans le journal Security.'' -ForegroundColor Green }'
                   Desc  = "Liste les 10 dernieres tentatives de connexion echouees (evenement 4625 du journal Security). Complementaire a 'Comptes locaux et administrateurs' : celle-la montre qui a le droit, celle-ci montre qui a essaye et echoue - un indicateur simple de tentative de bruteforce local. Message clair si le journal ne contient aucun evenement correspondant, plutot qu'une erreur bloquante."
                   Confirm = $false }
            )
        }
        @{
            Name = "Divers"
            Commands = @(
                @{ Label = "Rapport batterie"
                   Cmd   = 'powercfg /batteryreport /output %USERPROFILE%\Desktop\battery-report.html && start %USERPROFILE%\Desktop\battery-report.html'
                   Desc  = "Genere un rapport HTML detaille sur l'usure de la batterie (capacite actuelle vs capacite d'origine, historique d'utilisation) et l'ouvre automatiquement."
                   Confirm = $false }
                @{ Label = "Rapport diagnostic energie"
                   Cmd   = 'powercfg /energy /output %USERPROFILE%\Desktop\energy-report.html && start %USERPROFILE%\Desktop\energy-report.html'
                   Desc  = "Analyse le systeme pendant 60 secondes et genere un rapport sur les problemes d'alimentation/veille (pilotes qui empechent la mise en veille, erreurs USB, etc.)."
                   Confirm = $false }
                @{ Label = "Charge CPU instantanee"
                   Cmd   = 'powershell -NoExit -Command Get-CimInstance Win32_Processor ^| Select-Object LoadPercentage'
                   Desc  = "Affiche le pourcentage d'utilisation CPU au moment de l'execution. Un instantane simple, pas un suivi en continu."
                   Confirm = $false }
                @{ Label = "Espace disque (Get-Volume)"
                   Cmd   = 'powershell -NoExit -Command Get-Volume'
                   Desc  = "Liste toutes les partitions avec leur espace libre/total dans un format lisible, plus rapide a lire qu'un explorateur de fichiers."
                   Confirm = $false }
                @{ Label = "Etats d'alimentation disponibles"
                   Cmd   = 'powercfg /a'
                   Desc  = "Indique quels etats de veille/hibernation sont disponibles sur la machine, et pourquoi certains sont indisponibles si c'est le cas (utile pour diagnostiquer S3/Modern Standby)."
                   Confirm = $false }
                @{ Label = "Redemarrer le PC"
                   Cmd   = 'shutdown /r /t 0'
                   Desc  = "ATTENTION : redemarre la machine IMMEDIATEMENT, sans delai. Ferme toutes les applications ouvertes sans confirmation prealable de leur part."
                   Confirm = $true
                   Help  = "Difference importante avec un redemarrage classique depuis le menu Demarrer : celui-ci utilise /t 0 (delai de 0 seconde), donc Windows ne laisse PAS le temps aux applications ouvertes de proposer d'enregistrer leur travail en cours - contrairement au redemarrage normal qui affiche generalement une invite 'voulez-vous enregistrer ?' pour chaque application concernee avant de fermer.`n`nCe que ca implique concretement : tout document non enregistre au moment du clic (fichier Office, code en cours d'edition, formulaire web rempli...) est perdu, sans avertissement. A utiliser seulement quand tu es certain d'avoir sauvegarde ton travail en cours, ou pour un redemarrage volontairement rapide sans etat des lieux prealable." }
                @{ Label = "Eteindre le PC"
                   Cmd   = 'shutdown /s /t 0'
                   Desc  = "ATTENTION : eteint la machine IMMEDIATEMENT, sans delai. Ferme toutes les applications ouvertes sans confirmation prealable de leur part."
                   Confirm = $true
                   Help  = "Meme logique que 'Redemarrer le PC' mais pour un arret complet : /t 0 signifie aucun delai, donc aucune invite d'enregistrement pour les applications ouvertes avant la fermeture. Tout document non sauvegarde au moment du clic est perdu.`n`nDifference avec la mise en veille : ceci est un arret complet (l'alimentation coupee), pas une mise en veille - au prochain demarrage, Windows redemarre entierement plutot que de reprendre instantanement la ou tu en etais. A utiliser en connaissance de cause si tu as du travail en cours non sauvegarde." }
                @{ Label = "Rapport DirectX (dxdiag)"
                   Cmd   = 'dxdiag /t %TEMP%\dxdiag.txt && notepad %TEMP%\dxdiag.txt'
                   Desc  = "Genere le rapport de diagnostic DirectX (GPU, pilotes, DirectX supporte) et l'ouvre dans le Bloc-notes. Utile pour du depannage gaming."
                   Confirm = $false }
                @{ Label = "Etat activation Windows"
                   Cmd   = 'slmgr /xpr'
                   Desc  = "Affiche l'etat d'activation de Windows (licence active ou non) dans une fenetre popup (comportement natif de slmgr, pas une erreur si la console reste vide en dessous)."
                   Confirm = $false }
                @{ Label = "Vider la corbeille"
                   Cmd   = 'powershell -NoExit -Command Clear-RecycleBin -Confirm:$false; Write-Host ''Corbeille videe.'' -ForegroundColor Green'
                   Desc  = "ATTENTION : supprime definitivement tout le contenu de la Corbeille, sans possibilite de recuperation. Verifie son contenu avant de lancer si un doute existe."
                   Confirm = $true
                   Help  = "Clear-RecycleBin vide la Corbeille de TOUS les disques de la machine en une seule fois (pas seulement C:), pas de selection possible fichier par fichier depuis cette commande. Les fichiers ne sont pas deplaces ailleurs ni archives - ils sont effaces au sens ou l'espace disque qu'ils occupaient est marque comme libre et reutilisable, sans passer par un second niveau de recuperation.`n`nCe que ca implique concretement : contrairement a un simple glisser-deposer vers la Corbeille (recuperable), cette action est reellement irreversible dans le fonctionnement normal de Windows - seul un outil specialise de recuperation de donnees (qui recherche les traces sur le disque avant qu'elles soient reecrites par de nouveaux fichiers) pourrait eventuellement recuperer quelque chose, sans garantie. Si un fichier recemment supprime pourrait encore avoir de la valeur, verifie le contenu de la Corbeille avant de lancer cette commande plutot qu'apres." }
                @{ Label = "Informations systeme generales"
                   Cmd   = 'powershell -NoExit -Command $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem; $reg = Get-ItemProperty ''HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion''; [PSCustomObject]@{OS=$os.Caption;Version=$reg.DisplayVersion;Build=($os.BuildNumber.ToString() + ''.'' + $reg.UBR.ToString());Fabricant=$cs.Manufacturer;Modele=$cs.Model;DateInstallation=$os.InstallDate} ^| Format-List'
                   Desc  = "Carte d'identite rapide de la machine (edition Windows, version, build, fabricant, modele, date d'installation). Utilise Win32_OperatingSystem.Caption + le registre DisplayVersion/UBR plutot que WindowsProductName (bug Microsoft connu et jamais corrige : la cle de registre ProductName reste figee sur 'Windows 10 [Edition]' meme sur une installation Windows 11 a jour - Get-ComputerInfo herite de ce defaut)."
                   Confirm = $false }
                @{ Label = "Ouvrir Rapports_Maintenance"
                   Cmd   = 'explorer %USERPROFILE%\Desktop\Rapports_Maintenance'
                   Desc  = "Ouvre directement le dossier ou atterrissent tous les rapports HTML/JSON generes par la suite de scripts de maintenance."
                   Confirm = $false }
                @{ Label = "Version PowerShell active"
                   Cmd   = 'powershell -NoExit -Command $PSVersionTable; (Get-Command powershell.exe).Source'
                   Desc  = "Affiche la version exacte de PowerShell resolue par 'powershell.exe' sur cette machine, plus le chemin complet de l'executable utilise. Utile pour verifier rapidement si powershell.exe pointe vers PowerShell 7 ou Windows PowerShell 5.1 natif (les deux peuvent coexister selon le PATH)."
                   Confirm = $false }
                @{ Label = "Variables d'environnement"
                   Cmd   = 'powershell -NoExit -Command Get-ChildItem Env: ^| Sort-Object Name ^| Format-Table -AutoSize'
                   Desc  = "Liste toutes les variables d'environnement actives (PATH, TEMP, USERPROFILE, etc.), triees par nom. Diagnostic basique mais pratique pour verifier rapidement une valeur de PATH ou une variable custom sans ouvrir les proprietes systeme."
                   Confirm = $false }
            )
        }
    )
}
