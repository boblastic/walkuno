# Vérifications du 4 novembre 2026

Environnement de compilation : Xcode 27.1, Swift 6.4 ; sources applicatives en mode Swift 5, cœur testé en mode Swift 6. iOS 17 / watchOS 10 minimum. Aucune bibliothèque tierce.

| Vérification | Résultat |
| --- | --- |
| Tests Foundation | 8 réussis |
| Tests d’interface iPhone | 4 réussis : navigation/Premium, objectif/confidentialité, accueil/effacement, partage |
| Compilation Debug simulateur | Application iPhone, widgets iOS, application Watch et complications compilés |
| Compilation Release appareils sans signature | 4 cibles compilées ; aucune erreur ou alerte Swift dans la dernière passe |
| Lancement Watch sur simulateur | Réussi, état sans mesure contrôlé |
| Localisations | 174 clés identiques en français et anglais ; fichiers validés |
| Configuration | Plists, entitlements, manifeste et JSON StoreKit analysés sans erreur |
| Revue de sécurité | Voir `Audit-securite.md` ; aucun problème confirmé dans le périmètre vérifié |
| Signature de développement | Réussie pour les quatre cibles ; signatures vérifiées, appareils autorisés, capacités Santé/App Groups/Data Protection présentes |
| Installation physique | Réussie sur l’iPhone et l’Apple Watch ; lancement confirmé sur les deux appareils |

Le compte Apple a été connecté dans Xcode par l’utilisateur. Xcode a créé les quatre profils de développement pour l’équipe personnelle préconfigurée. Les profils sont valables jusqu’au **11 novembre 2026** : une nouvelle signature et une réinstallation seront nécessaires après cette date avec ce type de profil.

L’iPhone avait atteint la limite Apple de trois applications sous profil gratuit. Après autorisation explicite de l’utilisateur, iComptes a été désinstallé pour libérer une place, puis Walkuno a été installé. La Watch a reçu son application compagnon. Les deux applications ont été lancées sans argument de démonstration. Aucune autorisation Santé personnelle n’a été accordée par l’agent ; le parcours d’accueil laisse ce choix à l’utilisateur.

Pour renouveler l’installation, le script `Scripts/install_devices.py --iphone UDID --watch UDID` compile avec signature automatique, vérifie les deux bundles puis installe et lance Walkuno. Les identifiants d’appareils doivent être choisis explicitement via `xcrun devicectl list devices`. L’installation ne téléverse rien sur App Store Connect.

Les captures de `Captures/` utilisent des mesures de démonstration ou des états vides. Elles servent à la recette visuelle, pas à prouver la fiabilité de HealthKit sur un appareil physique. La cohérence Santé, les achats Sandbox, le comportement au verrouillage et la batterie restent à vérifier selon `Recette.md`.

## Correctif d’actualisation du 4 novembre 2026

- 35 tests Foundation réussis lors de la dernière passe sur les sources partagées, dont huit tests couvrant les délais limites, les callbacks tardifs, l’annulation, le regroupement des demandes et l’absence de relance après erreur.
- Quatre scénarios supplémentaires exécutés avec le véritable AppModel et des services synthétiques : les données récentes arrivent avant l’historique ancien, cet historique ne remplace pas les nouvelles mesures, un échec horaire conserve les totaux et l’effacement bloque les relances/réponses tardives. Tous réussissent. Aucun accès aux données Santé personnelles pour ces vérifications.
- Les quatre cibles compilent en Debug pour simulateur et appareils ; la signature du bundle iPhone est vérifiée. La version corrigée est installée et lancée sur l’iPhone connecté en conservant ses données. La Watch était déconnectée : son correctif est compilé, sans réinstallation directe vérifiée pendant cette intervention.
- La suite d’interface a cinq scénarios réussis et trois échecs en mode démo : navigation/Premium, balayage des périodes et statistiques. Les journaux signalent un arrêt inattendu du runner pour la navigation, une assertion de balayage et une interruption pendant les statistiques. Des modifications d’interface et de tests sont arrivées en parallèle ; cette exécution ne valide pas l’ensemble de l’interface actuelle. Le mode démo désactive le chemin Santé corrigé.
- Une nouvelle exécution ciblée du test de balayage, après mise à jour du projet avec les nouveaux fichiers d’interface, échoue encore lors du retour au jour courant (`testHomeSwipesAndChangesPeriod`). Ce point de navigation est distinct des lectures Santé et reste ouvert.

Les contrôles locaux ne prouvent pas la réception de nouvelles mesures HealthKit sur matériel. Cette recette, les livraisons en arrière-plan et le comportement appareil verrouillé restent à réaliser. La revue ciblée de confidentialité et la course corrigée pendant l’effacement sont documentées dans `Audit-securite.md`.

## Sept langues et repli anglais — 4 novembre 2026

- 269 textes disponibles en français, anglais, allemand, espagnol, italien, portugais et japonais, plus l’autorisation Santé. La signature des réglages et des cartes partagées est traduite. Les deux produits StoreKit locaux disposent également des sept langues.
- `python3 Scripts/validate_localizations.py` réussit : clés, valeurs non vides, paramètres de format, ressources Xcode des quatre cibles et langue de repli anglaise vérifiés. La régénération du projet conserve les configurations de compilation existantes.
- Compilations Debug et Release pour simulateur réussies sur les quatre cibles. Le validateur exécuté avec `--app-bundle` confirme que chaque traduction compilée correspond à sa source et que chaque bundle déclare `CFBundleDevelopmentRegion = en`.
- **3 tests UI réussis, aucun échec**, sur le simulateur isolé iPhone 18 Pro / iOS 27. Parcours accueil/statistiques/succès/réglages/Premium dans les sept langues, avec `en-GB`, `fr-FR`, `de-DE`, `es-MX`, `it-IT`, `pt-BR` et `ja-JP`. L’accueil initial est également vérifié en japonais et en anglais de repli. Le néerlandais seul, le chinois seul et la liste coréen/suédois donnent l’anglais ; la liste néerlandais/allemand/français donne l’allemand, première langue disponible.
- Contrôle visuel des captures allemandes et japonaises, sans anomalie de lisibilité relevée. Les captures utilisent uniquement les données de démonstration.

Preuves locales : `/tmp/walkuno-languages-ui.xcresult`, `/tmp/walkuno-languages-ui.log`, `/tmp/walkuno-languages-release.log`. Les bundles contrôlés sont dans `/tmp/walkuno-languages-derived/Build/Products/Debug-iphonesimulator/Walkuno.app` et `/tmp/walkuno-languages-release/Build/Products/Release-iphonesimulator/Walkuno.app`.

Cette intervention modifie le projet ; aucune nouvelle installation sur iPhone ou Watch physique, ni mise à jour App Store Connect n’a été effectuée. Les noms et descriptions des offres commerciales proviennent d’Apple et restent à renseigner dans ces sept langues dans App Store Connect avant publication.

## Correctif de balayage de l’accueil du 4 novembre 2026

Le geste de balayage horizontal a maintenant la priorité sur le toucher du compteur qui ouvre le détail. Le seuil et le filtrage horizontal restent identiques.

Quatre scénarios d’interface réussissent sur les simulateurs iOS 26 et 27 : navigation jour/semaine/mois dans les deux sens, balayages courts lents et rapides sans ouverture du détail, défilement vertical suivi d’un toucher ouvrant le détail, et détail/partage du jour sélectionné. Les gestes synthétiques sur la version d’origine n’ont pas reproduit l’ouverture involontaire signalée ; la correction rend la priorité des gestes explicite.

La compilation Debug pour appareils et la vérification de signature du bundle iPhone réussissent. La version corrigée est installée et lancée sur l’iPhone connecté, sans désinstallation ni argument de démonstration. Le comportement tactile sur cet appareil reste à confirmer à l’usage.

## Année dans le sélecteur d’accueil — 4 novembre 2026

- L’accueil propose Jour / Semaine / Mois / Année. La vue annuelle conserve l’accès Pro, affiche les totaux et objectifs de l’année sélectionnée, les repères mensuels du graphique et la comparaison avec l’année précédente. Le partage conserve l’année, ses pas et sa distance.
- Compilation Debug simulateur réussie pour les quatre cibles. Les 271 textes et les traductions compilées sont vérifiés dans les sept langues.
- Deux scénarios UI réussissent sur iPhone / iOS 27 : disposition des quatre segments ; accès Pro, navigation vers l’année précédente, partage du même total annuel, retour à l’année courante et retour au jour après désactivation de Pro.

Preuves : `/tmp/walkuno-year-ui.xcresult` (disposition) et `/tmp/walkuno-year-final.xcresult` (parcours annuel).

## Anneau au-delà de 100 % — 4 novembre 2026

