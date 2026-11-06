# WALKUNO
## Cahier des charges fonctionnel et technique

**Éditeur :** Orbelio  
**Produit :** Walkuno  
**Version du document :** 1.0  
**Date :** 4 novembre 2026  
**Statut :** Proposition initiale pour développement

---

# 1. Présentation générale

## 1.1. Vision du produit

Walkuno est une application mobile de suivi des pas et de l'activité quotidienne, destinée aux utilisateurs d'iPhone et d'Apple Watch.

Son ambition est de proposer l'une des expériences de suivi de la marche les plus élégantes et agréables de l'écosystème Apple.

Walkuno doit transformer une information relativement simple — le nombre de pas réalisés dans la journée — en une expérience visuelle attractive, personnalisable et motivante.

**Signature proposée :** *Walkuno — Every step counts.*

## 1.2. Objectifs

- Afficher simplement et précisément le nombre de pas.
- Encourager une activité physique régulière.
- Permettre de visualiser facilement ses progrès.
- Offrir des interfaces et animations de qualité premium.
- Exploiter intelligemment les données Apple Santé.
- Fournir des widgets particulièrement travaillés.
- Proposer une expérience homogène sur iPhone et Apple Watch.
- Générer des revenus grâce à des options Premium.

## 1.3. Public cible

Walkuno s'adresse aux utilisateurs souhaitant suivre leur activité quotidienne sans utiliser une application sportive complexe.

Cibles principales :

- Utilisateurs souhaitant atteindre un objectif quotidien de pas.
- Possesseurs d'Apple Watch.
- Personnes souhaitant reprendre une activité physique régulière.
- Amateurs de statistiques et de visualisations.
- Utilisateurs sensibles au design, aux widgets et à la personnalisation de leur iPhone.

L'application doit convenir aux profils débutants comme aux utilisateurs marchant quotidiennement plusieurs kilomètres.

## 1.4. Positionnement

Walkuno se différencie par trois éléments :

1. **Design premium :** animations, typographie, graphiques et finitions.
2. **Simplicité :** accès immédiat aux informations importantes.
3. **Personnalisation :** thèmes, widgets et présentation des statistiques.

L'application ne doit pas devenir une plateforme de fitness généraliste.

---

# 2. Plateformes et principes techniques

## 2.1. Plateformes

- iPhone : plateforme principale.
- Apple Watch : application complémentaire.
- Widgets iOS : écran d'accueil et écran verrouillé.
- Complications et Smart Stack Apple Watch, selon les possibilités du système.

Les versions minimales d'iOS et de watchOS seront arrêtées au démarrage technique pour équilibrer couverture du parc et fonctionnalités graphiques.

## 2.2. Technologies envisagées

| Composant | Technologie |
|---|---|
| Développement | Swift |
| Interface | SwiftUI |
| Données de santé | HealthKit |
| Statistiques | Swift Charts |
| Widgets | WidgetKit |
| Achats intégrés | StoreKit 2 |
| Stockage des préférences | SwiftData ou UserDefaults |
| Partage de données entre extensions | App Groups |
| Communication avec l'Apple Watch | WatchConnectivity si nécessaire |
| Animations | SwiftUI et Core Animation |

L'architecture doit privilégier les technologies natives Apple.

## 2.3. Architecture générale

Walkuno doit fonctionner principalement en local.

**Aucun compte utilisateur ni serveur ne sont nécessaires pour les fonctionnalités principales.**

Les données relatives aux pas, distances et calories proviennent d'Apple Santé.

Walkuno conserve uniquement les informations nécessaires à son fonctionnement : préférences, objectifs, personnalisations, états des achats et éventuels caches de présentation.

L'architecture doit permettre l'ajout ultérieur de fonctionnalités connectées sans refonte majeure.

---

# 3. Fonctionnalités principales — Version 1

## 3.1. Tableau de bord quotidien

Il constitue l'écran principal de Walkuno.

### Informations affichées

- Nombre de pas réalisés aujourd'hui.
- Objectif quotidien.
- Pourcentage de réalisation.
- Distance parcourue.
- Calories actives, lorsque les données correspondantes sont accessibles.
- Évolution horaire des pas.
- Comparaison avec la veille.

### Présentation

Le nombre de pas doit occuper une place centrale, avec une typographie particulièrement lisible.

Une jauge circulaire ou une visualisation de progression originale doit entourer ou accompagner le compteur.

Les valeurs évoluent avec des transitions numériques fluides.

