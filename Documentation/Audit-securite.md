# Revue de confidentialité et de sécurité

> Évolution du 5 novembre 2026 : la fonction d’effacement local a été retirée des réglages et du code. Les constats historiques sur cet ancien parcours sont conservés ci-dessous à titre de trace.

Audit statique du projet initial, complété par compilation et tests locaux. Pas de dépôt Git ou de révision de référence dans le dossier initial. Périmètre : application iPhone, Watch, widgets, pont WatchConnectivity, StoreKit, fichiers de configuration et scripts locaux.

**Aucun problème confirmé dans le périmètre vérifié.** Cette conclusion est limitée au code et aux vérifications décrits ci-dessous ; les capacités et comportements sur appareils signés restent à recetter.

## Modèle de menace et couverture

Actifs : mesures Santé, cache de sept jours, objectifs et droits Premium. Frontières : autorisation Santé, sandbox de chaque cible, App Group local, appareil compagnon appairé et transactions signées Apple. Entrées : résultats Santé, préférences locales, contexte WatchConnectivity, transactions Apple et URL `walkuno://today`.

Pas de compte, backend, WebView, upload, télémétrie, IA embarquée, secret d’API ou dépendance tierce. Les surfaces serveur/authentification, SQL, CSRF, SSRF et CI distante ne s’appliquent pas à cette version. Aucun scan de service distant n’a été effectué.

| Contrôle | Preuve dans le code | Portée |
| --- | --- | --- |
| Santé en lecture seule | `AppShared/HealthService.swift`, `authorize()` : `toShare: []` | Pas de création d’échantillon |
| Pas d’exfiltration | Recherche de URLSession, CloudKit, Logger, os_log et endpoints | Pas de transport applicatif des mesures Santé ; StoreKit contacte Apple |
| Protection du cache | `AppShared/LocalStore.swift:30` : écriture atomique, protection complète, exclusion de sauvegarde | À contrôler sur appareil verrouillé signé |
| Pas d’historique durable complet | `Walkuno/AppModel.swift` et `WidgetSnapshot` | Historique en mémoire, cache limité à sept jours |
| Widgets sensibles | `Widgets/WalkunoWidgets.swift`, `.privacySensitive()` et entitlements Data Protection | Masquage système à valider sur écran verrouillé |
| IPC limité | `AppShared/WatchBridge.swift:54` : payload limité à 100 ko, décodage Codable | Objectifs/palette/unité seulement |
| Objectifs bornés | `Sources/WalkunoCore/Preferences.swift`, `GoalHistory.set()` et `merge()` | 500…100 000, arbitrage daté |
| Paiement vérifié | `Walkuno/PurchaseStore.swift:35` et listener | Transactions vérifiées, allowlist produits, expiration/révocation |
| Effacement et concurrence | `Walkuno/AppModel.swift`, `generation` et `resetLocalData()` | Résultats tardifs ignorés, observateurs arrêtés |
| Liens profonds | `Walkuno/WalkunoApp.swift`, `onOpenURL` | Route fixe vers le compteur, aucun paramètre exécuté |
| Mode démo | `Walkuno/AppModel.swift`, `#if DEBUG` et gardes `isDemo` | Aucun passage Premium forcé, aucune écriture Santé ou cache |
| Manifeste | `Config/PrivacyInfo.xcprivacy` | Aucune collecte déclarée ; UserDefaults privé CA92.1 |

## Durcissements intégrés pendant la création

- Protection complète et absence de sauvegarde du cache d’activité.
- Pas de mesure de santé dans UserDefaults ni dans WatchConnectivity.
- Décodeurs/encodeurs créés par opération pour éviter un partage concurrent de leur état.
- Cache rejeté après minuit ou changement de fuseau ; timeline vide prévue à minuit.
- Génération de requête invalidée avant effacement pour bloquer un repeuplement tardif.
- La palette et l’unité sont pilotées par l’iPhone, seul appareil proposant ces réglages ; un ancien contexte Watch ne remplace pas les choix iPhone. Les objectifs se fusionnent dans les deux sens.
- Les événements de réglages n’envoient pas de contexte lors du retour à l’accueil après effacement.

Ces mesures sont des choix de conception, sans allégation de vulnérabilité d’une ancienne version inexistante.

## Risques à vérifier et actions opérationnelles

**SEC-01 — Confidentialité du cache sur appareil verrouillé.** Priorité avant TestFlight ; confiance élevée dans la nécessité du contrôle, aucun contournement confirmé. La compilation sans signature ne prouve pas l’application des capacités Apple. Installer une version signée, verrouiller/redémarrer l’iPhone et la Watch, vérifier l’absence de mesure lisible dans les widgets et l’accès protégé aux fichiers. Vérifier aussi l’effacement pendant une livraison Santé.

