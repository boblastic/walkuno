# Votre élan du jour

La carte de l’accueil apparaît uniquement pour aujourd’hui, après le graphique des sept derniers jours. Elle affiche les pas restant vers l’objectif, un encouragement court et, pendant la journée, un petit palier facultatif. Le lien « Pourquoi ce conseil ? » explique les mesures utilisées, leur couverture et l’origine de la formulation. Les textes existent dans les sept langues de l’application. La fonction est disponible sans Pro.

En français, Walkuno utilise le vouvoiement dans toute l’interface, avec un ton chaleureux, des formulations courtes et des encouragements sans pression. Cette règle s’applique aussi aux reformulations demandées à Apple Intelligence.

## Calculs locaux

`Sources/WalkunoCore/Motivation.swift` construit un instantané à partir des données déjà chargées ; aucune requête Santé supplémentaire n’est nécessaire.

- Les sept jours terminés précédant aujourd’hui sont comparés aux sept jours qui les précèdent. Les journées sans mesure sont exclues des moyennes ; une mesure de zéro reste un zéro. Les doublons d’une même date locale sont fusionnés et les données futures ignorées.
- Chaque réussite utilise l’objectif enregistré pour cette journée. L’objectif actuel n’est jamais appliqué rétroactivement.
- Une tendance est présentée avec au moins quatre jours mesurés par fenêtre et une moyenne précédente strictement positive. Une hausse d’au moins 10 % valorise la progression, même si peu d’objectifs sont atteints. Une baisse d’au moins 15 %, ou peu d’objectifs atteints sans progression établie, conduit à une reprise plus douce.
- La comparaison à la même heure réutilise `WidgetActivityDetail.usual` : au moins trois références, jusqu’à sept jours récents parmi les vingt-huit derniers, requêtes arrêtées à la même heure locale. Elle est omise si les données horaires et quotidiennes ne proviennent pas de la même actualisation, si le cache disque est utilisé ou si l’actualisation date de plus de deux heures. L’heure de la mesure est précisée. La tolérance est le maximum entre 300 pas et 15 % de la référence.
- Le palier est plafonné à 1 000 pas supplémentaires, ou 500 lors d’une reprise, sans dépasser les pas restant vers l’objectif. Il disparaît lorsque l’objectif est atteint et entre 22 h et 6 h. Aucun objectif, paramètre ou rappel n’est modifié.
- L’encouragement distingue la proximité de l’objectif (dès 80 %, en journée), l’objectif atteint, l’objectif dépassé et l’objectif largement dépassé (dès 150 %). Les réussites restent célébrées le soir, sans proposer de pas supplémentaires. Chaque situation possède une phrase locale dans les sept langues et peut être reformulée par Apple Intelligence.

## Encouragements contextuels

La phrase locale et la phrase fournie à Apple Intelligence partagent le même contexte. Les 18 variantes croisent l’heure locale, l’avancement vers l’objectif, le rythme habituel à la même heure et les jours récents. Elles restent disponibles sans génération.

| Scénario | Exemple de formulation française |
| --- | --- |
| Matin, objectif proche et activité au moins triple de la référence | Ce matin, vous marchez bien plus que d’habitude à cette heure et votre objectif est déjà tout proche. |
| Matin, objectif proche et rythme en avance | Ce matin, vous êtes en avance sur votre rythme habituel et déjà proche de votre objectif. |
| Matin, objectif proche sans avance établie | Votre objectif est déjà proche ce matin ; appréciez les pas accomplis à votre rythme. |
| Objectif proche et rythme en avance, après le matin | Vous êtes proche de votre objectif et en avance sur votre rythme habituel à cette heure ; bravo pour cet élan. |
| Soir, objectif proche | Ce soir, vous êtes proche de votre objectif ; les pas déjà faits comptent, sans pression pour la suite. |
| Objectif atteint le matin | Votre objectif est déjà atteint ce matin ; bravo pour ce beau début de journée. |
| Objectif dépassé le matin | Votre objectif est déjà dépassé ce matin ; profitez du chemin parcouru. |
| Objectif largement dépassé le matin | Vous avez déjà largement dépassé votre objectif ce matin ; bravo, sans besoin d’en faire davantage. |
| Objectif proche et régularité récente | Votre régularité des derniers jours se poursuit ; vous êtes proche de votre objectif. |
| Objectif atteint et régularité récente | Encore un objectif atteint, dans la continuité des derniers jours ; bravo pour votre régularité. |
| Matin très en avance, objectif encore éloigné | Ce matin, vous marchez bien plus que d’habitude à cette heure ; bravo pour ce bel élan. |
| Matin en avance, objectif encore éloigné | Ce matin, vous êtes en avance sur votre rythme habituel ; appréciez ce bel élan. |
| En avance à la même heure, après le matin | Vous êtes en avance sur votre rythme habituel à cette heure ; chaque pas déjà fait compte. |
| Progression hebdomadaire et avance aujourd’hui | Vos progrès récents se prolongent aujourd’hui ; vous êtes en avance sur votre rythme habituel à cette heure. |
| Activité plus calme à la même heure, objectif encore éloigné | Votre journée est plus calme que d’habitude à cette heure ; avancez à votre rythme, sans rien rattraper. |
| Matin sans autre contexte établi | Ce matin, avancez à votre rythme ; chaque petit pas compte. |
| Après-midi sans autre contexte établi | Cet après-midi, une petite marche reste une option, si vous en avez envie. |
| Soir sans autre contexte établi | Ce soir, appréciez les pas déjà faits ; chaque petit pas compte. |