Lorsqu'un utilisateur atteint son objectif, une animation valorisante apparaît.

Exemple :

**8 432 pas**

Objectif : 10 000 pas  
Progression : 84 %

### Interactions

- Appuyer sur le compteur pour consulter le détail de la journée.
- Modifier son objectif.
- Accéder à la progression horaire.
- Consulter les records et comparaisons.
- Partager une carte de progression.

### Contraintes

Le tableau de bord doit être immédiatement compréhensible.

Aucune publicité, fenêtre promotionnelle ou information secondaire ne doit perturber la lecture du compteur.

## 3.2. Synchronisation Apple Santé

Walkuno utilise HealthKit comme source principale des mesures.

### Données lues

| Donnée | Priorité |
|---|---|
| Nombre de pas | Obligatoire |
| Distance marche/course | Élevée |
| Énergie active dépensée | Élevée |
| Historique des pas | Obligatoire |
| Nombre d'étages montés | Optionnel |

### Comportement attendu

- Demander l'autorisation Apple Santé lors de l'intégration initiale.
- Expliquer clairement l'intérêt de chaque autorisation.
- Lire les données historiques autorisées.
- Rafraîchir les mesures lors de l'ouverture de l'application.
- Prendre en compte les modifications des données Santé.
- Gérer correctement les données issues de plusieurs appareils.

**Règle impérative :** ne jamais additionner naïvement les pas de l'iPhone et de l'Apple Watch, afin d'éviter les doubles comptages.

Les statistiques doivent s'appuyer sur les mécanismes d'agrégation de HealthKit.

Walkuno doit fonctionner avec un iPhone seul, sans Apple Watch.

### Cas particuliers

L'interface devra traiter les situations suivantes :

- Autorisation non accordée.
- Historique partiellement accessible.
- Absence de données.
- Apple Watch non synchronisée.
- Changement de fuseau horaire.
- Données HealthKit corrigées rétroactivement.

Un écran explicatif doit être proposé lorsque les données nécessaires ne sont pas accessibles, sans présumer systématiquement que l'utilisateur a refusé une autorisation.

## 3.3. Objectifs quotidiens

L'utilisateur doit pouvoir choisir librement son objectif.

### Fonctionnalités

- Objectif initial proposé : 8 000 pas.
- Modification manuelle.
- Choix parmi des objectifs prédéfinis.
- Visualisation de la progression.
- Historique des objectifs atteints.
- Possibilité de modifier l'objectif sans perdre l'historique.

Les objectifs doivent rester personnalisables et ne pas être présentés comme des recommandations médicales.

### Évolution future

Suggestion automatique d'un objectif adapté à l'activité observée sur les dernières semaines.

## 3.4. Statistiques

Walkuno doit proposer des statistiques particulièrement soignées et interactives.

### Vues disponibles

**Journalier**
- Pas par heure.
- Total quotidien.
- Comparaison avec la veille.
- Moment le plus actif de la journée.

**Hebdomadaire**
- Pas par jour.
- Total hebdomadaire.
- Moyenne quotidienne.
- Nombre d'objectifs atteints.
- Comparaison avec la semaine précédente.

**Mensuel**
- Historique quotidien.
- Total du mois.
- Moyenne par jour.
- Meilleure journée.
- Évolution par rapport au mois précédent.

**Annuel**
- Total des pas.
- Distance cumulée.
- Moyenne quotidienne.
- Meilleur mois.
- Record quotidien.

### Visualisations

- Histogrammes interactifs.
- Courbes de progression.
- Calendrier thermique (heatmap).
- Barres de comparaison.
- Cartes de statistiques synthétiques.

Les graphiques doivent être fluides, cohérents avec les couleurs du thème et permettre la consultation des valeurs détaillées.

## 3.5. Historique et calendrier

Un calendrier visuel doit permettre de retrouver facilement l'activité passée.

Chaque journée est représentée par une intensité de couleur correspondant à son niveau d'activité.

L'utilisateur peut sélectionner une date pour accéder au détail.

Le calendrier doit distinguer :

- Journées très actives.
- Journées moyennement actives.
- Journées peu actives.
- Journées sans données disponibles.

Une journée sans données ne doit pas automatiquement être considérée comme une journée à zéro pas.

## 3.6. Records et récompenses

Walkuno doit valoriser la progression personnelle.

### Records

- Meilleur nombre de pas en une journée.
- Meilleure semaine.
- Meilleur mois.
- Plus longue série d'objectifs atteints.
- Nombre total de pas depuis le début du suivi accessible.