L’anneau conserve le premier tour complet et trace le dépassement dans une voie contrastée, avec un repère à son extrémité. Les tours supplémentaires alternent clair et sombre pour rester visibles après 200 %. Le total est interpolé avant le calcul des tours pour conserver une animation dans le sens horaire. Ce rendu est partagé par l’accueil, les cartes de partage, la Watch et les widgets circulaires, y compris les complications.

- Compilation Debug simulateur réussie pour les quatre cibles.
- Test d’interface existant `testHomeSwipesAndChangesPeriod` réussi sur iOS 27 : navigation jour/semaine/mois et compteur animé. La capture de la semaine confirme le dépassement à 114 % dans l’accueil.
- Rendus SwiftUI contrôlés à 50, 100, 125, 150, 200, 250 et 300 % en apparences claire et sombre, ainsi qu’aux tailles des widgets et de la Watch.

Preuves : `/tmp/walkuno-ring-derived/Logs/Test/Test-Walkuno-2026.11.04_23-08-10-+0100.xcresult` et `/tmp/walkuno-ring-preview.png`.

## Contenu dégagé sous le bandeau — 4 novembre 2026

Le composant commun réserve la hauteur réelle du bandeau avec `safeAreaInset`, sur un conteneur extérieur aux vues défilantes. L’estimation initiale de 76 points et sa mise à jour après mesure sont supprimées. Les quatre onglets, l’accueil initial et les fenêtres de détail bénéficient de cette réservation dès la mise en page ; le défilement derrière le verre reste possible.

- Compilation Debug pour simulateur réussie sur les quatre cibles.
- **5 exécutions de tests UI réussies, aucun échec**, sur la version finale : deux sous iOS 26.3 et trois sous iOS 27. Les premiers éléments des quatre onglets, du compte, de Premium et de l’éditeur d’objectif sont contrôlés sous le bandeau. L’ouverture effective du compte après défilement des réglages est vérifiée sur les deux versions.
- Le parcours sans Santé ni achat, le premier affichage de l’accueil sans démonstration et son affichage après relancement sont vérifiés sous iOS 27.
- Captures finales des statistiques et de l’éditeur d’objectif contrôlées visuellement. Les contrôles initiaux en démonstration ne reproduisaient pas le chevauchement signalé ; la correction supprime la dépendance à une hauteur estimée puis mesurée.

Preuves : `/tmp/walkuno-header-layout-ios26-current.xcresult`, `/tmp/walkuno-header-layout-ios27-current.xcresult` et `/tmp/walkuno-header-layout-build-current.log`. Aucune installation physique effectuée pendant cette intervention.

## Sens du balayage de l’accueil — 5 novembre 2026

Le balayage vers la droite affiche désormais la période précédente ; vers la gauche, la période suivante. La navigation reste bloquée au jour ou à la période courante.

- Compilation Debug pour simulateur réussie sur les quatre cibles.
- **5 tests UI réussis, aucun échec**, sur iOS 27 : navigation jour/semaine/mois avec blocage du futur, aller-retour annuel et partage, gestes courts lents et rapides, défilement vertical puis ouverture du détail, détail et partage du jour sélectionné.

Preuves : `/tmp/walkuno-swipe-direction.xcresult` et `/tmp/walkuno-swipe-direction.log`. Aucune installation physique effectuée pendant cette intervention.

## Installation du correctif de bandeau sur iPhone — 5 novembre 2026

La compilation Debug pour appareils et la vérification de signature réussissent. Walkuno 1.0.0 (3) est installé sur l’iPhone connecté, puis relancé sans argument de démonstration et sans désinstallation. Les données existantes sont conservées.

Le contrôle visuel sur l’appareil confirme que le sélecteur de période, la date et le compteur de l’accueil sont dégagés sous le bandeau après relancement. Aucune installation directe sur la Watch n’a été effectuée.

Preuve de compilation, signature, installation et lancement : `/tmp/walkuno-header-device-install.log`.

## Explorer et mesure commune des statistiques — 5 novembre 2026

L’exploration jour/semaine/mois/année dispose de son propre onglet Explorer. Le calendrier, les détails horaires et les restrictions de l’historique gratuit sont conservés. Les titres et les mois isolés utilisent la capitalisation de début de phrase : « Novembre 2026 », « Janvier », tout en conservant « 5 novembre » dans une date. La même règle est appliquée aux dates de l’accueil et aux libellés des records.

Les statistiques partagent un seul choix Pas / Distance / Énergie / Exercice / Étages, fixé sous le bandeau. Les cinq cartes reçoivent la même mesure ; l’option de masquage de l’énergie reste prise en compte. Les noms courts et l’onglet Explorer sont traduits dans les sept langues.

- Les quatre cibles compilent en Debug pour simulateur. Les traductions compilées sont identiques aux sources dans les quatre bundles.
- 40 tests Foundation réussis.
- Le parcours des cinq onglets et des nouveaux libellés réussit dans les sept langues sur iOS 26.3.
- **5 exécutions UI finales réussies, aucun échec**, sur iOS 26.3 et 27 : navigation d’Explorer, capitalisation des mois et dates, ouverture d’un détail depuis le calendrier, sélection commune sur les cinq cartes, maintien de la position du menu après défilement et accès au compte depuis les statistiques défilées. La disposition des cinq onglets est également vérifiée sous iOS 26.3.
- L’accès Pro facultatif, les restrictions de l’historique gratuit et le contenu dégagé sous le bandeau sont vérifiés sous iOS 27. Le scénario de bandeau fixe sur les cinq onglets et les fenêtres de détail réussit également.

Preuves finales : `/tmp/walkuno-explorer-verified-ios26.xcresult`, `/tmp/walkuno-explorer-verified-ios27.xcresult`. Captures contrôlées dans `/tmp/walkuno-explorer-verified-captures/`. Tests Foundation : `/tmp/walkuno-explorer-core.log`. Le scénario des sept langues est réussi dans `/tmp/walkuno-explorer-ios26.log`. Aucune installation physique effectuée pendant cette intervention.

## Installation d’Explorer et des statistiques sur iPhone — 5 novembre 2026

La compilation Debug signée et la vérification de signature réussissent. La nouvelle version de Walkuno 1.0.0 (3), incluant Explorer, les majuscules contextuelles et le sélecteur commun fixe, est installée et lancée sur l’iPhone connecté, sans désinstallation et sans argument de démonstration. Le nouveau bundle et le processus Walkuno en cours d’exécution sont confirmés par les métadonnées de l’appareil. Le conteneur du groupe partagé est conservé. Le chemin du conteneur de données de l’application est renouvelé par l’installation ; aucune comparaison de son contenu n’est effectuée.

Une vérification supplémentaire par copie du fichier des préférences a été refusée par le contrôle automatique, qui considère ce fichier comme privé et hors du périmètre de l’autorisation d’installation. Cette copie n’a pas été effectuée ; aucun accès au contenu des préférences ou aux données Santé n’est utilisé pour cette validation.

Preuves : `/tmp/walkuno-explorer-iphone-install.log`, `/tmp/walkuno-explorer-iphone-before.json`, `/tmp/walkuno-explorer-iphone-after.json` et `/tmp/walkuno-explorer-iphone-processes.json`. Aucune installation directe sur la Watch n’a été effectuée.

## Liquid Glass du menu des statistiques — 5 novembre 2026

Le sélecteur Pas / Distance / Énergie / Exercice / Étages réserve sa hauteur au début du contenu avec `safeAreaInset`, puis les cartes défilent derrière lui. Il partage désormais le composant `WalkunoGlassSurface` du bandeau principal : même transparence réglable, même repli translucide avant iOS 26 et même opacité imposée par les options d’accessibilité iOS.

Compilation Debug réussie et **3 tests d’interface réussis, aucun échec**, sur iOS 27 : réglage de transparence, contenu initial dégagé sous le bandeau, sélection des cinq mesures et menu toujours fixe et utilisable après défilement. Les captures initiale et défilée confirment visuellement les cartes derrière le verre du menu.

Preuves : `/tmp/walkuno-statistics-glass-ui.xcresult`, journal `/tmp/walkuno-statistics-glass-ui.log` et captures `/tmp/walkuno-statistics-glass-captures/`. Aucune installation physique effectuée pendant cette intervention.

## Graphiques de l’accueil et palette — 5 novembre 2026

Le rythme horaire présente le jour sélectionné dans la couleur du thème et la veille en barres grises côte à côte. La légende et les descriptions VoiceOver des sept langues suivent ce rendu. Le texte et le repère de moyenne du graphique récent utilisent désormais la teinte du thème, adaptée à l’apparence claire ou sombre.

- Compilation Debug simulateur des quatre cibles réussie pour cette version des graphiques. Les 28 traductions compilées de la description modifiée correspondent aux sources.
- Les deux tests UI existants passent sur iOS 27 : rythme sur 24 heures et journée passée ; sélection des sept jours avec conservation de la fenêtre et de la moyenne. Le second a été relancé avec `test-without-building` après un arrêt du processus de test par le simulateur.
- Captures du simulateur contrôlées et rendu des composants réels vérifié en palettes Grande foulée et Rose, en clair et sombre : `/tmp/walkuno-home-chart-preview.png`.

