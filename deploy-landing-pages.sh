#!/bin/bash
# ============================================================
# DÉPLOIEMENT LANDING PAGES — Les Inarrêtables
# ============================================================
# Ce script déploie les 4 landing pages sur un sous-domaine
# SANS toucher au projet existant sur le VPS.
#
# Usage :
#   1. Modifier les variables ci-dessous
#   2. Copier ce script + les 4 fichiers HTML sur le VPS
#   3. Exécuter : bash deploy-landing-pages.sh
# ============================================================

set -e

# ============================================================
# CONFIGURATION — MODIFIER ICI
# ============================================================
SUBDOMAIN="formations.lesinarretables.com"  # Ton sous-domaine
WEBROOT="/var/www/formations-ia"             # Dossier dédié (séparé du projet existant)
CALENDLY_LINK="https://calendly.com/VOTRE_LIEN"  # Ton lien de prise de RDV
EMAIL="info@lesinarretables.com"          # Pour le certificat SSL Let's Encrypt

# ============================================================
# DÉTECTION DU SERVEUR WEB
# ============================================================
echo "========================================"
echo " Déploiement Landing Pages IA"
echo " Sous-domaine : $SUBDOMAIN"
echo "========================================"
echo ""

WEBSERVER=""
if command -v nginx &> /dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
    WEBSERVER="nginx"
    echo "[OK] Nginx détecté et actif"
elif command -v apache2 &> /dev/null && systemctl is-active --quiet apache2 2>/dev/null; then
    WEBSERVER="apache"
    echo "[OK] Apache détecté et actif"
elif command -v httpd &> /dev/null && systemctl is-active --quiet httpd 2>/dev/null; then
    WEBSERVER="apache"
    echo "[OK] Apache (httpd) détecté et actif"
elif command -v nginx &> /dev/null; then
    WEBSERVER="nginx"
    echo "[INFO] Nginx installé mais pas actif — on l'utilise quand même"
else
    echo "[INFO] Aucun serveur web détecté. Installation de Nginx..."
    apt update && apt install -y nginx
    systemctl enable nginx && systemctl start nginx
    WEBSERVER="nginx"
    echo "[OK] Nginx installé et démarré"
fi

echo "[INFO] Serveur web : $WEBSERVER"
echo ""

# ============================================================
# CRÉATION DU DOSSIER (isolé du projet existant)
# ============================================================
echo "[1/6] Création du dossier $WEBROOT ..."
mkdir -p "$WEBROOT"

# ============================================================
# COPIE DES FICHIERS HTML
# ============================================================
echo "[2/6] Copie des landing pages..."

# Cherche les fichiers HTML dans le même dossier que le script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for FILE in landing-productivite.html landing-contenu.html landing-marketing.html landing-video.html; do
    if [ -f "$SCRIPT_DIR/$FILE" ]; then
        cp "$SCRIPT_DIR/$FILE" "$WEBROOT/$FILE"
        echo "  -> $FILE copié"
    else
        echo "  [ERREUR] $FILE introuvable dans $SCRIPT_DIR"
        echo "  Assure-toi que les 4 fichiers HTML sont dans le même dossier que ce script."
        exit 1
    fi
done