### Récompenses

Des badges visuels peuvent être débloqués à certains seuils.

Exemples :

- Première journée à 5 000 pas.
- Première journée à 10 000 pas.
- 100 000 pas cumulés.
- Sept objectifs quotidiens atteints.
- Nouveau record personnel.

Chaque récompense doit posséder une illustration soignée.

La gamification doit rester positive et éviter les mécanismes culpabilisants.

## 3.7. Widgets iPhone

Les widgets constituent un élément différenciant majeur de Walkuno.

### Formats

- Petit widget carré.
- Widget moyen.
- Grand widget.
- Widgets pour écran verrouillé.
- Variantes adaptées aux emplacements pris en charge par iOS.

### Informations possibles

- Nombre de pas.
- Progression de l'objectif.
- Cercle de progression.
- Distance.
- Évolution hebdomadaire.
- Série de journées actives.

### Personnalisation

- Plusieurs styles.
- Plusieurs couleurs.
- Version minimaliste.
- Version graphique.
- Version compacte avec grands chiffres.

### Contraintes

Le rafraîchissement des widgets dépend du système iOS et ne peut pas être garanti en temps réel.

Walkuno doit utiliser un cache partagé entre l'application et les widgets, afficher si nécessaire la date de dernière actualisation et privilégier une consommation énergétique raisonnable.

## 3.8. Partage des statistiques

L'utilisateur doit pouvoir générer des visuels élégants pour partager son activité.

Exemples :

- Résultat du jour.
- Nouveau record.
- Bilan hebdomadaire.
- Badge obtenu.

Le visuel partagé doit reprendre l'identité Walkuno sans exposer d'autres données personnelles que celles choisies par l'utilisateur.

Le partage utilise les fonctions natives iOS.

---

# 4. Apple Watch

L'application Apple Watch fait partie de la vision du produit.

Une première version fonctionnelle pourra être livrée avec la V1 ou dans une mise à jour rapprochée, selon la charge de développement.

## 4.1. Écran principal

- Nombre de pas.
- Cercle de progression.
- Objectif quotidien.
- Distance parcourue.
- Animation lors de l'atteinte de l'objectif.

## 4.2. Navigation

Navigation limitée à quelques écrans simples :

- Aujourd'hui.
- Statistiques rapides.
- Objectif.

## 4.3. Complications

Proposer plusieurs complications lorsque les formats watchOS le permettent.

Exemples :

- Nombre de pas.
- Pourcentage d'objectif.
- Anneau de progression.

Les mises à jour doivent respecter les mécanismes et limitations de watchOS.

## 4.4. Synchronisation

Les paramètres et objectifs doivent rester cohérents entre iPhone et Apple Watch.

L'application doit gérer les périodes où les deux appareils ne sont pas connectés.

---

# 5. Expérience utilisateur et identité visuelle

## 5.1. Direction artistique

Walkuno doit proposer une identité moderne et premium, distincte des applications de fitness classiques.

### Palette initiale

| Élément | Couleur |
|---|---|
| Fond principal sombre | `#0B1424` |
| Vert menthe principal | `#75F0CE` |
| Turquoise profond | `#124B53` |
| Accent corail | `#FF956F` |
| Texte principal | Blanc légèrement adouci |

Une déclinaison claire doit également être prévue.

### Typographie

- Typographie native Apple.
- Chiffres particulièrement grands.
- Hiérarchie visuelle forte.
- Texte secondaire discret mais accessible.

### Design des composants

- Cartes aux angles arrondis.
- Arrière-plans subtilement dégradés.
- Effets de profondeur mesurés.
- Graphiques épurés.
- Indicateurs de progression animés.
- Transitions harmonieuses.

Le design ne doit jamais nuire à la lisibilité.

## 5.2. Animations

Les animations constituent une caractéristique centrale du produit.

### Animations attendues

- Incrémentation progressive des chiffres.
- Remplissage fluide des jauges.
- Transitions entre périodes statistiques.
- Apparition animée des graphiques.
- Animation de célébration d'objectif.
- Effets subtils de lumière et de mouvement.

### Exigences

- Objectif de fluidité : 60 images/seconde sur appareils compatibles.
- Absence de ralentissement perceptible lors des interactions courantes.
- Animations limitées lorsque le mode Réduire les animations est activé.
- Consommation énergétique maîtrisée.

## 5.3. Personnalisation

L'utilisateur doit pouvoir personnaliser :

