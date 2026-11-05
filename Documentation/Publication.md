# Compilation, livraison et mises à jour

## Configuration Apple Developer

Ouvrir le projet et choisir l’équipe de signature dans Walkuno, WalkunoWidgets, WalkunoWatch, WalkunoWatchWidgets. Les identifiants provisoires sont `fr.orbelio.walkuno`, `fr.orbelio.walkuno.widgets`, `fr.orbelio.walkuno.watchkitapp` et `fr.orbelio.walkuno.watchkitapp.widgets`.

Si ces identifiants changent, mettre à jour les build settings, les plists (dont `WKCompanionAppBundleIdentifier`), App Groups, URL scheme si souhaité, le générateur de projet et les identifiants StoreKit du code/configuration. Le groupe `group.fr.orbelio.walkuno` doit être configuré pour les quatre produits ; la communication entre appareils utilise WatchConnectivity, pas le conteneur App Group.

Activer HealthKit et sa livraison en arrière-plan pour les deux applications. Aucun droit d’écriture Santé n’est demandé. Activer Data Protection et App Groups pour chaque produit. La permission Santé est traduite en français, anglais, allemand, espagnol, italien, portugais et japonais dans `InfoPlist.strings`. La langue de développement des quatre bundles est l’anglais, utilisé si aucune langue préférée n’est prise en charge. Renseigner les titres et descriptions des deux produits Premium dans ces sept langues dans App Store Connect ; les traductions du fichier StoreKit local servent uniquement aux essais.

## Achats

Créer un groupe d’abonnements Premium. Ajouter :

- abonnement annuel `fr.orbelio.walkuno.premium.annual` ;
- achat non consommable `fr.orbelio.walkuno.premium.lifetime`.

Les prix 14,99 € et 29,99 € du cahier des charges ne sont que les prix de la configuration de test locale. Configurer les prix, traductions et disponibilité dans App Store Connect. L’application affiche les prix réellement renvoyés par Apple. Tester achat, annulation, attente d’approbation, remboursement, expiration et restauration avec StoreKit Testing, puis Sandbox.

`Config/Walkuno.storekit` s’active manuellement dans les options du schéma Run. Le schéma partagé n’active pas cette simulation par défaut.

## Archive et TestFlight

1. Exécuter les tests et la recette physique ; vérifier également le schéma WalkunoWatch.
2. Contrôler les capacités et le manifeste de confidentialité. Le seul Required Reason API déclaré concerne UserDefaults privé (`CA92.1`). Aucun SDK tiers n’est embarqué.
3. Mettre à jour version et numéro de build. Désactiver tout argument de démonstration ; de toute façon `--demo` n’est interprété qu’en Debug.
4. Choisir un appareil iOS générique, configuration Release, Product → Archive.
5. Valider l’archive, examiner les erreurs de capacités et uploader après décision explicite de l’éditeur.
6. Renseigner fiche, captures, support, confidentialité publique, classification, informations de revue et achats.
7. Tester TestFlight sur iPhone seul, puis iPhone/Watch, avec les widgets réellement installés.

Les données de santé ne sont pas collectées à distance par cette version. Les déclarations de confidentialité doivent rester alignées avec les flux effectifs lors de tout ajout futur de télémétrie. Faire valider les obligations applicables à Orbelio avant publication.

## Installation locale sur iPhone et Watch

Avec le compte Apple connecté dans Xcode et les appareils appairés, déverrouillés et en mode développeur :

```sh
xcrun devicectl list devices
python3 Scripts/install_devices.py --iphone UDID_IPHONE --watch UDID_WATCH
```

Le script utilise l’équipe préconfigurée, crée les profils via Xcode, vérifie la signature et installe les bundles sur les appareils choisis. Aucun argument de démonstration n’est transmis. Les demandes d’accès Santé restent à valider par l’utilisateur sur ses appareils. Un autre compte peut être choisi avec `--team IDENTIFIANT_EQUIPE`.

## Mise à jour

Conserver les clés `walkuno.preferences.v1` et le format `activity-v1.json`, ou fournir une migration. Les historiques de santé ne sont pas migrés : ils restent dans Santé. Un changement de groupe ou de bundle ID est une rupture d’accès au conteneur et aux droits ; le traiter comme une décision de livraison. Ne pas placer les caches Santé dans une sauvegarde ou un service distant lors d’une future évolution.

## Textes intégrés aux réglages

Les réglages regroupent désormais l’espace local, la formule et les achats. La politique de confidentialité et les conditions générales d’utilisation sont les deux dernières entrées ; elles sont disponibles hors ligne dans les sept langues. Les CGU abordent l’usage personnel, le bien-être, les achats Apple, la propriété intellectuelle de Walkuno et Orbelio, le partage des cartes et le maintien des droits légaux. Elles renvoient au [contrat de licence standard Apple](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/).

La politique décrit le traitement réellement implémenté : accès Santé en lecture seule, calculs locaux, cache des widgets, échanges de préférences avec la Watch, achats StoreKit, partage explicite et effacement. Référence de rédaction : [recommandation de la CNIL sur les applications mobiles, version modifiée en 2025](https://cnil.fr/sites/default/files/2025-04/recommandation-applications-mobiles-modifiee.pdf). Le lien d’assistance de la fiche App Store sert de point de contact dans les textes ; renseigner ce lien, les coordonnées de l’éditeur et l’URL publique de confidentialité avant la soumission, comme indiqué plus haut.

Les nouvelles préférences activent les animations de changement de période et placent la transparence du Liquid Glass à 70 %. Les valeurs déjà enregistrées sont conservées ; les fichiers anciens dépourvus de ces clés utilisent les nouvelles valeurs initiales.
