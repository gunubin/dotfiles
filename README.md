# Dotfiles

![screen.png](./assets/screen.png)

このリポジトリには私の開発環境の設定ファイル（dotfiles）が含まれています。Makefileを使用して簡単にインストールと管理ができるように設計されています。

## 特徴

- GNU Stowを使用したシンボリックリンク管理
- Brewfileを使用したパッケージ管理
- Makefileによる簡単なセットアップ

## 含まれるパッケージ

- starship: モダンなプロンプト
- fish: シェル
- yazi: ファイルマネージャ
- nvim: テキストエディタ
- karabiner: macOSのキーボードカスタマイズツール
- git: バージョン管理
- iterm2: ターミナルエミュレータ
- tmux: ターミナルマルチプレクサ

## 必要条件

- macOS
- [Homebrew](https://brew.sh/)
- [Git](https://git-scm.com/)

## インストール方法

### 1. リポジトリのクローン

```bash
git clone https://github.com/[username]/dotfiles.git
cd dotfiles
```

### 2. セットアップ
依存パッケージのインストールとdotfilesの設定を行います：

```bash
make install
```

これにより、以下の処理が実行されます：

- 必要なパッケージのインストール（brew-bundle）
- 設定ファイルのシンボリックリンク作成（stow-packages）

### 3. 個別のコマンド 

Brewの依存パッケージのみインストール
```bash
make brew-bundle
```


設定ファイルのリンクのみ作成

```bash
make stow-packages
```

リンクの削除（アンインストール）

```bash
make clean
```

設定の再同期

```bash
make update
```


### ~/.gitconfig.localの作成

Gitを使用する際、ユーザー名とメールアドレスは必須の設定です。個人情報はリポジトリに含めず、`~/.gitconfig.local`ファイルで管理します。

以下の内容で`~/.gitconfig.local`ファイルを作成してください：

```text
[user]
    name = YOUR_NAME
    email = YOUR_EMAIL
```