- Le thème de couleurs.
- Le style du compteur principal.
- Les widgets.
- L'affichage de certaines métriques.
- Les unités de distance.
- L'objectif quotidien.

La V1 proposera un nombre limité de thèmes soigneusement conçus plutôt qu'un éditeur visuel complexe.

## 5.4. Navigation

Navigation principale proposée :

1. **Aujourd'hui** : compteur et progression.
2. **Statistiques** : graphiques et historique.
3. **Succès** : records et récompenses.
4. **Réglages** : objectifs, thèmes, données et abonnement.

L'accès au compteur doit nécessiter zéro interaction après ouverture de l'application.

---

# 6. Onboarding

La première utilisation doit être rapide et valorisante.

## Étape 1 — Bienvenue

Présentation de Walkuno avec une animation du logo.

## Étape 2 — Autorisation Apple Santé

Explication de l'utilisation des données.

Demande d'accès au nombre de pas, puis aux métriques complémentaires nécessaires.

## Étape 3 — Objectif

Proposition d'un objectif quotidien modifiable.

## Étape 4 — Personnalisation

Choix entre quelques thèmes visuels.

## Étape 5 — Première utilisation

Affichage immédiat du tableau de bord avec les données disponibles.

**Objectif :** permettre à un nouvel utilisateur d'accéder à son compteur en moins d'une minute dans un parcours nominal.

L'abonnement Premium ne doit pas être obligatoire pour accéder au compteur.

---

# 7. Modèle économique

## 7.1. Modèle freemium

Répartition ajustée le 6 novembre 2026 : [tableau détaillé Gratuit / Pro](Offres.md).

Walkuno doit proposer une application gratuite réellement utile, complétée par Walkuno Pro.

### Version gratuite

- Compteur quotidien et synchronisation Apple Santé en lecture seule.
- Objectif quotidien personnalisable et les cinq mesures disponibles.
- Statistiques récentes et tendance sur sept jours.
- Consultation détaillée des 31 derniers jours, aujourd’hui compris.
- Records quotidiens, tous les trophées, séries et traversées sur l’historique disponible.
- Palette Walkuno, compteur Horizon, effet Étoiles. Dans le paramétrage du compteur, aperçu fixe sans relecture et choix désactivés ; bouton distinct de déblocage Pro.
- Application Apple Watch, objectifs et sept jours récents.
- Partage des périodes récentes, records et étapes.

### Version Pro

- Historique détaillé complet, calendrier complet et vue annuelle.
- Tendances mensuelles/annuelles et historique par année.
- Toutes les palettes, tous les compteurs (dont Anneau) et tous les effets, avec sélection et relecture dans le paramétrage.
- Tous les widgets iPhone, widgets d’écran verrouillé et complications Apple Watch.
- Records agrégés semaine/mois/année et partage annuel.

Les fonctionnalités essentielles ne doivent pas être artificiellement dégradées pour inciter à l'achat. Les trophées et les données Santé sont conservés lors d’un retour à l’offre gratuite. Les deux formules payantes donnent les mêmes fonctionnalités Pro.

## 7.2. Tarification indicative

Deux formules pourront être testées :

- **Premium annuel : 14,99 €**
- **Premium à vie : 29,99 €**

Ces tarifs constituent des hypothèses initiales, à valider avant publication.

Les achats doivent être intégrés avec StoreKit 2 et proposer la restauration des droits.

Le prix effectivement affiché dans l'application doit provenir de l'App Store, avec sa devise et ses conditions applicables.

## 7.3. Publicités

Aucune publicité prévue.

Le positionnement premium doit privilégier une expérience sans interruption publicitaire.

---

# 8. Confidentialité et sécurité

## 8.1. Principes

Walkuno doit suivre une approche de confidentialité dès la conception.

- Aucun compte requis.
- Pas de collecte distante des données Santé.
- Pas de vente de données.
- Pas de publicité comportementale.
- Pas de partage de données de santé avec des régies publicitaires.
- Permissions limitées au strict nécessaire.
- Aucun enregistrement de pas artificiels dans Apple Santé.

## 8.2. Stockage

Les historiques complets restent dans Apple Santé.

Le stockage local de Walkuno doit être limité aux préférences, métadonnées, achats et caches nécessaires.

Les caches contenant des informations d'activité doivent bénéficier d'une protection adaptée.

Aucune synchronisation de données de santé personnelles vers iCloud n'est prévue.

## 8.3. Transparence

L'application doit disposer :

