# Toolbox-SystemCommands_Win11

Un lanceur WinForms a theme sombre pour les commandes systeme Windows 11. Un clic execute une commande de diagnostic ou de maintenance dans sa propre fenetre console — plus besoin de chercher la bonne formule `DISM`/`SFC`/`netsh` ou de la retaper de memoire a chaque fois.

> 145 commandes reparties en 9 categories, chacune avec une description en langage clair, une confirmation demandee pour tout ce qui modifie l'etat du systeme, une journalisation complete de l'historique, et un self-test a 47 assertions qui ne necessite jamais les droits admin ni n'ouvre l'interface.

---

## Sommaire

- [Presentation](#presentation)
- [Fonctionnalites de l'interface](#fonctionnalites-de-linterface)
- [Catalogue de commandes](#catalogue-de-commandes)
- [Modele de securite des commandes](#modele-de-securite-des-commandes)
- [Prerequis](#prerequis)
- [Premier lancement](#premier-lancement-pas-a-pas)
- [Raccourci bureau](#raccourci-bureau)
- [Parametres en ligne de commande](#parametres-en-ligne-de-commande)
- [Fichiers ecrits par le script](#fichiers-ecrits-par-le-script)
- [Etendre le catalogue](#etendre-le-catalogue)
- [Deploiement multi-machines](#deploiement-multi-machines)
- [Depannage](#depannage)

---

## Presentation

`Toolbox-SystemCommands_Win11.ps1` est un lanceur graphique (WinForms, theme sombre) pour les commandes PowerShell/cmd du quotidien utilisees pour diagnostiquer et entretenir une machine Windows 11 — sante disque, resets reseau, reparations Windows Update, verification des pilotes, posture de securite, bascules de confidentialite/telemetrie, et bien plus.

Chaque commande s'execute dans **sa propre fenetre console** (`cmd.exe /k`), donc vous voyez la sortie brute, non filtree, exactement comme si vous aviez tape la commande vous-meme — la toolbox ne parse, ne capture ni ne reinterprete rien.

L'application **s'auto-eleve au demarrage** : comme la plupart des commandes necessitent de toute facon les droits administrateur, l'elevation se fait une seule fois pour toute la session, et chaque fenetre console ouverte ensuite herite de cette elevation — plus de prompt UAC repete par bouton.

Un seul fichier compagnon accompagne le script et doit rester dans le meme dossier : **`Commands.psd1`**, le catalogue de commandes (145 commandes).

---

## Fonctionnalites de l'interface

| Fonctionnalite | Detail |
|---|---|
| **Categories repliables** | Cliquer sur l'en-tete d'une categorie pour la replier/deplier — utile des que le catalogue depasse une vingtaine de commandes |
| **Favoris** | Cliquer sur l'etoile a cote de n'importe quelle commande pour l'epingler ; persiste dans `Favoris.txt` d'une session a l'autre ; filtre "Favoris uniquement" disponible |
| **Recherche** | `Ctrl+F` place directement le curseur dans la barre de recherche ; la recherche porte sur le libelle, la description, **et** le texte d'aide de la commande (pas seulement le libelle visible du bouton) |
| **Bouton d'aide (`?`)** | Present sur chaque commande pour garder un alignement constant, mais actif (cyan, cliquable) uniquement sur les commandes possedant un champ `Help` — ouvre une fenetre avec une explication plus detaillee. 81 commandes sur 145 en possedent une actuellement |
| **Clic droit → Copier la commande** | Copie la commande reelle sous-jacente dans le presse-papiers, si vous preferez la lancer ou l'inspecter vous-meme |
| **Confirmations** | Les commandes marquees `Confirm = $true` dans le catalogue demandent une confirmation Oui/Non avant de se lancer (voir [Modele de securite des commandes](#modele-de-securite-des-commandes)) |
| **Historique** | Chaque lancement est horodate et enregistre, avec le nom de la machine, l'utilisateur, la version de Windows, et le PID du processus lance |
| **Export HTML** | Un bouton genere un rapport a theme sombre (identite visuelle partagee avec le reste de la suite de maintenance) — groupe par jour (le plus recent deplie, les precedents replies), avec un filtre JavaScript en direct, des cartes de statistiques (total commandes, jours d'activite, commandes sensibles lancees, commande la plus utilisee), et les commandes sensibles surlignees en orange |
| **Export JSON** | Memes donnees d'historique en JSON exploitable par machine |

---

## Catalogue de commandes

**145 commandes** reparties en **9 categories**. La description complete en langage clair et (pour beaucoup) un texte d'aide etendu sont affiches directement dans l'application — ce tableau est une carte, pas un substitut.

| Categorie | Nombre | Exemples |
|---|---|---|
| **Integrite systeme** | 12 | SFC /scannow, DISM CheckHealth/ScanHealth/RestoreHealth, pack combine CHKDSK+DISM+SFC, points de restauration |
| **Disque** | 11 | CHKDSK (variantes lecture seule et reparation), etat SMART, verification TRIM, latence disque en temps reel, historique des erreurs disque |
| **Reseau** | 18 | Flush DNS, reset Winsock/TCP-IP, renouvellement de bail IP, test NextDNS, reseaux/vitesse Wifi, IP publique, diagnostic de connectivite multi-niveaux, contenu du fichier hosts |
| **Windows Update** | 9 | Reset des composants, scan force, reset Microsoft Store, historique des mises a jour, taille du cache SoftwareDistribution, verification de redemarrage en attente |
| **Performance** | 16 | Applications au demarrage (y compris via taches planifiees), detail du temps de demarrage, score WinSAT, bascules HVCI/VBS, top processus RAM/CPU, service de recherche Windows |
| **Pilotes / Materiel** | 12 | Peripheriques en erreur, etat GPU NVIDIA, info BIOS/carte mere, RAM installee, pilotes recemment installes, peripheriques desactives |
| **Securite rapide** | 22 | Etat Defender, verification SMBv1, verification pare-feu, Secure Boot/TPM, BitLocker, tentatives de connexion echouees, regles ASR, UAC, Credential Guard, acces controle aux dossiers |
| **Confidentialite / Telemetrie** | 28 | Niveau de telemetrie, acces camera/micro/localisation, ID de publicite, Windows Recall, recherche web et suggestions sponsorisees du menu Demarrer, Copilot, Delivery Optimization, WER, synchronisation OneDrive — la plupart en paires "verifier l'etat" / "desactiver" |
| **Divers** | 17 | Rapport batterie, diagnostic energie, rapport DirectX, etat d'activation Windows, historique des arrets inattendus, synchronisation de l'heure, imprimantes installees |

---

## Modele de securite des commandes

- **Chaque commande a `Confirm = $true` ou `$false`** dans le catalogue — il n'existe pas d'etat "indecis" ; le self-test verifie que ce champ est toujours present.
- **26 commandes necessitent actuellement une confirmation** — tout ce qui modifie l'etat du systeme, necessite un redemarrage, ou pourrait perturber une session en cours (ex : `Reset Winsock`, `Reset pile TCP/IP`, `CHKDSK C: /f /r (au reboot)`, `Redemarrer le PC`, `Eteindre le PC`, la plupart des bascules de desactivation dans Confidentialite/Telemetrie).
- Une assertion dediee du self-test verrouille le fait que six commandes specifiques connues comme sensibles (reset Winsock, reset pile TCP/IP, reset composants WU, CHKDSK planifie, redemarrage, extinction) portent **toujours** `Confirm = $true` — une regression a cet endroit ferait immediatement echouer `-SelfTest` plutot que de se manifester plus tard comme une action destructrice silencieuse et non confirmee.
- **Aucune commande n'utilise `wmic`** (retire depuis Windows 11 24H2) — verifie par une assertion de regression dediee du self-test.
- Le champ `Cmd` du catalogue est **toujours en guillemets simples** dans `Commands.psd1`, ce qui empeche structurellement toute interpolation de variable PowerShell (`$_`, `$err`, etc.) de se glisser dans une commande — la cause racine de deux bugs precoces (v1.4.3, v1.4.4) que cette conception elimine entierement plutot que de corriger au cas par cas.
- Quelques commandes trop complexes pour survivre a la reconstruction `-Command` de `cmd.exe` sont stockees en Base64 (`-EncodedCommand`, UTF-16LE) a la place. Deux assertions du self-test decodent chacune d'entre elles et verifient que le script obtenu est syntaxiquement valide (via le vrai parseur AST PowerShell) — pour qu'un blob Base64 corrompu ou tronque soit detecte par `-SelfTest` plutot que de se manifester par une fenetre console vide et silencieuse au clic.

---

## Prerequis

- Windows 10 ou 11.
- PowerShell 5.1 (integre a Windows) — le script cible `#Requires -Version 5.1`, donc PowerShell 7+ fonctionne aussi.
- Droits administrateur. L'application s'auto-eleve au demarrage (fenetre UAC) — sauf `-SelfTest`, qui fonctionne sans elevation et n'ouvre jamais l'interface.
- `Commands.psd1` **doit** etre present dans le meme dossier que le script — l'application affiche une erreur claire et se replie sur un catalogue vide plutot que de planter si le fichier est absent ou invalide.
- Si le script est signe numeriquement (recommande en environnement `-ExecutionPolicy AllSigned`/`RemoteSigned`) : le certificat de signature doit etre approuve sur la machine cible.

---

## Premier lancement (pas a pas)

1. Copier **a la fois** `Toolbox-SystemCommands_Win11.ps1` **et** `Commands.psd1` sur la machine cible, dans le meme dossier (ex : `C:\Scripts\Toolbox`). Le script ne trouvera pas ses commandes si `Commands.psd1` est laisse de cote.

2. Valider le catalogue et les fonctions internes **sans ouvrir l'interface et sans droits admin** :

   ```powershell
   .\Toolbox-SystemCommands_Win11.ps1 -SelfTest
   ```

   Execute 47 assertions : structure du catalogue (chaque commande a un libelle/une commande/une description/un flag confirm, aucun libelle duplique), regressions connues (aucun pipe non echappe, aucun `wmic`, les blocs `-EncodedCommand` decodent et se parsent tous correctement), les six commandes sensibles nommees portent toutes `Confirm = $true`, toutes les fonctions requises sont definies, les chemins de journalisation/favoris sont valides, et la verification d'elevation elle-meme fonctionne. Sort avec le code `0` si tout passe, `1` sinon.

3. Lancer la toolbox normalement (accepter le prompt UAC) :

   ```powershell
   .\Toolbox-SystemCommands_Win11.ps1
   ```

4. Parcourir par categorie, ou appuyer sur `Ctrl+F` et rechercher ce dont vous avez besoin (ex : "DNS", "BitLocker", "telemetrie").

5. Cliquer sur une commande. Si elle est marquee sensible, confirmer le prompt Oui/Non. Une fenetre console s'ouvre et l'execute — lisez sa sortie directement la.

6. Marquer d'une etoile (⭐) les commandes que vous utilisez souvent — elles seront ensuite rapidement filtrables sans avoir a fouiller dans les categories.

7. Pour consulter ce qui a ete lance, utiliser le bouton d'export HTML ou JSON dans la barre superieure.

---

## Raccourci bureau

Lancer la toolbox par clic droit sur le fichier `.ps1` puis "Executer avec PowerShell" fonctionne, mais fait clignoter brievement une fenetre console et la laisse ouverte derriere l'interface graphique. Un raccourci bureau evite les deux problemes et offre un lancement par simple double-clic.

1. Clic droit sur le Bureau → **Nouveau → Raccourci**.

2. Dans l'emplacement, saisir (en adaptant le chemin du script a l'endroit ou vous l'avez place) :

   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Scripts\Toolbox\Toolbox-SystemCommands_Win11.ps1"
   ```

   | Parametre | Pourquoi |
   |---|---|
   | `-NoProfile` | Ignore le chargement de votre profil PowerShell, donc la toolbox demarre plus vite et n'est pas affectee par un contenu personnalise dans ce profil |
   | `-ExecutionPolicy Bypass` | S'applique uniquement a ce processus — permet au script de s'executer meme si la politique d'execution par defaut du systeme le bloquerait sinon, sans modifier cette politique a l'echelle de la machine |
   | `-WindowStyle Hidden` | Supprime la fenetre console PowerShell, pour que seule l'interface propre de la toolbox apparaisse |

3. Nommer le raccourci (ex : "Toolbox Commandes Systeme"), puis terminer.

4. *(Optionnel)* Clic droit sur le nouveau raccourci → **Proprietes** → **Changer d'icone...** pour choisir quelque chose de plus reconnaissable que l'icone PowerShell par defaut.

5. *(Optionnel)* Sur le meme onglet **Proprietes**, regler **Executer** sur **Reduite** en securite supplementaire — avec `-WindowStyle Hidden` deja present dans la commande, c'est normalement inutile, mais c'est une option sans risque sur les systemes ou un outil de securite intercepte et neutralise `-WindowStyle`.

L'invite d'elevation UAC continue de s'afficher au lancement — `-WindowStyle Hidden` masque uniquement la fenetre console, elle ne supprime pas (et ne doit pas supprimer) la confirmation administrateur.

---

## Parametres en ligne de commande

| Parametre | Description |
|---|---|
| `-SelfTest` | Execute la batterie de tests internes a 47 assertions (integrite du catalogue, fonctions requises, regressions connues) puis quitte. Aucun droit admin requis, l'interface ne s'ouvre jamais. Code de sortie `0` = tout est passe, `1` = au moins un echec. |

Il n'existe pas de parametre CLI pour lancer une commande specifique directement — la toolbox est concue pour la navigation et le clic, pas pour l'invocation scriptee.

---

## Fichiers ecrits par le script

| Fichier / dossier | Contenu |
|---|---|
| `%USERPROFILE%\Desktop\Rapports_Maintenance\ToolboxCommandes\Historique.log` | Journal texte brut, ajout uniquement, de chaque commande lancee — horodatage, nom de machine, utilisateur, version de Windows, et PID du processus lance |
| `%USERPROFILE%\Desktop\Rapports_Maintenance\ToolboxCommandes\Favoris.txt` | Un libelle de commande favorite par ligne, recharge au lancement suivant |
| `Historique.html` *(a la demande, bouton d'export)* | Rapport visuel a theme sombre, groupe par jour et repliable, avec recherche et cartes de statistiques |
| `Historique.json` *(a la demande, bouton d'export)* | Memes donnees d'historique en JSON exploitable par machine |

La toolbox ne redirige ni ne capture jamais la sortie des commandes qu'elle lance — chacune s'execute dans sa propre fenetre `cmd.exe` interactive, donc le journal enregistre *ce qui* a ete lance, pas sa sortie. Voir [Depannage](#depannage) pour comprendre pourquoi c'est un choix delibere, pas un oubli.

---

## Etendre le catalogue

Ajouter une commande signifie editer directement `Commands.psd1` — il n'y a volontairement pas d'editeur integre a l'application, pour garder le catalogue en texte brut, facile a comparer, versionner et synchroniser entre machines.

```powershell
@{ Label   = "Ma nouvelle commande"
   Cmd     = 'ipconfig /all'
   Desc    = "Affiche dans le panneau de description fixe quand la commande est selectionnee."
   Confirm = $false
   # Help  = "Optionnel — n'ajouter cette cle que si vous voulez activer le bouton '?'."
}
```

**Regles, imposees par `-SelfTest`:**

- `Cmd` doit **toujours** utiliser des guillemets simples, jamais des guillemets doubles — c'est ce qui rend l'interpolation de variable (`$_`, `$err`...) structurellement impossible, pas seulement evitee par convention. Si le texte lui-meme a besoin d'un guillemet simple litteral, le doubler (`''`).
- `Desc` et `Help` utilisent des guillemets doubles par convention — tout `$` litteral qu'ils contiennent doit etre echappe par un backtick (`` `$ ``), sinon le mode "restricted language" d'`Import-PowerShellDataFile` refusera de charger **tout** le catalogue (un seul `$` non echappe dans le champ `Help` d'une commande a deja casse toute la toolbox de cette maniere — voir l'historique de version du script pour le detail de l'incident).
- Chaque commande a besoin de `Label`, `Cmd`, `Desc`, et `Confirm` — aucun des quatre ne peut etre omis.
- Lancer `-SelfTest` apres chaque modification, avant de se fier au changement.

---

## Deploiement multi-machines

1. **Distribuer les deux fichiers ensemble** : `Toolbox-SystemCommands_Win11.ps1` et `Commands.psd1`, dans le meme dossier.

2. **Approuver le certificat de signature** si une politique d'execution stricte est en place (`-ExecutionPolicy AllSigned`/`RemoteSigned`).

3. **Executer `-SelfTest` en premier** sur chaque machine — aucun droit admin necessaire, l'interface ne s'ouvre jamais, sans risque a lancer avant de decider de la suite. Un code de sortie `1` signifie que quelque chose dans le catalogue necessite votre attention avant utilisation.

4. Comme la toolbox est un **lanceur graphique pense pour un usage interactif, en presence d'un utilisateur**, elle n'est pas concue pour etre declenchee de maniere non supervisee depuis une tache planifiee comme le serait un script de nettoyage — il n'existe pas de parametre CLI pour lancer une commande specifique de maniere non interactive. Deployez-la comme un outil que les gens ouvrent et parcourent eux-memes, pas comme une tache de fond.

5. Garder `Commands.psd1` identique sur toutes les machines — c'est son but.

---

## Depannage

<details>
<summary><strong>La fenetre console d'une commande est vide ou se ferme instantanement</strong></summary>

C'etait historiquement le symptome d'un probleme de decodage ou de syntaxe `-EncodedCommand` (voir l'incident "AutoPlay/AutoRun" dans l'historique de version). Lancer `-SelfTest` — les deux assertions dediees `-EncodedCommand` decodent et verifient la syntaxe de chaque commande encodee du catalogue, et detecteraient ce probleme avant meme que vous ne cliquiez sur le bouton.
</details>

<details>
<summary><strong>Le chargement de Commands.psd1 echoue, ou tout le catalogue est vide</strong></summary>

Presque toujours un `$` non echappe dans un champ `Desc` ou `Help` (qui utilisent des guillemets doubles, donc PowerShell tente de l'interpoler comme une variable — le mode "restricted language" d'`Import-PowerShellDataFile` refuse alors de charger le fichier entier). Chercher dans le fichier modifie en dernier un `$` litteral non precede d'un backtick. `-SelfTest` inclut une verification de regression dediee qui scanne chaque ligne `Desc`/`Help` a la recherche exactement de ce motif.
</details>

<details>
<summary><strong>-SelfTest signale un FAIL</strong></summary>

Lire le libelle de l'assertion — il pointe directement vers le probleme : un champ manquant sur une commande specifique, un libelle duplique, un `$` non echappe, un appel `wmic` reapparu, ou une commande sensible ayant perdu son `Confirm = $true`. Corriger l'entree du catalogue, puis relancer `-SelfTest`.
</details>

<details>
<summary><strong>Le rapport d'historique ne montre pas ce qu'une commande a reellement affiche</strong></summary>

C'est voulu — chaque commande se lance dans sa propre fenetre `cmd.exe` interactive (`Start-Process`, sans redirection de sortie), donc `Historique.log` enregistre la commande qui a ete lancee, pas sa sortie. Capturer la sortie reelle impliquerait de rediriger chacune des 145 commandes vers un fichier journal, ce qui changerait aussi le comportement de plusieurs d'entre elles (celles volontairement laissees interactives/ouvertes, comme les moniteurs reseau en temps reel) par rapport a leur usage prevu — un changement architectural plus large, pas la conception actuelle.
</details>

---

<sub>Toolbox-SystemCommands_Win11 — lanceur WinForms, confirmation par commande sur tout ce qui modifie l'etat systeme, journalisation complete de l'historique, self-test a 47 assertions.</sub>
