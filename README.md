# Dotfiles

![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![Homebrew](https://img.shields.io/badge/Homebrew-FBB040?style=flat&logo=homebrew&logoColor=black)
![Fish Shell](https://img.shields.io/badge/Fish_Shell-4AAE46?style=flat)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=flat&logo=neovim&logoColor=white)
![Tmux](https://img.shields.io/badge/Tmux-1BB91F?style=flat&logo=tmux&logoColor=white)

![Terminal screenshot](./assets/screen.png)

My personal development environment managed with [GNU Stow](https://www.gnu.org/software/stow/), [Homebrew](https://brew.sh/), and [Make](https://www.gnu.org/software/make/).

## Features

- **GNU Stow** — Symlink-based dotfile management
- **Brewfile** — Declarative package management via Homebrew Bundle
- **Makefile** — One-command setup and teardown

## Packages

### Shell & Prompt

| Package | Description |
|---------|-------------|
| [Fish](https://fishshell.com/) | User-friendly interactive shell |
| [Starship](https://starship.rs/) | Cross-shell prompt |

### Terminal

| Package | Description |
|---------|-------------|
| [Ghostty](https://ghostty.org/) | GPU-accelerated terminal emulator |
| [iTerm2](https://iterm2.com/) | macOS terminal emulator |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer |
| [workmux](https://github.com/raine/workmux) | Git worktree + tmux workflow manager |

### Editor & IDE

| Package | Description |
|---------|-------------|
| [Neovim](https://neovim.io/) | Hyperextensible text editor |
| [IntelliJ IDEA](https://www.jetbrains.com/idea/) | JetBrains IDE settings |

### CLI Tools

| Package | Description |
|---------|-------------|
| [bat](https://github.com/sharkdp/bat) | A `cat` clone with syntax highlighting |
| [eza](https://eza.rocks/) | A modern replacement for `ls` |
| [yazi](https://yazi-rs.github.io/) | Terminal file manager |
| [Claude Code](https://github.com/anthropics/claude-code) | AI coding assistant |

### System

| Package | Description |
|---------|-------------|
| [Git](https://git-scm.com/) | Version control configuration |
| [Karabiner-Elements](https://karabiner-elements.pqrs.org/) | macOS keyboard customizer (config generated via [karabiner.ts](https://github.com/evan-liu/karabiner.ts) in `karabiner-config/`) |

## Prerequisites

- macOS
- [Homebrew](https://brew.sh/)
- [Git](https://git-scm.com/)

## Installation

### Quick Start

```bash
git clone https://github.com/gunubin/dotfiles.git
cd dotfiles
make install
```

### Individual Commands

| Command | Description |
|---------|-------------|
| `make install` | Create symlinks for all packages |
| `make brew-bundle` | Install Homebrew dependencies from Brewfile |
| `make update` | Re-sync all symlinks (clean + install) |
| `make clean` | Remove all symlinks |

## Git Configuration

User-specific Git settings (name, email) should be stored in `~/.gitconfig.local`, which is **not** tracked by this repository.

```gitconfig
[user]
    name = YOUR_NAME
    email = YOUR_EMAIL
```
