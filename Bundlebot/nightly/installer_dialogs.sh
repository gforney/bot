# Included in the self-extracting installer before the text setup code.
installer_backend=
case ${1:-} in
  --text) shift; installer_gui=0 ;;
  y) installer_gui=0 ;;
esac
if [ "$installer_gui" = 1 ]; then
  if [ "$(uname -s)" = Darwin ] && command -v osascript >/dev/null 2>&1; then
    installer_backend=osascript
  elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
    installer_backend=zenity
  fi
fi

installer_dialog() {
  if [ "$installer_backend" = zenity ]; then
    zenity --entry --title="$installer_product" --text="$1" --entry-text="$2"
  else
    osascript - "$installer_product" "$1" "$2" <<'APPLESCRIPT'
on run argv
  try
    return text returned of (display dialog (item 2 of argv) with title (item 1 of argv) default answer (item 3 of argv))
  on error number -128
    return "__BUNDLEBOT_CANCEL__"
  end try
end run
APPLESCRIPT
  fi
}

installer_read() {
  local installer_kind=$1 installer_variable=$2 installer_prompt=${3:-}
  local installer_default= installer_reply installer_error installer_status
  if [ -n "$installer_backend" ]; then
    case "$installer_kind" in
      start)
        installer_prompt=$'Enter 1 to continue with setup or 2 to extract the archive.'
        installer_default=1 ;;
      location)
        installer_prompt=$'Choose a destination by number, or enter an absolute path without spaces.\n\n'
        if [ "$(uname -s)" = Darwin ]; then
          installer_prompt+="1. /Applications/$installer_default_dir"$'\n'
          installer_prompt+="2. $HOME/$installer_default_dir"
          if [ "$installer_product" = "FDS and Smokeview" ]; then
            installer_prompt+=$'\n'"3. /Applications/FDS/$installer_custom_base"
          fi
        else
          installer_prompt+="1. $HOME/$installer_default_dir"$'\n'
          installer_prompt+="2. /opt/$installer_default_dir"$'\n'
          installer_prompt+="3. /usr/local/bin/$installer_default_dir"
          if [ "$installer_product" = "FDS and Smokeview" ]; then
            installer_prompt+=$'\n'"4. $HOME/FDS/$installer_custom_base"
          fi
        fi
        installer_default=1 ;;
      confirm) installer_default=no ;;
    esac

    installer_error=$(mktemp "${TMPDIR:-/tmp}/bundlebot-dialog.XXXXXX")
    if [ -z "$installer_error" ]; then
      installer_status=2
    else
      installer_reply=$(installer_dialog "$installer_prompt" "$installer_default" 2>"$installer_error")
      installer_status=$?
      if [ "$installer_backend" = zenity ] && [ "$installer_status" = 1 ] && [ ! -s "$installer_error" ]; then
        installer_reply=__BUNDLEBOT_CANCEL__
      fi
      rm -f "$installer_error"
    fi
    if [ "$installer_reply" = __BUNDLEBOT_CANCEL__ ]; then
      echo "Setup cancelled."
      exit 0
    fi
    if [ "$installer_status" = 0 ]; then
      if [ "$installer_kind" = location ]; then
        case "$installer_reply" in
          ''|1|2) ;;
          3) if [ "$(uname -s)" = Darwin ] && [ "$installer_product" = Smokeview ]; then installer_reply=invalid; fi ;;
          4) if [ "$(uname -s)" = Darwin ] || [ "$installer_product" = Smokeview ]; then installer_reply=invalid; fi ;;
          /*) ;;
          *) installer_reply=invalid ;;
        esac
        if [[ ! $installer_reply =~ ^(/[a-zA-Z0-9_./+-]+|[1-4]?)$ ]]; then
          echo "Choose a numbered destination or an absolute path using letters, numbers, /, ., _, +, or -." >&2
          exit 1
        fi
      fi
      printf -v "$installer_variable" '%s' "$installer_reply"
      return 0
    fi
    if [ "$installer_kind" != start ]; then
      echo "The installer dialog failed. Setup stopped." >&2
      exit 1
    fi
    echo "Graphical setup could not start. Using text setup." >&2
    installer_backend=
  fi

  if [ -n "$installer_prompt" ] && [ "$installer_kind" = confirm ]; then
    read -p "$installer_prompt " "$installer_variable" || exit 0
  else
    read "$installer_variable" || exit 0
  fi
}