Des modifications parallèles du compteur sont apparues après la première compilation. La recompilation intermédiaire du workspace échoue dans `TodayView.counter` sur le typage de l’expression `.id(...)` ; elles sont conservées, et les tests ci-dessus portent sur le bundle déjà compilé avec les graphiques corrigés.

Preuves : `/tmp/walkuno-home-chart-colors.xcresult` (rythme réussi ; processus du second test interrompu), `/tmp/walkuno-home-chart-colors-seven-retry.xcresult` (sept jours réussi), `/tmp/walkuno-home-chart-colors-seven.log` (compilation intermédiaire). Aucune installation physique effectuée.

## Trophées par catégories — 5 novembre 2026

L’onglet Succès affiche les cinq records quotidiens, les compteurs des objectifs à 100/200/300 %, les semaines/mois/années parfaits, les séries de 7/15/30 jours et une collection de 18 voyages cumulés. Les médaillons distinguent objectifs et séries ; les traversées possèdent leurs illustrations, leur multiplicateur et leur progression vers la traversée suivante. Le catalogue sourcé et les règles sont dans `Trophees.md`.

- 68 tests Foundation réussis sur l’état courant du dossier partagé, dont 11 nouveaux tests consacrés aux trophées : objectifs datés, dates distinctes, jours absents, cinq records indépendants, seuils exacts, calendrier et année bissextile, séries et répétitions de distances.
- Compilation Debug simulateur réussie des quatre cibles. Le parcours UI final des quatre catégories réussit : cinq records visibles, compteurs et progressions, absence de série à 60 jours, ouverture des 18 voyages jusqu’à la Terre, la Lune et le Soleil.
- 352 textes validés dans les sept langues ; les traductions compilées des quatre bundles correspondent aux sources. Contrôle visuel des captures des records, objectifs, périodes parfaites, séries et traversées sur iPhone/iOS 27 en mode démonstration.

Preuves : `/tmp/walkuno-trophies-core-final.log`, `/tmp/walkuno-trophies-ui-final.xcresult`, `/tmp/walkuno-trophies-ui-final.log`, `/tmp/walkuno-trophies-captures-final/`. Aucune installation sur appareil physique effectuée pendant cette intervention.

## Bornes et lisibilité de la courbe d’accueil — 5 novembre 2026

Le titre, l’objectif et la moyenne partagent une seule ligne. Le graphique récupère la hauteur de l’ancienne légende, avec une hauteur de carte conservée à un point près. Les deux références utilisent les mêmes petits pointillés. Les libellés sont centrés sur leurs repères et les références sont bornées au premier et au dernier repère, sans marge calendaire supplémentaire.

Le mode jour conserve sept jours, jusqu’au jour sélectionné inclus, et la sélection conserve sa fenêtre. Les semaines vont du lundi au dimanche, les mois couvrent tous leurs jours et les années affichent les douze mois. Les mesures futures restent absentes. La moyenne utilise les jours renseignés jusqu’au jour courant inclus ; les jours sans mesure ne sont pas assimilés à zéro. La courbe annuelle lissée représente la moyenne journalière de chaque mois, avec le mois courant calculé jusqu’au jour J. La moyenne annuelle reste pondérée par le nombre de jours renseignés.

- Compilation Debug simulateur réussie des quatre cibles, y compris sur l’état final du dossier partagé.
- 68 tests Foundation réussis, dont sept nouveaux scénarios de bornes, changement d’heure, semaine commençant le lundi, mois bissextile, accès limité, mois futurs et moyennes annuelles.
- Deux tests UI réussis sur iPhone 17e / iOS 26.3 : sélection des sept jours avec moyenne stable ; en-tête sur une ligne et hauteur du graphique identique sur les quatre périodes, également contrôlés avec les libellés longs allemands. Les captures des semaines, mois et années sont vérifiées visuellement.

Preuves : `/tmp/walkuno-period-core-final.log`, `/tmp/walkuno-period26-final.xcresult`, `/tmp/walkuno-period26-final.log`, `/tmp/walkuno-period-captures/`. Le premier lancement sur iOS 27 a été interrompu avant exécution des scénarios ; il ne constitue pas une validation de cette version d’iOS. Aucune installation sur appareil physique effectuée pendant cette intervention.


## Cercles préparés et animation des périodes — 5 novembre 2026

Le cercle suit le balayage horizontal avec les périodes voisines déjà préparées en mémoire. Par défaut, une période sélectionnée affiche immédiatement sa valeur finale ; aujourd’hui conserve son animation initiale et celles des nouvelles mesures. Le réglage « Animer les changements de période » permet de rejouer le remplissage et le compteur sur les jours, semaines, mois et années. Les anciennes préférences restent lisibles et la réduction des animations iOS reste prioritaire.

- 72 tests Foundation réussis sur l’état courant du dossier partagé, dont les nouveaux tests des cercles voisins, des limites gratuites, des données corrigées, des objectifs, du changement d’heure et de la sauvegarde du réglage.
- Compilation Debug simulateur réussie. Trois parcours UI passent sur iOS 26.3 : quatre périodes dans les deux sens avec animation activée puis désactivée ; balayages et changements de granularité ; détail et partage de la journée sélectionnée.
- Un parcours supplémentaire sur installation neuve vérifie l’état désactivé par défaut, l’activation puis la conservation du réglage après fermeture et relancement de l’application.
- Contrôle visuel des captures : la veille affiche directement 9 138 pas et 114 % lorsque l’option est désactivée ; l’option activée montre bien le remplissage et le compteur en cours d’animation. Les sept langues et les traductions compilées des quatre bundles sont validées.

Preuves : `/tmp/walkuno-core-final.log`, `/tmp/walkuno-period-ios26-final.xcresult`, `/tmp/walkuno-period-preferences.xcresult`, `/tmp/walkuno-period-ios26-captures/`. Les assertions des anciens parcours attendent désormais la fin du glissement avant de lire la nouvelle date. Aucune installation sur appareil physique effectuée pendant cette intervention.


## Explorer fixe et balayage des périodes — 5 novembre 2026

Le titre « Explorer une période » est retiré. Le sélecteur Jour / Semaine / Mois / Année et la date restent fixes sous le bandeau commun, dans le composant Liquid Glass partagé. Le panneau respecte le réglage de transparence et les options d’accessibilité ; les cartes défilent derrière lui.

Un glissement vers la droite révèle la période précédente ; vers la gauche, la suivante. Toutes les cartes suivent le geste. Une fenêtre de trois périodes conserve les résumés, comparaisons, séries du graphique, meilleur mois et calendrier déjà calculés ; seule la nouvelle voisine est calculée après navigation. Les heures des jours voisins sont chargées simultanément et conservées dans cette fenêtre. Les changements de données, d’objectifs, de droits ou de calendrier reconstruisent les pages. La réduction des animations supprime la translation.

- Compilation Debug simulateur réussie pour les quatre cibles.
- **72 tests Foundation réussis**, dont quatre scénarios Explorer couvrant les pages préparées, leur réutilisation, les limites gratuites et futures, les corrections de mesures/objectifs, les changements d’heure et le 29 février.
- Parcours complet des quatre périodes réussi sous **iOS 26.3 et iOS 27** : balayages dans les deux sens avant et après défilement, position fixe du sélecteur et de la date, action des deux flèches après défilement. La vérification porte sur les actions effectives, car iOS 27 peut déclarer une flèche non atteignable à l’accessibilité alors que son toucher fonctionne.
- Les scénarios de libellés et de détail du calendrier, d’accès gratuit/Pro, de geste annulé et de blocage du futur passent également. Les 352 textes et autorisations Santé sont vérifiés dans les sept langues.
- Captures après défilement et image extraite pendant un balayage contrôlées visuellement : les cartes voisines sont présentes pendant la translation et le panneau Liquid Glass reste fixe.

Preuves : `/tmp/walkuno-explorer-core-final.log`, `/tmp/walkuno-explorer-final26-20261105.xcresult`, `/tmp/walkuno-explorer-touch26-20261105.xcresult` et `/tmp/walkuno-explorer-touch27-20261105.xcresult`. Recette en données de démonstration sur simulateurs.

## Complications compactes et nouveaux graphiques — 5 novembre 2026

Les petits compteurs abrègent les pas dès 10 000 (`10.1K`) et les pourcentages très élevés ; distance et étages n’ont plus d’anneau. Les grands formats sont regroupés dans **Walkuno · Graphiques** avec seulement **Pas par heure**, **Suivi de l’objectif** et **Semaine**. Les anciennes grandes complications du widget de compteurs doivent être remplacées dans le cadran. La semaine réserve le graphique aux barres, place son maximum abrégé dans la barre correspondante et affiche les totaux du jour et de la semaine en pied, sans pourcentage.