**SEC-02 — Droits StoreKit réels.** Aucun produit distant n’a été créé et aucun achat Sandbox n’a été exécuté. Avant distribution, tester les identifiants détenus par l’éditeur, achat annuel/à vie, expiration, révocation, remboursement, attente et restauration. Une validation locale ne garantit pas la configuration App Store Connect.

**SEC-03 — Documentation éditeur.** Le texte intégré décrit les flux techniques. Publier une politique finale avec contact de l’éditeur et canal d’exercice des droits, puis faire valider les déclarations App Store et obligations applicables. Aucune conformité juridique complète n’est affirmée par cet audit.

## Validation et limites

Commandes utilisées : `rg` ciblé sur sources/configurations ; lecture manuelle de HealthService, LocalStore, WatchBridge, PurchaseStore, modèles, widgets et effacement ; `swift test` ; `xcodebuild ... build` ; `xcodebuild ... test` sur simulateur dédié. Aucun secret, serveur ou dépendance à scanner n’a été identifié dans ce périmètre.

La revue ne mesure pas la résistance d’un appareil compromis et ne prétend pas empêcher un utilisateur de modifier un binaire local. Les horloges des appareils appairés sont supposées correctes pour arbitrer les objectifs. App Groups, Data Protection, HealthKit Background Delivery et droits Apple doivent être confirmés avec les profils de signature finaux.

## Complément après signature et installation

Le 4 novembre 2026, les quatre signatures et profils de développement ont été vérifiés : équipe attendue, présence des appareils cibles, App Group et protection complète ; HealthKit et Background Delivery présents pour les deux applications. L’installation et le lancement ont réussi sur iPhone et Watch. Les profils expirent le 11 novembre 2026. Ces contrôles ferment le point de configuration de signature ; le comportement des widgets et caches sur appareil verrouillé ainsi que les achats Sandbox restent à recetter. Aucune autorisation Santé personnelle n’a été accordée par l’agent.

## Revue du correctif d’actualisation — 4 novembre 2026

Périmètre : modifications locales de HealthService, AppModel, WatchModel, coordination des actualisations et réponses asynchrones ; suivi de LocalStore, WidgetSnapshot, WatchBridge et des capacités Santé. Comparaison avec les copies des fichiers prises avant ce correctif, sans référence Git disponible. Actifs et frontières : mesures privées en mémoire, cache protégé de sept jours, callbacks HealthKit et effacement local. Les surfaces serveur, comptes, uploads et IA restent non applicables.

**SEC-04 — Relecture possible pendant l’effacement, corrigée par analyse.** Gravité faible, confiance élevée dans le chemin de concurrence ; aucune exploitation sur données personnelles. Un callback d’observation déjà en attente pouvait lancer une lecture pendant la suspension de `health.stop()`, après l’incrément de génération mais avant la remise à zéro des préférences. Cette lecture pouvait alors être acceptée comme appartenant à la génération actuelle. Les deux modèles désactivent désormais `healthRequested` avant toute suspension de l’effacement, puis annulent les tâches et requêtes. Les gardes de génération restent présentes après les attentes, y compris avant d’affecter le détail horaire. La fermeture du chemin dans les modèles est vérifiée statiquement ; les tests Foundation vérifient l’annulation et qu’une ancienne tâche ne puisse pas effacer l’état de coordination d’une nouvelle tâche.

**Aucun autre problème confirmé dans le périmètre vérifié.** Les requêtes ont un délai limite, leurs callbacks tardifs sont ignorés et les rafales ne provoquent pas de relance illimitée. Aucun transport, journal de mesures, permission supplémentaire ou stockage d’historique complet n’est ajouté. Les erreurs affichées sont des textes localisés sans contenu Santé. Le cache reste écrit atomiquement avec protection complète et exclusion des sauvegardes ; WatchConnectivity reste limité aux réglages.

Validation : 35 tests Foundation réussis dans la dernière passe sur les sources partagées, dont huit tests du correctif ; compilation Debug des quatre cibles pour simulateur et appareils. Quatre vérifications supplémentaires exécutent le véritable AppModel avec des services synthétiques : priorité aux mesures récentes, conservation des totaux après échec horaire, blocage des callbacks pendant l’arrêt de Santé et rejet d’une réponse horaire après effacement. Les quatre réussissent, notamment le scénario SEC-04. Limites : aucun test Santé avec données personnelles ni scénario de verrouillage matériel exécuté dans cette revue. La protection réelle au verrouillage et les livraisons Santé sur iPhone/Watch restent à recetter. Aucun changement opérationnel de permissions ou de distribution n’est requis par cette revue.