Le matin va de 6 h à midi, l’après-midi de midi à 18 h, le soir de 18 h à 22 h. De 22 h à 6 h, la phrase de fin de journée est conservée, sauf si l’objectif est déjà atteint ou dépassé. La réussite et la proximité de l’objectif passent avant les messages de rythme. Le matin, l’avance passe avant la régularité. En dehors du matin, une avance près de l’objectif passe avant la régularité, puis vient la variante du soir. Une tendance hebdomadaire établie conserve sa phrase lorsqu’aucune comparaison horaire ne justifie un message plus précis.

L’avance marquée du matin demande au moins trois fois la référence horaire, une référence d’au moins 500 pas et une avance dépassant la tolérance habituelle. Toutes les affirmations de rythme utilisent les contrôles de fraîcheur et de couverture décrits plus haut ; une référence absente, périmée ou insuffisante n’autorise aucune comparaison. La régularité demande au moins quatre objectifs atteints parmi les sept derniers jours terminés. Elle ne suppose pas une série de jours consécutifs.

Le contexte fait partie de la clé de formulation : franchir le seuil d’avance marquée invalide le texte même au sein d’une tranche de 500 pas. Le changement de période et la péremption des références sont également réévalués. Les nouveaux scénarios changent uniquement la phrase, pas les calculs des mesures ou du palier facultatif.

## Apple Intelligence

`Walkuno/MotivationWriter.swift` utilise explicitement `SystemLanguageModel.default` avec Foundation Models à partir d’iOS 26. La disponibilité et la langue de l’application sont contrôlées avant chaque nouvelle tentative. Les versions antérieures, appareils incompatibles, erreurs, refus et réponses rejetées conservent immédiatement les textes locaux.

Seuls un encouragement traduit et des catégories de situation, de contexte, de moment de la journée, de tendance et de rythme sont fournis au modèle. Aucun historique brut, identifiant, valeur de mesure ou date précise n’est nécessaire au prompt. Le modèle reformule une phrase en conservant son contexte ; les chiffres et le palier restent calculés et affichés par l’app. La génération utilise une structure `@Generable`, des instructions limitant son rôle et un contrôle de longueur, chiffres, liens, balisage et caractères de contrôle. Ce contrôle de forme ne prouve pas à lui seul la pertinence sémantique d’une phrase.

Une seule réponse, ou l’absence de réponse en cas d’indisponibilité, est conservée en mémoire. La clé évolue avec la journée, le fuseau, la langue, les tranches de six heures, les paliers de 500 pas, l’objectif et le contexte analysé. Les chiffres visibles restent actualisés indépendamment de cette clé. Un réveil de la carte toutes les cinq minutes permet de réévaluer le moment de la journée et la fraîcheur des données. La génération se limite au premier plan ; les résultats annulés sont ignorés. Aucune notification n’est ajoutée.

Dans « Pourquoi ce conseil ? », le bouton « Actualiser avec Apple Intelligence » vide ce cache et relance la formulation à partir de l’activité déjà chargée. Un indicateur accompagne la génération et empêche les appuis répétés. Le bouton est désactivé en l’absence de pas disponibles ou lorsque l’app est inactive. Si la tentative ne produit pas de texte accepté (y compris en mode démonstration), le conseil local est affiché et un message signale l’indisponibilité. Les mesures et objectifs ne sont pas modifiés et aucune nouvelle lecture Santé n’est déclenchée.

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

### Actualisation manuelle — 6 novembre 2026

Les trois tests d’interface ciblés passent sur le simulateur iOS 27 : explication et visibilité uniquement pour aujourd’hui, langue anglaise, puis deux actualisations successives en mode démonstration. Ce dernier scénario vérifie le message d’indisponibilité, le bouton réutilisable et la conservation des mesures et du conseil local. La capture du détail a été inspectée. Les traductions des nouveaux textes ont aussi été vérifiées dans les quatre bundles compilés. La génération réelle reste à vérifier sur iPhone compatible.

Preuves : `/tmp/walkuno-advice-refresh-ui-retry.xcresult` et `/tmp/walkuno-advice-refresh-captures/`.
