# Post-Install Debian Script

> ⚡ **Script Bash pour configurer un serveur Debian après installation**

---

## 📋 **Fonctionnalités**

✅ **Mise à jour du système** (`apt update`, `dist-upgrade`, `autoremove`)
✅ **Création d'un utilisateur** avec droits `sudo`
✅ **Configuration SSH** :
   - Changement du port SSH (par défaut : **2222**)
   - Copie des clés `authorized_keys` depuis `/root/.ssh/`
   - Sauvegarde automatique de `sshd_config`
✅ **Personnalisation du `.bashrc`** (aliases `ls`, `ll`, `l` avec couleurs)
✅ **Configuration du fuseau horaire** (par défaut : **Europe/Paris**)
✅ **Configuration des locales** (par défaut : **fr_FR.UTF-8**)

---

## 🚀 **Utilisation**

### ➡️ **Exécution basique (valeurs par défaut)**
```bash
sudo ./postinstall.sh
```

### ➡️ **Personnalisation avec arguments**
```bash
# Exemple : utilisateur "alice", port SSH 2222, fuseau horaire New York
sudo ./postinstall.sh \
    --user alice \
    --port 2222 \
    --timezone America/New_York \
    --locale en_US.UTF-8
```

### ➡️ **Mode simulation (pour tester sans risque)**
```bash
sudo ./postinstall.sh --dry-run --user test
```
→ Affiche toutes les actions **sans les exécuter** (idéal pour vérifier avant de lancer en production).

### ➡️ **Ignorer le redémarrage**
```bash
sudo ./postinstall.sh --skip-reboot
```

### ➡️ **Affiche l'aide complète**
```bash
./postinstall.sh --help
```

---

## 🔧 **Options disponibles**

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `-u, --user` | Nom de l'utilisateur à créer | `ldfa` |
| `-p, --port` | Port SSH | `50822` |
| `-t, --timezone` | Fuseau horaire (ex: `Europe/Paris`) | `Europe/Paris` |
| `-l, --locale` | Locale (ex: `fr_FR.UTF-8`) | `fr_FR.UTF-8` |
| `-n, --dry-run` | Mode simulation (aucune modification) | `false` |
| `-s, --skip-reboot` | Ignore la demande de redémarrage | `false` |
| `-h, --help` | Affiche l'aide | - |

---

## ⚠️ **Avertissements importants**

### ❗ **Ne pas exécuter en SSH si tu changes le port**
- Si tu es connecté **en SSH** et que tu changes le port (`--port`), **tu risques de perdre l'accès** à ton serveur.
- **Solution** :
  - Exécute le script **en local** (console physique ou VNC).
  - **OU** commente les lignes de changement de port SSH dans le script.

### ❗ **Mot de passe par défaut**
- Le script définit un mot de passe **par défaut** : `ChangerCeMotDePasse` pour l'utilisateur créé.
- **⚠️ Change-le immédiatement après l'exécution** avec :
  ```bash
  sudo passwd ldfa  # Remplace "ldfa" par ton nom d'utilisateur
  ```

### ❗ **Droits root obligatoires**
- Le script **nécessite `sudo`** pour fonctionner (modification de fichiers système).

---

## 📁 **Installation**

1. **Télécharge le script** :
   ```bash
   git clone https://github.com/Ldfa07/Linux.git
   cd Linux
   ```

2. **Rends-le exécutable** :
   ```bash
   chmod +x postinstall.sh
   ```

3. **Exécute-le** (voir section [Utilisation](#-utilisation)) :
   ```bash
   sudo ./postinstall.sh
   ```

---

## 🔍 **Vérification avant exécution**

Pour vérifier que le script est **syntactiquement correct** :
```bash
# Installe shellcheck (si non présent)
sudo apt install shellcheck

# Vérifie le script
shellcheck postinstall.sh
```

---

## 📜 **Licence**

Ce projet est sous licence **MIT** – libre à utiliser, modifier et distribuer.

---

## 🤝 **Contribuer**

Les contributions sont les bienvenues !
Ouvre une **Issue** ou une **Pull Request** sur [GitHub](https://github.com/Ldfa07/Linux).

---

## 📞 **Support**

Si tu as des questions ou des problèmes, ouvre une **Issue** sur ce dépôt.