**76 tests Foundation réussis**, compilations iPhone/Watch et contrôle des sept traductions dans les quatre bundles réussis. Les nouveaux tests couvrent les abréviations, les 24 heures consécutives aux changements d’heure, les références absentes, le cumul à l’heure partielle et la compatibilité des anciens caches. Rendus SwiftUI contrôlés à 9 999, 10 123 et 100 432 pas, et dans les formats circulaire 44 pt, rectangulaire 158 × 64 et 130 × 58, moyen et grand.

La version Debug signée 1.0.0 (3), avec l’extension des complications, est installée sur l’Apple Watch physique et relancée sans argument de démonstration. L’emplacement du bundle installé est confirmé par les métadonnées de l’appareil ; le lancement retourne un processus valide. La vérification ne lit pas les préférences ni les données Santé de l’appareil.

Preuves : `/tmp/walkuno-widget-v2-tests.log`, `/tmp/walkuno-widget-v2-build.log`, `/tmp/walkuno-widget-v2-device-build.log`, `/tmp/walkuno-widget-preview/v2-*.png`, `/tmp/walkuno-widget-v2-install.json`, `/tmp/walkuno-widget-v2-after.json` et `/tmp/walkuno-widget-v2-launch.json`.


## Installation iPhone et Watch, préparation GitHub — 5 novembre 2026

La version de développement Walkuno 1.0.0 (3), incluant le panneau Explorer fixe, le balayage des périodes et les derniers ajustements des widgets/complications, est compilée et signée pour les quatre cibles, puis installée sur l’iPhone et l’Apple Watch physiques. Les métadonnées des deux appareils confirment la version et les nouveaux emplacements des bundles. L’installation est effectuée sans désinstallation ni argument de démonstration.

Les **76 tests Foundation passent** ; les **360 textes**, autorisations Santé et ressources sont validés dans les sept langues. Le dossier local est initialisé avec Git sur la branche `main` et associé au dépôt `https://github.com/boblastic/walkuno`, initialement vide. Le premier commit contient les sources, ressources, tests et documents du projet ; les produits de compilation et préférences Xcode locales sont exclus par `.gitignore`.

Preuves locales : `/tmp/walkuno-publish-device-install.log`, `/tmp/walkuno-publish-iphone-app.json`, `/tmp/walkuno-publish-watch-app.json` et `/tmp/walkuno-publish-core.log`.

## Basculement du compteur d’accueil — 5 novembre 2026

Le glissement de l’accueil se termine en 0,5 seconde au lieu de 0,22, avec une courbe progressive au départ et à l’arrivée. Les compteurs s’inclinent légèrement en perspective et diminuent de taille en s’éloignant du centre. Un geste annulé revient en place en 0,3 seconde. La réduction des animations conserve le changement immédiat de période.

Compilation Debug simulateur réussie des quatre cibles et **2 tests UI réussis sous iOS 27** : navigation jour/semaine/mois, limite des dates futures, retour à aujourd’hui et parcours des quatre périodes avec le remplissage du cercle activé puis désactivé. Les images extraites d’un enregistrement confirment la présence des deux compteurs pendant le basculement.

Preuves : `/tmp/walkuno-home-swipe-build.log`, `/tmp/walkuno-home-swipe-ui.xcresult`, `/tmp/walkuno-home-swipe-ui.log`, `/tmp/walkuno-home-swipe.mp4` et `/tmp/walkuno-home-swipe-frames.png`. Aucune installation sur appareil physique effectuée.


## Repères horaires et semaine en courbe — 5 novembre 2026

**Pas par heure** affiche désormais l’heure locale toutes les trois heures, en petits chiffres sous les barres, y compris dans la complication rectangulaire. Les repères suivent les vraies heures de la fenêtre glissante (00, 03, 06…), avec un affichage sur deux chiffres sans suffixe afin de rester lisibles sur les petits cadrans.

**Semaine** devient **Semaine en barre** ; son identifiant de configuration reste conservé. **Semaine courbe** ajoute une courbe lissée, un point pour chaque jour renseigné et un point plus grand sur le jour courant, également repéré sous le graphique. Les totaux du jour et des sept jours restent en pied. La variante existe dans les grands widgets et complications rectangulaires, ainsi que dans les petits widgets et complications circulaires. Les jours sans mesure interrompent la courbe ; zéro reste une mesure valide.

- Compilation Debug simulateur réussie pour les quatre cibles sur les sources finales, sans erreur ni avertissement du compilateur.
- **76 tests Foundation réussis** ; **361 textes** et les traductions compilées des quatre bundles sont validés dans les sept langues.
- Rendus des vues SwiftUI contrôlés aux formats rectangulaires 158 × 64 et 130 × 58, circulaire 44 pt, petit, moyen et grand. Contrôle supplémentaire du passage à minuit, des jours absents, des sept jours à zéro et de l’absence totale de mesures.

Preuves : `/tmp/walkuno-widget-hours-build.log`, `/tmp/walkuno-widget-hours-tests.log` et `/tmp/walkuno-widget-hours-preview/hours-*.png`. Les rendus utilisent des données synthétiques et ne remplacent pas une recette sur cadran réel. Aucune installation sur appareil physique effectuée pendant cette intervention.


## Lisibilité des cartes Explorer — 5 novembre 2026

Le total quotidien est intégré à la carte horaire. Le graphique affiche une échelle chiffrée à gauche, des lignes de repère discrètes et de petits pointillés gris aux heures sans activité ou sans mesure. L’objectif quotidien est retiré de ce détail. Les créneaux couvrent la journée locale entière, y compris ses 23 ou 25 heures lors des changements d’heure ; une mesure absente reste distincte de zéro.

Le récapitulatif semaine/mois/année ajoute les cumuls d’étages, d’énergie active (selon le réglage de visibilité) et de temps d’exercice. La meilleure journée réunit date et nombre de pas sur une ligne. La semaine présente sept cases du lundi au dimanche, même à cheval sur deux mois ; les jours futurs restent neutres et désactivés. Le calendrier mensuel est conservé. L’année présente douze cases mensuelles, colorées selon le rapport entre les pas et les objectifs historiques des journées renseignées ; toucher un mois ouvre sa vue mensuelle.

- Compilation Debug simulateur réussie des quatre cibles et **80 tests Foundation réussis**, dont quatre nouveaux cas couvrant cumuls indépendants, limites d’accès, lundi/dimanche, mois futurs, objectifs datés et changements d’heure.
- **Trois parcours UI distincts réussis sous iOS 26.3**, sans échec : nouvelles cartes et calendriers, capitalisation et ouverture d’un détail mensuel, panneau fixe et balayage des quatre périodes. Le parcours des nouvelles cartes passe également sur le rendu définitif des pointillés gris.
- **362 textes** validés dans les sept langues ; les traductions compilées des quatre bundles correspondent aux sources.
- Captures contrôlées : total/échelle horaire, meilleure journée sur une ligne, cumuls et semaine complète. Rendu SwiftUI supplémentaire du graphique renseigné et vide, en clair et sombre.

Preuves : `/tmp/walkuno-explorer-polish-core-final.log`, `/tmp/walkuno-explorer-polish-ui.xcresult`, `/tmp/walkuno-explorer-polish-final.xcresult`, `/tmp/walkuno-explorer-polish-final-captures/` et `/tmp/walkuno-explorer-polish-preview/hourly.png`. Validation avec données de démonstration/synthétiques sur simulateur ; aucune installation physique effectuée.


## Installation des repères horaires et de Semaine courbe sur Watch — 5 novembre 2026

La version Debug signée 1.0.0 (3), contenant les heures toutes les trois heures, le nom **Semaine en barre** et la nouvelle variante **Semaine courbe**, est installée sur l’Apple Watch physique. Le schéma Watch et son extension de complications sont compilés ; la signature complète et les traductions des deux bundles sont vérifiées. L’installation est effectuée sans désinstallation ni modification de l’application iPhone.

La première tentative échoue lors de la connexion aux services de développement. Après rétablissement de ces services et confirmation par l’utilisateur que la montre et l’iPhone sont déverrouillés à proximité, la nouvelle tentative réussit. Le résultat d’installation confirme le bundle attendu et un nouvel emplacement de bundle par rapport au relevé précédent. Le lancement automatique et la seconde lecture des métadonnées échouent ensuite sur une expiration de la connexion réseau ; le lancement sur la montre reste manuel et aucun contrôle du cadran réel n’est revendiqué.

Preuves : `/tmp/walkuno-widget-hours-device-build.log`, `/tmp/walkuno-widget-hours-watch-before.json`, `/tmp/walkuno-widget-hours-watch-ddi.json`, `/tmp/walkuno-widget-hours-watch-install-retry.json` et `/tmp/walkuno-widget-hours-watch-launch.log`.

