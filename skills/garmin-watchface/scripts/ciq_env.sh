# Sourced by the other scripts: finds the Connect IQ SDK bin dir and the developer key.
# Override with CIQ_HOME=/path/to/sdk/bin and CIQ_KEY=/path/to/developer_key.der
if [ -z "${CIQ_HOME:-}" ]; then
  for d in "$HOME/.Garmin/ConnectIQ/Sdks"/*/bin "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/*/bin "$HOME/.local/share/garmin"/*/bin; do
    [ -x "$d/monkeyc" ] && CIQ_HOME="$d"   # last match = newest by name
  done
fi
if [ -z "${CIQ_HOME:-}" ] || [ ! -x "$CIQ_HOME/monkeyc" ]; then
  echo "Connect IQ SDK not found. Install it with the SDK Manager, or set CIQ_HOME to its bin folder." >&2
  exit 1
fi
CIQ_KEY="${CIQ_KEY:-$HOME/.Garmin/ConnectIQ/developer_key.der}"
if [ ! -f "$CIQ_KEY" ]; then
  echo "No developer key at $CIQ_KEY. Create one (keep it private, never commit it):" >&2
  echo "  mkdir -p ~/.Garmin/ConnectIQ && openssl genrsa -out /tmp/k.pem 4096 && \\" >&2
  echo "  openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/k.pem -out $CIQ_KEY -nocrypt && rm /tmp/k.pem" >&2
  exit 1
fi
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
