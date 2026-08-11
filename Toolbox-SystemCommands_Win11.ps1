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
    Version  : 2.5.3
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

    v2.3.0 : refonte de l'export HTML (Export-History). Colonnes PC/Utilisateur retirees du
    tableau (identiques sur quasi toutes les lignes) et deplacees dans l'entete. Prefixe
    redondant 'powershell -NoExit -Command' retire de la colonne Detail ; commandes de plus
    de 120 caracteres repliees derriere un <details>/<summary> ('Voir la commande complete').
    Regroupement visuel par jour (sous-en-tete de date). Commandes sensibles (Confirm=$true
    dans Commands.psd1) surlignees en orange, via un nouveau HashSet global $confirmLabels
    alimente au chargement du catalogue - permet a Export-History (fonction globale) de
    connaitre le flag Confirm de chaque commande sans re-parser Commands.psd1 ni dependre de
    $commandGroups (portee script, invisible depuis une fonction globale). Barre de recherche
    JavaScript integree au rapport exporte (filtre les lignes en direct, sans dependance
    externe). -SelfTest passe a 38 assertions.

    v2.4.0 : support d'un second catalogue OPTIONNEL, Commands.Personnel.psd1, meme dossier
    et meme format que Commands.psd1 - mais non destine a etre partage entre machines
    (contrairement au catalogue principal). S'il est absent, aucun impact : le catalogue
    principal fonctionne seul, sans erreur ni avertissement. S'il est present mais invalide,
    avertissement non bloquant (le catalogue principal reste charge normalement). Permet de
    garder des commandes propres a une machine precise (ex: gestion de taches planifiees
    jugees inutiles apres analyse) hors du catalogue portable. -SelfTest passe a 39
    assertions (verifie que Commands.Personnel.psd1, absent ou present-et-valide, ne bloque
    jamais le chargement).

    v2.4.1 : ajout dans Commands.psd1 (categorie "Integrite systeme") du pack "Pack Integrite
    complet (CHKDSK+DISM+SFC)" - enchaine CHKDSK C: /scan, DISM CheckHealth, DISM ScanHealth
    puis SFC /scannow en une seule commande, dans l'ordre recommande (disque -> magasin de
    composants -> fichiers systeme, SFC beneficiant d'un magasin deja verifie par DISM).
    Chainage volontairement en '&' (execution inconditionnelle) et non '&&', pour que les 4
    etapes s'executent toujours meme si une etape precedente detecte une anomalie (CHKDSK
    /scan par exemple renvoie un code de sortie non-nul des qu'une irregularite est detectee,
    meme sans rien corriger) - avec '&&' la chaine se serait arretee net a la premiere
    anomalie. Reperes visuels "=== ... ===" via echo entre chaque etape pour ne rien manquer
    dans le defilement de la fenetre console unique. Nouvelle assertion -SelfTest de
    regression verifiant que ce pack reste chaine avec '&' et ne contient jamais '&&'.
    -SelfTest passe a 40 assertions.

    v2.4.2 : correction d'un defaut de securite dans le "Pack Integrite complet" (v2.4.1) -
    le chainage inconditionnel '&' lancait SFC /scannow meme si DISM ScanHealth venait de
    detecter une corruption du magasin de composants. Or ScanHealth est un DIAGNOSTIC, pas
    une reparation : SFC risquait de puiser ses fichiers de remplacement dans un magasin
    toujours corrompu, sans erreur visible. Remplace par un garde-fou explicite via
    Repair-WindowsImage -Online -ScanHealth (module DISM PowerShell, deja utilise ailleurs
    dans le catalogue) et sa propriete structuree ImageHealthState (Healthy/Repairable/
    NonRepairable) - fiable et independante de la langue du systeme, contrairement a un
    parsing du texte affiche par dism.exe. SFC ne se lance desormais que si le magasin est
    confirme sain ; sinon le pack s'arrete avant SFC avec un message invitant a lancer DISM
    RestoreHealth manuellement au prealable. Assertion -SelfTest de regression mise a jour en
    consequence (verifie la presence du garde-fou ImageHealthState, plus seulement la
    presence du chainage '&'). -SelfTest reste a 40 assertions.

    v2.4.3 : amelioration de la lisibilite console du "Pack Integrite complet" - chaque etape
    (CHKDSK, DISM CheckHealth, DISM ScanHealth, SFC ou le message d'arret) est desormais
    precedee de 2 lignes vides (deux appels Write-Host sans argument, pour eviter toute
    sequence d'echappement `n incompatible avec la regle guillemets-simples-uniquement du
    champ Cmd) et d'un en-tete en Cyan, pour reperer immediatement chaque bloc dans le long
    defilement de sortie CHKDSK/DISM/SFC. Ajout d'un en-tete "=== CHKDSK C: /scan ===" qui
    manquait a l'etape 1 (seule etape sans annonce visuelle jusqu'ici). -SelfTest reste a 40
    assertions (pas de nouvelle assertion : changement purement cosmetique, deja couvert par
    l'assertion existante sur la presence du garde-fou ImageHealthState).

    v2.4.4 : correction de l'assertion -SelfTest ajoutee en v2.4.2 (faux [FAIL] alors que le
    pack lui-meme est correct). Le regex testait la presence de ''Healthy'' (guillemets
    doubles) dans $packIntegrite.Cmd, en confondant deux niveaux d'echappement distincts :
    ''Healthy'' est l'ecriture BRUTE dans le fichier Commands.psd1 (doublage requis par la
    syntaxe .psd1 pour representer un guillemet simple litteral), mais Import-PowerShellDataFile
    depli automatiquement ce doublage a la lecture - la valeur reelle en memoire dans
    $packIntegrite.Cmd contient 'Healthy' avec un seul guillemet de chaque cote, jamais deux.
    Regex corrige en consequence (eq\s+'Healthy' au lieu de eq\s+''Healthy''). -SelfTest
    repasse a 40/40.

    v2.4.5 : ajustements d'affichage du "Pack Integrite complet" (Commands.psd1, pas de
    changement de code dans ce script) suite a un retour visuel reel en console. Deux points :
    (1) le cyan des en-tetes passe du ConsoleColor.Cyan classique (terne selon le theme
    Windows Terminal) a un code ANSI bright cyan direct ([char]27+'[96m', reinitialise par
    [char]27+'[0m'), sans fond colore ni bandeau plein - juste un texte plus contraste. (2) La
    barre de progression animee de Repair-WindowsImage (Write-Progress) provoquait un
    decalage visuel dans conhost/Windows Terminal (elle s'affichait dans une zone fixe non
    synchronisee avec le defilement du texte CHKDSK) - corrige en desactivant l'affichage de
    progression via $ProgressPreference = 'SilentlyContinue', SANS revenir a
    'DISM /Online /Cleanup-Image /ScanHealth' classique : ce dernier n'expose son resultat
    qu'en texte localise, ce qui aurait reintroduit la dependance a la langue du systeme que
    le garde-fou ImageHealthState (v2.4.2) avait justement supprimee. -SelfTest reste a 40/40
    (assertion inchangee, toujours basee sur la presence de 'ImageHealthState' et
    "eq 'Healthy'" dans le Cmd).

    v2.4.6 : correction d'un bug bloquant dans Commands.psd1 (pas de changement de code dans
    ce script) introduit en v2.4.5 - le champ Help du "Pack Integrite complet" (en guillemets
    DOUBLES, contrairement a Cmd qui reste toujours en guillemets simples) contenait le texte
    litteral "$ProgressPreference" non echappe. En guillemets doubles, PowerShell interprete
    $ProgressPreference comme une interpolation de variable, et le mode "restricted language"
    d'Import-PowerShellDataFile interdit toute reference de variable - resultat : echec
    complet du chargement de Commands.psd1, catalogue de repli vide, cascade de 10 assertions
    -SelfTest en echec (nombre de commandes, Confirm actif sur les commandes sensibles, etc.).
    Corrige en echappant le signe dollar avec un backtick (`$ProgressPreference) pour le
    forcer en texte litteral. Rappel de la regle : Cmd doit toujours rester en guillemets
    simples (jamais d'interpolation possible, donc jamais ce risque) ; Desc et Help restent en
    guillemets doubles par convention existante, mais tout signe $ litteral qui y est ecrit
    doit systematiquement etre echappe par un backtick. Ajout d'une assertion -SelfTest de
    regression dediee qui scanne toutes les lignes Desc/Help de Commands.psd1 a la recherche
    d'un $ non precede d'un backtick, pour detecter ce type de bug avant deploiement sur les
    autres machines plutot qu'au premier -SelfTest execute dessus. -SelfTest passe a 41
    assertions.

    v2.4.7 : redesign du "Pack Integrite complet" (Commands.psd1, pas de changement de code
    dans ce script) pour simplifier et supprimer definitivement deux problemes a la source
    plutot que de les contourner. Retour a 'DISM /Online /Cleanup-Image /ScanHealth' classique
    (dism.exe natif) a la place du cmdlet PowerShell Repair-WindowsImage -ScanHealth : plus de
    barre de progression Write-Progress, donc plus de decalage visuel possible dans
    conhost/Windows Terminal (le probleme corrige en v2.4.5 par $ProgressPreference disparait
    structurellement, cette rustine n'est donc plus necessaire et est retiree). SFC passe de
    /scannow (conditionne par ImageHealthState depuis v2.4.2) a /verifyonly : SFC ne repare
    plus jamais rien automatiquement dans ce pack, il se contente de verifier - le risque
    initial ("SFC repare depuis un magasin de composants lui-meme corrompu", corrige par le
    garde-fou ImageHealthState en v2.4.2) disparait donc lui aussi structurellement, sans
    necessiter de detection fiable ni de logique conditionnelle. En cas d'anomalie signalee
    par CHKDSK, DISM ou SFC, un message jaune final rappelle simplement de lancer DISM
    RestoreHealth puis SFC /scannow manuellement (commandes separees du catalogue) - la
    reparation reste une decision humaine. CHKDSK, DISM et SFC restent des outils natifs
    invoques directement ; PowerShell ne sert plus que d'enveloppe pour l'affichage (cyan vif
    ANSI + espacement). Assertion -SelfTest mise a jour en consequence : verifie que SFC
    tourne en /verifyonly et que /scannow n'est jamais chaine comme instruction executable
    (uniquement mentionne en texte d'instruction). -SelfTest reste a 41/41.

    v2.4.8 : simplification des en-tetes du "Pack Integrite complet" (Commands.psd1, pas de
    changement de code dans ce script) - retour du code ANSI bright cyan ([char]27+'[96m',
    variables $c/$r et concatenations) vers -ForegroundColor Cyan natif de PowerShell.
    Verification faite par comparaison visuelle directe sur la machine cible : le theme
    Windows Terminal utilise rend deja le Cyan natif de facon suffisamment vive et contrastee
    (contrairement au theme par defaut "Campbell", plus terne sur ce slot de couleur), rendant
    le contournement ANSI inutile ici. Code plus court, sans variable intermediaire ni
    concatenation de chaines. Aucun changement fonctionnel (memes 4 etapes diagnostiques,
    meme comportement) - purement cosmetique/simplification. -SelfTest reste a 41/41
    (assertion inchangee, toujours basee sur /verifyonly et l'absence de /scannow chaine).

    v2.4.9 : recherche (Ctrl+F) etendue au champ Help en plus de Label/Desc, deja concatenes
    dans $entry.Search depuis la creation de cette fonctionnalite. $helpCopy etait deja
    disponible dans la portee au moment de la construction de Search (utilise juste au-dessus
    pour le bouton "?") mais jamais inclus dans la chaine de recherche elle-meme - un oubli
    plutot qu'un choix, corrige en une ligne. Devient utile avec un catalogue de 100+
    commandes : plusieurs mots-cles pertinents (ex. noms de GUID de regles ASR, codes
    d'evenements comme "6008", termes techniques detailles) n'apparaissent que dans le Help,
    pas dans le Label ni le Desc, et restaient donc introuvables via Ctrl+F jusqu'ici. Aucun
    changement de comportement pour les commandes sans Help ($helpCopy = $null, interpolation
    silencieuse en chaine vide dans "$labelCopy $descCopy $helpCopy", sans erreur). -SelfTest
    inchange (aucune assertion ne couvre le contenu de $entry.Search).

    v2.4.10 : ajout d'une assertion -SelfTest de regression comblant un trou identifie lors
    d'un audit du catalogue : le chargement sequentiel de Commands.Personnel.psd1 apres
    Commands.psd1 ($commandGroups[$cat.Name] = $cat.Commands) ecrase silencieusement tout le
    contenu d'une categorie du catalogue principal si une categorie personnelle porte
    exactement le meme Name - sans erreur ni avertissement visible, contrairement aux echecs
    de chargement deja couverts par $global:personalCatalogLoadError. La nouvelle assertion
    compare les noms de categories des deux catalogues deja charges en memoire
    ($catalogData/$personalCatalogData) et echoue si une collision est detectee, avant meme
    que le probleme ne se manifeste par une categorie du catalogue principal amputee sans
    explication. -SelfTest passe a 42 assertions.

    v2.4.11 : suite a un audit complet du lanceur et des deux catalogues (script + Commands.psd1
    + Commands.Personnel.psd1), 2 corrections et 1 amelioration.
    - Export-History (export HTML) : le retrait du prefixe redondant 'powershell -NoExit
      -Command' (v2.3.0) ne matchait pas '-EncodedCommand', introduit le 08/08/2026 pour
      contourner un bug de reconstruction -Command par cmd.exe/PowerShell 5.1. Consequence :
      les commandes en -EncodedCommand affichaient un long blob Base64 illisible dans la
      colonne Detail de l'export, au lieu du script reellement execute. Corrige en decodant
      ces commandes avant affichage (avec repli silencieux sur la ligne brute en cas de Base64
      invalide, plutot que de faire planter l'export). Ajout au passage d'un echappement HTML
      basique (& < >) sur le contenu affiche, absent jusqu'ici et sans consequence tant que
      Commands.psd1 ne contenait que des Cmd -Command classiques (deja couverts par
      l'assertion "aucun guillemet double"), mais plus prudent maintenant qu'un script decode
      depuis Base64 est un texte plus libre.
    - Commentaire d'en-tete de la region SELFTEST : restait fige a "39 assertions" depuis la
      v2.4.0 alors que le compteur reel avait deja progresse a 41 puis 42 au fil des versions
      suivantes sans jamais mettre a jour ce commentaire. Recale a 44 (42 existantes + 2
      nouvelles ci-dessous).
    - Nouvelles assertions -SelfTest (42 -> 44) : le -SelfTest validait deja la structure du
      catalogue (Label/Cmd/Desc/Confirm, absence de guillemets doubles, absence de $ non
      echappe...) mais aucune assertion ne verifiait qu'un -EncodedCommand decode
      correctement - un Base64 invalide ou tronque ne casse ni le parsing de Commands.psd1
      (simple chaine de caracteres du point de vue du .psd1) ni l'ancien jeu d'assertions,
      l'echec ne se serait manifeste qu'au clic reel dans l'interface (fenetre vide, meme
      symptome que le bug "AutoPlay/AutoRun" ayant motive l'adoption d'-EncodedCommand).
      Ajout de 2 assertions de regression : (1) chaque -EncodedCommand du catalogue decode
      sans exception depuis son Base64, (2) le script obtenu est syntaxiquement valide via le
      vrai parseur AST PowerShell ([System.Management.Automation.Language.Parser]::ParseInput)
      plutot qu'un simple comptage d'accolades/parentheses - verification plus fiable, et qui
      ne necessite pas d'executer le script (donc aucune dependance aux cmdlets Windows-only
      qu'il invoque).

    v2.5.0 : refonte complete d'Export-History (rapport Historique.html), sur demande du
    09/08/2026.
    - Identite visuelle alignee sur SpicyCheck-v7.1 : meme logo Windows-95-like (SVG exact,
      chemins et couleurs extraits directement du rapport SpicyCheck fourni, pas une
      reinterpretation) et meme palette bleu nuit (variables CSS --bg/--bg2.../--accent...
      reprises a l'identique), pour une identite coherente entre tous les rapports de la
      suite plutot que chaque script avec son propre theme improvise.
    - Colonne Windows retiree du tableau (repetee inutilement sur 328+ lignes alors qu'elle
      ne varie quasiment jamais) - deplacee dans la barre meta de l'entete, a cote de
      Machine/Utilisateur qui y etaient deja.
    - Groupes de jours desormais repliables (clic sur l'en-tete de jour), tries par date
      decroissante (le jour le plus recent en premier et deplie par defaut, les precedents
      replies) plutot que l'ordre d'ecriture ascendant du fichier log - l'activite recente
      est ce qui interesse en priorite a l'ouverture du rapport. Compteur d'entrees par jour
      affiche a cote de la date. La recherche (filterHistory) deplie automatiquement tous
      les groupes des qu'un texte est tape, pour ne jamais masquer un resultat filtre dans un
      groupe replie.
    - Cartes de stats ajoutees en tete (total commandes, jours d'activite, commandes
      sensibles lancees, commande la plus utilisee) - amelioration non demandee explicitement
      mais utile, ajoutee a l'occasion de la refonte.
    - Limite connue, non adressee par cette version : le rapport affiche la commande
      executee, pas sa sortie reelle (stdout/stderr) - Invoke-ConsoleCommand lance chaque
      commande dans une fenetre cmd.exe interactive separee (Start-Process) sans rediriger
      ni capturer sa sortie, et Historique.log n'enregistre donc que la commande elle-meme.
      Capturer la sortie reelle necessiterait de rediriger chaque invocation vers un fichier
      journal, un changement d'architecture plus large qui toucherait les 130 commandes du
      catalogue (dont certaines sont volontairement laissees interactives/ouvertes) - hors
      perimetre de cette version, a rediscuter si le besoin se confirme.

    v2.5.1 : le correctif v2.5.0 (decodage -EncodedCommand) n'avait ete applique que dans
    Export-History (export HTML) - Historique.log (a l'ecriture, via Write-CommandLog) et
    Historique.json (via Export-HistoryJson, qui exportait $r.Cmd sans transformation)
    contenaient donc toujours le blob Base64 brut, illisible meme ouvert directement dans un
    editeur de texte hors Toolbox (retour utilisateur du 09/08/2026). Logique de decodage
    extraite dans une fonction partagee Resolve-DisplayCommand, appelee a deux niveaux :
    - Write-CommandLog : decode avant d'ecrire la ligne, pour que Historique.log soit
      lisible des sa creation (n'affecte que la journalisation - Invoke-ConsoleCommand
      continue de lancer le $Command brut tel quel pour l'execution reelle).
    - Get-HistoryEntries : redecode aussi a la lecture (no-op sur les lignes deja lisibles
      post-v2.5.1, la regex ne matche pas) - corrige retroactivement l'affichage des
      entrees deja ecrites en Base64 brut avant ce correctif, dans Historique.json comme
      dans l'export HTML, sans avoir a reecrire Historique.log lui-meme sur le disque.
    Bloc de decodage devenu redondant supprime d'Export-History (une seule source de
    verite desormais, au lieu de deux implementations a maintenir en parallele).

    v2.5.2 : les 2-3 labels les plus longs du catalogue (ex: "Suggestions et apps
    sponsorisees (menu Demarrer) - desactiver", 61 caracteres - le plus long de tout le
    catalogue) depassaient la largeur du bouton de commande (334px en Segoe UI 9pt, fenetre
    limitee a 470px de large au total, donc pas de marge pour agrandir le bouton sans
    risquer de casser la mise en page) : rendu coupe/deforme en fin de libelle plutot qu'une
    troncature propre, faute d'AutoEllipsis active sur le controle (retour utilisateur du
    09/08/2026, capture a l'appui). Corrige en activant AutoEllipsis sur le bouton - le
    libelle complet reste consultable au survol via le panneau description fixe qui
    l'affichait deja integralement, donc aucune perte d'information, juste un affichage
    propre de la coupure la ou elle etait de toute facon deja inevitable.

    v2.5.3 : correction d'un bug de "unwrapping" de tableau a un seul element dans
    Export-History (meme piege que celui deja documente et corrige ailleurs dans la suite,
    ex: Dashboard-Global_Win11), visible uniquement quand tout l'historique tient sur une
    seule journee - donc jamais remarque jusqu'ici puisqu'un historique multi-jours produit
    naturellement un vrai tableau de groupes (retour utilisateur du 11/08/2026, historique
    fraichement reinitialise, 8 commandes lancees le meme jour).
    $grouped = $rows | Group-Object {...} | Sort-Object {...} -Descending : quand
    Group-Object ne produit qu'UN SEUL groupe, PowerShell deballe le resultat et $grouped
    devient l'objet GroupInfo lui-meme plutot qu'un tableau d'un element. Or GroupInfo
    possede lui-meme une propriete .Count - qui represente le nombre d'ELEMENTS DANS CE
    GROUPE (8, dans le cas remonte), pas le nombre de groupes/jours (qui aurait du valoir
    1). La boucle de generation des lignes HTML ($i -lt $grouped.Count) tournait alors 8
    fois au lieu d'1, et $grouped[$i] au-dela de l'index 0 ne pointant plus vers rien de
    valide, generait 7 lignes de separation de jour fantomes ("(0 entree)", sans date)
    en plus de la vraie. La carte de stats "Jours d'activite" affichait egalement le
    mauvais chiffre par le meme mecanisme ($grouped.Count reutilise telle quelle).
    Corrige en encapsulant l'intégralite du pipeline dans @(...), forcant $grouped a
    toujours etre un veritable tableau quel que soit le nombre de groupes obtenus (0, 1
    ou plusieurs) - pattern deja utilise a plusieurs reprises ailleurs dans le catalogue
    et la suite pour ce meme type de piege.
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
# Resout un Cmd de catalogue en texte lisible pour la journalisation/l'export :
# les commandes en -EncodedCommand (Base64 UTF-16LE, utilise depuis le 08/08/2026
# pour les scripts trop complexes pour survivre a la reconstruction -Command de
# cmd.exe/PowerShell 5.1 - cf. bug "AutoPlay/AutoRun") sont decodees plutot que
# laissees en blob illisible. Fonction centralisee (source unique) appelee a la
# fois par Write-CommandLog (pour que Historique.log soit lisible des l'ecriture,
# meme ouvert directement dans un editeur de texte hors Toolbox) et par
# Get-HistoryEntries (pour que les entrees deja ecrites en Base64 avant ce correctif
# redeviennent lisibles a la relecture, dans Historique.json comme dans l'export
# HTML - sans avoir a reecrire le fichier .log existant sur le disque).
# ------------------------------------------------------------
function global:Resolve-DisplayCommand {
    param([string]$Cmd)
    if ($Cmd -match '^powershell -NoExit -EncodedCommand\s+(\S+)') {
        try {
            return [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($matches[1])) + " (decode depuis -EncodedCommand)"
        } catch {
            # Base64 invalide (ne devrait jamais arriver si le catalogue a passe le
            # -SelfTest, mais on reste defensif plutot que de faire planter l'appelant).
            return $Cmd
        }
    }
    return $Cmd
}

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
    $entry = "[$timestamp] PC=$($global:machineName) | User=$($global:userName) | Win=$($global:winInfo) | $pidPart | $Title -> $(Resolve-DisplayCommand $Command)"
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
                # Resolve-DisplayCommand est deja applique par Write-CommandLog pour les
                # entrees ecrites depuis ce correctif (v2.5.1), mais rappele ici pour les
                # entrees ecrites avant (encore en Base64 brut sur le disque) : ainsi
                # Historique.json et l'export HTML redeviennent lisibles retroactivement
                # pour tout l'historique existant, sans devoir reecrire Historique.log
                # lui-meme (no-op sur les entrees deja lisibles, la regex ne matche pas).
                Cmd   = Resolve-DisplayCommand ($Matches.cmd.Trim())
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

    # PC/Utilisateur/Windows ne varient quasiment jamais d'une ligne a l'autre (meme
    # machine) -> affiches une seule fois dans l'entete plutot que repetes sur chaque
    # ligne (et la colonne Windows a ete retiree du tableau pour cette meme raison,
    # v2.5.0 - cf. demande utilisateur du 09/08/2026), ce qui libere de la largeur pour
    # la colonne Detail qui en a besoin.
    $derniereEntree = $rows[$rows.Count - 1]

    # Tri par date decroissante (jour le plus recent en premier) plutot que l'ordre
    # d'ecriture ascendant du fichier log : c'est l'activite recente qui interesse en
    # priorite a l'ouverture du rapport. ParseExact en InvariantCulture pour eviter le
    # piege documente ailleurs dans la suite (dd/MM/yyyy mal interprete en MM/dd/yyyy
    # selon la culture systeme).
    # @() autour du pipeline complet : quand tout l'historique tient sur une seule
    # journee, Group-Object ne produit qu'UN SEUL groupe et PowerShell le "deballe"
    # (meme piege de unwrapping documente ailleurs dans la suite) - $grouped devient
    # alors l'objet GroupInfo lui-meme plutot qu'un tableau d'un element. Or GroupInfo
    # possede lui-meme une propriete .Count, qui represente le nombre d'ELEMENTS DANS
    # CE GROUPE (ex: 8 commandes lancees aujourd'hui), pas le nombre de groupes/jours
    # (qui devrait valoir 1) - la boucle plus bas tournait alors 8 fois au lieu d'1,
    # produisant 7 lignes de separation de jour fantomes ("(0 entree)") en plus de la
    # vraie (retour utilisateur du 11/08/2026, historique fraichement reinitialise
    # donc entierement sur une seule journee - condition qui masquait ce bug latent
    # jusque-la, un historique multi-jours produisant naturellement un vrai tableau).
    $grouped = @($rows | Group-Object { ($_.Date -split ' ')[0] } | Sort-Object {
        [datetime]::ParseExact($_.Name, 'dd/MM/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    } -Descending)

    # Cartes de stats en tete de rapport : total, nombre de jours couverts, commandes
    # sensibles (Confirm=true) lancees, et la commande la plus frequemment utilisee -
    # improvise en plus de la demande initiale comme amelioration utile (v2.5.0).
    $nbSensibles = ($rows | Where-Object { $global:confirmLabels.Contains($_.Title) }).Count
    $commandePlusUtilisee = ($rows | Group-Object Title | Sort-Object Count -Descending | Select-Object -First 1).Name

    $htmlRows = for ($i = 0; $i -lt $grouped.Count; $i++) {
        $grp = $grouped[$i]
        $collapsedClass = if ($i -eq 0) { "" } else { " collapsed" }
        "<tr class=`"daysep$collapsedClass`" data-group=`"$i`" onclick=`"toggleDay($i)`"><td colspan=`"4`"><span class=`"chevron`">&#9662;</span>$($grp.Name)<span class=`"count`">($($grp.Count) entree$(if($grp.Count -gt 1){'s'}))</span></td></tr>"
        foreach ($r in $grp.Group) {
            $sensible = $global:confirmLabels.Contains($r.Title)
            $rowClass = if ($sensible) { "row sensible" } else { "row" }
            $styleAttr = if ($i -eq 0) { "" } else { " style=`"display:none`"" }
            $titreHtml = if ($sensible) { "<span class=`"label-sensible`">$($r.Title)</span>" } else { $r.Title }

            # Le prefixe 'powershell -NoExit -Command' est identique sur la grande
            # majorite des lignes non-encodees - retire pour la lisibilite, il n'apporte
            # rien de nouveau a chaque repetition. Les commandes deja en -EncodedCommand
            # sont deja decodees en amont par Get-HistoryEntries (Resolve-DisplayCommand,
            # v2.5.1) donc ce -replace est deja un no-op pour elles (pas de prefixe
            # -Command a trouver dans un script decode) : pas besoin de dupliquer ici la
            # logique de decodage Base64, une seule source de verite suffit.
            $cmdAffiche = $r.Cmd -replace '^powershell -NoExit -Command ', ''

            # Echappement HTML basique : un script decode depuis Base64 est un texte plus
            # libre qu'un Cmd -Command classique (deja valide par le -SelfTest pour
            # l'absence de guillemets doubles), donc plus prudent de ne jamais injecter de
            # < > & non echappes dans le HTML genere, meme si le catalogue actuel n'en
            # contient pas.
            $cmdAffiche = $cmdAffiche -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'

            if ($cmdAffiche.Length -gt 120) {
                $detailHtml = "<details><summary>Voir la commande complete</summary><code>$cmdAffiche</code></details>"
            } else {
                $detailHtml = "<code>$cmdAffiche</code>"
            }

            "<tr class=`"$rowClass`" data-group=`"$i`"$styleAttr><td>$($r.Date)</td><td>$($r.PID)</td><td>$titreHtml</td><td>$detailHtml</td></tr>"
        }
    }

    # Logo Windows-95-like et palette bleu nuit : identiques (memes chemins SVG, memes
    # variables CSS) a SpicyCheck-v7.1, pour une identite visuelle coherente entre tous
    # les rapports de la suite - cf. demande utilisateur du 09/08/2026, capture et
    # fichiers source de SpicyCheck fournis pour extraction exacte plutot que
    # reinterpretation approximative.
    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Historique - Toolbox Commandes Systeme</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:       #080b12;
  --bg2:      #0d1117;
  --bg3:      #111827;
  --bg4:      #1a2235;
  --bg5:      #0a0f1a;
  --border:   #1e2d45;
  --border2:  #243350;
  --accent:   #00d4ff;
  --accent2:  #0099cc;
  --accent3:  #005f80;
  --purple:   #7c6af7;
  --yellow:   #ffb347;
  --text:     #e2e8f0;
  --text2:    #94a3b8;
  --text3:    #475569;
}
body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;font-size:13px;line-height:1.6;min-height:100vh}
::-webkit-scrollbar{width:12px;height:12px}
::-webkit-scrollbar-track{background:var(--bg2)}
::-webkit-scrollbar-thumb{background:var(--border2);border-radius:6px;border:3px solid var(--bg2)}
::-webkit-scrollbar-thumb:hover{background:var(--accent3)}
header{background:linear-gradient(160deg,#060c1a 0%,#0a1628 50%,#060a14 100%);border-bottom:2px solid var(--accent3);padding:32px 48px 24px;position:relative;overflow:hidden}
header::before{content:'';position:absolute;top:0;left:0;right:0;bottom:0;background:radial-gradient(ellipse at 20% 50%,rgba(0,212,255,.06) 0%,transparent 60%),radial-gradient(ellipse at 80% 20%,rgba(124,106,247,.05) 0%,transparent 50%);pointer-events:none}
.titlerow{display:flex;align-items:flex-end;gap:0;position:relative;z-index:1}
.title-text h1{font-family:'Cascadia Code','Consolas','Courier New',monospace;font-size:26px;font-weight:700;color:var(--accent);text-shadow:0 0 20px rgba(0,212,255,.4);letter-spacing:1px;margin:0 0 10px 0}
.logo-sub{font-family:'Cascadia Code','Consolas',monospace;font-size:12px;color:var(--text2);letter-spacing:2px;margin-bottom:14px}
.logo-sub b{color:var(--accent)}
.meta-bar{display:flex;flex-wrap:wrap;gap:8px 24px;font-size:11.5px;color:var(--text3);border-top:1px solid var(--border);padding-top:12px;margin-top:4px;position:relative;z-index:1}
.meta-bar span{display:flex;align-items:center;gap:6px}
.meta-bar b{color:var(--text2)}
.meta-dot{width:5px;height:5px;border-radius:50%;background:var(--accent);display:inline-block;box-shadow:0 0 6px var(--accent)}
main{padding:24px 48px 64px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:22px}
.stat-card{background:var(--bg3);border:1px solid var(--border);border-radius:8px;padding:14px 16px}
.stat-card .num{font-size:22px;font-weight:700;color:var(--accent);line-height:1.2}
.stat-card .lbl{font-size:11px;color:var(--text3);text-transform:uppercase;letter-spacing:.05em;margin-top:2px}
.stat-card.warn .num{color:var(--yellow)}
.searchbar{margin-bottom:18px;position:sticky;top:12px;z-index:5}
.searchbar input{width:100%;max-width:380px;padding:10px 14px;background:var(--bg3);border:1px solid var(--border2);color:var(--text);border-radius:6px;font-size:13px;transition:border-color .15s,box-shadow .15s}
.searchbar input::placeholder{color:var(--text3)}
.searchbar input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(0,212,255,.12)}
table{border-collapse:collapse;width:100%}
th,td{padding:9px 12px;border-bottom:1px solid var(--border);text-align:left;font-size:13px;vertical-align:top}
th{color:var(--accent);text-transform:uppercase;font-size:11px;letter-spacing:.05em;background:var(--bg5);position:sticky;top:52px}
tr.row{transition:background-color .1s}
tr.row:hover{background:var(--bg3)}
tr.row.sensible{background:rgba(255,179,71,.06)}
tr.row.sensible:hover{background:rgba(255,179,71,.12)}
tr.daysep{cursor:pointer;user-select:none}
tr.daysep td{background:var(--bg4);color:var(--accent);font-weight:700;font-size:12.5px;text-transform:uppercase;letter-spacing:.05em;padding:12px;border-bottom:1px solid var(--border2)}
tr.daysep:hover td{background:#212c45}
tr.daysep .count{color:var(--text3);font-weight:400;text-transform:none;letter-spacing:normal;margin-left:8px}
.chevron{display:inline-block;margin-right:8px;transition:transform .18s;color:var(--purple)}
tr.daysep.collapsed .chevron{transform:rotate(-90deg)}
.label-sensible{color:var(--yellow);font-weight:600}
.label-sensible::before{content:"⚠ "}
code{color:var(--accent2);background:var(--bg4);padding:2px 6px;border-radius:4px;font-family:Consolas,'Cascadia Code',monospace;font-size:12px;word-break:break-all}
details summary{cursor:pointer;color:var(--purple);font-size:12px;list-style:none}
details summary::-webkit-details-marker{display:none}
details summary::before{content:"▸ "}
details[open] summary::before{content:"▾ "}
details[open] summary{margin-bottom:6px;display:block}
</style>
</head>
<body>

<header>
  <div class="titlerow">
    <div class="title-text">
      <h1>Historique - Toolbox Commandes Systeme</h1>
      <div class="logo-sub">by <b>Nephren</b></div>
    </div>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="9.39 8.477 484.197 428.149" style="width:76px;height:76px;margin-left:24px;align-self:flex-end;filter:drop-shadow(0 0 12px rgba(0,212,255,.4));flex-shrink:0"><path d="m347.015 235.334 42.877-112.525 67.515 25.727-42.877 112.524z" fill="#a8ce81"/><path d="m303.267 350.143 42.92-112.634 67.514 25.726-42.919 112.634z" fill="#fddb1d"/><path d="m263.921 207.033 42.879-112.525 67.406 25.685-42.877 112.525z" fill="#ef7066"/><path d="m220.505 320.972 42.588-111.764 67.406 25.685-42.588 111.764z" fill="#6eaed7"/><path d="m415.69 247.559c-12.962-10.418-30.606-21.623-53.002-30.158-1.455-.43-2.827-1.077-4.131-1.574l33.307-87.41c1.755.295 3.277.875 4.893 1.864 22.194 8.083 39.661 19.097 52.64 29.147zm-44.284 116.221a216.14 216.14 0 0 0 -53.045-30.048c-1.496-.321-2.91-.86-4.131-1.574l34.136-89.586c1.673.513 3.236.984 4.893 1.865 22.153 8.192 39.62 19.206 52.392 29.8zm122.181-212.166s-25.485-37.351-81.827-59.07c-56.66-21.216-98.7-15.447-98.482-15.364l-15.038 39.466c-.135-.3 27.632-5.533 68.583 3.971l-33.597 88.172c-41.045-9.913-68.776-3.795-68.693-4.013l-10.29 27.33s27.736-7.111 69.123 2.558l-34.717 91.108c-33.74-8.499-58.772-7.828-67.506-6.798l-14.5 38.052c10.873-1.087 47.89-2.17 95.075 15.809 56.467 21.392 82.284 57.873 82.408 57.547zm-241.467-32.87 14.747-38.705 41.45-2.259-14.748 38.705zm-91.514 240.162 14.748-38.704 41.45-2.259-14.5 38.052zm16.364-42.944 13.38-35.117 41.492-2.367-13.423 35.225zm60.11-157.752 13.382-35.118 41.45-2.259-13.381 35.117zm-30.034 78.821 13.381-35.116 41.45-2.26-13.381 35.117zm-15.038 39.466 13.38-35.117 41.45-2.26-13.38 35.117zm30.035-78.823 13.422-35.225 41.45-2.259-13.423 35.225zm-10.213-90.174 11.476-30.115 40.145-2.756-11.766 30.876zm-110.927-84.974 4.93-12.937 16.36-1.112-4.93 12.937zm76.852 67.881 8.99-23.592 35.117-2.306-9.03 23.7zm-28.691-20.768 6.835-17.94 28.455-1.483-6.836 17.94zm-24.068-24.734 5.469-14.351 23.495-.884-5.179 13.59zm40.932 183.057 11.476-30.115 39.855-1.995-11.475 30.115zm-110.927-84.974 4.93-12.938 16.36-1.111-5.178 13.59zm76.852 67.881 9.031-23.7 35.077-2.198-9.032 23.7zm-28.691-20.769 6.835-17.938 28.455-1.484-6.835 17.939zm-24.067-24.734 5.22-13.698 23.743-1.536-5.179 13.59zm41.222 182.297 11.475-30.115 40.145-2.757-11.475 30.116zm-110.927-84.974 5.178-13.59 16.112-.46-4.93 12.938zm77.1 67.229 8.74-22.94 35.119-2.307-8.783 23.05zm-28.691-20.769 6.587-17.287 28.454-1.483-6.587 17.286zm-24.026-24.843 5.178-13.59 23.495-.883-5.178 13.59z" fill="#000101"/><path d="m114.017 84.174 4.889-12.83 17.411-1.582-4.888 12.829zm88.133 61.472 9.529-25.006 32.364-1.612-9.28 24.353zm-34.836-17.383 7.913-20.766 29.355-1.887-7.913 20.766zm-29.271-19.247 6.049-15.873 22.733-1.173-6.007 15.764zm-50.589-48.909 4.102-10.763 12.995-.776-4.101 10.764zm11.525 63.532 4.93-12.938 17.411-1.583-4.93 12.938zm88.133 61.472 9.57-25.114 32.612-2.265-9.528 25.006zm-34.588-18.035 7.664-20.113 29.397-1.996-7.954 20.874zm-29.478-18.703 6.007-15.764 22.734-1.174-5.758 15.112zm-50.63-48.8 4.392-11.525 12.995-.775-4.392 11.524z" fill="#ef7066"/><path d="m68.115 204.635 4.93-12.937 17.122-.822-4.93 12.938zm87.844 62.234 9.57-25.114 32.653-2.374-9.57 25.114zm-34.547-18.144 7.913-20.766 29.107-1.235-7.664 20.113zm-29.229-19.355 5.717-15.004 22.733-1.173-5.717 15.003zm-50.92-48.04 4.391-11.524 12.995-.776-4.35 11.416zm11.814 62.77 4.93-12.937 17.122-.822-4.93 12.938zm88.133 61.473 9.28-24.353 32.654-2.374-9.57 25.115zm-34.836-17.383 7.913-20.765 29.397-1.996-7.955 20.874zm-29.229-19.355 5.717-15.004 23.023-1.934-6.007 15.764zm-50.631-48.801 4.102-10.763 12.995-.775-4.101 10.763z" fill="#6eaed7"/></svg>
  </div>
  <div class="meta-bar">
    <span><span class="meta-dot"></span>Genere le <b>$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</b></span>
    <span><b>$($rows.Count)</b> entree(s)</span>
    <span>Machine : <b>$($derniereEntree.PC)</b></span>
    <span>Utilisateur : <b>$($derniereEntree.User)</b></span>
    <span>Windows : <b>$($derniereEntree.Win)</b></span>
  </div>
</header>

<main>
  <div class="stats">
    <div class="stat-card"><div class="num">$($rows.Count)</div><div class="lbl">Commandes lancees</div></div>
    <div class="stat-card"><div class="num">$($grouped.Count)</div><div class="lbl">Jours d'activite</div></div>
    <div class="stat-card warn"><div class="num">$nbSensibles</div><div class="lbl">Commandes sensibles</div></div>
    <div class="stat-card"><div class="num">$commandePlusUtilisee</div><div class="lbl">Commande la + utilisee</div></div>
  </div>

  <div class="searchbar"><input type="text" id="searchBox" placeholder="Filtrer (nom de commande, date, PID...)" onkeyup="filterHistory()"></div>

  <table>
    <tr><th>Date</th><th>PID</th><th>Commande</th><th>Detail</th></tr>
    $($htmlRows -join "`n")
  </table>
</main>

<script>
function toggleDay(id) {
  var header = document.querySelector('tr.daysep[data-group="' + id + '"]');
  var collapsed = header.classList.toggle('collapsed');
  document.querySelectorAll('tr.row[data-group="' + id + '"]').forEach(function(r) {
    r.style.display = collapsed ? 'none' : '';
  });
}
function filterHistory() {
  var filtre = document.getElementById('searchBox').value.toLowerCase();
  var groups = document.querySelectorAll('tr.daysep');
  if (filtre === '') {
    groups.forEach(function(g, idx) {
      var id = g.getAttribute('data-group');
      var collapse = idx !== 0;
      g.classList.toggle('collapsed', collapse);
      document.querySelectorAll('tr.row[data-group="' + id + '"]').forEach(function(r) {
        r.style.display = collapse ? 'none' : '';
      });
    });
    return;
  }
  groups.forEach(function(g) { g.classList.remove('collapsed'); });
  document.querySelectorAll('tr.row').forEach(function(ligne) {
    var texte = ligne.textContent.toLowerCase();
    ligne.style.display = texte.indexOf(filtre) !== -1 ? '' : 'none';
  });
}
</script>
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
# HashSet des Label dont Confirm=$true, alimente au chargement du catalogue - permet a
# Export-History (fonction globale, ne voit pas $commandGroups qui est en portee script)
# de savoir quelles lignes de l'historique surligner sans devoir re-parser Commands.psd1.
$global:confirmLabels = [System.Collections.Generic.HashSet[string]]::new()

if (-not (Test-Path $global:catalogPath)) {
    $global:catalogLoadError = "Fichier Commands.psd1 introuvable a cote du script (chemin attendu : $global:catalogPath)."
} else {
    try {
        $catalogData = Import-PowerShellDataFile -Path $global:catalogPath -ErrorAction Stop
        foreach ($cat in $catalogData.Categories) {
            $commandGroups[$cat.Name] = $cat.Commands
            foreach ($cmdItem in $cat.Commands) {
                if ($cmdItem.Confirm) {
                    [void]$global:confirmLabels.Add($cmdItem.Label)
                }
            }
        }
    } catch {
        $global:catalogLoadError = "Echec du chargement de Commands.psd1 : $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# Catalogue PERSONNEL, optionnel - Commands.Personnel.psd1, meme dossier, meme format que
# Commands.psd1. Contrairement au catalogue principal, celui-ci n'est PAS concu pour etre
# partage entre machines (reglages/decisions propres a une machine precise). S'il est absent,
# rien ne se passe : aucune erreur, le catalogue principal fonctionne normalement seul -
# c'est ce qui garantit que Commands.psd1 + le script restent copiables tels quels sur une
# autre machine sans ce fichier. S'il est present mais invalide, meme logique defensive que
# le catalogue principal : message clair au lieu d'un plantage, sans bloquer le reste.
$global:personalCatalogPath = Join-Path $PSScriptRoot "Commands.Personnel.psd1"
$global:personalCatalogLoadError = $null
if (Test-Path $global:personalCatalogPath) {
    try {
        $personalCatalogData = Import-PowerShellDataFile -Path $global:personalCatalogPath -ErrorAction Stop
        foreach ($cat in $personalCatalogData.Categories) {
            $commandGroups[$cat.Name] = $cat.Commands
            foreach ($cmdItem in $cat.Commands) {
                if ($cmdItem.Confirm) {
                    [void]$global:confirmLabels.Add($cmdItem.Label)
                }
            }
        }
    } catch {
        $global:personalCatalogLoadError = "Echec du chargement de Commands.Personnel.psd1 : $($_.Exception.Message)"
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

if ($global:personalCatalogLoadError -and -not $SelfTest) {
    # Non bloquant expres : Commands.Personnel.psd1 est optionnel, une erreur dessus ne doit
    # jamais empecher le catalogue principal (portable) de fonctionner normalement.
    [System.Windows.Forms.MessageBox]::Show(
        "$($global:personalCatalogLoadError)`n`nLe catalogue principal (Commands.psd1) reste charge normalement - seule la categorie personnelle est absente.",
        "Catalogue personnel non charge",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
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
# 47 assertions sur l'integrite du catalogue de commandes et les
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

    # Regression : -EncodedCommand (introduit le 08/08/2026 pour contourner un bug de
    # reconstruction -Command par cmd.exe/PowerShell 5.1 sur "AutoPlay/AutoRun", puis
    # reutilise sur plusieurs commandes de la categorie Confidentialite/Telemetrie) encode le
    # script en Base64 UTF-16LE : un Base64 invalide ou tronque ne casserait ni le parsing de
    # Commands.psd1 (simple chaine), ni ce -SelfTest sans ces deux assertions dediees - l'echec
    # ne se manifesterait qu'au clic reel dans l'interface, silencieusement (fenetre vide,
    # cf. bug "AutoPlay/AutoRun" du 08/08/2026 qui a motive ce contournement). On decode donc
    # ici chaque -EncodedCommand pour verifier (1) que le Base64 decode sans exception et (2)
    # que le script obtenu est syntaxiquement valide via le vrai parseur AST PowerShell -
    # verification plus fiable qu'un simple comptage d'accolades/parentheses, et qui ne
    # necessite pas d'executer le script (donc sans dependance aux cmdlets Windows-only qu'il
    # invoque, ce qui permettrait meme a cette assertion de tourner correctement hors Windows).
    $commandesEncoded = $allCommands | Where-Object { $_.Cmd -match 'EncodedCommand\s+(\S+)' }
    $echecsDecodage = 0
    $echecsSyntaxe = 0
    foreach ($cmdEncoded in $commandesEncoded) {
        if ($cmdEncoded.Cmd -match 'EncodedCommand\s+(\S+)') {
            $b64 = $matches[1].Trim("'")
            try {
                $scriptDecode = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b64))
                $tokensAst = $null
                $erreursAst = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput($scriptDecode, [ref]$tokensAst, [ref]$erreursAst)
                if ($erreursAst -and $erreursAst.Count -gt 0) { $echecsSyntaxe++ }
            } catch {
                $echecsDecodage++
            }
        }
    }
    Test-Assertion "Toutes les commandes -EncodedCommand decodent correctement depuis leur Base64" ($commandesEncoded.Count -eq 0 -or $echecsDecodage -eq 0)
    Test-Assertion "Tous les scripts -EncodedCommand decodes sont syntaxiquement valides (AST)" ($commandesEncoded.Count -eq 0 -or $echecsSyntaxe -eq 0)

    # Regression : le pack "Integrite complet" doit rester 100% diagnostique - SFC y tourne
    # en /verifyonly (ne repare rien) et /scannow ne doit jamais y etre execute
    # automatiquement (seulement mentionne comme instruction textuelle en cas d'anomalie
    # detectee). Repare-t-on automatiquement depuis un magasin de composants potentiellement
    # corrompu ? Avec /verifyonly, cette question ne se pose plus : rien n'est jamais modifie
    # par ce pack, la reparation reste une decision humaine.
    $packIntegrite = $allCommands | Where-Object { $_.Label -eq "Pack Integrite complet (CHKDSK+DISM+SFC)" }
    $packSfcGate = $packIntegrite -and ($packIntegrite.Cmd -match '(?i)sfc\s+/verifyonly') -and ($packIntegrite.Cmd -notmatch '(?i);\s*sfc\s+/scannow')
    Test-Assertion "Pack Integrite complet : SFC en /verifyonly uniquement, jamais de /scannow auto" $packSfcGate

    # --- Catalogue externe (Commands.psd1) ---
    Test-Assertion "Fichier Commands.psd1 present a cote du script" (Test-Path $global:catalogPath)
    Test-Assertion "Au moins une commande possede un champ Help (bouton '?')" (($allCommands | Where-Object { $_.Help }).Count -gt 0)
    Test-Assertion "Commands.psd1 charge sans erreur" (-not $global:catalogLoadError)
    Test-Assertion "Commands.Personnel.psd1 absent ou charge sans erreur (optionnel)" (-not $global:personalCatalogLoadError)

    # Regression : si une categorie de Commands.Personnel.psd1 porte le meme Name qu'une
    # categorie de Commands.psd1, le chargement sequentiel ($commandGroups[$cat.Name] = ...)
    # ecrase silencieusement les commandes du catalogue principal pour cette categorie, sans
    # erreur ni avertissement visible pour l'utilisateur - seul le contenu personnel survit
    # dans $commandGroups. Cette assertion detecte ce cas avant qu'il ne passe inapercu.
    $categoriesPrincipal = @($catalogData.Categories | ForEach-Object { $_.Name })
    $categoriesPersonnel = @($personalCatalogData.Categories | ForEach-Object { $_.Name })
    $categoriesEnCollision = $categoriesPersonnel | Where-Object { $categoriesPrincipal -contains $_ }
    Test-Assertion "Aucune categorie de Commands.Personnel.psd1 n'ecrase une categorie de Commands.psd1 (regression collision silencieuse)" ($categoriesEnCollision.Count -eq 0)

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

    # Regression : les champs Desc et Help sont en guillemets doubles ("...") par convention -
    # tout signe $ qui y est ecrit sans etre precede d'un backtick (`$) serait interprete par
    # PowerShell comme une interpolation de variable, ce que le mode "restricted language"
    # d'Import-PowerShellDataFile interdit purement et simplement (echec de chargement complet
    # du catalogue). Cf. bug du "Pack Integrite complet" v2.4.5 ($ProgressPreference non
    # echappe dans Help, corrige en v2.4.6).
    $descHelpAvecDollarNonEchappe = $false
    if ($catalogRaw) {
        $descHelpLines = $catalogRaw -split "`r?`n" | Where-Object { $_ -match '^\s*(Desc|Help)\s*=\s*"' }
        foreach ($ligneDescHelp in $descHelpLines) {
            $sansEchappes = $ligneDescHelp -replace '`\$', ''
            if ($sansEchappes -match '\$') { $descHelpAvecDollarNonEchappe = $true; break }
        }
    }
    Test-Assertion 'Aucun $ non echappe dans les champs Desc/Help de Commands.psd1 (regression interpolation)' (-not $descHelpAvecDollarNonEchappe)

    Test-Assertion "Fonction Get-HistoryEntries definie" ([bool](Get-Command Get-HistoryEntries -ErrorAction SilentlyContinue))

    # Regression v2.5.1 : Resolve-DisplayCommand doit exister et decoder correctement, sinon
    # Historique.log/.json redeviennent illisibles pour toute commande en -EncodedCommand
    # (cf. retour utilisateur du 09/08/2026 - blob Base64 brut dans ces deux fichiers).
    Test-Assertion "Fonction Resolve-DisplayCommand definie" ([bool](Get-Command Resolve-DisplayCommand -ErrorAction SilentlyContinue))
    if (Get-Command Resolve-DisplayCommand -ErrorAction SilentlyContinue) {
        $testB64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Write-Host 'test'"))
        $testResultat = Resolve-DisplayCommand "powershell -NoExit -EncodedCommand $testB64"
        Test-Assertion "Resolve-DisplayCommand decode correctement un -EncodedCommand" ($testResultat -match "Write-Host 'test'")
        Test-Assertion "Resolve-DisplayCommand laisse une commande -Command classique inchangee" ((Resolve-DisplayCommand 'ipconfig /flushdns') -eq 'ipconfig /flushdns')
    }
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
    Test-Assertion "confirmLabels alimente pour le surlignage des commandes sensibles dans l'export HTML" ($global:confirmLabels.Count -gt 0)

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
        # Les 2-3 labels les plus longs du catalogue (ex: "Suggestions et apps
        # sponsorisees (menu Demarrer) - desactiver", 61 caracteres) depassent la largeur
        # du bouton (334px en Segoe UI 9pt) : sans AutoEllipsis, WinForms coupe le texte
        # brutalement au lieu d'afficher '...', ce qui produit un rendu deforme/illisible
        # en fin de libelle (retour utilisateur du 09/08/2026, capture a l'appui). Le
        # libelle complet reste de toute facon visible au survol via le panneau
        # description fixe (Add_MouseEnter, $descTitle.Text = $labelCopy juste en
        # dessous) - AutoEllipsis ne fait donc perdre aucune information, juste
        # l'affichage propre d'une coupure la ou elle est deja inevitable.
        $btn.AutoEllipsis = $true

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
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(40,220,255)
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
            $helpBtn.BackColor = [System.Drawing.Color]::FromArgb(32,32,36)
            $helpBtn.ForeColor = [System.Drawing.Color]::FromArgb(150,150,155)
            $helpBtn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(45,45,50)
            # Enabled reste $true expres : un bouton WinForms desactive (Enabled=$false)
            # ignore ForeColor et applique son propre rendu systeme "grise", ce qui rendait
            # toute personnalisation de couleur invisible. Ici, pas de gestionnaire de clic
            # attache -> visuellement discret mais sans effet au clic, sans ce probleme de
            # rendu.
        }
        $row.Controls.Add($helpBtn)

        $flowPanel.Controls.Add($row)

        $global:layoutItems.Add([PSCustomObject]@{
            Type    = "Button"
            Control = $row
            Group   = $group
            Search  = ("$labelCopy $descCopy $helpCopy").ToLowerInvariant()
            Label   = $labelCopy
        })
    }
}

$global:searchBox.Add_TextChanged({ Update-Visibility })

Update-Visibility

[System.Windows.Forms.Application]::Run($form)