## Cartes des victoires et borne de l’historique — 5 novembre 2026

Les explications des semaines, mois et années parfaits sont placées en petits caractères sous leur titre. Les six cartes des victoires partagent une hauteur commune mesurée sur leur contenu, avec un espace de titre compact et des textes qui peuvent grandir.

Le cumul des traversées ne possède aucun plafond à 24 000 km : il additionne uniquement les distances marche/course disponibles dans les journées chargées. La borne initiale de la lecture Santé dépend désormais de la plus ancienne mesure accessible des cinq types, au lieu du seul premier relevé de pas. Cela évite d’écarter des distances plus anciennes ou accessibles sans autorisation de lecture des pas. Aucun total personnel n’a été consulté ni certifié.

- **81 tests Foundation réussis**, dont un cas de distance cumulée supérieure à 24 000 km, de journées sans pas et d’exclusion du futur.
- Compilation Debug des quatre cibles réussie. Le parcours Succès réussit sous iOS 27 sur la version finale, avec comparaison des hauteurs des six cartes à un point près et ouverture de la collection complète.
- Captures finales des périodes parfaites contrôlées visuellement en mode démonstration. Aucune installation physique effectuée ; la correction de la borne Santé est compilée, sans validation sur données Santé réelles.

Preuves : `/tmp/walkuno-trophy-layout-core.log`, `/tmp/walkuno-trophy-layout-final.xcresult`, `/tmp/walkuno-trophy-layout-final-ui.log` et `/tmp/walkuno-trophy-layout-final-captures/`.


## Version 1.0.0 (4) installée sur iPhone — 5 novembre 2026

La version Debug de développement 1.0.0 (4) réunit les dernières modifications des cartes Succès et de la borne de lecture Santé, les cartes et calendriers Explorer, le basculement du compteur, les widgets avec repères horaires et Semaine courbe, ainsi que le mode sombre permanent. Le numéro de build est mis à jour pour les quatre cibles et dans le générateur de projet.

Les **81 tests Foundation réussissent** sur les sources préparées. La compilation signée des quatre cibles, la vérification complète de signature et le contrôle des **362 textes dans les sept langues** des quatre bundles réussissent. Les sources n’ont pas changé entre le début de cette compilation et l’installation. Le dernier parcours Succès sur simulateur, avec comparaison des six hauteurs de cartes, est documenté ci-dessus.

Walkuno est mis à jour sur l’iPhone physique sans désinstallation et lancé sans argument de démonstration. Les métadonnées de l’appareil confirment le passage du build 3 au build 4 et le nouvel emplacement du bundle. Aucun contenu des préférences ni aucune donnée Santé personnelle n’est lu pour cette vérification. Aucune installation directe sur la Watch n’est effectuée pendant cette opération.

Preuves : `/tmp/walkuno-release-4-build.log`, `/tmp/walkuno-release-4-tests.log`, `/tmp/walkuno-release-4-install.json`, `/tmp/walkuno-release-4-launch.json`, `/tmp/walkuno-release-iphone-before.json` et `/tmp/walkuno-release-4-iphone-after.json`.

## 5 novembre 2026 — Aventures intermédiaires et collection permanente

- Collection portée à 24 traversées : ajout du Nil (6 650 km), du tour de l’Australie (14 500 km), du Transsibérien aller-retour (18 600 km), de la Grande Muraille (21 200 km), du Sentier Transcanadien (30 000 km), du quart du chemin vers la Lune (96 100 km) et de la moitié (192 200 km). Références et arrondis dans `Trophees.md`.
- Suppression du tour de piste et des commandes de déploiement/réduction. Toutes les aventures restent affichées ; la première non terminée conserve la mention « Prochaine aventure ».
- 83 tests Foundation réussis ; validation des 367 textes dans les sept langues réussie ; analyse syntaxique Swift de la vue Succès et du parcours UI réussie ; `git diff --check` sans erreur.
- Test UI adapté pour parcourir les nouveaux jalons sans ouvrir la collection, mais non exécuté : CoreSimulator inaccessible dans cet environnement. Compilation complète tentée, bloquée par `sandbox-exec: sandbox_apply: Operation not permitted` lors du lancement des macros Swift de la cible Watch. Le rendu et la compilation complète restent à confirmer dans Xcode.

Journaux : `/tmp/walkuno-journeys-tests.log` et `/tmp/walkuno-journeys-build.log`. Aucun déploiement sur appareil.

### Ajustement — Retrait des deux jalons lunaires

À la demande de Damien, suppression du quart du chemin et de la moitié du chemin vers la Lune. Le catalogue contient désormais 22 traversées, toujours affichées. Les traductions, le catalogue documenté et les tests ont été adaptés. Les 12 tests `AchievementTests` réussissent, ainsi que la validation des 365 textes dans les sept langues. Journal : `/tmp/walkuno-journeys-removal-tests.log`.

### Simplification des statistiques et repères des tendances — 5 novembre 2026

- « Votre semaine type » : suppression du détail dépliable et de la note sur l’historique accessible.
- Tendances : choix 7 jours/mois/année, écart aligné à droite du titre, suppression de la grande moyenne répétée.
- Graphiques : séries précédente grise et actuelle dans le thème, côte à côte par position calendaire ; initiales des jours et des mois, jours du mois espacés avec dernier jour visible. Périodes calendaires précédentes complètes, mesures actuelles jusqu’à aujourd’hui et emplacements futurs vides. Les moyennes comparatives restent calculées sur les journées terminées comparables.
- `swift test --disable-sandbox --scratch-path /tmp/walkuno-core-tests` avec caches de modules sous `/tmp` : **87 tests réussis**, dont quatre nouveaux tests couvrant les mois de longueurs différentes, février bissextile, les valeurs absentes/futures, les douze mois et les changements d’heure/année.
- Compilation générique iOS Simulator de Walkuno et de ses cibles embarquées : **BUILD SUCCEEDED**, avec `CODE_SIGNING_ALLOWED=NO` et `OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` pour permettre les macros Swift dans cet environnement.
- Parcours UI adapté aux trois périodes et captures mois/année ajoutées. Exécution UI et contrôle visuel non effectués : service CoreSimulator inaccessible dans cette session.


## Reprise du compteur au changement de granularité — 5 novembre 2026

Le sélecteur Jour / Semaine / Mois / Année rejoue le compteur depuis zéro et le remplissage du cercle, y compris au retour au jour. Le réglage existant continue de commander la reprise lors de la navigation entre les dates. La réduction des animations iOS reste prioritaire. Les explications du réglage sont adaptées dans les sept langues.

- Compilation Debug générique iOS Simulator des quatre cibles réussie.
- Test UI `testHomeNavigationWithPeriodAnimationsEnabledAndDisabled` réussi sur iOS 26.3 : navigation dans les quatre périodes, avec le réglage activé puis désactivé, aucun échec. Ce parcours valide la navigation et les totaux accessibles, sans assertion sur les images intermédiaires de l’animation.
- Validation des 365 textes dans les sept langues et `git diff --check` réussis.

Preuves : `/tmp/walkuno-period-replay-build.log`, `/tmp/walkuno-period-replay-ui.log` et `/tmp/walkuno-period-replay-ui.xcresult`. Aucune installation physique effectuée.

## Libellés du graphique d’accueil — 5 novembre 2026

L’axe utilise des repères alignés avec les dates, des traits verticaux sans décalage et une marge de 10 points aux deux extrémités pour préserver les libellés centrés.

- Compilation Debug des cibles iPhone, widgets et Watch réussie pour simulateur.
- Test UI `testHomeTrendKeepsCompactHeaderAcrossCalendarPeriods` réussi sur iOS 26.3, sans échec.
- Captures contrôlées visuellement : J de jeudi, D de dimanche, dernier jour de novembre (30) et D de décembre visibles et centrés sous leurs traits ; vue annuelle allemande également contrôlée.
- `git diff --check` réussi.

Preuves : `/tmp/walkuno-axis-labels-ui.log`, `/tmp/walkuno-axis-labels-ui.xcresult` et `/tmp/walkuno-axis-labels-captures/`. Aucune installation physique effectuée.

### Installation du correctif des libellés sur iPhone — 5 novembre 2026

Walkuno 1.0.0 (5) est compilé avec signature de développement, vérifié avec `codesign --verify --deep --strict`, puis installé sur l’iPhone connecté « iBoblastic » sans désinstallation. Le lancement sans argument de démonstration réussit et le processus Walkuno est confirmé sur l’appareil. Le rendu corrigé a été contrôlé sur simulateur ; aucun contrôle visuel supplémentaire sur l’iPhone physique n’a été effectué pendant cette installation.

Preuves : `/tmp/walkuno-axis-labels-iphone-install.log` et `/tmp/walkuno-axis-labels-iphone-processes.json`.


