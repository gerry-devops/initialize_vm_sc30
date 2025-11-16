#!/usr/bin/env bash
#
# install_docker_with_proxy.sh
# Docker-Installation auf RHEL9 inkl. Proxy-/DNF-/Systemd-Konfiguration

set -euo pipefail

PROXY_URL='http://193.222.84.93:8080'
SYSTEMD_PROXY_DIR='/etc/systemd/system.conf.d'
SYSTEMD_PROXY_FILE="${SYSTEMD_PROXY_DIR}/proxy.conf"
DNF_CONF='/etc/dnf/dnf.conf'
YUM_CONF='/etc/yum.conf'
REDHAT_REPO='/etc/yum.repos.d/redhat.repo'
DOCKER_REPO_FILE='/etc/yum.repos.d/docker-ce.repo'
DOCKER_SYSTEMD_DIR='/etc/systemd/system/docker.service.d'
DOCKER_SYSTEMD_PROXY_FILE="${DOCKER_SYSTEMD_DIR}/http-proxy.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen (z.B. mit: sudo $0)"
  exit 1
fi

echo "==> 1) systemd Manager-Proxy konfigurieren"

# 1. /etc/systemd/system.conf.d anlegen falls nötig
mkdir -p "${SYSTEMD_PROXY_DIR}"

# 2. proxy.conf mit gewünschtem Inhalt (überschreiben/erzeugen)
cat > "${SYSTEMD_PROXY_FILE}" <<EOF
[Manager]
DefaultEnvironment="HTTP_PROXY=${PROXY_URL}"
DefaultEnvironment="HTTPS_PROXY=${PROXY_URL}/"
DefaultEnvironment="NO_PROXY=127.0.0.1, localhost, *.draco-449.sccloudres.net, *.mgmt-emm.local, *.sccloudinfra.net, private.cloud.swisscom.com, *.private.cloud.swisscom.com, ds12s3.swisscom.com, *.sharedit.ch, 194.11.96.*, pcms2capsule-5.prd.cms.sccloudinfra.net"
EOF

echo "==> 2) redhat.repo um proxy=_none_ ergänzen"

if [[ -f "${REDHAT_REPO}" ]]; then
  if ! grep -q '^[[:space:]]*proxy=_none_' "${REDHAT_REPO}"; then
    # nach jeder Zeile 'enabled_metadata = 0' proxy=_none_ einfügen
    sed -i '/enabled_metadata[[:space:]]*=[[:space:]]*0/a proxy=_none_' "${REDHAT_REPO}"
  fi
else
  echo "WARNUNG: ${REDHAT_REPO} existiert nicht, überspringe diesen Schritt."
fi

echo "==> 3) Proxy in /etc/yum.conf auskommentieren (falls vorhanden)"

if [[ -f "${YUM_CONF}" ]]; then
  sed -i 's/^\s*proxy="http:\/\/193.222.84.93:8080"/#&/' "${YUM_CONF}"
fi

echo "==> 4) Proxy-Einträge in /etc/dnf/dnf.conf auskommentieren (Erste Runde)"

if [[ -f "${DNF_CONF}" ]]; then
  sed -i 's/^\s*proxy="http:\/\/193.222.84.93:8080"/#&/' "${DNF_CONF}" || true
  sed -i 's/^\s*PROXY="http:\/\/193.222.84.93:8080"/#&/' "${DNF_CONF}" || true
fi

echo "==> 5) dnf-plugins-core installieren"

dnf -y install dnf-plugins-core

echo "==> 6) Proxy-Einträge in /etc/dnf/dnf.conf aktiv setzen (für docker-ce.repo-Add)"

# Nach Installation sicherstellen, dass die Einträge (un-kommentiert) vorhanden sind
if [[ -f "${DNF_CONF}" ]]; then
  # Falls kommentiert -> entkommentieren
  sed -i 's/^#\s*proxy="http:\/\/193.222.84.93:8080"/proxy="http:\/\/193.222.84.93:8080"/' "${DNF_CONF}" || true
  sed -i 's/^#\s*PROXY="http:\/\/193.222.84.93:8080"/PROXY="http:\/\/193.222.84.93:8080"/' "${DNF_CONF}" || true

  # Falls gar nicht vorhanden -> hinzufügen
  if ! grep -q '^[[:space:]]*proxy="http://193.222.84.93:8080"' "${DNF_CONF}"; then
    echo 'proxy="http://193.222.84.93:8080"' >> "${DNF_CONF}"
  fi
  if ! grep -q '^[[:space:]]*PROXY="http://193.222.84.93:8080"' "${DNF_CONF}"; then
    echo 'PROXY="http://193.222.84.93:8080"' >> "${DNF_CONF}"
  fi
