#!/usr/bin/env bash
#
# setup_proxy_and_register.sh
#
# Beschreibung:
# Dieses Skript richtet systemweite Proxy-Einstellungen ein,
# ergänzt DNS-Einträge in /etc/resolv.conf und registriert optional das
# System gegen eine Red Hat Subscription und bindet Repositories ein.
#
# Author: Gerry Racine
# Erstellungsdatum: 2025-05-17
#

# Dieses Skript muss als root ausgeführt werden
if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen."
  exit 1
fi

# 1) Systemweiten Proxy einrichten
PROXY_CONF="/etc/profile.d/proxy.sh"

cat > "$PROXY_CONF" << 'EOF'
# Systemweite Proxy-Einstellungen
export http_proxy="193.222.84.93:8080"
export https_proxy="193.222.84.93:8080"
export ftp_proxy="193.222.84.93:8080"
export no_proxy="localhost,127.0.0.1,.sccloudinfra.net"
EOF

chmod 644 "$PROXY_CONF"
# Proxy aktivieren
source "$PROXY_CONF"
echo "Proxy-Konfiguration unter $PROXY_CONF angelegt und aktiviert."

# 2) Einträge in /etc/resolv.conf ergänzen, falls nicht vorhanden
RESOLV="/etc/resolv.conf"

grep -qxF "search draco-449.sccloudres.net" "$RESOLV" \
  || echo "search draco-449.sccloudres.net" >> "$RESOLV"

grep -qxF "nameserver 194.11.96.8" "$RESOLV" \
  || echo "nameserver 194.11.96.8" >> "$RESOLV"

grep -qxF "nameserver 194.11.96.9" "$RESOLV" \
  || echo "nameserver 194.11.96.9" >> "$RESOLV"

echo "Einträge in $RESOLV geprüft und ggf. ergänzt."

# 3) Abfrage zur System-Registrierung
read -p "Soll das System jetzt registriert und Repos eingebunden werden? (j/n) " ANTWORT
case "$ANTWORT" in
  [Jj]*)
    # 3.1) Aktuellen FQDN holen
    HOST="$(hostname -f)"
    # 3.2) Trailing-Komma entfernen, falls vorhanden
    if [[ "${HOST: -1}" == "," ]]; then
      CLEAN_HOST="${HOST%,}"
      echo "Hostname endet auf ',', setze bereinigten Hostname auf $CLEAN_HOST"
      hostnamectl set-hostname "$CLEAN_HOST"
      HOST="$CLEAN_HOST"
    fi
    # 3.3) Alles in Kleinbuchstaben wandeln
    LOWER="$(echo "$HOST" | tr '[:upper:]' '[:lower:]')"
    if [[ "$HOST" != "$LOWER" ]]; then
      echo "Hostname enthält Großbuchstaben oder ungültige Zeichen, setze zu $LOWER"
      hostnamectl set-hostname "$LOWER"
    fi

    echo "Registriere System und binde Repositories ein…"
    curl -s -k https://pcms2capsule-5.prd.cms.sccloudinfra.net/pub/register-client.sh | sh
    echo
    echo "Alle Vorgänge erfolgreich abgeschlossen."
    echo "Bitte führen Sie abschließend noch 'yum update' aus."
    ;;
  *)
    echo "System-Registrierung übersprungen."
    echo "Wenn gewünscht, führen Sie später manuell aus:"
    echo "  curl -s -k https://pcms2capsule-5.prd.cms.sccloudinfra.net/pub/register-client.sh | sh"
    echo "Und danach 'yum update'."
    ;;
esac

exit 0
