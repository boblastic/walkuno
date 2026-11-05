# Walkuno

Application native iPhone et Apple Watch de suivi des pas, éditée par Orbelio. SwiftUI, HealthKit, Swift Charts, WidgetKit, StoreKit 2. Aucun serveur, compte, SDK publicitaire ou dépendance tierce.

## Démarrer

1. Ouvrir `Walkuno.xcodeproj` dans Xcode.
2. Choisir le schéma **Walkuno**, puis un simulateur iPhone. iOS 17 minimum ; watchOS 10 minimum.
3. Lancer. Le parcours d’accueil propose Santé, l’objectif et l’apparence.
4. Pour un aperçu rempli : Edit Scheme → Run → Arguments → ajouter `--demo` à une configuration **Debug**. Ce mode affiche un bandeau explicite et n’écrit ni dans Santé ni dans le cache partagé.

Le projet et les deux schémas sont déjà générés et partagés. Aucun outil de génération externe n’est nécessaire. Xcode 27.1 a été utilisé pour la compilation initiale.

## Inclus

- Accueil compact avec compteur et anneau animés ensemble, navigation par balayage et vues jour/semaine/mois/année (année avec Pro) ; série d’objectifs, distance, énergie optionnelle, durée d’exercice, étages et courbe d’activité récente. La moyenne du graphique suit la palette sélectionnée. En mode jour, le rythme horaire compare des barres du thème pour le jour sélectionné et des barres grises pour la veille, côte à côte. Les compteurs voisins sont préparés en mémoire et suivent le geste ; si le remplissage est activé, ils commencent directement à zéro pendant le glissement. Le glissement se termine en 0,5 seconde avec une légère rotation en perspective pour rendre le basculement visible. Réglages → À votre image → Animer les changements de période permet de réactiver le remplissage ; le sélecteur Jour / Semaine / Mois / Année rejoue toujours l’animation du cercle et du compteur, comme à l’ouverture d’aujourd’hui. Les totaux et objectifs suivent la période sélectionnée ; le détail et le partage conservent la date choisie.
- Objectifs libres de 500 à 100 000 pas, préréglages, historique daté ; 8 000 par défaut.
- Agrégations Santé multicapteurs, lecture seule, données absentes distinctes du zéro, observations en arrière-plan et actualisation au retour au premier plan.
- Onglet Explorer avec sélecteur jour/semaine/mois/année et date fixes dans un panneau Liquid Glass, au-dessus des cartes défilantes. Balayage horizontal animé de toutes les cartes, avec périodes voisines précalculées et détails horaires préchargés ; bulles de valeur au toucher et glissement après un bref appui maintenu (balayage rapide pour changer de période), calendrier d’intensité et détail horaire. Les mois prennent une majuscule en début de libellé ou lorsqu’ils sont seuls.
- Statistiques : cartes « Mon activité du jour » avec comparaison à la même heure, courbe habituelle jusqu’à 24 h, repères toutes les six heures et objectif de pas annoté, tendances sur 7 jours/mois/année avec périodes précédente et actuelle côte à côte, repères calendaires et emplacements futurs vides, records et historique annuel en totaux ou moyennes. Un sélecteur commun Pas / Distance / Énergie / Exercice / Étages reste fixe sous le bandeau et actualise tous les graphiques ; le contenu défile derrière son Liquid Glass, avec le même réglage de transparence que le bandeau. Bulles au toucher/glissement sur les courbes, tendances, records horaires et agrégés. En-tête quotidien compact avec les valeurs Aujourd’hui / Habituellement ; graphiques dans la palette choisie, sans descriptions ni détails dépliables.
- Trophées en quatre catégories : cinq records quotidiens en tête, objectifs à 100/200/300 % avec compteurs, semaines/mois/années parfaits, séries de 7/15/30 jours et 22 traversées cumulées toujours affichées avec multiplicateurs et progressions. [Catalogue et règles](Documentation/Trophees.md). Partage natif de cartes journée/semaine/record/étape avec distance facultative.
- Neuf palettes avec sélecteur visuel et aperçu dans Réglages → Palette de couleurs, mode sombre permanent et kilomètres/miles. Cinq compteurs natifs avec aperçu dans Réglages → Style du compteur : Anneau, Horizon, Chemin, Paliers et Typographique ; chaque dessin suit les deux couleurs de la palette et représente les dépassements d’objectif. Les cinq styles portent une traînée d’étoiles à dégradés nacrés et halos colorés : chaque étoile dérive puis s’éteint individuellement, et les dernières se dissipent après le remplissage. Aucune étoile ne reste au repos ; la réduction des animations affiche directement la valeur finale. La même galerie propose quatre effets indépendants du dessin : Étoiles, Feu vivant (flammes et braises), Aurore boréale (voiles irisés) et Onde liquide (perles et sillage brillant), avec sélection mémorisée et bouton de relecture. Tous se dissipent entièrement après le remplissage.
- Bandeau fixe avec un espace réservé au début du contenu sur les cinq onglets, le parcours d’accueil et les fenêtres de détail, badge Gratuit/Pro à côté du logo et accès « Mon compte » à droite (formule, achats et réglages, sans compte en ligne). Liquid Glass natif dès iOS 26, matériau translucide sur iOS 17–25 ; transparence réglable dans Réglages → Liquid Glass, avec respect des options d’accessibilité iOS.
- Quatre familles de widgets iPhone, chacune en petit, moyen et grand : **Compteurs**, **Graphiques**, **Tendances**, **Tableau de bord**. Anneaux et cinq dessins de compteur, pas/distance/objectif, rythme horaire de l’accueil (aujourd’hui/veille), 24 heures glissantes, suivi cumulatif, semaine en courbe/barres avec moyenne, comparaisons 7 jours/mois/année et calendrier d’intensité. Les tendances proposent les cinq mesures ; les périodes suivent l’historique disponible et l’année nécessite Pro. Palette, unités, objectif et énergie masquée suivent les réglages de l’application. Écran verrouillé : compteurs circulaires, ligne de texte et rectangles avec chiffres, graphiques et moyenne ; deux rectangles occupent la rangée complète. Les identifiants des widgets installés sont conservés. Cache borné et invalidé au changement de jour/fuseau.
- Compagnon Watch autonome pour Santé, sept jours récents, objectifs et complications distinctes. Les anneaux des variantes pas, distance + pas et progression suivent l’objectif de pas ; la distance respecte le choix kilomètres/miles. Synchronisation différée des objectifs et préférences.
- StoreKit 2 avec transactions vérifiées, droits réévalués, restauration et gestion des abonnements. Les prix affichés viennent des produits Apple.
- Interface en français, anglais, allemand, espagnol, italien, portugais et japonais sur iPhone, Watch et widgets ; anglais par défaut si aucune langue préférée n’est prise en charge. Dynamic Type, VoiceOver, réduction des animations, confidentialité intégrée et effacement local.

