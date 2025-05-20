#!/bin/bash
# setup_lvm.sh
# Beschreibung: Dieses Skript automatisiert das Einrichten von LVM auf der Disk /dev/sdb unter RHEL9.
#               Es prüft das Vorhandensein der Disk, erstellt eine Partition, Physical Volume,
#               Volume Group und Logical Volume, formatiert das LV mit XFS, richtet einen Mountpoint ein,
#               aktualisiert /etc/fstab und mountet das Dateisystem optional.
# Author: Gerry Racine
# Datum: 2025-05-18
# Version 1.0


set -euo pipefail

# 1) Prüfen, ob /dev/sdb existiert
if [ ! -b /dev/sdb ]; then
  echo "Fehler: Die Disk /dev/sdb wurde nicht gefunden."
  exit 1
fi

# 2) Partition anlegen (100% des Platzes)
echo "Erstelle Partition /dev/sdb1 auf /dev/sdb..."
parted -s /dev/sdb mklabel gpt mkpart primary 0% 100%
sleep 1
PART="/dev/sdb1"
echo "Partition $PART erstellt."

# 3) PV anlegen
pvcreate "$PART"
echo "Physical Volume $PART erstellt."

# 4) VG anlegen – Name abfragen, Standard 'vgdata'
read -p "Name der Volume Group (default: vgdata): " VG_NAME
VG_NAME=${VG_NAME:-vgdata}
vgcreate "$VG_NAME" "$PART"
echo "Volume Group '$VG_NAME' erstellt."

# 5) LV anlegen – füllt 100% und heißt 'lvdata'
lvcreate -l 100%FREE -n lvdata "$VG_NAME"
echo "Logical Volume 'lvdata' in VG '$VG_NAME' erstellt."

# 6) VG/LV anzeigen und Bestätigung einholen
echo
echo "=== Aktuelle Volume Groups ==="
vgs "$VG_NAME"
echo
echo "=== Aktuelle Logical Volumes ==="
lvs "$VG_NAME/lvdata"
echo
read -p "Ist das so in Ordnung? (ja/nein): " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn] ]]; then
  lvremove -y "$VG_NAME/lvdata"
  vgremove -y "$VG_NAME"
  echo "LV und VG wurden gelöscht. Skript beendet."
  exit 0
fi

# 7) XFS-Dateisystem erstellen
mkfs.xfs "/dev/$VG_NAME/lvdata"
echo "XFS-Dateisystem auf /dev/$VG_NAME/lvdata erstellt."

# 8) Mountpoint anlegen – Vorschlag '/data'
DEFAULT_MNT="/data"
read -p "Mountpoint-Verzeichnis (default: $DEFAULT_MNT): " MNT_DIR
MNT_DIR=${MNT_DIR:-$DEFAULT_MNT}
mkdir -p "$MNT_DIR"
echo "Mountpoint-Verzeichnis '$MNT_DIR' angelegt (falls nicht vorhanden)."

# 9) Automatisches Mounten (/etc/fstab) mit nofail
echo "/dev/$VG_NAME/lvdata $MNT_DIR xfs defaults,nofail 0 0" >> /etc/fstab
echo "/etc/fstab aktualisiert mit Eintrag für '$MNT_DIR'."

# 10) Nach sofortigem Mounten fragen
read -p "Soll das Filesystem jetzt gemounted werden? (ja/nein): " MOUNT_NOW
if [[ "$MOUNT_NOW" =~ ^[Jj] ]]; then
  mount "$MNT_DIR"
  echo "Dateisystem erfolgreich gemounted. Aktuelle Mounts:"
  mount | grep "$MNT_DIR"
else
  echo "Das Dateisystem wurde noch nicht gemounted."
  echo "Zum Mounten führen Sie aus: mount $MNT_DIR"
fi

echo "Fertig."
