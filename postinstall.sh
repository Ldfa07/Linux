#!/bin/bash
# Script de personnalisation Debian post-install
# Auteur: Ldfa
# Version: 3.0
# Usage: sudo ./postinstall.sh [OPTIONS]

set -euo pipefail  # Arrête le script en cas d'erreur

# --- Variables par défaut ---
NEW_USER="ldfa"
SSH_PORT="50822"
TIMEZONE="Europe/Paris"
LOCALE="fr_FR.UTF-8"
DRY_RUN=false
SKIP_REBOOT=false

# --- Couleurs pour les logs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info()   { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()  { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }
log_dryrun() { echo -e "${BLUE}[DRY-RUN]${NC} $1 (simulation)"; }

# --- Fonction d'aide ---
usage() {
    cat <<EOF
Usage: sudo ./$(basename "$0") [OPTIONS]

Options:
  -u, --user USERNAME       Nom de l'utilisateur à créer (défaut: $NEW_USER)
  -p, --port PORT           Port SSH (défaut: $SSH_PORT)
  -t, --timezone TIMEZONE   Fuseau horaire (défaut: $TIMEZONE)
  -l, --locale LOCALE       Locale (défaut: $LOCALE)
  -n, --dry-run             Mode simulation (aucune modification n'est appliquée)
  -s, --skip-reboot         Ignore la demande de redémarrage
  -h, --help                Affiche cette aide

Exemples:
  sudo ./$(basename "$0") --user alice --port 2222
  sudo ./$(basename "$0") --dry-run
  sudo ./$(basename "$0") --help
EOF
    exit 0
}

# --- Parsing des arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            NEW_USER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -t|--timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        -l|--locale)
            LOCALE="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-reboot)
            SKIP_REBOOT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Option inconnue: $1. Utilisez --help pour voir les options disponibles."
            ;;
    esac
done

# --- Affichage des paramètres (pour débogage) ---
log_info "=== Configuration ==="
log_info "Utilisateur: $NEW_USER"
log_info "Port SSH: $SSH_PORT"
log_info "Fuseau horaire: $TIMEZONE"
log_info "Locale: $LOCALE"
log_info "Mode dry-run: $DRY_RUN"
log_info "Ignorer redémarrage: $SKIP_REBOOT"
log_info "====================="

# --- Vérification des droits root ---
if [[ $EUID -ne 0 ]]; then
   log_error "Ce script doit être exécuté en tant que root. Utilisez 'sudo'."
fi

# --- Fonction pour exécuter une commande (avec gestion du dry-run) ---
run_cmd() {
    if $DRY_RUN; then
        log_dryrun "$*"
        return 0
    else
        "$@" || return $?
    fi
}

# --- 1. Mise à jour du système ---
log_info "Mise à jour du système..."
export DEBIAN_FRONTEND=noninteractive
run_cmd apt-get update -qq || log_error "Échec de 'apt update'"
run_cmd apt-get dist-upgrade -y -qq || log_error "Échec de 'apt dist-upgrade'"
run_cmd apt-get autoremove -y -qq || log_warn "Échec de 'apt autoremove' (non critique)"
run_cmd apt-get install -y -qq curl || log_error "Échec de l'installation de curl"

# --- 2. Création de l'utilisateur ---
if id "$NEW_USER" &>/dev/null; then
    log_warn "L'utilisateur $NEW_USER existe déjà. On passe."
else
    log_info "Création de l'utilisateur $NEW_USER..."
    run_cmd useradd -m -s /bin/bash -G sudo "$NEW_USER" || log_error "Échec de la création de l'utilisateur"
    echo "$NEW_USER:ChangerCeMotDePasse" | run_cmd chpasswd || log_error "Échec de la définition du mot de passe"
fi

# --- 3. Configuration SSH ---
log_info "Configuration SSH pour $NEW_USER..."
SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="/root/.ssh/authorized_keys"

# Créer le répertoire .ssh avec les bonnes permissions
run_cmd mkdir -p "$SSH_DIR" || log_error "Échec de la création de $SSH_DIR"
run_cmd chmod 700 "$SSH_DIR" || log_error "Échec de chmod 700 sur $SSH_DIR"

# Copier authorized_keys si le fichier existe
if [[ -f "$AUTH_KEYS" ]]; then
    run_cmd cp "$AUTH_KEYS" "$SSH_DIR/" || log_error "Échec de la copie de $AUTH_KEYS"
    run_cmd chmod 600 "$SSH_DIR/authorized_keys" || log_error "Échec de chmod 600 sur authorized_keys"
    run_cmd chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR" || log_error "Échec du chown sur $SSH_DIR"
else
    log_warn "$AUTH_KEYS n'existe pas. Aucune clé SSH copiée."
fi

# Changer le port SSH (avec sauvegarde)
SSHD_CONFIG="/etc/ssh/sshd_config"
log_info "Changement du port SSH vers $SSH_PORT..."
run_cmd cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak" || log_error "Échec de la sauvegarde de $SSHD_CONFIG"
run_cmd sed -i "s/^#Port 22/Port $SSH_PORT/g" "$SSHD_CONFIG" || log_error "Échec de la modification du port SSH"
run_cmd sed -i "s/^Port 22/Port $SSH_PORT/g" "$SSHD_CONFIG" || log_error "Échec de la modification du port SSH (2ème tentative)"

# Redémarrer SSH (gérer ssh.socket si présent)
if systemctl is-active --quiet ssh.socket 2>/dev/null; then
    run_cmd systemctl stop ssh.socket || log_warn "Échec de l'arrêt de ssh.socket"
    run_cmd systemctl disable ssh.socket || log_warn "Échec du désactivation de ssh.socket"
fi
run_cmd systemctl enable ssh.service || log_error "Échec de l'activation de ssh.service"
run_cmd systemctl restart ssh.service || log_error "Échec du redémarrage de SSH"
log_info "SSH redémarré. Nouveau port: $SSH_PORT"

# --- 4. Personnalisation du .bashrc (root) ---
log_info "Personnalisation de /root/.bashrc..."
BASHRC="/root/.bashrc"
if [[ -f "$BASHRC" ]]; then
    cat >> "$BASHRC" << 'EOF'

# Aliases personnalisés (ajoutés par postinstall.sh)
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -lah'
alias l='ls $LS_OPTIONS -lA'
EOF
    if ! $DRY_RUN; then
        source "$BASHRC" || log_warn "Échec du 'source' de $BASHRC (non critique)"
    fi
else
    log_warn "$BASHRC n'existe pas. Création..."
    cat > "$BASHRC" << 'EOF'
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -lah'
alias l='ls $LS_OPTIONS -lA'
EOF
fi

# --- 5. Configuration du fuseau horaire ---
log_info "Configuration du fuseau horaire vers $TIMEZONE..."
run_cmd ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime || log_error "Échec de la configuration du fuseau horaire"
run_cmd dpkg-reconfigure -f noninteractive tzdata || log_warn "Échec de dpkg-reconfigure tzdata (non critique)"

# --- 6. Configuration des locales ---
log_info "Configuration des locales vers $LOCALE..."
run_cmd sed -i "s/^# *$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen || log_warn "Échec de la modification de /etc/locale.gen"
run_cmd locale-gen || log_error "Échec de la génération des locales"
run_cmd update-locale LANG="$LOCALE" || log_warn "Échec de update-locale (non critique)"

# --- 7. Redémarrage (optionnel) ---
if $SKIP_REBOOT; then
    log_info "✅ Script terminé avec succès ! (redémarrage ignoré)"
    exit 0
fi

log_info "✅ Script terminé avec succès !"
log_warn "Un redémarrage est nécessaire pour appliquer toutes les modifications."
if $DRY_RUN; then
    log_dryrun "Redémarrage simulé (aucune action)"
    exit 0
fi
read -rp "Voulez-vous redémarrer maintenant ? [o/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[OoYy]$ ]]; then
    log_info "Redémarrage en cours..."
    reboot
else
    log_info "Redémarrage annulé. Faites-le manuellement avec 'sudo reboot'."
fi
