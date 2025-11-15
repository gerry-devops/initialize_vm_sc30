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
setup_lvm
cat > "$PROXY_CONF" << 'EOF'
# Systemweite Proxy-Einstellungen
export http_proxy="193.222.84.93:8080"
export HTTP_PROXY="193.222.84.93:8080"
export https_proxy="193.222.84.93:8080"
export HTTPS_PROXY="193.222.84.93:8080"
export ftp_proxy="193.222.84.93:8080"
export FTP_PROXY="193.222.84.93:8080"
export no_proxy="127.0.0.1, localhost, *.draco-449.sccloudres.net, *.mgmt-emm.local, *.sccloudinfra.net, private.cloud.swisscom.com, *.private.cloud.swisscom.com, ds12s3.swisscom.com, *.sharedit.ch, 194.11.96.*, pcms2capsule-5.prd.cms.sccloudinfra.net"
export NO_PROXY="127.0.0.1, localhost, *.draco-449.sccloudres.net, *.mgmt-emm.local, *.sccloudinfra.net, private.cloud.swisscom.com, *.private.cloud.swisscom.com, ds12s3.swisscom.com, *.sharedit.ch, 194.11.96.*, pcms2capsule-5.prd.cms.sccloudinfra.net"
EOF

chmod 644 "$PROXY_CONF"
# shellcheck source=/etc/profile.d/proxy.sh
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
    # 3.1) Kurzen Hostnamen für die Registrierung abfragen
    read -p "Bitte geben Sie den kurzen Hostnamen (ohne Domain) ein: " SHORT_HOST

    # 3.2) Domain definieren
    DOMAIN="draco-449.sccloudres.net"

    # 3.3) Eingabe bereinigen (Kleinbuchstaben, Komma entfernen)
    # Zuerst in Kleinbuchstaben wandeln
    CLEAN_HOST=$(echo "$SHORT_HOST" | tr '[:upper:]' '[:lower:]')
    
    # Trailing-Komma entfernen, falls vorhanden
    if [[ "${CLEAN_HOST: -1}" == "," ]]; then
      CLEAN_HOST="${CLEAN_HOST%,}"
      echo "Trailing-Komma entfernt."
    fi

    # 3.4) FQDN zusammensetzen
    HOST_FQDN="${CLEAN_HOST}.${DOMAIN}"

    # 3.5) Hostnamen setzen
    echo "Setze finalen Hostnamen (FQDN) auf: $HOST_FQDN"
    hostnamectl set-hostname "$HOST_FQDN"

    # 3.6) Registrierung durchführen
    echo "Registriere System mit Hostnamen $HOST_FQDN und binde Repositories ein…"
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