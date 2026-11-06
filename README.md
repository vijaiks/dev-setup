# dev-setup

[![CI](https://github.com/vijaiks/dev-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/vijaiks/dev-setup/actions/workflows/ci.yml)

One script that sets up a **C / C++ / Go / Python** development environment on **WSL Ubuntu 24.04**.
It works on Intel/AMD (x86_64) and ARM (Snapdragon, aarch64) laptops, and it's safe to re-run.

## What gets installed

| Area | Tools |
|---|---|
| Base | build-essential, git, curl, wget, vim, nano, jq, build libraries (ssl, ffi, sqlite, zlib…) |
| C / C++ | gcc-14 / g++-14 (default), clang, clangd, clang-format, clang-tidy, lldb, lld, cmake, ninja, gdb, valgrind, ccache, bear |
| Go | Latest stable from go.dev (correct CPU arch, SHA256 verified) + gopls, dlv, staticcheck, govulncheck |
| Python | [uv](https://docs.astral.sh/uv/) + Python 3.13 and 3.14 side by side, ruff, ipython. System Python 3.12 is left untouched. |
| Utilities | htop, tree, ripgrep (`rg`), fd (`fd`), bat (`bat`), shellcheck |
| Git | `init.defaultBranch main`, `pull.rebase true`, `core.autocrlf input`, Windows Git Credential Manager (if installed) |

## Quick start

### 1. Install WSL (once, in PowerShell as Administrator)
```powershell
wsl --install -d Ubuntu-24.04
```
Open **Ubuntu 24.04** from the Start menu and create your Linux user.

### 2. Run the script (in the Ubuntu terminal)
```bash
git clone https://github.com/vijaiks/dev-setup.git
cd dev-setup
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" ./setup-dev.sh
source ~/.bashrc
```

> Don't use `sudo ./setup-dev.sh`. The script calls `sudo` itself where it needs to.
> With `sudo` in front, your tools would install under `/root`.

If you leave out `GIT_NAME` / `GIT_EMAIL`, the script keeps your existing git config.

**One-line install** (no clone; read the script first if you don't know the author):
```bash
curl -fsSL https://raw.githubusercontent.com/vijaiks/dev-setup/main/setup-dev.sh | GIT_NAME="Your Name" GIT_EMAIL="you@example.com" bash
```

### Options
Set any of these before running:

| Variable | Default | Example |
|---|---|---|
| `GIT_NAME` / `GIT_EMAIL` | keep existing | `GIT_NAME="Ana"` |
| `PY_VERSIONS` | `3.13 3.14` | `PY_VERSIONS="3.12 3.13 3.15"` |
| `PY_DEFAULT` | `3.13` | `PY_DEFAULT=3.14` |
| `GO_VERSION` | latest | `GO_VERSION=1.26.5` |
| `SKIP_UPGRADE` | `0` | `SKIP_UPGRADE=1` (skip `apt upgrade` on re-runs) |

## Verify
```bash
gcc --version && go version && uv --version
uv run --python 3.13 python --version
python3 --version   # still 3.12 = system python, leave it alone
```

## Python: how to work after setup

**New project (recommended)**
```bash
uv init myproj && cd myproj
uv add requests pandas      # creates .venv + uv.lock automatically
uv run main.py
uv python pin 3.14          # use 3.14 for this project only
```

**Existing repo with requirements.txt**
```bash
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt
```

**Classic pip + venv also works**
```bash
python3.13 -m venv .venv && source .venv/bin/activate
pip install requests
```

Never `pip install` outside a venv. Ubuntu 24.04 blocks it (`externally-managed-environment`).

## Design choices

- **The system `python3` is never replaced.** Ubuntu tools (`apt` add-ons, `add-apt-repository`) need Python 3.12. Replacing it breaks them.
- **Python comes from uv, not the deadsnakes PPA.** uv's Pythons work on x86_64 and ARM, include pip and venv, and don't touch system packages.
- **Go comes from the official tarball, not apt.** apt's Go is old. The script picks amd64 or arm64 automatically.
- **apt runs non-interactively.** That way it doesn't stop at the needrestart prompt on Ubuntu 24.04.

## GitHub SSH setup (push without passwords)
GitHub doesn't accept your account password for `git push`. Use an SSH key:
```bash
ssh-keygen -t ed25519 -C "you@example.com"   # press Enter at every prompt
cat ~/.ssh/id_ed25519.pub                    # copy this line
```
Add it at <https://github.com/settings/ssh/new>, then:
```bash
ssh -T git@github.com                        # type "yes" -> "Hi <user>! ..."
git clone git@github.com:<user>/<repo>.git   # use SSH URLs from now on
git remote set-url origin git@github.com:<user>/<repo>.git   # convert an HTTPS clone
```

| Error | Fix |
|---|---|
| `Password authentication is not supported` | Switch to SSH (above), or use a Personal Access Token as the password |
| `Permission denied (publickey)` | The key isn't added to GitHub, or it was added to a different account |
| `Repository not found` | Create the repo on GitHub first, and check `git remote -v` for typos |
| `port 22: Connection timed out` | Your network blocks SSH. Add `Host github.com` / `Hostname ssh.github.com` / `Port 443` to `~/.ssh/config` |

## WSL tips
- Keep code under `~/` (Linux filesystem), not `/mnt/c/...`. It's much faster.
- Install VS Code on Windows plus the **WSL** extension, then run `code .` from Ubuntu.
- If WSL has no internet, run `wsl --shutdown` in PowerShell and reopen Ubuntu.

## Troubleshooting

| Error | Fix |
|---|---|
| `/usr/bin/env: 'bash\r'` | `sed -i 's/\r$//' setup-dev.sh` (Windows line endings) |
| `Permission denied` | `chmod +x setup-dev.sh` |
| `go: command not found` | `source ~/.bashrc` or open a new terminal |
| `Temporary failure resolving` | `wsl --shutdown` in PowerShell, reopen Ubuntu |

## License
MIT. See [LICENSE](LICENSE).
