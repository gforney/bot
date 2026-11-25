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
  local kind=$1 prompt=$2 action=$3 selection status index destination
  shift 3

  if [ "$installer_backend" = zenity ]; then
    case "$kind" in
      start)
        selection=$(zenity --question --title="$installer_product" --text="$prompt" \
          --ok-label=Install --cancel-label=Cancel --extra-button="Extract Only")
        status=$?
        if [ "$selection" != "Extract Only" ]; then
          [ "$status" = 0 ] || return "$status"
          selection=Install
        fi ;;
      confirm)
        zenity --question --title="$installer_product" --text="$prompt" \
          --no-markup --ok-label="$action" --cancel-label=Cancel || return "$?"
        selection=$action ;;
      location)
        selection=$(zenity --list --title="$installer_product" --text="$prompt" \
          --column=Destination --ok-label=Continue "$@") || return "$?" ;;
      folder)
        zenity --file-selection --directory --title="$prompt"
        return "$?" ;;
    esac
  else
    selection=$(osascript - "$installer_product" "$kind" "$prompt" "$action" "$@" <<'APPLESCRIPT'
on run argv
  set windowTitle to item 1 of argv
  set dialogKind to item 2 of argv
  set promptText to item 3 of argv
  set actionLabel to item 4 of argv
  try
    if dialogKind is "start" then
      return button returned of (display dialog promptText with title windowTitle buttons {"Cancel", "Extract Only", "Install"} default button "Install" cancel button "Cancel")
    else if dialogKind is "confirm" then
      return button returned of (display dialog promptText with title windowTitle buttons {"Cancel", actionLabel} default button "Cancel" cancel button "Cancel")
    else if dialogKind is "location" then
      set destinations to items 5 thru -1 of argv
      set selectedItem to choose from list destinations with title windowTitle with prompt promptText default items {item 1 of destinations} OK button name "Continue"
      if selectedItem is false then return "__BUNDLEBOT_CANCEL__"
      return item 1 of selectedItem
    else if dialogKind is "folder" then
      return POSIX path of (choose folder with prompt promptText)
    end if
  on error number -128
    return "__BUNDLEBOT_CANCEL__"
  end try
end run
APPLESCRIPT
    ) || return "$?"
  fi

  if [ "$selection" = __BUNDLEBOT_CANCEL__ ]; then
    printf '%s\n' "$selection"
    return
  fi
  case "$kind" in
    start)
      case "$selection" in
        Install) echo 1 ;;
        "Extract Only") echo 2 ;;
        *) return 2 ;;
      esac ;;
    confirm) echo yes ;;
    location)
      index=1
      for destination in "$@"; do
        if [ "$selection" = "$destination" ]; then
          if [ "$destination" = "Choose Folder…" ]; then
            installer_dialog folder "$action" ""
          else
            echo "$index"
          fi
          return "$?"
        fi
        index=$((index + 1))
      done
      return 2 ;;
    folder) printf '%s\n' "$selection" ;;
  esac
}

installer_read() {
  local installer_kind=$1 installer_variable=$2 installer_prompt=${3:-}
  local installer_gui_prompt installer_action=${4:-} installer_reply installer_error installer_status
  local installer_choices=()
  if [ -n "$installer_backend" ]; then
    case "$installer_kind" in
      start)
        installer_prompt="Install $installer_product or extract the archive." ;;
      location)
        installer_prompt="Select an installation location."
        if [ "$installer_product" = "FDS and Smokeview" ]; then
          installer_action="Choose a folder in which to create $installer_default_dir."
        else
          installer_action="Choose the existing FDS and Smokeview installation folder."
        fi
        if [ "$installer_backend" = osascript ]; then
          installer_choices=("/Applications/$installer_default_dir" "$HOME/$installer_default_dir")
          if [ "$installer_product" = "FDS and Smokeview" ]; then
            installer_choices+=("/Applications/FDS/$installer_custom_base")
          fi
        else
          installer_choices=("$HOME/$installer_default_dir" "/opt/$installer_default_dir" "/usr/local/bin/$installer_default_dir")
          if [ "$installer_product" = "FDS and Smokeview" ]; then
            installer_choices+=("$HOME/FDS/$installer_custom_base")
          fi
        fi
        installer_choices+=("Choose Folder…") ;;
    esac

    installer_gui_prompt=${installer_prompt%" (yes/no)"}
    installer_error=$(mktemp "${TMPDIR:-/tmp}/bundlebot-dialog.XXXXXX")
    if [ -z "$installer_error" ]; then
      installer_status=2
    else
      installer_reply=$(installer_dialog "$installer_kind" "$installer_gui_prompt" "$installer_action" "${installer_choices[@]}" 2>"$installer_error")
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
        if [[ $installer_reply = /* ]]; then
          if [ "$installer_product" = "FDS and Smokeview" ]; then
            installer_reply="${installer_reply%/}/$installer_default_dir"
          fi
          if [[ ! $installer_reply =~ ^/[a-zA-Z0-9_./+-]+$ ]]; then
            echo "The selected path must use only letters, numbers, /, ., _, +, or -." >&2
            exit 1
          fi
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
