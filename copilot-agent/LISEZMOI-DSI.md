# Agent Microsoft 365 Copilot « Biblio-Tech » — déploiement

Agent déclaratif Microsoft 365 Copilot qui répond aux demandes en langage courant à partir
des pages Confluence Biblio-Tech (`https://confluence.apps.eul.sncf.fr`), avec les droits
de l'utilisateur connecté (SSO Microsoft 365).

## Qui peut l'utiliser ?

| Profil de l'utilisateur | Accès à l'agent | Coût |
|---|---|---|
| Licence **Microsoft 365 Copilot** | Oui, dès la publication | Inclus dans la licence |
| **Copilot Chat** (gratuit), facturation à l'usage **activée** par l'admin | Oui | Facturé à l'usage (messages Copilot Studio, environ 0,01 $ par message) |
| **Copilot Chat** (gratuit), facturation à l'usage **non activée** | Non : l'agent lit des données internes (connecteur) | — |

Les utilisateurs sans accès à l'agent utilisent l'**assistant local du widget Biblio-Tech**
(compréhension du langage courant, synonymes, élargissement automatique), sans IA externe et
sans coût. Dans le widget, un utilisateur licencié coche **… > J'ai une licence Microsoft
365 Copilot** pour voir le bouton **Demander à Copilot**.

## Étapes

### 1. Confluence (admin Confluence)
Suivre [Set up the Confluence On-premises service for connector ingestion](https://learn.microsoft.com/microsoft-365/copilot/connectors/confluence-onpremises-admin-setup) :
- Confluence Data Center **8.0 ou plus**, plugin « Confluence On-prem » de l'Atlassian Marketplace installé ;
- compte de service en lecture, **User Email Visibility = public** (pour faire correspondre les comptes Entra ID) ;
- ajouter des **descriptions** aux espaces et aux pages clés (Copilot s'en sert pour choisir les bonnes fiches).

### 2. Connecteur Copilot (admin Microsoft 365)
1. Installer le **Microsoft Graph connector agent** sur un serveur Windows du réseau SNCF qui accède à Confluence.
2. Centre d'admin Microsoft 365 > **Copilot > Connecteurs > Galerie > Confluence On-premises**.
   - Nom affiché : `Biblio-Tech` ; URL de l'instance : `https://confluence.apps.eul.sncf.fr` ;
   - authentification : OAuth 2.0 (ou OAuth 1.0a / Basic pour Confluence 10+) ;
   - **conserver les permissions Confluence** (chaque utilisateur ne voit que ses pages).
3. Une fois l'indexation terminée, relever l'**identifiant de connexion** (champ *Connection ID*, par ex. `bibliotech`).

Référence : [Deploy the Confluence On-premises Copilot connector](https://learn.microsoft.com/microsoft-365/copilot/connectors/confluence-onpremises-deployment).

### 3. Construire le paquet de l'agent
```powershell
powershell -ExecutionPolicy Bypass -File copilot-agent\build-agent.ps1 -ConnectionId bibliotech -Version 1.0.0
```
Le script génère `copilot-agent\build\BiblioTech-Copilot-Agent.zip`. Il contient le manifeste
(schéma Teams 1.24), l'agent déclaratif (schéma 1.8), les instructions et les icônes. Les deux
manifestes ont été validés contre les schémas JSON officiels de Microsoft.

### 4. Publier
- Centre d'admin **Teams** > Applications Teams > **Gérer les applications** > **Charger une
  nouvelle application**, puis l'autoriser pour les utilisateurs ou les groupes souhaités ;
- ou centre d'admin Microsoft 365 > **Agents** (catalogue d'agents de l'organisation).

### 5. Ouvrir l'agent pour les utilisateurs sans licence (optionnel)
Centre d'admin Microsoft 365 > **Facturation à l'usage** : créer une stratégie de facturation (abonnement
Azure), la relier à **Microsoft Copilot Chat**, puis cibler les utilisateurs concernés.
Voir [Using agents in Microsoft Copilot Chat](https://learn.microsoft.com/copilot/agents).

### 6. Relier le widget à l'agent
Copier le lien de l'agent publié (Copilot > agent Biblio-Tech > **Partager / copier le lien**)
dans `BiblioTech-Widget-PS\config.ps1` :
```powershell
CopilotAgentUrl = 'https://m365.cloud.microsoft/chat/?titleId=T_...'
```
puis publier une nouvelle version du widget (`build-release.ps1`).

## Modifier le comportement de l'agent
- Ton, format de réponse, règles : `appPackage\instructions.txt` (8 000 caractères au plus).
- Suggestions affichées à l'ouverture : `conversation_starters` dans `appPackage\declarativeAgent.json` (12 au plus).
- Après modification : relancer `build-agent.ps1` en incrémentant `-Version`, puis recharger le paquet.

## Sécurité
- Aucun secret dans le paquet : l'accès à Confluence passe par le connecteur, configuré dans le tenant.
- Le contenu indexé est stocké dans le tenant Microsoft 365 SNCF. Cette indexation est à valider par le RSSI.
- `discourage_model_knowledge` est activé : l'agent répond à partir des fiches, pas de ses connaissances générales.
