# Compte rendu — TP Pipeline DevSecOps (Master TRC)
Étapes validées : 10/10

## Étape 1 — Préparer son poste
- [x] node -v affiche v22.x
- [x] docker run hello-world fonctionne sans sudo
- [x] Les 7 images sont téléchargées (docker images)
- [x] La base Trivy est téléchargée

## Étape 2 — Mise en place
- [x] npm test affiche 3 tests réussis
- [x] package-lock.json est commité
- [x] Le dépôt tp-notes est visible sur github.com

**Q.** Pourquoi faut-il commiter package-lock.json, et pourquoi utilisera-t-on npm ci plutôt que npm install dans le pipeline ?
On commite package-lock.json pour figer les versions exactes (et leurs hashs) de toutes les dépendances, afin que le build soit reproductible et que les scanners analysent exactement ce qui sera déployé. Dans le pipeline on utilise npm ci car il installe strictement ce qui est dans le lock et échoue en cas d’écart, alors que npm install peut modifier les versions.

## Étape 3 — CI de base
- Durée du job build-test (secondes) : 8 
- [x] Le pipeline passe au vert sur main
- [x] La pull request test-rouge est bloquée (pipeline rouge)
- [x] La pull request est fermée sans merge, branche supprimée

**Q.** Quelle est la différence entre ce que vous venez de faire (Continuous Integration) et le Continuous Delivery ? Que manque-t-il au pipeline pour en faire du Continuous Delivery ?
La CI automatise le build et les tests à chaque push pour détecter tôt les erreurs et protéger main. La CD va plus loin : à chaque version validée, le pipeline produit un artefact livrable (image Docker publiée dans un registre) et le déploie automatiquement vers un environnement de test, la mise en production restant une décision manuelle. Il manque à mon pipeline le packaging (image Docker) et le déploiement vers un environnement.

## Étape 4 — Conteneur
- Taille de l'image naïve (Mo) : 1140 Mo (1.14GB)
- Trivy : HIGH + CRITICAL (naïve) : 720 (709 Debian + 11 npm)
- Checkov : contrôles échoués (naïve) : 2 (23 passés)
- Utilisateur affiché par whoami (naïve) : ROOT

**Q.** Repérez trois défauts de la version naïve. Pour chacun, dites quel risque il crée.
Trois défauts de la version naïve :

Image de base trop volumineuse (node:22, Debian complète). Elle pèse 1,14 Go et Trivy y détecte 720 vulnérabilités HIGH/CRITICAL, dont 709 viennent des paquets système. Risque : une surface d’attaque très large, car l’image embarque de nombreux paquets inutiles à l’application, chacun pouvant contenir une faille exploitable.
Le conteneur s’exécute en root. Aucune instruction USER n’est définie (Checkov : CKV_DOCKER_3) et whoami renvoie root. Risque : si l’application est compromise, l’attaquant dispose de tous les privilèges dans le conteneur, ce qui facilite l’évasion vers l’hôte ou l’accès aux ressources montées.
Aucun HEALTHCHECK. (Checkov : CKV_DOCKER_2). Risque : si l’application plante ou se bloque, Docker ne le détecte pas, le conteneur reste « en cours d’exécution » alors que le service est indisponible, et aucune supervision ne peut le redémarrer automatiquement.
- Taille de l'image durcie (Mo) : 170 MB.
- Trivy : HIGH + CRITICAL (durcie) : Total: 11 (HIGH: 11, CRITICAL: 0)
- Checkov : contrôles échoués (durcie) : Passed checks: 31, Failed checks: 0, Skipped checks: 0
- Utilisateur affiché par whoami (durcie) : node
- [x] L'image durcie démarre et /health répond
- [x] L'état de santé Docker passe à healthy
- [x] Dockerfile et .dockerignore durcis sont commités

**Q.** Une image avec 0 vulnérabilité HIGH/CRITICAL aujourd'hui le sera-t-elle encore dans un mois ? Que faut-il prévoir ?
Non, une image avec 0 vulnérabilité HIGH/CRITICAL aujourd’hui ne le sera pas forcément encore dans un mois.la sécurité d’une image Docker n’est pas définitive. Elle nécessite une surveillance continue, des mises à jour régulières et des scans périodiques.

## Étape 5 — Dépendances & SBOM
- Dépendances directes : express@4.22.3
- Paquets dans l'arbre complet : 128
- npm audit : vulnérabilités trouvées : found 0 vulnerabilities
- Composants dans sbom-src : 69
- Composants dans sbom-image : 285
- [x] Les deux SBOM sont générés (et ignorés par Git)
- [x] dependabot.yml est commité et les alertes sont activées

**Q.** Vous n'avez déclaré qu'une dépendance. Pourquoi l'arbre en contient-il autant ? Et pourquoi le SBOM de l'image est-il plus gros que celui du code source ?
Même si Express est la seule dépendance directe, il utilise d’autres bibliothèques appelées dépendances transitives, ce qui explique les 128 paquets.

Le SBOM de l’image est plus grand (285 composants contre 69 pour le code source), car il inclut aussi les composants système de l’image Alpine, comme musl et busybox

