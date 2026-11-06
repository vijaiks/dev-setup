#!/usr/bin/env bash
# ============================================================
# WSL Ubuntu 24.04 - Dev Setup Script (reviewed / fixed)
# C / C++ / Go / Python + Dev Tools
# Works on x86_64 (Intel/AMD) AND arm64 (Snapdragon Surface)
# Usage:
#   ./setup-dev.sh
#   GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./setup-dev.sh
# Safe to re-run (idempotent).
# ============================================================
set -euo pipefail

# ---------- Settings you may want to change ----------
# All can be overridden from the environment, e.g. PY_DEFAULT=3.14 ./setup-dev.sh
GIT_NAME="${GIT_NAME:-}"                 # empty = keep existing git config
GIT_EMAIL="${GIT_EMAIL:-}"               # empty = keep existing git config
PY_VERSIONS="${PY_VERSIONS:-3.13 3.14}"  # uv installs these side-by-side
PY_DEFAULT="${PY_DEFAULT:-3.13}"         # version 'python' points to (via uv)
GO_VERSION="${GO_VERSION:-}"             # empty = latest stable from go.dev
SKIP_UPGRADE="${SKIP_UPGRADE:-0}"        # 1 = skip "apt upgrade" (faster re-runs / CI)
# -----------------------------------------------------

# Never let apt stop and ask questions (needrestart prompt on 24.04)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT="sudo -E apt-get -y -o Dpkg::Options::=--force-confold"

# Detect CPU: Surface Laptop 7 is ARM (Snapdragon) -> arm64
ARCH="$(dpkg --print-architecture)"      # amd64 or arm64
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

step() { echo; echo "==== $* ===="; }

# 1. Update + base tools --------------------------------------
step "[1/7] System update + base tools ($ARCH)"
$APT update
if [[ "$SKIP_UPGRADE" != "1" ]]; then $APT upgrade; fi
$APT install build-essential curl wget git vim nano unzip zip \
  ca-certificates gnupg pkg-config jq \
  libssl-dev libffi-dev libsqlite3-dev zlib1g-dev \
  libbz2-dev liblzma-dev libreadline-dev \
  python3-pip python3-venv      # pip/venv for SYSTEM python 3.12 only

# 2. C / C++ ---------------------------------------------------
# Ubuntu 24.04 default: gcc 13, clang 18. gcc-14 adds better C++20/23.
step "[2/7] C/C++ toolchain"
$APT install gcc-14 g++-14 \
  clang clang-format clang-tidy clangd lldb lld \
  cmake ninja-build gdb valgrind ccache bear
# Make gcc-14 the default 'gcc'/'g++' (gcc-13 stays installed)
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 140 \
  --slave /usr/bin/g++ g++ /usr/bin/g++-14

# 3. Go (official tarball, correct arch, checksum verified) ----
step "[3/7] Go"
if [[ -z "$GO_VERSION" ]]; then
  GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1 | sed 's/^go//')"
fi
GO_TGZ="go${GO_VERSION}.linux-${ARCH}.tar.gz"

if command -v /usr/local/go/bin/go >/dev/null && \
   [[ "$(/usr/local/go/bin/go env GOVERSION)" == "go${GO_VERSION}" ]]; then
  echo "Go ${GO_VERSION} already installed, skipping."
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL -o "$TMP/$GO_TGZ" "https://go.dev/dl/$GO_TGZ"
  # Verify SHA256 against go.dev's published list
  EXPECTED="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' \
    | jq -r --arg f "$GO_TGZ" '.[].files[] | select(.filename==$f) | .sha256')" || true
  if [[ -n "${EXPECTED:-}" ]]; then
    echo "$EXPECTED  $TMP/$GO_TGZ" | sha256sum -c -
  else
    echo "WARN: could not fetch checksum, skipping verify"
  fi
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$TMP/$GO_TGZ"
fi

# PATH for Go + user-local bins (added once).
# Written to login files too: Ubuntu's ~/.bashrc exits early in
# non-interactive shells (scripts, cron, editor tasks).
RCS=(~/.bashrc ~/.profile)
[[ -f ~/.bash_profile ]] && RCS+=(~/.bash_profile)   # bash -l reads this INSTEAD of ~/.profile
for rc in "${RCS[@]}"; do
  touch "$rc"
  if ! grep -q '# >>> dev-setup PATH >>>' "$rc"; then
    cat >> "$rc" <<'EOF'
# >>> dev-setup PATH >>>
case ":$PATH:" in
  *":/usr/local/go/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH" ;;
esac
# <<< dev-setup PATH <<<
EOF
  fi
done
export PATH="$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

# Go dev tools: language server, debugger, linter, vuln check
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

# 4. Python via uv (NO deadsnakes, NO touching system python3) --
# System python3 (3.12) is used by apt & Ubuntu tools - leave it alone.
step "[4/7] Python via uv"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
uv self update || true
# shellcheck disable=SC2086
uv python install $PY_VERSIONS
uv python install "$PY_DEFAULT" --default \
  || uv python install --preview "$PY_DEFAULT" --default || true   # puts python/python3.13 in ~/.local/bin
uv tool install ruff || uv tool upgrade ruff
uv tool install ipython || true

# 5. Extra dev tools -------------------------------------------
step "[5/7] Extra dev tools"
$APT install htop tree ripgrep fd-find bat shellcheck
# Ubuntu renames these: fdfind -> fd, batcat -> bat
mkdir -p ~/.local/bin
ln -sf "$(command -v fdfind)" ~/.local/bin/fd
ln -sf "$(command -v batcat)" ~/.local/bin/bat

# 6. Git config ------------------------------------------------
step "[6/7] Git config"
if [[ -n "$GIT_NAME" ]];  then git config --global user.name  "$GIT_NAME";  fi
if [[ -n "$GIT_EMAIL" ]]; then git config --global user.email "$GIT_EMAIL"; fi
if ! git config --global user.email >/dev/null; then
  echo "NOTE: git user not set. Run:"
  echo '  git config --global user.name  "Your Name"'
  echo '  git config --global user.email "you@example.com"'
fi
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input          # avoid CRLF mess from Windows
# Reuse Windows Git Credential Manager if Git for Windows is installed
GCM="/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
if [[ -f "$GCM" ]]; then
  git config --global credential.helper "$GCM"
fi

# 7. Verify ----------------------------------------------------
step "[7/7] Verify"
v() { printf '%-14s' "$1"; shift; "$@" 2>&1 | head -1 || echo "MISSING"; }
v "Arch:"     uname -m
v "gcc:"      gcc --version
v "g++:"      g++ --version
v "clang:"    clang --version
v "cmake:"    cmake --version
v "Go:"       go version
v "gopls:"    gopls version
v "uv:"       uv --version
v "python:"   uv run --python "$PY_DEFAULT" python --version
v "sys py3:"  /usr/bin/python3 --version
v "Git:"      git --version

echo
echo "Done! Run: source ~/.bashrc   (or open a new terminal)"
echo "Python tip: per project ->  uv init myproj && cd myproj && uv add requests"