else
  echo "WARNUNG: ${DNF_CONF} existiert nicht, erstelle neue Datei mit Proxy-Einträgen."
  cat > "${DNF_CONF}" <<EOF
[main]
proxy="http://193.222.84.93:8080"
PROXY="http://193.222.84.93:8080"
EOF
fi

echo "==> 7) Docker CE Repo hinzufügen"

dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

echo "==> 8) Proxy-Einträge in /etc/dnf/dnf.conf wieder auskommentieren"

if [[ -f "${DNF_CONF}" ]]; then
  sed -i 's/^\s*proxy="http:\/\/193.222.84.93:8080"/#proxy="http:\/\/193.222.84.93:8080"/' "${DNF_CONF}" || true
  sed -i 's/^\s*PROXY="http:\/\/193.222.84.93:8080"/#PROXY="http:\/\/193.222.84.93:8080"/' "${DNF_CONF}" || true
fi

echo "==> 9) Proxy im Abschnitt [docker-ce-stable] der docker-ce.repo einfügen"

if [[ -f "${DOCKER_REPO_FILE}" ]]; then
  # Nur einfügen, wenn noch kein entsprechender Proxy-Eintrag existiert
  if ! grep -q '^[[:space:]]*proxy="http://193.222.84.93:8080"' "${DOCKER_REPO_FILE}"; then
    # Nach gpgkey=... Zeile im Abschnitt [docker-ce-stable] einfügen
    awk '
      BEGIN {in_section=0}
      /^\[docker-ce-stable\]/ {in_section=1}
      /^\[/ && $0 !~ /^\[docker-ce-stable\]/ {in_section=0}
      {
        print $0
        if (in_section && $0 ~ /^gpgkey=https:\/\/download\.docker\.com\/linux\/rhel\/gpg/) {
          print "proxy=\"http://193.222.84.93:8080\""
        }
      }
    ' "${DOCKER_REPO_FILE}" > "${DOCKER_REPO_FILE}.tmp"
    mv "${DOCKER_REPO_FILE}.tmp" "${DOCKER_REPO_FILE}"
  fi
else
  echo "WARNUNG: ${DOCKER_REPO_FILE} existiert nicht, wurde docker-ce.repo nicht angelegt?"
fi

echo "==> 10) dnf makecache ausführen"

dnf makecache

echo "==> 11) Docker-Pakete installieren"

dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> 12) Docker-Service aktivieren und starten"

systemctl enable --now docker

echo "==> 13) Aktuellen Benutzer zur docker-Gruppe hinzufügen"

TARGET_USER="${SUDO_USER:-$USER}"
if id "${TARGET_USER}" &>/dev/null; then
  usermod -aG docker "${TARGET_USER}"
  echo "Benutzer ${TARGET_USER} wurde zur Gruppe 'docker' hinzugefügt."
else
  echo "WARNUNG: Benutzer ${TARGET_USER} existiert nicht, überspringe usermod."
fi

echo "==> 14) newgrp docker (wirksam nur für aktuelle Shell; in Script eher informativ)"
# Dieser Aufruf hat in einem Non-Interactive-Script wenig Effekt,
# wird aber der Vollständigkeit halber ausgeführt.
newgrp docker <<'EOF' || true
exit
EOF

echo "==> 15) systemd Drop-in für docker.service mit Proxy setzen"

mkdir -p "${DOCKER_SYSTEMD_DIR}"

cat > "${DOCKER_SYSTEMD_PROXY_FILE}" <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL}" "HTTPS_PROXY=${PROXY_URL}" "NO_PROXY=127.0.0.1, localhost, .draco-449.sccloudres.net, .mgmt-emm.local, .sccloudinfra.net, private.cloud.swisscom.com, .private.cloud.swisscom.com, ds12s3.swisscom.com, .sharedit.ch, 194.11.96., pcms2capsule-5.prd.cms.sccloudinfra.net"
EOF

echo "==> 16) systemd daemon-reexec & Docker-Service neu starten"

systemctl daemon-reexec
systemctl restart docker

echo "========================================================="
echo "Fertig. Docker ist installiert und Proxy-Konfigurationen"
echo "für systemd, dnf und docker.service wurden gesetzt."
echo
echo "Hinweis: Bitte einmal neu einloggen, damit die Gruppen-"
echo "änderung (docker-Gruppe für ${TARGET_USER}) aktiv wird."
echo "========================================================="