## Étape 6 — Secrets
- Gitleaks : fuites trouvées sur le dépôt : 0
- Gitleaks : fuites trouvées avec demo.env : 1
- Nom de la règle déclenchée : (RuleID) : github-pat
- [x] Le commit contenant demo.env a été refusé par le hook
- [x] demo.env est supprimé, rien n'a été poussé

**Q.** Le hook pre-commit est sur votre poste. Pourquoi faut-il quand même un scan de secrets dans le pipeline CI ? Et si un vrai secret avait été poussé, quelle serait la première action ?
Le hook pre-commit fonctionne uniquement sur mon poste et peut être absent ou contourné. Le scan dans le pipeline CI ajoute une protection supplémentaire pour détecter les secrets avant le déploiement.

Si un vrai secret est poussé sur GitHub, la première action est de le révoquer immédiatement, puis de le remplacer par un nouveau. Supprimer le fichier ne suffit pas, car le secret peut rester dans l’historique Git.

## Étape 7 — SAST
- Nombre de règles exécutées : 75
- Alertes (findings) : 0
- Alertes avec le Dockerfile naïf : 1

**Q.** Semgrep ne trouve rien (ou presque) sur votre code. Cela prouve-t-il que l'application est sûre ? Citez deux limites du SAST.
Non, l’absence d’alertes ne prouve pas que l’application est sûre.
1. Le SAST peut manquer certaines vulnérabilités si aucune règle ne les détecte.
2. Il analyse le code sans l’exécuter et peut donc manquer des problèmes qui apparaissent uniquement à l’exécution.

## Étape 8 — Pipeline & portes
- Durée totale du pipeline (minutes) : 1 MIN 42 S
- Job le plus long : IMAGE 36S
- Porte 1 : jobs en échec : failing checks - DevSecOps / image (pull_request)DevSecOps / image (pull_request)   Failing after 11s - DevSecOps / image (push)DevSecOps / image (push)
- Porte 2 : jobs en échec : DevSecOps / iac (pull_request) DevSecOps / iac (pull_request)Failing after 21s DevSecOps / iac (push) DevSecOps / iac (push)Failing after 26s DevSecOps / sast (pull_request) DevSecOps / sast (pull_request)Failing after 20s DevSecOps / sast (push) DevSecOps / sast (push)Failing after 24s
- [x] Le pipeline complet est vert sur main
- [x] Les deux pull requests de test sont bloquées
- [x] Les branches de test sont fermées sans merge
- [x] Le SBOM est téléchargeable dans les artefacts

**Q.** Le pipeline utilise des images aquasec/trivy:latest, semgrep/semgrep, etc. sans version fixée. Quel risque cela crée-t-il pour la chaîne d'approvisionnement, et comment le réduire ?
L’utilisation de latest sans version fixe crée un risque : l’image peut changer, contenir des vulnérabilités ou être compromise.

Solutions : fixer les versions ou les digests SHA-256, mettre à jour régulièrement les images, scanner les vulnérabilités et protéger les secrets du pipeline.

**Q.** Le job Trivy utilise --ignore-unfixed et ne bloque que HIGH et CRITICAL. Justifiez ces deux choix, et dites ce qu'ils laissent passer.
- --ignore-unfixed : ignore les vulnérabilités qui n’ont pas encore de correctif disponible, pour éviter de bloquer inutilement le pipeline. Cela laisse passer ces vulnérabilités, même si elles sont graves.
- HIGH et CRITICAL uniquement : bloque les vulnérabilités les plus sévères tout en limitant les faux blocages. Cela laisse passer les vulnérabilités LOW et MEDIUM.
Limite : des vulnérabilités ignorées peuvent toujours représenter un risque pour l’application.

## Étape 9 — Tri d'alertes
- Alerte 1 : Vrai positif · Bloquer la livraison maintenant (juste)
- Alerte 2 : Faux positif · Accepter et documenter l'exception (juste)
- Alerte 3 : Vrai positif · Backlog / surveiller (juste)
- Alerte 4 : Faux positif · Accepter et documenter l'exception (juste)
- Alerte 5 : Vrai positif · Corriger sous quelques jours (faux)
- Alerte 6 : Vrai positif · Corriger sous quelques jours (juste)
- Alerte 7 : Vrai positif · Backlog / surveiller (juste)
Score : 6/7

**Q.** Pour l'alerte que vous avez trouvée la plus difficile à classer, expliquez votre raisonnement.
L’alerte 7 est difficile à classer : même si la CVE est de sévérité haute, aucun correctif n’est disponible et l’API n’utilise pas les commandes système de BusyBox. Je la place donc en backlog avec surveillance, tout en évaluant l’exposition réelle et les possibilités de réduction du risque.

## Bilan

**Q.** Placez chaque contrôle que vous avez mis en place sur la boucle Plan › Code › Build › Test › Release › Deploy › Operate › Monitor. Quelles étapes de la boucle restent sans contrôle dans votre pipeline ?
PLAN , test,Deploy, Operate et Monitor

**Q.** Si vous deviez ajouter un seul contrôle de plus à ce pipeline, lequel choisiriez-vous et pourquoi ?
J’ajouterais un scan DAST (Dynamic Application Security Testing) pour tester l’application en cours d’exécution et détecter des vulnérabilités exploitables, comme les failles d’authentification ou les injections. Cela compléterait le SAST, qui analyse le code source, et renforcerait la sécurité avant le déploiement.