## Inspection des graphiques et préparation du build 5 — 5 novembre 2026

Ajout des bulles date/heure et valeur sur les graphiques des statistiques (comparaison du jour, tendances, records horaires et agrégés, historique annuel) et sur Explorer (jour/semaine/mois/année et détail d’une journée). Les deux valeurs de la comparaison quotidienne sont affichées ensemble ; les séries des tendances peuvent être inspectées séparément. Les bulles suivent la métrique, l’unité et la palette. Explorer distingue toucher, appui maintenu avec glissement et balayage rapide de période.

- Les **87 tests Foundation** réussissent : `/tmp/walkuno-inspection-core.log`.
- Les **365 textes dans les sept langues**, ainsi que les traductions compilées des quatre bundles, sont validés. `git diff --check` réussit.
- Compilation Debug générique pour appareil iOS réussie avec les quatre cibles embarquées, sans signature dans ce contrôle : `/tmp/walkuno-inspection-build.log`.
- Le parcours UI existant `testExplorerPinsGlassControlsAndSwipesEveryPeriod` réussit sous iOS 27 : panneau fixe, navigation rapide dans les quatre périodes et défilement vertical.
- Contrôle visuel sur simulateur de la comparaison quotidienne : heure, valeurs actuelle/habituelle, repère vertical et bulle au-dessus du point.

Le numéro de build est porté à **5** dans le générateur et les quatre cibles.

Le nouveau test UI `testExplorerChartScrubbingKeepsPeriodAndShowsValues` réussit sous iOS 27 : bulle au toucher, valeur/date modifiée par glissement maintenu, période conservée pour semaine/mois/année/jour. Les dates sans mesure, y compris futures, possèdent leur propre emplacement et affichent l’absence de donnée au lieu de reprendre la dernière barre renseignée.

Les deux nouveaux parcours UI réussissent ensemble sur les sources finales : `testExplorerChartScrubbingKeepsPeriodAndShowsValues` et `testStatisticsChartsShowValuesOnTapAndDrag` (comparaison du jour, tendances, record annuel, puis record quotidien horaire). La compilation effectuée par Xcode pour ce parcours est réussie. Résultat conservé sous `/tmp/walkuno-inspection-final-ui.xcresult`.

L’installation physique du build 5 reste à terminer : le Mac s’est verrouillé avant le choix de la destination iPhone dans Xcode. La voie CLI ne peut pas accéder aux services de l’appareil dans cet environnement ; la tentative de signature CLI ne trouve pas les profils de développement. Aucun succès d’installation ni de signature du build 5 sur appareil n’est revendiqué.

## Lisibilité des statistiques et bulles temporaires — 5 novembre 2026

- Les deux valeurs de « Mon activité du jour » figurent à droite de leur légende. « Habituellement » affiche le total moyen d’une journée historique complète ; le message d’avance/retard conserve la comparaison à la même heure.
- Tendances : période précédente entière en gris, suivie de la période actuelle en vert, pour les sept jours, les mois et les années. Chaque moyenne en pointillés reste dans sa propre période ; les créneaux absents ou futurs sont conservés. Les repères mensuels évitent le chevauchement entre le dernier jour précédent et le premier jour actuel.
- Les bulles des graphiques Statistiques et Explorer disparaissent une seconde après le relâchement. Un nouvel appui annule la fermeture en attente. Le mois du record annuel est en majuscules ; le record quotidien n’a plus de détail dépliable.
- **87 tests Foundation réussis**, dont les assertions distinguant total habituel de fin de journée, référence à heure égale et mesure absente. Validation des **365 textes dans les sept langues** et `git diff --check` réussie.
- Compilation Debug générique iOS des quatre cibles réussie sur les sources finales, sans signature. Journaux : `/tmp/walkuno-statistics-refine-core.log` et `/tmp/walkuno-statistics-refine-build-final.log`.
- Le parcours UI Explorer passe sous iOS 27 avec lecture immédiate des bulles et vérification de leur disparition. Les assertions de comparaison quotidienne et de tendances passent également, y compris la sélection précédente à gauche, actuelle à droite, et le maintien de la bulle pendant un appui de plus d’une seconde. Résultat : `/tmp/walkuno-statistics-refine-final-ui.xcresult`.
- La recette UI complète des records/historique reste inachevée : le geste de défilement du test n’atteint pas les cartes du bas. La page reçoit ensuite une zone de toucher couvrant aussi ses marges et les gestes de test sont ancrés à la fenêtre. Une copie temporaire est compilée pour préserver les modifications simultanées du compteur d’accueil ; les relancements iOS 27 puis iOS 26 restent bloqués avant l’exécution et sont interrompus. Aucun succès du parcours complet ni de la capitalisation du record au toucher n’est revendiqué. Journaux : `/tmp/walkuno-statistics-review-complete-ui.log` et `/tmp/walkuno-statistics-review-ios26-ui.log`.
- Les captures de la carte quotidienne et des sept jours sont contrôlées visuellement. Les captures des tendances mensuelles et annuelles sont partielles ; le contrôle visuel complet reste à effectuer. Aucun déploiement sur appareil physique.
- Dernier contrôle du projet partagé, après les modifications simultanées et l’ajout de la zone de défilement : **BUILD SUCCEEDED** pour les quatre cibles iOS/Watch et extensions, sans signature. Journal : `/tmp/walkuno-statistics-refine-build-current.log`. Le délai d’appui maintenu partagé est désormais de 0,4 seconde et les parcours UI utilisent un appui de 0,6 seconde.

## Cinq styles du compteur — 5 novembre 2026

- Compteur d’accueil et galerie de réglages natifs : Anneau, Horizon, Chemin, Paliers et Typographique, dessinés avec les deux teintes de chacune des neuf palettes. L’ancien identifiant `minimal` conserve le choix Typographique après mise à jour.
- Compilation de l’app, de la Watch, des extensions et du runner UI réussie. Validation des 381 textes dans les sept langues et dans les quatre bundles compilés.
- **91 tests de logique réussis**, dont la sauvegarde des cinq choix et les nouveaux contrôles des paliers, données invalides, objectifs atteints et tours supplémentaires à 125 %, 200 %, 225 % et 300 %.
- **Cinq scénarios UI ciblés validés** sur iPhone 17 Pro / iOS 26.3 : sélection des cinq dessins, navigation par balayage et totaux annuels ; parcours des neuf palettes ; prévisualisation Premium sans écraser le choix actif ; mémorisation après relancement réel sans connexion Santé ; compteur visible et accessible à la taille de texte maximale. Le mode démonstration ne sauvegarde volontairement aucune préférence.
- Captures natives examinées pour les cinq dessins, les grands totaux annuels et plusieurs palettes. L’espacement du nombre dans Horizon a été resserré au centre pour dégager les graduations ; la galerie remonte automatiquement vers l’aperçu après sélection, en respectant la réduction des animations.

Preuves : `/tmp/walkuno-counters-core.log`, `/tmp/walkuno-counters-build.log`, `/tmp/walkuno-counters-polish.xcresult` (sélection et périodes), `/tmp/walkuno-counters-persistence.xcresult` (sauvegarde), `/tmp/walkuno-counters-accessibility-verified.xcresult` (grands caractères), `/tmp/walkuno-counters-final-ui.xcresult` (scénarios palettes et aperçu gratuit réussis ; son premier scénario de balayage avait une attente insuffisante, corrigée et validée dans `polish`). Captures finales : `/tmp/walkuno-counters-polish-captures/`. Les alertes de changement d’icône du simulateur non signé sont indépendantes du compteur et ont été fermées pendant le parcours des palettes.

## Étoiles des cinq compteurs — 5 novembre 2026

- Un même dessin SwiftUI Canvas ajoute aux cinq styles des étoiles à dégradé nacré, facettes, cœur blanc et halos dans les deux couleurs de la palette. Les étoiles principales et satellites restent visibles au repos ; la traînée supplémentaire suit uniquement l’interpolation existante, sans minuterie ni animation continue. La réduction des animations conserve le dessin statique.
- Les étoiles suivent les tours supplémentaires. Les débuts sans pas restent discrets ; les surfaces décoratives ne capturent aucun toucher et sont masquées à VoiceOver. L’anneau et Horizon réservent davantage de place autour des étoiles ; Paliers suit une ligne continue au-dessus des barres et garde ses extrémités à l’intérieur du compteur.
- Deux parcours UI existants réussis sur iPhone 17 Pro / iOS 26.3.1 : galerie et sélection des cinq styles, balayages et totaux annuels, puis compteur avec taille de texte d’accessibilité maximale. Les captures des cinq compteurs d’accueil ont été examinées. Résultat : `/tmp/walkuno-starlight-gallery.xcresult`, captures : `/tmp/walkuno-starlight-captures/`.
- Contrôle natif supplémentaire avec les vues SwiftUI réelles : les cinq styles à 0 %, 100 %, 125 % et 200 %, puis une image de la traînée à mi-animation. Le dernier ajustement des extrémités de Paliers est inclus dans ces rendus : `/tmp/walkuno-starlight-edges.png` et `/tmp/walkuno-starlight-motion.png`. Aperçu violet : `/tmp/walkuno-starlight-native-grid.png`.
- Compilation finale des quatre cibles pour simulateur avec signature locale réussie : `/tmp/walkuno-starlight-final-build.log`. Validation des 381 textes dans les sept langues et `git diff --check` réussis. Aucun changement de calcul des pas ou d’objectif, aucune installation sur appareil physique.

