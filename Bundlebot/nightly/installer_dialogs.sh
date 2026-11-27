# Included in the self-extracting installer before the text setup code.
installer_backend=
case ${1:-} in
  --text) shift; installer_gui=0 ;;
  y) installer_gui=0 ;;
esac
if [ "$installer_gui" = 1 ]; then
  if [ "$(uname -s)" = Darwin ] && command -v osascript >/dev/null 2>&1; then
    installer_backend=osascript
  elif [ "$(uname -s)" = Linux ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    # Use the system Python so virtual environments do not hide desktop bindings.
    installer_python=/usr/bin/python3
    if [ ! -x "$installer_python" ]; then
      installer_python=$(command -v python3)
    fi
    if [ -n "$installer_python" ] && "$installer_python" -I -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' >/dev/null 2>&1; then
      installer_backend=gtk
    elif command -v zenity >/dev/null 2>&1; then
      installer_backend=zenity
    fi
  fi
fi

installer_start_gtk() {
  local gtk_code
  gtk_code=$(cat <<'PYTHON'
import os
import sys

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

if not Gtk.init_check()[0]:
    sys.exit("GTK could not open the display")

dialog = Gtk.Dialog(title=sys.argv[1])
dialog.set_default_size(480, 240)
content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
content.set_border_width(12)
dialog.get_content_area().pack_start(content, True, True, 0)

def position_dialog(window, _event):
    window.move(48, 48)
    return False

dialog.connect("map-event", position_dialog)
dialog.connect("delete-event", lambda window, _event: window.response(Gtk.ResponseType.CANCEL) or True)
pending = bytearray()
request = []
loop = GLib.MainLoop()
cancel = "__BUNDLEBOT_CANCEL__"

def send_reply(text):
    sys.stdout.buffer.write(os.fsencode(text) + b"\0")
    sys.stdout.buffer.flush()

def show_step(kind, prompt, action, *choices):
    for box in (content, dialog.get_action_area()):
        for child in box.get_children():
            child.destroy()
    label = Gtk.Label(label=prompt)
    label.set_line_wrap(True)
    content.add(label)
    dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)

    chooser = None
    locations = None
    if kind == "start":
        dialog.add_button("Extract Only", 1)
        dialog.add_button("Install", Gtk.ResponseType.OK)
    elif kind == "confirm":
        dialog.add_button(action, Gtk.ResponseType.OK)
    elif kind == "location":
        locations = Gtk.ComboBoxText()
        for choice in choices:
            locations.append_text(choice)
        locations.set_active(0)
        content.add(locations)
        dialog.add_button("Continue", Gtk.ResponseType.OK)
    else:
        chooser = Gtk.FileChooserWidget(action=Gtk.FileChooserAction.SELECT_FOLDER)
        content.pack_start(chooser, True, True, 0)
        dialog.add_button("Choose Folder", Gtk.ResponseType.OK)

    def respond(window, response):
        if response == 1 and kind == "start":
            selection = "Extract Only"
        elif response != Gtk.ResponseType.OK:
            selection = cancel
        elif kind == "location":
            selection = locations.get_active_text()
        elif kind == "folder":
            selection = chooser.get_filename()
            if selection is None:
                return
        elif kind == "start":
            selection = "Install"
        else:
            selection = action
        window.disconnect(handler)
        window.set_sensitive(False)
        send_reply(selection or cancel)

    handler = dialog.connect("response", respond)
    dialog.set_default_response(Gtk.ResponseType.CANCEL)
    dialog.set_sensitive(True)
    dialog.show_all()

def read_request(_source, _condition):
    data = os.read(0, 65536)
    if not data:
        loop.quit()
        return False
    pending.extend(data)
    while b"\0" in pending:
        field, _, rest = pending.partition(b"\0")
        pending[:] = rest
        request.append(os.fsdecode(bytes(field)))
        if len(request) == int(request[0]) + 1:
            show_step(*request[1:])
            request.clear()
    return True

GLib.io_add_watch(0, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, read_request)
loop.run()
PYTHON
  ) || return 1

  # The worker is Linux-only. Keep coproc syntax out of the macOS Bash parser.
  # Duplicate its descriptors so dialog calls can use them in a subshell.
  eval '
    coproc INSTALLER_GTK {
      GDK_BACKEND="${GDK_BACKEND:-x11,wayland}" "$installer_python" -I -c "$gtk_code" "$installer_product"
    }
    exec 8<&"${INSTALLER_GTK[0]}" 9>&"${INSTALLER_GTK[1]}"
  '
}

installer_gtk_dialog() {
  local reply
  printf '%s\0' "$#" "$@" >&9 || return 1
  IFS= read -r -d '' reply <&8 || return 1
  printf '%s\n' "$reply"
}

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
  elif [ "$installer_backend" = gtk ]; then
    selection=$(installer_gtk_dialog "$kind" "$prompt" "$action" "$@") || return "$?"
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
  if [ "$installer_backend" = gtk ] && [ "$installer_kind" = start ]; then
    if ! installer_start_gtk; then
      echo "Graphical setup could not start. Using text setup." >&2
      installer_backend=
    fi
  fi
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

  case "$installer_kind" in
    start) installer_text_start ;;
    location) installer_text_location ;;
  esac
  if [ -n "$installer_prompt" ] && [ "$installer_kind" = confirm ]; then
    read -p "$installer_prompt " "$installer_variable" || exit 0
  else
    read "$installer_variable" || exit 0
  fi
}
