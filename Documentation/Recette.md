# Recette et limites

Cette version est un point de départ natif exécutable, pas une certification de tous les critères de la V1.

## Automatisé

`Tests/WalkunoCoreTests` : huit tests Foundation sur absence/zéro, moyenne, historique des objectifs, conflits Watch, séries, changement d’heure, cache jour/fuseau et jours futurs.

`Tests/WalkunoUITests` : quatre tests couvrant navigation, ouverture/fermeture de Premium, retour au compteur, édition d’objectif, politique de confidentialité, partage, accueil sans autoriser Santé et effacement local. Les parcours remplis utilisent uniquement les données synthétiques de `--demo`, sans écriture dans Santé ou le cache partagé. Le parcours d’accueil est testé hors mode démonstration. Les captures sont jointes au résultat Xcode.

## À vérifier sur iPhone et Watch physiques

| Cas | Résultat attendu |
| --- | --- |
| iPhone seul | Compteur et historique sans erreur Watch |
| iPhone + Watch | Totaux cohérents avec Santé pour une même plage et les mêmes sources |
| Pas autorisés, distance/énergie absentes | Pas visibles ; métriques absentes affichées par un tiret |
| Aucun accès ou aucune mesure | Explication neutre, aucune affirmation de refus |
| Verrouillage / déverrouillage | Pas de perte de cache ; erreur d’accès temporaire compréhensible |
| Correction d’une journée ancienne dans Santé | Prise en compte au prochain retour au premier plan |
| Minuit, DST, voyage | Nouveau compteur et nouvelle clé de cache, pas de valeur de la veille |
| Objectif modifié | Objectifs antérieurs inchangés |
| Watch hors ligne puis reconnectée | Objectif fusionné et mêmes paramètres |
| Effacement pendant une requête | Aucun retour tardif des anciennes données |
| Widgets et complications | Valeur datée, protection au verrouillage, invalidation après minuit |
| Complications circulaires | Distance et étages sans anneau ; pas et distance + pas abrégés dès 10 000 (`10.1K`), nombres complets avec VoiceOver, vérifier aussi 100 000 pas et les grands pourcentages |
| Progression à la même heure | À 14 h 37, comparer aux mesures d’hier jusqu’à 14 h 37, y compris lors du changement d’heure ; référence nulle/absente = « — » |
| Complication centrale et grands widgets | Seulement Pas par heure, Suivi de l’objectif et Semaine dans les choix du nouveau widget ; remplacer les anciennes grandes complications |
| Pas par heure | 24 heures glissantes, veille grise et aujourd’hui dans le thème, heure courante partielle incluse ; pas, distance et pourcentage du jour en pied, sans total sur 24 heures |
| Suivi de l’objectif | Axe de 0 à 24 h, cumul actuel et référence habituelle en pointillés ; deux totaux complets, moyenne des dernières journées observées à la même heure et absence distincte du zéro |
| Widget semaine | Sept jours glissants, aujourd’hui mis en évidence, maximum abrégé dans sa barre ; totaux du jour et de la semaine sous le graphique, aucun pourcentage, jours absents distincts du zéro |
| Achat annuel, à vie, restauration | Droits issus d’une transaction vérifiée |
| Expiration, remboursement, Ask to Buy, achat annulé | Réévaluation des droits sans bloquer le compteur |
| Sans réseau | Compteur Santé, préférences et cache utilisables ; état d’achat StoreKit géré |
| Accessibilité | VoiceOver, tailles de texte maximales, Réduire les animations, contraste |
| Performance | Lancement, longues années d’historique, fluidité, consommation et Energy Log |

Utiliser un jeu de données connu et comparer les **mêmes intervalles calendaires** dans Santé. La disponibilité de l’historique et la synchronisation Watch relèvent du système. Les animations à 60 FPS et l’impact batterie doivent être mesurés, pas déduits d’un passage sur simulateur.

## Finitions à prévoir avant publication

- Recette matérielle et StoreKit Sandbox/TestFlight ; pas d’achat réel effectué dans ce développement.
- Choisir les identifiants Orbelio, l’équipe de signature et les produits App Store Connect.
- Publier une politique de confidentialité avec les coordonnées effectives de l’éditeur, son URL publique et un canal d’exercice des droits. La politique intégrée décrit les flux du code mais ne vaut pas validation juridique.
- Ajouter des captures finales sur les tailles App Store requises, sans bandeau de démonstration et avec des données fictives clairement présentées pour la fiche.
- Raffiner les visuels de récompenses, les variantes de cartes et les animations de célébration après tests utilisateurs. Les badges actuels sont vectoriels, sans illustrations externes.
- Valider la stratégie freemium : historique gratuit de 31 jours, toutes les variantes de widgets incluses, autres palettes et compteur minimaliste Premium.
- La montre présente sept jours récents. Pas de notifications, compte, collecte de fréquentation ou serveur.
- Le nombre d’étages est optionnel dans le cahier des charges et n’est pas demandé par cette version.
- L’historique au-delà de la portée autorisée par Apple ne peut pas être reconstitué. Les records indiquent leur périmètre accessible.

Ne pas considérer les préparatifs de publication comme une autorisation de téléverser ou publier : aucune opération App Store distante n’a été effectuée.