### Installation sur iPhone et Apple Watch — 5 novembre 2026

À la demande de l’utilisateur, les sources finales avec les étoiles sont compilées pour appareils physiques, avec signature de développement et profils embarqués. La vérification `codesign --verify --deep --strict` réussit pour les deux applications. Walkuno 1.0.0 (5) est mis à jour sans désinstallation sur l’iPhone « iBoblastic » et l’Apple Watch de Damien. Le lancement sans arguments de démonstration réussit sur les deux appareils ; les processus des deux applications et de leurs extensions sont ensuite confirmés dans les nouveaux emplacements d’installation.

Preuves : `/tmp/walkuno-starlight-device-install.log`, `/tmp/walkuno-starlight-iphone-processes.json` et `/tmp/walkuno-starlight-watch-processes.json`. Aucun contrôle visuel supplémentaire du rendu sur appareil physique n’a été effectué pendant cette installation.

## Traînée éphémère et départ sans clignotement — 5 novembre 2026

Les étoiles naissent à des positions successives du tracé, dérivent et tournent avec des durées de vie individuelles de 0,4 à 0,8 seconde. Les dernières se dissipent après la fin du remplissage ; aucune étoile ne reste au repos. Une horloge de rendu limitée au remplissage et à cette dissipation fournit la même progression au nombre, au tracé et à l’historique des particules. La réduction des animations affiche directement le résultat sans particules.

Quand le remplissage des périodes est activé, les compteurs voisins commencent à zéro pendant le swipe. Le compteur actif possède un état initial propre à chaque reprise ; revenir d’un autre onglet conserve la reprise déjà terminée. Cela élimine les deux causes du flash du total avant le départ à zéro.

- Les 96 tests Foundation réussissent, dont cinq nouveaux cas sur la progression, la dissipation finale, les positions de naissance lors des tours supplémentaires et les corrections de valeur. Journal : `/tmp/walkuno-fairy-core.log`.
- Les rendus natifs des cinq styles pendant le remplissage, pendant la dissipation et au repos ont été examinés : `/tmp/walkuno-fairy-native.png`.
- Les deux parcours UI finaux réussissent : sélection des cinq styles et navigation dans les quatre périodes avec remplissage activé puis désactivé. Résultat : `/tmp/walkuno-fairy-final-ui.xcresult` (deux tests, aucun échec).
- La vidéo du simulateur est examinée à intervalles de 0,1 seconde autour des swipes : la page entrante affiche zéro pendant le glissement, puis sa valeur augmente progressivement. Preuves : `/tmp/walkuno-fairy-swipes.mov`, `/tmp/walkuno-fairy-day-frames.png` et `/tmp/walkuno-fairy-period-frames.png`. Le rendu temporel confirme également la présence de la traînée pendant le remplissage.
- Compilation signée finale des quatre cibles réussie, signatures des applications vérifiées, validation des traductions et `git diff --check` réussis : `/tmp/walkuno-fairy-final-device-build.log`.
- Mise à jour physique sans désinstallation réussie sur l’iPhone iBoblastic et l’Apple Watch de Damien, puis lancement des deux applications sans démonstration. Le transfert Watch a nécessité une reconnexion après deux expirations du tunnel réseau. Journaux : `/tmp/walkuno-fairy-iphone-install.log`, `/tmp/walkuno-fairy-iphone-launch.log`, `/tmp/walkuno-fairy-iphone-processes.json`, `/tmp/walkuno-fairy-watch-final-install.log` et `/tmp/walkuno-fairy-watch-launch.log`. Le rendu animé a été vérifié sur simulateur ; aucun contrôle visuel supplémentaire sur les appareils physiques n’a été effectué.

## Statistiques compactes — 5 novembre 2026

- En-tête « Mon activité du jour » sur la même rangée que les valeurs Aujourd’hui / Habituellement, avec légendes réduites et repères plein/pointillés conservés.
- Suppression des descriptions sous les graphiques, des notes de couverture et des détails dépliables des records. Les légendes des tendances et les valeurs principales sont conservées. La série actuelle utilise désormais la palette sélectionnée ; la couleur des baisses reste distincte.
- Compilation Debug générique iOS Simulator réussie. Parcours UI `testStatisticsInsightsMetricsRecordsAndYearHistory` réussi sur iOS 27 : mesures, trois périodes de tendances, records, historique en totaux/moyennes et menu fixe. L’aide de défilement du test ignore désormais les cadres vides des éléments hors écran pour éviter une inversion du geste.
- Captures de démonstration contrôlées ; `git diff --check` réussi. Aucun déploiement physique.

Preuves : `/tmp/walkuno-statistics-compact-build.log`, `/tmp/walkuno-statistics-compact-verified.log` et `/tmp/walkuno-statistics-compact-verified.xcresult`.

## Trois effets alternatifs du compteur — 5 novembre 2026

- Ajout de Feu vivant (flammes déformées, cœur chaud et braises), Aurore boréale (trois voiles irisés avec ondulation et liserés lumineux) et Onde liquide (sillage lisse, perle nacrée, gouttelettes et ondelettes). Étoiles reste disponible et demeure le choix des installations existantes. Chaque effet utilise le même historique de progression, y compris les dépassements d’objectif, puis disparaît entièrement après le remplissage.
- La galerie Réglages → Style du compteur propose les quatre effets indépendamment du dessin, avec choix mémorisé et bouton « Revoir l’animation ». La préférence absente ou inconnue revient aux étoiles en conservant les autres réglages. Les libellés sont traduits dans les sept langues.
- 97 tests Foundation réussis, dont la sauvegarde des quatre choix et la migration des anciennes préférences : `/tmp/walkuno-effects-core.log`. Validation des 391 textes et `git diff --check` réussis.
- Deux parcours UI réussis : sélection/relecture des quatre effets et choix des cinq dessins avec navigation par jour et année. Résultat : `/tmp/walkuno-effects-ui.xcresult` ; captures : `/tmp/walkuno-effects-captures/`. Les captures des effets et de leur disparition ont été examinées dans l’interface iPhone.
- Les derniers ajustements visuels (flammes ascendantes, sillage liquide lissé) ont été compilés et contrôlés avec les vues SwiftUI réelles sur les cinq dessins : `/tmp/walkuno-effects-native-final.png`. L’aperçu animé natif compare les trois effets et leur dissipation : `/tmp/walkuno-effects-preview.gif`.
- Compilation finale des quatre cibles pour simulateur réussie : `/tmp/walkuno-effects-final-build.log`. Aucun déploiement physique effectué pour cette évolution.

## Widgets iPhone : quatre familles et trois tailles — 5 novembre 2026

- Compteurs, Graphiques, Tendances et Tableau de bord proposent chacun petit/moyen/grand. Les identifiants des deux widgets existants sont conservés. L’écran verrouillé reçoit les compteurs, graphiques, tendances et synthèses rectangulaires ; deux rectangles remplissent les quatre emplacements autorisés par iOS.
- Courbes/barres hebdomadaires, rythme horaire aujourd’hui/veille de l’accueil, 24 heures glissantes et suivi cumulatif. Tendances configurables : cinq mesures, 7 jours/mois/année, courbe/barres/comparaison/calendrier mensuel. L’année suit les droits Pro, les autres périodes l’historique accessible. Moyennes sur jours observés ; créneaux futurs et données manquantes distincts du zéro.
- Palette, kilomètres/miles, objectif, dessin du compteur et visibilité de l’énergie partagés avec l’extension. Les effets animés ne sont pas rejoués dans les snapshots statiques. La lecture prioritaire couvre désormais 31 jours, ou les deux années de tendances avec Pro, pour maintenir ces résumés lors des livraisons en arrière-plan.
- 101 tests Foundation réussis : `/tmp/walkuno-widgets-tests-final.log`. Vérifications ajoutées : objectifs datés du calendrier, absence/zéro/futur, moyenne annuelle pondérée, totaux et moyennes mensuels distincts, février bissextile, anciens caches et taille bornée avec 5 000 jours synthétiques.
- Validation des 408 textes dans les sept langues et quatre cibles réussie. Compilation Debug des quatre cibles pour iOS/watchOS Simulator réussie : `/tmp/walkuno-widgets-simulator-final.log`. `git diff --check` réussi.
- 53 rendus natifs avec un harnais temporaire ImageRenderer sur iOS Simulator : 12 formats sur dimensions standard et petit iPhone, huit variantes circulaires, sept rectangles, quatre graphiques de tendance, cinq compteurs, thème violet/miles/énergie masquée et quatre états sans données. Le harnais remplace uniquement la clé d’environnement de famille pour reproduire les dimensions hors du processus WidgetKit. Les captures ne valident pas la composition finale du système, les modes teintés ni la protection sous verrouillage matériel.
- Revue ciblée de confidentialité consignée dans `Documentation/Audit-securite.md`. Aucun déploiement physique ni publication.

