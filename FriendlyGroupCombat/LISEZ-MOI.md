# Smart Friendly Nameplates — 0.1.4

Première version pour **WoW Forever 1.60.1**, interface **16001**.

Les barres des joueurs amicaux sont affichées si le joueur est dans votre
groupe/raid **ou si ce joueur est lui-même en combat**. Les autres gardent
**leur nom seul**, sans barre de vie, niveau ou autres éléments de la barre d'info.
Votre propre combat n'est pas un critère. Aucun filtre n'est
appliqué aux ennemis, aux PNJ ou à la barre personnelle.

Les **noms seuls prennent la couleur de classe**. Avec une barre de vie visible,
le nom reprend sa couleur normale. L'addon maintient donc l'option globale
« Utiliser les couleurs de classes pour les noms » décochée et applique la
couleur uniquement au texte des joueurs dont il masque la barre. L'ancienne
valeur de cette option est restaurée à la désactivation du filtre.

## Installation

1. Fermez le jeu pour cette première installation.
2. Copiez le dossier `FriendlyGroupCombat` dans :
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
3. Vérifiez que le fichier est bien à cet emplacement :
   `Interface\AddOns\FriendlyGroupCombat\FriendlyGroupCombat.toc`.
4. Lancez **Forever** et activez **Smart Friendly Nameplates** dans la liste des addons.

Le dossier technique `FriendlyGroupCombat` est conservé pour garder vos réglages.
Le nom affiché dans le jeu est **Smart Friendly Nameplates**.

Pour passer d'une version déjà installée à celle-ci, remplacez ses fichiers puis
faites `/reload`. Il n'est pas nécessaire de recréer vos réglages.
Après la version 0.1.1, `/reload` est indispensable pour supprimer l'état
perturbé dans l'interface. Si vous aviez désactivé le filtre, faites ensuite
`/sfn on` hors combat. Le correctif 0.1.2 n'appelle plus les fonctions Lua
internes de Blizzard : il rend transparents les éléments autres que le nom,
sans modifier leur état ni manipuler les valeurs de santé.

Le filtre est actif par défaut. Il active les barres des joueurs amicaux et
désactive leur mode « nom uniquement », en mémorisant les valeurs précédentes.
Pour tester l'affichage des barres complètes, évitez aussi les modes simplifiés
des barres dans les options du jeu.

## Commandes

- `/sfn on` : active le filtre et les réglages nécessaires.
- `/sfn off` : désactive le filtre, rétablit l'affichage natif et restaure les
  réglages précédents que vous n'avez pas changés entre-temps.
- `/sfn status` : état, version du client, nombre de barres et réglages.
- `/sfn debug` : informations de groupe/combat et décision pour votre cible.
- `/sfn colors off` : désactive la coloration des noms seuls et rétablit l'option
  de couleur globale précédente, sans arrêter le filtre des barres.
- `/sfn colors on` : réactive la couleur de classe uniquement pour les noms seuls.
- `/bgc` et `/fgc` restent des alias de `/sfn` pour les versions précédentes.

Si la modification d'un réglage est demandée pendant votre combat, elle attend
la sortie de combat. Les entrées/sorties de combat des autres joueurs sont
vérifiées environ toutes les 0,2 seconde, même si vous restez hors combat.
`/sfn on` réapplique les réglages si vous avez désactivé les barres avec Maj+V.

Avant de désinstaller ou de décocher l'addon, faites `/sfn off` **hors combat**
pour restaurer les options. Un addon désactivé ne peut plus restaurer ses réglages.

## Limites

- **Version expérimentale : les tests automatisés ne remplacent pas un essai en jeu.**
- Les barres amicales rendues inaccessibles par Blizzard, notamment en donjon/raid,
  sont laissées telles quelles. Aucun contournement n'est tenté.
- Si une donnée est secrète ou indisponible, la barre reste visible.
- L'affichage « nom seul » utilise le texte Blizzard de la barre, en conservant
  son contenu et sa transparence ; la couleur de classe s'applique par défaut.
  Si la classe ou la couleur est inaccessible, la couleur native est conservée.
  Ce n'est pas le texte 3D du moteur
  lorsque l'option des barres amicales est décochée : police, emplacement ou
  comportement à distance peuvent différer. Les options générales d'affichage
  des noms du jeu continuent de s'appliquer.
- Les ancrages, zones de clic et règles d'empilement restent ceux de Blizzard.
  La barre de vie transparente peut donc encore avoir une zone de clic et
  occuper de la place dans l'empilement des barres.
- Les options natives (portée, noms uniquement, style simplifié, etc.) continuent
  de s'appliquer. L'addon filtre les barres créées par le jeu.
- Évitez de combiner ce filtre avec un autre addon qui règle la transparence ou
  active/désactive les barres amicales. Cette version vise les barres Blizzard.

## Essai en monde ouvert

1. `/sfn status` doit indiquer « actif » et `nameplateShowFriendlyPlayers = 1`.
2. Un joueur amical hors groupe et hors combat doit garder son nom, sans barre de vie.
3. Invitez ce joueur : sa barre doit apparaître même s'il reste hors combat.
4. Quittez le groupe : seul le nom doit rester.
5. Sans être groupé, observez un joueur amical combattre : sa barre doit apparaître,
   puis revenir au nom seul après son combat, même si vous n'avez pas combattu.
6. Vérifiez qu'un ennemi et un PNJ conservent leur affichage habituel.
7. Éloignez-vous puis revenez : vérifiez que les noms restent présents et que
   les barres des joueurs du groupe ou en combat réapparaissent correctement.
8. `/sfn off` doit rétablir l'affichage normal ; `/sfn on` relance le filtre.
9. Faites `/reload` et changez de zone pour vérifier que le filtre reprend.
10. En donjon/raid, vérifiez l'absence d'erreur ; les barres verrouillées restent natives.
11. Pour un joueur hors groupe et hors combat, vérifiez la couleur de classe du nom.
    Invitez-le ou attendez son combat : le nom doit reprendre sa couleur normale.

En cas de problème, notez le lieu et le résultat de `/sfn status`. Ciblez le joueur
concerné puis lancez `/sfn debug`. Si une erreur Lua apparaît, conservez son texte.

## Références vérifiées

- [API d'unités du client Forever](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Gestion des barres par Blizzard](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)
- [Restrictions documentées par Dynamic Display Nameplate](https://github.com/rubens-lopes/DynamicDisplayNameplate#inside-dungeons-and-raids)

Ce projet est un addon indépendant ; il ne nécessite pas Dynamic Display Nameplate.