- D'une politique de confidentialité.
- D'une explication des données lues.
- D'un accès aux réglages d'autorisation.
- D'une explication du stockage local des préférences et du renouvellement des caches.
- D'informations claires sur les achats Premium.

## 8.4. Conformité

Le projet devra respecter les exigences applicables du RGPD, les règles de l'App Store et les dispositions relatives aux données Santé.

Walkuno doit rester une application de suivi d'activité et de bien-être, sans prétention de diagnostic médical.

---

# 9. Internationalisation et accessibilité

## 9.1. Langues

Langues de lancement :

- Français.
- Anglais.

Les textes devront être externalisés pour faciliter l'ajout ultérieur d'autres langues.

## 9.2. Unités

- Kilomètres.
- Miles.
- Calories en kcal, lorsque disponibles.
- Formats de date et nombres adaptés au pays.

## 9.3. Accessibilité

- VoiceOver.
- Dynamic Type pour les textes compatibles.
- Contrastes suffisants.
- Réduction des animations.
- Commandes accessibles sans dépendance à la couleur.
- Zones tactiles adaptées.

Les graphiques doivent proposer une alternative textuelle permettant de comprendre les valeurs essentielles.

---

# 10. Exigences non fonctionnelles

| Domaine | Exigence cible |
|---|---|
| Démarrage | Compteur visible rapidement, avec cache si nécessaire |
| Fluidité | Objectif 60 FPS sur appareils compatibles |
| Fonctionnement hors ligne | Obligatoire pour les fonctions principales |
| Dépendance serveur | Aucune pour le suivi des pas |
| Batterie | Impact faible, sans interrogation excessive de HealthKit |
| Fiabilité des mesures | Cohérence avec les statistiques Apple Santé |
| Résilience | Gestion des permissions, données manquantes et interruptions |
| Sécurité | Stockage minimal et protection des caches |
| Compatibilité | iPhone sans Apple Watch pris en charge |
| Maintenance | Architecture modulaire et tests automatisés |

Les objectifs de performance devront être mesurés sur des appareils physiques représentatifs.

---

# 11. Organisation du développement

## Phase 1 — Fondations

- Initialisation du projet Xcode.
- Architecture des composants.
- Intégration HealthKit.
- Gestion des autorisations.
- Récupération du nombre de pas.
- Gestion des objectifs.
- Stockage des préférences.

**Livrable :** podomètre fonctionnel.

## Phase 2 — Interface premium

- Design du tableau de bord.
- Animations.
- Thèmes.
- Gestion des états vides.
- Navigation.
- Adaptation aux différentes tailles d'iPhone.

**Livrable :** application iPhone visuellement aboutie.

## Phase 3 — Statistiques et widgets

- Graphiques journaliers.
- Comparaisons hebdomadaires et mensuelles.
- Calendrier thermique.
- Records.
- Widgets iOS.
- Cartes de partage.

**Livrable :** première version complète du produit iPhone.

## Phase 4 — Monétisation et qualité

- Intégration StoreKit 2.
- Version Premium.
- Traduction anglais/français.
- Accessibilité.
- Tests fonctionnels.
- Tests sur appareils physiques.
- Préparation App Store et TestFlight.

**Livrable :** version candidate à la publication.

## Phase 5 — Apple Watch

- Application watchOS.
- Compteur et objectifs.
- Complications.
- Synchronisation.
- Optimisation et tests.

Cette phase peut être menée en parallèle des phases finales ou publiée en V1.1.

---

# 12. Fonctionnalités hors périmètre de la V1

Les fonctionnalités suivantes sont volontairement reportées :

- Comptes utilisateurs.
- Classements entre amis.
- Défis communautaires.
- Synchronisation avec des serveurs Orbelio.
- Coaching par intelligence artificielle.
- Cartographie GPS permanente.
- Reconnaissance automatique d'itinéraires.
- Intégration Android.
- Challenges sponsorisés.
- Bilan annuel animé façon « Wrapped ».

Ces fonctionnalités pourront être étudiées après validation de l'intérêt des utilisateurs.

---

# 13. Critères de recette

La V1 iPhone sera considérée comme fonctionnellement prête lorsque les critères suivants auront été validés.

### Données

- Le nombre de pas quotidien est cohérent avec Apple Santé pour une même période et les mêmes données accessibles.
- L'usage simultané d'un iPhone et d'une Apple Watch n'entraîne pas de double comptage.
- Les historiques sont correctement calculés.
- Les modifications rétroactives des données sont prises en compte.
- Les changements de date et de fuseau horaire sont gérés.

### Interface