Gratuit : compteur, objectifs, 31 jours récents, records de base, palette Grande foulée, widgets. Premium : historique complet et année, autres palettes, quatre styles de compteur supplémentaires, records semaine/mois. Le compteur fonctionne sans paiement même si les produits App Store sont indisponibles.

## Vérifier

```sh
python3 Scripts/validate_localizations.py
swift test --scratch-path /tmp/walkuno-core-tests
xcodebuild -project Walkuno.xcodeproj -scheme Walkuno \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/walkuno-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Walkuno.xcodeproj -scheme Walkuno \
  -destination 'platform=iOS Simulator,name=Walkuno QA' \
  -derivedDataPath /tmp/walkuno-derived test
```

Les tests Swift couvrent les valeurs absentes, les objectifs historiques, les conflits Watch, les séries, les bornes calendaires et les caches périmés. Les tests XCUITest couvrent navigation, présentation Premium non bloquante, objectif et confidentialité.

La langue suit les préférences du système et le choix de langue par application d’iOS. Les variantes régionales utilisent la traduction de leur langue (`es-MX` → espagnol, `pt-BR` → portugais). Si aucune langue préférée n’est disponible, l’anglais est utilisé via la langue de développement du bundle. Les autorisations Santé, les messages d’achat, VoiceOver et les cartes partagées sont également traduits. Les noms Walkuno, Orbelio, Pro, Premium et Liquid Glass sont conservés. Les titres des produits vendus proviennent de l’App Store : renseigner aussi leurs traductions dans App Store Connect ; le fichier StoreKit local contient les sept langues pour les essais.

