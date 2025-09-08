
function fish_greeting
  set_color cyan
  echo '
    ><((((º>'
  set_color normal
end

#######
# franciscolourenco/done
#######
set -g __done_enabled 1
set -g __done_notify_sound 1
set -g __done_min_cmd_duration 3000
set -g __done_notification_command 'echo "$message" | terminal-notifier -title "$title" -sound Pop -contentImage /Users/koki/Documents/ghostty-catppuccin-mocha.icns'

###
set U FZF_LEGACY_KEYBINDINGS 0

set -gx EDITOR nvim

#######
# fish command color
#######
set -U fish_color_command b8e5b4
set -U fish_color_error a6727b

#######
# path
#######
set -x PATH $HOME/.nodebrew/current/bin $PATH
set -x PATH $HOME/.rbenv/bin $PATH
set -x PATH /usr/local/bin $PATH
set -x JAVA_HOME /Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
# set -x NVM_DIR $HOME/.nvm

# pnpm
set -gx PNPM_HOME "/Users/koki/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

#######
# path react-native Android
#######
set -x ANDROID_HOME $HOME/Library/Android/sdk
set -x PATH $PATH $ANDROID_HOME/emulator
set -x PATH $PATH $ANDROID_HOME/platform-tools


#######
# brew
#######

eval $(/opt/homebrew/bin/brew shellenv)

######
# Load rbenv automatically by appending
# # the following to ~/.config/fish/config.fish:
######
status --is-interactive; and source (rbenv init -|psub)

#######
# alias
#######
alias dkc='docker-compose'
alias y='yazi'
alias p='pnpm'

#######
# eza
#######
set -Ux EZA_CONFIG_DIR ~/.config/eza
alias ei="eza --icons --git"
alias ea="eza -a --icons --git"
alias ee="eza -aahl --icons --git"
alias et="eza -T -L 3 -a -I 'node_modules|.git|.cache' --icons"
alias eta="eza -T -a -I 'node_modules|.git|.cache' --color=always --icons | less -r"
alias ls=ei
alias la=ea
alias ll=ee
alias lt=et
alias lta=eta
alias l="clear && ls"

alias vim="nvim"

# tmux関連のエイリアス
alias tls='tmux ls'
alias ta='tmux attach-session -t'
alias tk='tmux kill-session -t'
alias tka='tmux kill-server'  # 全セッション削除（注意して使用）


#######
# fzf
#######
#   --color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284
#   --color=border:#303446,label:#C6D0F5
set -x FZF_DEFAULT_OPTS '
  --style=full
  --tmux 70%
  --padding=0,0
  --input-label=" Input "
  --preview="fzf-preview.sh {}"
  --no-border

  --color=spinner:#F2D5CF,hl:#E78284
  --color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF
  --color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284
  --color=bg+:#51576D
  --color=border:#303446,label:#C6D0F5

  --color=preview-border:#9999cc,preview-label:#ccccff
  --color=list-border:#bfe7bb,list-label:#99cc99
  --color=input-border:#f6cce7,input-label:#ffcccc
'

function go_parent_directory --description 'Go to parent directory'
  cd ..
  commandline -f repaint
end

function go_back_directory --description 'Go to previous directory'
  prevd
  # cd -
  commandline -f repaint
end

function go_next_directory --description 'Go to previous directory'
  # cd -
  nextd
  commandline -f repaint
end

# キーバインド設定
#bind --erase \cu
bind \cu 'go_parent_directory'   # Ctrl+U
bind \co 'go_back_directory'     # Ctrl+O
bind \e\ci 'go_next_directory'     # Ctrl+I

bind \ci complete


#######
# dirh
#######
# option + [ でディレクトリを戻る
# bind \e\[ prevd-or-backward-word
# option + ] でディレクトリを進む
# bind \e\] nextd-or-forward-word


#######
# tmux
#######
if status is-interactive
and not set -q TMUX
  # JetBrains IDEのターミナルでは起動しない
  if not set -q TERMINAL_EMULATOR
    # 既存のセッションがあれば最初のセッションにアタッチ、なければ新規作成
    if tmux has-session 2>/dev/null
      # 最初のセッション番号を取得してアタッチ
      set first_session (tmux ls -F "#{session_name}" | head -n1)
      exec tmux attach-session -t $first_session
    else
      exec tmux new-session
    end
  end
end


#######
# tab for fzf
#######
# fzf補完をTABにバインドする（イベント駆動で）
function __fzf_tab_complete --on-event fish_prompt
    bind \t '__fzf_complete_token'
end

#######
# direnv
#######
#eval (direnv hook fish)

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/koki/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/Users/koki/Downloads/google-cloud-sdk/path.fish.inc'; end

# set -gx VOLTA_HOME "$HOME/.volta"
# set -gx PATH "$VOLTA_HOME/bin" $PATH

# nvm のデフォルトバージョンを設定
set --universal nvm_default_version v22.14.0

# zの代替
zoxide init fish | source

function zf --description 'zoxide + fzf + eza preview'
  set selected (
    zoxide query -ls |
    fzf --preview 'eza --icons --color=always (echo {} | awk \'{print $2}\') | head -20' |
    awk '{print $2}'
  )
  if test -n "$selected"
    cd $selected
  end
  commandline -f repaint
end

bind \cj 'zf'

# cdコマンドをzoxideで置き換え
function cd
  z $argv
end


#######
# starship
#######
starship init fish | source



alias claude="/Users/koki/.claude/local/claude"
