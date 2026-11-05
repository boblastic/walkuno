# Ton élan du jour

La carte de l’accueil apparaît uniquement pour aujourd’hui, après le graphique des sept derniers jours. Elle affiche les pas restant vers l’objectif, un encouragement court et, pendant la journée, un petit palier facultatif. Le lien « Pourquoi ce conseil ? » explique les mesures utilisées, leur couverture et l’origine de la formulation. Les textes existent dans les sept langues de l’application. La fonction est disponible sans Pro.

## Calculs locaux

`Sources/WalkunoCore/Motivation.swift` construit un instantané à partir des données déjà chargées ; aucune requête Santé supplémentaire n’est nécessaire.

- Les sept jours terminés précédant aujourd’hui sont comparés aux sept jours qui les précèdent. Les journées sans mesure sont exclues des moyennes ; une mesure de zéro reste un zéro. Les doublons d’une même date locale sont fusionnés et les données futures ignorées.
- Chaque réussite utilise l’objectif enregistré pour cette journée. L’objectif actuel n’est jamais appliqué rétroactivement.
- Une tendance est présentée avec au moins quatre jours mesurés par fenêtre et une moyenne précédente strictement positive. Une hausse d’au moins 10 % valorise la progression, même si peu d’objectifs sont atteints. Une baisse d’au moins 15 %, ou peu d’objectifs atteints sans progression établie, conduit à une reprise plus douce.
- La comparaison à la même heure réutilise `WidgetActivityDetail.usual` : au moins trois références, jusqu’à sept jours récents parmi les vingt-huit derniers, requêtes arrêtées à la même heure locale. Elle est omise si les données horaires et quotidiennes ne proviennent pas de la même actualisation, si le cache disque est utilisé ou si l’actualisation date de plus de deux heures. L’heure de la mesure est précisée. La tolérance est le maximum entre 300 pas et 15 % de la référence.
- Le palier est plafonné à 1 000 pas supplémentaires, ou 500 lors d’une reprise, sans dépasser les pas restant vers l’objectif. Il disparaît lorsque l’objectif est atteint et entre 22 h et 6 h. Aucun objectif, paramètre ou rappel n’est modifié.

## Apple Intelligence

`Walkuno/MotivationWriter.swift` utilise explicitement `SystemLanguageModel.default` avec Foundation Models à partir d’iOS 26. La disponibilité et la langue de l’application sont contrôlées avant chaque nouvelle tentative. Les versions antérieures, appareils incompatibles, erreurs, refus et réponses rejetées conservent immédiatement les textes locaux.

Seuls un encouragement traduit et des catégories de situation, tendance et rythme sont fournis au modèle. Aucun historique brut, identifiant, valeur de mesure ou date précise n’est nécessaire au prompt. Le modèle reformule une phrase ; les chiffres et le palier restent calculés et affichés par l’app. La génération utilise une structure `@Generable`, des instructions limitant son rôle et un contrôle de longueur, chiffres, liens, balisage et caractères de contrôle. Ce contrôle de forme ne prouve pas à lui seul la pertinence sémantique d’une phrase.

Une seule réponse, ou l’absence de réponse en cas d’indisponibilité, est conservée en mémoire. La clé évolue avec la journée, le fuseau, la langue, les tranches de six heures, les paliers de 500 pas, l’objectif et le contexte analysé. Les chiffres visibles restent actualisés indépendamment de cette clé. Un réveil de la carte toutes les cinq minutes permet de réévaluer le moment de la journée et la fraîcheur des données. La génération se limite au premier plan ; les résultats annulés sont ignorés. Aucune notification n’est ajoutée.

## Vérification de sécurité — 5 novembre 2026

Périmètre : ajout de la motivation sur la branche `main`, base `dfb8948`, dans un arbre contenant déjà des modifications locales indépendantes. La revue porte sur `Motivation.swift`, `MotivationWriter.swift`, `MotivationCard.swift`, leurs points d’entrée dans `AppModel`/`TodayView`, les données horaires réutilisées et les configurations de confidentialité. Elle ne constitue pas un nouvel audit de toute l’application.

Actifs : données Santé dérivées et texte personnalisé. Frontières : lecture Santé déjà autorisée → calcul local → modèle système local → rendu SwiftUI. Les entrées du modèle sont des textes embarqués et des catégories choisies par le code ; sa sortie est considérée non fiable. Aucun outil, droit d’écriture Santé, accès réseau ou action sur les objectifs n’est confié au modèle. Les modifications d’autorisations, de stockage partagé, d’achats, de serveur et de déploiement sont hors de ce changement.

**Aucun problème confirmé dans le périmètre vérifié.** Le chemin de génération ne contient ni journalisation du prompt ou de la réponse, ni persistance, ni fournisseur distant, ni outil exécutable. Le rendu est du texte SwiftUI, sans interprétation HTML ni exécution de la sortie. Aucun entitlement cloud ou nouvelle dépendance n’est ajouté. Les réponses obsolètes après annulation ou réinitialisation ne remplacent pas les messages courants.

Risque à vérifier, confiance élevée sur la limite : la qualité, la langue et le ton d’une génération réelle doivent être évalués sur iPhone compatible, avec plusieurs versions du modèle. Le filtre ne détecte pas toutes les affirmations erronées ou quantités écrites en lettres. La sortie ne modifie toutefois aucune mesure ni consigne chiffrée. Les instructions et garde-fous système restent activés, avec repli local sur erreur ou refus.

## Validation

- Suite Swift : 122 tests, dont neuf tests de motivation couvrant données absentes/zéro/futures, objectifs datés, tendances et couverture, progression sans réussite, paliers, soirée, rythme à la même heure et fraîcheur, changement d’heure, clé de formulation et filtrage des réponses.
- Compilation Debug de l’application et des trois extensions/app Watch sur simulateur, sans signature.
- Deux tests d’interface sur iOS 27 : explication locale en français, navigation vers une date passée et retour à aujourd’hui, textes anglais. Les captures ont été inspectées.
- Validation des clés et arguments de formatage des sept langues ; vérification des 25 textes de motivation dans les sept langues et quatre bundles compilés. Des modifications indépendantes des traductions ont continué pendant cette intervention ; la comparaison des ressources compilées finale est limitée aux clés `motivation.*`.
- Génération réelle sur appareil : non exécutée. Le mode démonstration désactive explicitement la génération pour rendre les tests d’interface déterministes. Le repli local est donc le chemin vérifié en interface.

Preuves locales : `/tmp/walkuno-motivation-tests.log`, `/tmp/walkuno-motivation-integrated-ui.log`, `/tmp/walkuno-motivation-integrated-ui.xcresult` et `/tmp/walkuno-motivation-captures/`. Aucune installation sur appareil physique ni publication n’a été effectuée.