# ============================================================
# REMPLACEMENT DU LIEN CALENDLY
# ============================================================
echo "[3/6] Configuration du lien de prise de RDV..."
if [ "$CALENDLY_LINK" != "https://calendly.com/VOTRE_LIEN" ]; then
    sed -i "s|\[VOTRE_LIEN_CALENDLY\]|$CALENDLY_LINK|g" "$WEBROOT"/*.html
    echo "  -> Lien Calendly mis à jour dans toutes les pages"
else
    echo "  [ATTENTION] Tu n'as pas modifié CALENDLY_LINK dans le script."
    echo "  Les boutons pointeront vers [VOTRE_LIEN_CALENDLY]."
    echo "  Tu pourras le modifier plus tard avec :"
    echo "  sed -i 's|\[VOTRE_LIEN_CALENDLY\]|https://ton-vrai-lien.com|g' $WEBROOT/*.html"
fi

# Créer un index qui redirige vers la page productivité par défaut
cat > "$WEBROOT/index.html" << 'INDEXEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Les Inarrêtables — Formations IA Générative</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, 'Inter', sans-serif; background: #f8f9fa; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
.hub { max-width: 500px; text-align: center; padding: 40px 24px; }
h1 { font-size: 28px; color: #1B4F72; margin-bottom: 8px; }
p { color: #666; margin-bottom: 32px; font-size: 16px; }
.links { display: grid; gap: 12px; }
a { display: block; padding: 16px 24px; border-radius: 12px; text-decoration: none; color: #fff; font-weight: 700; font-size: 16px; transition: transform 0.2s, box-shadow 0.2s; }
a:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.15); }
.a1 { background: linear-gradient(135deg, #1B4F72, #2E86C1); }
.a2 { background: linear-gradient(135deg, #6C3483, #A569BD); }
.a3 { background: linear-gradient(135deg, #C0392B, #E74C3C); }
.a4 { background: linear-gradient(135deg, #1a1a2e, #E67E22); }
</style>
</head>
<body>
<div class="hub">
  <h1>Les Inarrêtables</h1>
  <p>Formations IA Générative pour PME</p>
  <div class="links">
    <a href="landing-productivite.html" class="a1">Productivité — Gagnez 5-10h/semaine</a>
    <a href="landing-contenu.html" class="a2">Contenu — Produisez 3x plus</a>
    <a href="landing-marketing.html" class="a3">Marketing — +40% de ROI</a>
    <a href="landing-video.html" class="a4">Vidéo — Qualité cinéma, -90% de coût</a>
  </div>
</div>
</body>
</html>
INDEXEOF
echo "  -> Page index créée (hub vers les 4 landing pages)"

# ============================================================
# CONFIGURATION DU SERVEUR WEB
# ============================================================
echo "[4/6] Configuration du serveur web ($WEBSERVER)..."

if [ "$WEBSERVER" = "nginx" ]; then

    # Vérifier qu'on ne crée pas de conflit avec un site existant
    if [ -f "/etc/nginx/sites-enabled/$SUBDOMAIN" ]; then
        echo "  [INFO] Config Nginx pour $SUBDOMAIN existe déjà — mise à jour"
    fi

    cat > "/etc/nginx/sites-available/$SUBDOMAIN" << NGINXEOF
server {
    listen 80;
    server_name $SUBDOMAIN;
    root $WEBROOT;
    index index.html;

    # Logs séparés (ne touche pas aux logs du projet existant)
    access_log /var/log/nginx/${SUBDOMAIN}_access.log;
    error_log /var/log/nginx/${SUBDOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache pour les assets statiques
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
NGINXEOF

    # Activer le site
    ln -sf "/etc/nginx/sites-available/$SUBDOMAIN" "/etc/nginx/sites-enabled/$SUBDOMAIN"

    # Tester la config avant de recharger (sécurité)
    echo "  -> Test de la configuration Nginx..."
    if nginx -t 2>&1; then
        systemctl reload nginx
        echo "  -> Nginx rechargé avec succès"
    else
        echo "  [ERREUR] Config Nginx invalide. Le projet existant n'est PAS affecté."
        echo "  Vérifie /etc/nginx/sites-available/$SUBDOMAIN"
        exit 1
    fi

elif [ "$WEBSERVER" = "apache" ]; then

    cat > "/etc/apache2/sites-available/$SUBDOMAIN.conf" << APACHEEOF
<VirtualHost *:80>
    ServerName $SUBDOMAIN
    DocumentRoot $WEBROOT

    # Logs séparés
    ErrorLog \${APACHE_LOG_DIR}/${SUBDOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SUBDOMAIN}_access.log combined

    <Directory $WEBROOT>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    # Cache statiques
    <FilesMatch "\.(css|js|jpg|jpeg|png|gif|ico|svg|woff2?)$">
        Header set Cache-Control "max-age=2592000, public, immutable"
    </FilesMatch>

    # Sécurité
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
</VirtualHost>
APACHEEOF

    a2ensite "$SUBDOMAIN.conf"
    a2enmod headers

    echo "  -> Test de la configuration Apache..."
    if apache2ctl configtest 2>&1; then
        systemctl reload apache2
        echo "  -> Apache rechargé avec succès"
    else
        echo "  [ERREUR] Config Apache invalide. Le projet existant n'est PAS affecté."
        exit 1
    fi
fi

# ============================================================
# PERMISSIONS
# ============================================================
echo "[5/6] Permissions..."
chown -R www-data:www-data "$WEBROOT"
chmod -R 755 "$WEBROOT"
echo "  -> Permissions OK"

# ============================================================
# SSL (LET'S ENCRYPT)
# ============================================================
echo "[6/6] Certificat SSL (Let's Encrypt)..."

if ! command -v certbot &> /dev/null; then
    echo "  -> Installation de Certbot..."
    apt install -y certbot
    if [ "$WEBSERVER" = "nginx" ]; then
        apt install -y python3-certbot-nginx
    else
        apt install -y python3-certbot-apache
    fi
fi

echo ""
echo "  Pour activer HTTPS, exécute :"
if [ "$WEBSERVER" = "nginx" ]; then
    echo "  certbot --nginx -d $SUBDOMAIN --email $EMAIL --agree-tos --non-interactive"
else
    echo "  certbot --apache -d $SUBDOMAIN --email $EMAIL --agree-tos --non-interactive"
fi

# ============================================================
# RÉSUMÉ
# ============================================================
echo ""
echo "========================================"
echo " DÉPLOIEMENT TERMINÉ"
echo "========================================"
echo ""
echo " Tes pages sont accessibles ici :"
echo ""
echo "   Hub :           http://$SUBDOMAIN/"
echo "   Productivité :  http://$SUBDOMAIN/landing-productivite.html"
echo "   Contenu :       http://$SUBDOMAIN/landing-contenu.html"
echo "   Marketing :     http://$SUBDOMAIN/landing-marketing.html"
echo "   Vidéo :         http://$SUBDOMAIN/landing-video.html"
echo ""
echo " IMPORTANT :"
echo "   1. Configure ton DNS : ajoute un enregistrement A"
echo "      $SUBDOMAIN -> $(curl -s ifconfig.me 2>/dev/null || echo 'IP_DU_VPS')"
echo "   2. Active HTTPS avec la commande certbot ci-dessus"
echo "   3. Si tu n'as pas modifié CALENDLY_LINK, fais-le avec :"
echo "      sed -i 's|\[VOTRE_LIEN_CALENDLY\]|https://ton-lien.com|g' $WEBROOT/*.html"
echo ""
echo " Ton projet existant n'a PAS été touché."
echo "========================================"