`Scripts/validate_localizations.py` vérifie la parité des textes, les paramètres de format, les ressources des quatre cibles et le repli anglais. Avec `--app-bundle /chemin/Walkuno.app`, il compare aussi les traductions compilées des quatre bundles aux sources. Les trois tests UI de localisation couvrent les sept langues, leurs variantes régionales, le parcours d’accueil, les préférences ordonnées et le repli anglais pour le néerlandais, le chinois et le coréen/suédois.

Pour tester les achats localement : Edit Scheme → Run → Options → StoreKit Configuration → `Config/Walkuno.storekit`. Ce fichier contient les hypothèses tarifaires du cahier des charges ; il n’est pas actif par défaut et n’est pas embarqué dans l’app. Les offres doivent être créées séparément dans App Store Connect.

En configuration **Debug**, l’écran d’abonnement propose aussi **Activer le mode Pro** dans une carte Développement. Ce choix persiste après relancement et permet de tester les fonctions payantes sans achat, même si les offres App Store sont indisponibles. Désactiver l’interrupteur rétablit les droits StoreKit réels. Ce contrôle et la simulation d’accès sont exclus des builds Release. Le badge du bandeau commun affiche **Gratuit** ou **Pro** selon l’accès effectif.

## Configurer avant un appareil physique

L’équipe du certificat de développement local est préconfigurée (`SZ36PWDB9C`) et le compte correspondant est connecté dans Xcode. Les profils des quatre cibles ont été créés et l’application installée sur l’iPhone et la Watch. Ces profils personnels sont valables jusqu’au **11 novembre 2026**. Pour une nouvelle machine, connecter le compte dans Xcode → Réglages → Comptes et configurer les identifiants `fr.orbelio.walkuno`, `.widgets`, `.watchkitapp`, `.watchkitapp.widgets` et `group.fr.orbelio.walkuno`, avec HealthKit et Background Delivery sur les applications, App Groups et Data Protection sur les quatre cibles. Voir [Publication](Documentation/Publication.md) et le [relevé de validation](Documentation/Validation.md).

## Structure

| Dossier | Rôle |
| --- | --- |
| `Sources/WalkunoCore` | Modèles et calculs Foundation, testables sur macOS |
| `AppShared` | HealthKit, cache protégé, WatchConnectivity, composants graphiques |
| `Walkuno` | Application iPhone, vues, achats et traductions |
| `Widgets` | Widgets iOS et complications watchOS |
| `WatchApp` | Application Watch |
| `Tests` | Tests métier et XCUITest |
| `Config` | Plists, capacités, manifeste de confidentialité, StoreKit local |
| `Documentation` | Architecture, recette, audit, publication, textes de fiche |
| `Scripts` | Génération reproductible du projet et de l’icône |

Après ajout de sources : `python3 Scripts/generate_project.py`. Ne pas relancer `configure.py` après personnalisation des identifiants sans reporter ces changements dans le script : il écrit la configuration initiale. L’icône principale et les huit variantes de palette peuvent être régénérées avec `swift Scripts/generate_icon.swift`. Le logo des vues, des widgets, du partage et de la Watch suit la palette active. Sur iPhone, l’icône d’accueil suit également la palette, avec retour à Grande foulée lorsque l’accès Premium est désactivé. La synchronisation attend la vérification initiale des droits pour conserver l’icône au lancement. watchOS conserve son icône de lanceur statique.

## État de livraison

Version de développement compilable, à recetter. Une compilation et des tests simulateur ne constituent pas une validation Santé sur matériel ni une candidature App Store. La configuration des achats, la signature, la vérification iPhone/Watch, l’accessibilité sur appareils et les mesures batterie/performance restent nécessaires. Voir [Recette](Documentation/Recette.md) pour les points précis et le [cahier des charges original](Documentation/Cahier-des-charges.md).
