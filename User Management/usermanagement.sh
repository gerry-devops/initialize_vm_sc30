#!/usr/bin/env bash
# =============================================
# Author: Gerry Racine
# Created: 2025-05-18
# Version: 1.0
# Description: Interaktives Benutzermanagement-Skript zur Anlage, Löschung
#              und Umbenennung von Benutzern.
# =============================================

# Funktion zur Anzeige des Menüs
show_menu() {
  echo ""
  echo "==== Benutzermanagement ===="
  echo "1) Neuen Benutzer anlegen"
  echo "2) Bestehenden Benutzer löschen"
  echo "3) Benutzername ändern"
  echo "4) Beenden"
  echo -n "Bitte Option wählen [1-4]: "
}

# Funktion: Neuen Benutzer anlegen
add_user() {
  read -rp "Neuen Benutzernamen eingeben: " username
  # Passwort abfragen
  read -rsp "Passwort für $username: " password
  echo
  # Sudo-Gruppe abfragen
  read -rp "Soll $username der Gruppe wheel (sudo) hinzugefügt werden? [y/N]: " need_sudo

  # User anlegen mit Home-Verzeichnis und Bash-Shell
  if [[ $need_sudo =~ ^[Yy]$ ]]; then
    useradd -m -s /bin/bash -G wheel "$username"
  else
    useradd -m -s /bin/bash "$username"
  fi

  # Passwort setzen
  echo "$username:$password" | chpasswd
  if [[ $? -eq 0 ]]; then
    echo "Benutzer $username erfolgreich angelegt."
  else
    echo "Fehler beim Anlegen des Benutzers $username." >&2
  fi
}

# Funktion: Bestehenden Benutzer löschen
delete_user() {
  # Liste der Benutzer mit UID >= 1000
  mapfile -t users < <(getent passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}')
  if [[ ${#users[@]} -eq 0 ]]; then
    echo "Keine normalen Benutzer zum Löschen gefunden."
    return
  fi

  echo "Verfügbare Benutzer:"
  select u in "${users[@]}" "Abbrechen"; do
    if [[ $REPLY -gt 0 && $REPLY -le ${#users[@]} ]]; then
      target_user=$u
      break
    elif [[ $REPLY -eq $(( ${#users[@]} + 1 )) ]]; then
      echo "Abbruch."; return
    else
      echo "Ungültige Auswahl.";
    fi
  done

  read -rp "Soll der Benutzer $target_user wirklich gelöscht werden? [y/N]: " confirm
  if [[ $confirm =~ ^[Yy]$ ]]; then
    userdel -r "$target_user"
    if [[ $? -eq 0 ]]; then
      echo "Benutzer $target_user wurde gelöscht."
    else
      echo "Fehler beim Löschen des Benutzers $target_user." >&2
    fi
  else
    echo "Löschen abgebrochen."
  fi
}

# Funktion: Benutzername ändern
rename_user() {
  mapfile -t users < <(getent passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}')
  if [[ ${#users[@]} -eq 0 ]]; then
    echo "Keine normalen Benutzer zum Umbenennen gefunden."
    return
  fi

  echo "Verfügbare Benutzer:"
  select u in "${users[@]}" "Abbrechen"; do
    if [[ $REPLY -gt 0 && $REPLY -le ${#users[@]} ]]; then
      old_name=$u
      break
    elif [[ $REPLY -eq $(( ${#users[@]} + 1 )) ]]; then
      echo "Abbruch."; return
    else
      echo "Ungültige Auswahl.";
    fi
  done

  read -rp "Neuen Benutzernamen für $old_name eingeben: " new_name
  usermod -l "$new_name" -d "/home/$new_name" -m "$old_name"
  if [[ $? -eq 0 ]]; then
    echo "Benutzer $old_name erfolgreich in $new_name umbenannt."
  else
    echo "Fehler beim Umbenennen von $old_name." >&2
  fi
}

# Hauptprogramm mit Menü
while true; do
  show_menu
  read -r choice
  case $choice in
    1) add_user ;;
    2) delete_user ;;
    3) rename_user ;;
    4) echo "Beende Skript."; exit 0 ;;
    *) echo "Ungültige Option." ;;
  esac
done
# Ende des Skripts
# Hinweis: Dieses Skript muss mit Root-Rechten ausgeführt werden.