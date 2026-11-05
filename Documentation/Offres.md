# Walkuno — offres Gratuite et Pro

Répartition retenue le 5 novembre 2026. La formule gratuite permet un suivi quotidien complet. Pro débloque l’historique détaillé ancien, les analyses longues, tous les widgets et la personnalisation supplémentaire. Abonnement annuel et achat à vie donnent les mêmes fonctionnalités Pro ; les tarifs restent à valider.

| Fonctionnalité | Gratuit | Pro |
| --- | --- | --- |
| Compteur, objectif libre et progression | Inclus | Inclus |
| Pas, distance, énergie active, exercice et étages | Toutes les mesures Santé disponibles | Identique |
| Santé en lecture seule et actualisation en arrière-plan | Inclus | Inclus |
| Courbe horaire, comparaison avec hier et activité habituelle | Inclus | Inclus |
| Historique détaillé, calendrier et vues jour/semaine/mois | 31 derniers jours, aujourd’hui compris | Tout l’historique Santé disponible |
| Vue annuelle et partage annuel | — | Inclus |
| Totaux, moyennes et graphiques récents | Inclus | Inclus |
| Tendance sur sept jours et comparaison avec les sept jours précédents | Incluse | Incluse |
| Tendances mensuelles et annuelles, historique par année | — | Inclus |
| Records quotidiens des cinq mesures | Tout l’historique disponible | Identique |
| Records agrégés semaine/mois/année | — | Inclus |
| Objectifs à 100/200/300 %, séries et périodes parfaites | Tous inclus | Identique |
| 22 traversées et multiplicateurs | Toutes incluses, cumul sans limite de 31 jours | Identique |
| Palettes | Walkuno | Les neuf palettes |
| Compteurs | Horizon et Anneau | Les cinq styles |
| Effets du compteur | Étoiles | Étoiles, Feu vivant, Aurore boréale et Onde liquide |
| Icône iPhone assortie à la palette | Walkuno | Variantes des palettes |
| Widgets iPhone Compteurs, Graphiques, Tableau de bord | — | Toutes les tailles |
| Widgets d’écran verrouillé | — | Toutes les présentations |
| Complications Apple Watch | — | Incluses |
| Application Apple Watch, objectif et sept jours récents | Incluse | Incluse |
| Synchronisation des objectifs et préférences | Incluse | Incluse |
| Partage journée/semaine/mois, record et étape | Inclus ; consultation des périodes limitée aux 31 jours | Tout l’historique disponible |
| Langues, unités, transparence, accessibilité et réduction des animations | Tous les réglages inclus | Identique |
| Confidentialité, absence de publicité et absence de compte | Incluses | Identiques |

## Présentation et changements de formule

- Le nom commercial est **Walkuno Pro** dans les sept langues. Les identifiants StoreKit existants restent inchangés pour conserver les achats.
- Les styles et effets payants sont prévisualisables sans remplacer la préférence enregistrée. Les cartes de palettes montrent leurs couleurs avant achat.
- Une fonction Pro sollicitée ouvre l’offre ou propose un bouton de déblocage ; le compteur gratuit reste utilisable.
- Les widgets restent présents dans la galerie système pour permettre leur découverte. Sans Pro, une fois ajoutés, ils affichent uniquement un verrou et la mention Walkuno Pro, sans mesure d’activité. Sur iPhone, le toucher ouvre l’offre ; sur Watch, le texte invite à ouvrir Walkuno sur l’iPhone.
- À l’expiration, le suivi détaillé revient aux 31 jours et l’apparence effective revient à Walkuno / Horizon / Étoiles si les choix enregistrés sont payants. Les préférences restent conservées pour une réactivation.
- Les trophées, records quotidiens et cumuls continuent d’utiliser l’historique disponible ; les données Santé ne sont jamais supprimées par un changement de formule.
- Les achats à vie et les abonnements actifs donnent les mêmes fonctionnalités.

## Droits des extensions

L’iPhone vérifie les transactions StoreKit et publie un miroir local des droits dans l’App Group, séparé du cache Santé. Le miroir de développement est séparé de celui de Release pour empêcher le mode Pro simulé de persister dans une version de production. Ce miroir conserve la date d’expiration et n’est jamais utilisé pour accorder des droits à PurchaseStore. Le droit est aussi transmis à la Watch via WatchConnectivity, sans mesure Santé. Un ancien contexte sans droit Pro ne débloque aucune complication.

Les extensions vérifient l’expiration à chaque timeline ; une entrée verrouillée est programmée à l’échéance lorsqu’elle précède minuit. Elles ne reçoivent aucune mesure dans leurs entrées gratuites. Achat, restauration et changement des droits demandent une actualisation des widgets, même sans autorisation Santé.

WidgetKit décide de la date effective des actualisations. Une révocation nécessite une nouvelle vérification StoreKit sur l’iPhone, puis la synchronisation de la Watch ; une montre déconnectée peut conserver le dernier droit connu jusqu’à son expiration ou sa prochaine synchronisation. Les essais StoreKit et cette propagation doivent être recettés sur appareils avant publication.