- Le compteur apparaît dès l'ouverture, avec un état de chargement ou une donnée mise en cache si nécessaire.
- Les transitions restent fluides.
- Les graphiques sont lisibles.
- Les thèmes sont cohérents.
- L'interface fonctionne dans les tailles d'écran prises en charge.

### Fonctionnalités

- L'objectif quotidien est personnalisable.
- Les statistiques sont consultables.
- Les widgets affichent une information datée et cohérente avec le dernier état connu.
- Les achats Premium et leur restauration fonctionnent.
- Les fonctionnalités gratuites restent accessibles sans paiement.

### Confidentialité

- L'application ne transmet aucune donnée Santé à un serveur.
- Les autorisations sont demandées explicitement.
- L'absence de données ou d'autorisation est gérée sans crash.
- La politique de confidentialité est accessible.

### Robustesse

- L'application fonctionne sans connexion Internet.
- L'absence d'Apple Watch ne génère aucune erreur.
- Les données manquantes sont correctement représentées.
- Aucun blocage critique ou crash reproductible n'est présent dans les parcours principaux.

---

# 14. Planning indicatif

Pour un développement assisté par Codex, avec une personne assurant conception, tests et validation :

| Phase | Durée indicative |
|---|---|
| Fondations et HealthKit | 3 à 5 jours |
| Interface et animations | 5 à 10 jours |
| Statistiques et widgets | 5 à 10 jours |
| Achats, tests et publication | 5 à 8 jours |
| Application Apple Watch | 5 à 10 jours supplémentaires |

Ces durées sont des estimations de travail et non des engagements.

Une première version iPhone aboutie pourrait être envisagée en **4 à 6 semaines**, puis une extension Apple Watch en fonction des priorités et des résultats des tests.

---

# 15. Évolutions envisagées

## V1.1 — Écosystème Apple

- Apple Watch complète.
- Complications supplémentaires.
- Nouveaux widgets.
- Optimisation des animations.

## V1.2 — Motivation intelligente

- Suggestions d'objectifs.
- Notifications locales optionnelles.
- Bilans hebdomadaires automatiques.
- Nouveaux badges et récompenses.

## V2 — Expérience enrichie

- Défis entre amis.
- Classements privés.
- Comparaisons sociales volontaires.
- Nouveaux thèmes graphiques.
- Bilans annuels animés.
- Statistiques et tendances plus avancées.

Toute fonctionnalité sociale devra faire l'objet d'une étude spécifique concernant les comptes, la confidentialité et les coûts d'hébergement.

---

# 16. Indicateurs de succès

Les premiers indicateurs à suivre seront :

- Nombre de téléchargements.
- Utilisateurs actifs quotidiens et mensuels.
- Taux de retour à J+7 et J+30.
- Proportion d'utilisateurs conservant un widget.
- Taux de conversion Premium.
- Revenus nets après commissions et frais.
- Notes et avis App Store.
- Taux de crash et problèmes de synchronisation.

Les mesures de fréquentation devront privilégier des statistiques agrégées et respectueuses de la vie privée, sans exploiter les données Santé pour du profilage marketing.

---

# 17. Livrables attendus

Le développement devra produire :

1. Le projet Xcode complet.
2. Le code source Swift structuré et documenté.
3. L'application iOS fonctionnelle.
4. Les extensions de widgets.
5. L'application watchOS, lors de sa livraison.
6. Les ressources graphiques et thèmes.
7. Les tests automatisés essentiels.
8. Les fichiers de traduction français/anglais.
9. Une politique de confidentialité.
10. Les visuels et textes nécessaires à l'App Store.
11. Une documentation technique et de compilation.
12. Les instructions de publication et de mise à jour.

---

# 18. Principes directeurs du projet

**Walkuno doit être simple à comprendre, agréable à consulter et suffisamment beau pour donner envie d'être installé même par des utilisateurs qui possèdent déjà un compteur de pas.**

Les décisions de développement devront respecter les priorités suivantes :

1. Fiabilité des données.
2. Qualité de l'interface.
3. Fluidité de l'expérience.
4. Simplicité d'utilisation.
5. Respect de la vie privée.
6. Personnalisation.
7. Richesse fonctionnelle.

La multiplication des fonctionnalités ne doit jamais être réalisée au détriment du design, des performances ou de la simplicité.

**Ambition finale : faire de Walkuno une référence du podomètre élégant sur iPhone et Apple Watch.**

*Document de cadrage initial — Orbelio — Walkuno — Version 1.0*