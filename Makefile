# dotfilesのセットアップと管理用Makefile

# 環境変数の定義
DOTFILES := $(shell pwd)
HOME_DIR := $(HOME)
STOW := $(shell command -v stow 2>/dev/null)
PACKAGES := bat claude eza fish git ghostty idea iterm2 karabiner maintenance nvim starship tmux workmux yazi

# stowコマンド用の共通オプション
STOW_VERBOSE := -v
STOW_TARGET := -t $(HOME_DIR)

# デフォルトターゲット
.PHONY: all
all: install

#
# stow関連のコマンド
#

# stowがインストールされているか確認
.PHONY: check-stow
check-stow:
	@if [ -z "$(STOW)" ]; then \
		echo "エラー: stowがインストールされていません。"; \
		echo "インストール方法: brew install stow"; \
		exit 1; \
	fi

# 各パッケージをstowでリンク
.PHONY: stow-packages
stow-packages: check-stow
	@echo "パッケージをリンクしています..."
	@for package in $(PACKAGES); do \
		echo "リンク作成: $$package"; \
		stow $(STOW_VERBOSE) -R $(STOW_TARGET) $$package; \
	done
	@echo "すべてのパッケージのリンクが完了しました"

# リンクを削除
.PHONY: clean
clean: check-stow
	@echo "既存のリンクを削除しています..."
	@for package in $(PACKAGES); do \
		echo "リンク削除: $$package"; \
		stow $(STOW_VERBOSE) -D $(STOW_TARGET) $$package; \
	done
	@echo "リンク削除が完了しました"

#
# インストールと更新のコマンド
#

# インストール処理
.PHONY: install
install: stow-packages gitignore-init hooks-init launchd-init
	@echo "dotfilesのインストールが完了しました！"

# グローバルgitignoreの初回セットアップ
# ~/.config/git/ignore をデフォルトテンプレートとして ~/.gitignore にコピー
# 既存ファイルがある場合は上書きしない
.PHONY: gitignore-init
gitignore-init:
	@if [ ! -f $(HOME_DIR)/.gitignore ]; then \
		cp $(DOTFILES)/git/.config/git/ignore $(HOME_DIR)/.gitignore; \
		echo "~/.gitignore を作成しました"; \
	else \
		echo "~/.gitignore は既に存在します"; \
	fi

# パッケージ更新（再同期）
.PHONY: update
update: clean install
	@echo "パッケージを再同期しました"

#
# Homebrew関連のコマンド
#

# Homebrewがインストールされているか確認
.PHONY: check-brew
check-brew:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "エラー: Homebrewがインストールされていません。"; \
		echo "インストール方法: https://brew.sh"; \
		exit 1; \
	fi

# Brewfileからパッケージをインストール
.PHONY: brew-bundle
brew-bundle: check-brew
	@echo "Brewfileからパッケージをインストールしています..."
	@brew bundle install --file=Brewfile
	@echo "Brewfileのインストールが完了しました"

# フルセットアップ（クリーンマシン用）
.PHONY: setup
setup: brew-bundle install
	@echo "フルセットアップが完了しました！"

# 現在インストールされているパッケージからBrewfileを作成
.PHONY: brew-dump
brew-dump: check-brew
	@echo "現在のパッケージからBrewfileを作成しています..."
	@brew bundle dump --force
	@echo "Brewfileの作成が完了しました"

# リポジトリ同梱の git hooks を有効化
.PHONY: hooks-init
hooks-init:
	@git -C $(DOTFILES) config core.hooksPath .githooks
	@echo "core.hooksPath を .githooks に設定しました"

# launchd のジョブ（ディスクの掃除・空き容量の通知）を登録
# launchd はシンボリックリンクの plist を嫌うのでコピーして読み込み直す
.PHONY: launchd-init
launchd-init:
	@for plist in $(DOTFILES)/launchd/*.plist; do \
		name=$$(basename $$plist .plist); \
		cp $$plist $(HOME_DIR)/Library/LaunchAgents/; \
		launchctl bootout gui/$$(id -u)/$$name 2>/dev/null; \
		launchctl bootstrap gui/$$(id -u) $(HOME_DIR)/Library/LaunchAgents/$$name.plist; \
		echo "launchd に登録: $$name"; \
	done