## Revue des nouveaux widgets iPhone — 5 novembre 2026

Périmètre : refonte des widgets de cette session sur `main`, base `b60de42`, avec modifications locales antérieures conservées. Lecture de WidgetSnapshot/WidgetHistory, AppModel, LocalStore, des quatre vues de widget et des liens profonds ; suivi de HealthService, WatchBridge, des App Groups, du manifeste de confidentialité et des entitlements des extensions. Actifs : mesures Santé, résumés en cache et choix d’affichage. Frontières : application/extension dans l’App Group et exposition des snapshots sur écran verrouillé. Serveur, comptes, WebView, uploads et IA non applicables.

**Aucun problème confirmé dans le périmètre vérifié.** Les quatre familles marquent leurs mesures sensibles. Le cache conserve l’écriture atomique, `NSFileProtectionComplete`, l’exclusion des sauvegardes et la limite de lecture de 100 Ko. Le nouvel historique est borné : deux séries de sept jours, créneaux quotidiens des deux mois et, avec Pro, douze agrégats par année sur deux ans. Les profils horaires historiques individuels ne sont pas stockés. L’application filtre l’historique autorisé et les choix effectifs avant écriture. Les nouvelles données restent dans l’App Group ; aucun transport ni journal de mesures n’est ajouté. Les nouveaux liens profonds ne font que sélectionner un onglet connu. L’effacement conserve les gardes de génération et remet à zéro les nouveaux états de chargement.

Validation : tests synthétiques sur données absentes/zéro, dates futures, objectifs historiques, année bissextile, moyennes pondérées, migration et taille du cache ; 101 tests Foundation réussis. Compilation Debug iPhone/Watch et extensions pour simulateur réussie. Contrôle des rendus natifs, dont les états sans données. Le JSON d’un historique synthétique de 5 000 jours avec cinq mesures reste sous 100 Ko après agrégation. Aucune donnée Santé personnelle n’a été utilisée.

Limites : la confidentialité réelle sous verrouillage et la fréquence des livraisons Santé/WidgetKit restent à vérifier sur appareils signés. Les capacités existantes sont examinées statiquement ; aucun nouveau test de verrouillage matériel ou d’achat Sandbox n’a été exécuté. Aucune action opérationnelle de sécurité requise par cette refonte ; les recettes matérielles SEC-01/SEC-02 restent applicables.


## Complément du 5 novembre 2026 — droits Pro et extensions

Base : branche `main`, révision `dfb8948`, modifications locales de la répartition Gratuit/Pro. Périmètre : PurchaseStore, ProAccess, LocalStore, WatchConnectivity, fournisseurs de timelines et lien `walkuno://pro`. Actifs : droits d’achat et mesures Santé ; frontières : transactions Apple vérifiées, App Group privé, compagnon appairé et configurations Debug/Release. Les surfaces serveur, WebView et dépendances tierces restent non applicables.

**Aucun problème confirmé dans le périmètre vérifié.**

- PurchaseStore n’accepte que les transactions vérifiées, des produits attendus, non révoquées, non remplacées et non expirées. Le miroir local ne sert jamais de preuve de paiement dans l’application.
- Le miroir des droits ne contient aucune mesure Santé, reste dans l’App Group, est exclu des sauvegardes et protégé jusqu’à la première authentification. Le cache Santé conserve sa protection complète.
- Les extensions ne reçoivent aucune mesure dans les entrées gratuites et contrôlent la date d’expiration. Les contextes anciens sans droits restent verrouillés ; sur Watch, un droit plus ancien ne remplace pas un droit vérifié plus récent. L’iPhone ignore les droits entrants du compagnon.
- Les fichiers de droits Debug et Release sont distincts : le mode de simulation ne peut pas déverrouiller les extensions Release via un cache issu de Debug.
- Le lien profond ouvre uniquement l’offre, sans octroyer de droit ni exécuter de paramètre externe. Les identifiants d’achat existants sont conservés.

Limites opérationnelles : WidgetKit conserve le contrôle du rafraîchissement ; une révocation ou un remboursement doit être relu par StoreKit sur l’iPhone puis transmis à la Watch. Hors connexion, la Watch conserve le dernier état jusqu’à expiration/synchronisation. La propagation effective StoreKit/App Group/WatchConnectivity et la protection des fichiers sur appareils signés restent à recetter. Aucun service distant ni achat réel n’a été testé.

Vérifications locales : compilation Debug et Release des quatre cibles, validation des sept langues, tests métier incluant l’expiration exacte et la compatibilité des contextes Watch, et tests d’interface ciblés Gratuit/Pro. Les résultats détaillés sont consignés avec la livraison de cette modification.