## Livraison locale de Walkuno 1.0.0 (6) — 5 novembre 2026

La version de développement Debug 1.0.0 (6) réunit les nouveaux widgets iPhone, les cinq styles et quatre effets du compteur, l’inspection des graphiques, les améliorations des tendances et les trophées présents dans l’espace de travail. Le numéro de build est mis à jour dans les quatre cibles et le générateur.

La compilation signée pour appareils iPhone/Watch et leurs extensions réussit. Vérification stricte de la signature complète ; les quatre profils portent l’App Group attendu et la protection complète. Les 408 textes et les autorisations Santé sont vérifiés dans les sept langues des quatre bundles compilés. La dernière validation métier compte 101 tests Foundation réussis.

Installation par mise à jour sur l’iPhone physique : les métadonnées confirment le passage du build 5 au build 6. L’application est lancée sans argument de démonstration. Aucune désinstallation ni lecture du contenu des préférences ou de Santé n’est effectuée. Le compagnon Watch est embarqué ; aucune installation directe sur la montre n’est demandée pendant cette livraison. La recette des widgets sur écran verrouillé matériel reste à effectuer.

L’ensemble cohérent des sources, ressources, tests et documents est préparé sur `main` pour le dépôt GitHub `boblastic/walkuno`. Aucun binaire signé, profil de provisioning ni journal d’appareil n’est inclus dans Git.

Preuves locales : `/tmp/walkuno-release-6-build.log`, `/tmp/walkuno-release-6-install.json`, `/tmp/walkuno-release-6-launch.json`, `/tmp/walkuno-release-6-iphone-before.json`, `/tmp/walkuno-release-6-iphone-after.json`, `/tmp/walkuno-widgets-tests-final.log`. Aperçu : `Documentation/Captures/Widgets-iPhone.png`.

## Ajustements des widgets iPhone — 5 novembre 2026

- Compteurs : format moyen retiré ; petit compteur agrandi avec pas complets, distance et pourcentage, rendu proportionnel des cinq styles transmis par l’application et représentation des dépassements. Le grand compteur et le grand tableau de bord partagent une disposition : compteur à gauche, courbe des sept jours à droite, objectif et moyenne en pointillés avec valeurs complètes, étages/exercice/énergie optionnelle, puis suivi d’objectif agrandi.
- Famille Tendances et son implémentation retirées de l’extension. Les identifiants Compteurs, Graphiques et Tableau de bord sont conservés.
- Le cache partage aussi le profil habituel des journées historiques complètes (25 points au maximum). Le tracé habituel continue jusqu’à 24 h ; aucune mesure future n’est attribuée à aujourd’hui. Les comparaisons à l’heure exacte et le chargement des anciens caches restent compatibles.
- 103 tests Foundation réussis, dont deux nouveaux tests sur le profil jusqu’à minuit, l’absence de mesures futures et les anciens caches : `/tmp/walkuno-widgets-revision-tests.log`. Compilation Debug des quatre cibles iOS/watchOS Simulator réussie : `/tmp/walkuno-widgets-revision-build.log`.
- 21 rendus natifs ImageRenderer contrôlés sur iOS Simulator : cinq styles en petit, grand et grand sur petit écran ; absence de pas, zéro, dépassement, suivi moyen, grand tableau de bord et petit compteur sans cache. Harnais temporaire avec une clé de famille dédiée ; données synthétiques et dimensions de widgets, sans validation de la composition finale par WidgetKit ni installation sur matériel. Rendus : `/tmp/walkuno-widget-revision-preview/`.

## Livraison locale de Walkuno 1.0.0 (7) — 5 novembre 2026

Le build 7 de développement Debug inclut les corrections des widgets : petit compteur agrandi et synchronisé avec le style de l’application, suppression du compteur moyen et de la famille Tendances, grand compteur réorganisé, étages et profil habituel jusqu’à minuit. Le numéro est mis à jour pour les quatre cibles et dans le générateur.

Compilation signée iPhone/Watch réussie ; signature complète vérifiée avec `codesign --verify --deep --strict`. Version, identifiants et profils embarqués contrôlés dans les quatre bundles. Les 408 textes sont vérifiés dans les sept langues des quatre bundles compilés. La validation métier précédente compte 103 tests réussis.

Mise à jour installée sur l’iPhone physique iBoblastic, sans désinstallation. Les métadonnées de l’appareil confirment le passage de 1.0.0 (6) à 1.0.0 (7). La tentative de lancement sans argument de démonstration est refusée par iOS car l’iPhone est verrouillé ; le démarrage sur appareil reste à vérifier après déverrouillage. Le compagnon Watch est embarqué, sans installation directe sur la montre.

Preuves : `/tmp/walkuno-release-7-build.log`, `/tmp/walkuno-release-7-install.json`, `/tmp/walkuno-release-7-iphone-before.json`, `/tmp/walkuno-release-7-iphone-after.json`, `/tmp/walkuno-release-7-launch.log`.

## Lisibilité des widgets et cohérence de l’aperçu — 5 novembre 2026

- Le snapshot de galerie utilise le même cache courant que la timeline, avec ses préférences de compteur, palette et unités. Les données de démonstration restent le repli en l’absence de cache dans la galerie. Les configurations historiques « Pas · grands chiffres » reprennent le dessin choisi sur l’écran d’accueil ; le petit compteur dispose d’une taille carrée explicite.
- Le grand compteur affiche « Semaine », les tableaux de bord moyen et grand « Cette semaine ». Les Graphiques retirent l’unité « pas » à côté du nombre ; le petit format y affiche la distance en couleur, les autres gardent la distance à droite.
- Courbes hebdomadaires : plage verticale resserrée sur les valeurs et repères, jours abrégés alignés avec les points et sept lignes verticales à faible opacité. Le petit tableau de bord ajoute les jours, moyenne et objectif chiffrés, et la distance remplace le libellé « pas ». Le moyen ajoute les deux valeurs. Le grand graphique Semaine courbe ajoute les deux lignes et leurs chiffres dans une légende condensée.
- Compilation des quatre cibles iOS/watchOS Simulator réussie : `/tmp/walkuno-widget-polish-build.log`. Validation des traductions et `git diff --check` réussis. Aucun changement de calcul métier ; les 103 tests Foundation de la validation précédente restent la référence.
- 41 rendus synthétiques natifs sur iOS Simulator : cinq styles de compteur en trois dimensions et leurs cinq configurations historiques, quinze graphiques, trois tableaux de bord et trois cas de courbe (objectif élevé, valeurs constantes, jours absents). Lecture du cache de galerie vérifiée pour les cinq styles ; égalité des PNG des anciennes configurations et du compteur courant. Dossier : `/tmp/walkuno-widget-polish-preview/`. Les sept jours et les petits formats sont contrôlés visuellement. Le harnais ImageRenderer ne reproduit pas l’hôte WidgetKit de l’écran d’accueil ; l’écart signalé sur l’iPhone reste à confirmer sur cet hôte après mise à jour.

## Livraison locale de Walkuno 1.0.0 (8) — 5 novembre 2026

Le build 8 de développement Debug réunit les ajustements de lisibilité et de cohérence de l’aperçu ci-dessus. Numéro synchronisé dans les quatre cibles et le générateur. Compilation signée iPhone/Watch réussie, signature complète vérifiée et traductions contrôlées dans les quatre bundles.

Mise à jour installée sur l’iPhone iBoblastic sans désinstallation, puis lancement sans argument de démonstration réussi. Les métadonnées de l’appareil confirment 1.0.0 (8). Le compagnon Watch reste embarqué sans installation directe sur la montre. La correction visuelle de l’écart signalé dans l’hôte WidgetKit physique reste à confirmer sur l’écran d’accueil ; les contrôles de rendu décrits plus haut portent sur le harnais natif du simulateur.

Preuves : `/tmp/walkuno-release-8-build.log`, `/tmp/walkuno-release-8-install.json`, `/tmp/walkuno-release-8-launch.json`, `/tmp/walkuno-release-8-iphone-after.json`. Aperçu actualisé : `Documentation/Captures/Widgets-iPhone.png`.
