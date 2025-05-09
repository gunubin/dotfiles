#######
# starship
#######
starship init fish | source

set U FZF_LEGACY_KEYBINDINGS 0

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
alias y='yarn'
alias p='pnpm'

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

#######
# https://github.com/oh-my-fish/oh-my-fish/blob/master/docs/Themes.md#bobthefish
#######
set -g theme_powerline_fonts yes
#set -g theme_nerd_fonts yes
set -g theme_display_docker_machine yes
#set -g theme_display_vi yes

#######
# fzf
#######
#set FZF_DEFAULT_OPTS '--height 40% --reverse --select-1'
#set -x FZF_DEFAULT_OPTS '--style full --tmux 80%'
set -x FZF_DEFAULT_OPTS '
  --style=full
  --tmux 80%
  --border=none
  --padding=1,2
  --input-label=" Input "
  --preview="fzf-preview.sh {}"
  --color=border:#aaaaaa,label:#cccccc
  --color=preview-border:#9999cc,preview-label:#ccccff
  --color=list-border:#669966,list-label:#99cc99
  --color=input-border:#996666,input-label:#ffcccc
'

#######
# http://ka2n.hatenablog.com/entry/2017/01/09/fish_shell%E3%81%A7z%E3%81%AE%E7%B5%90%E6%9E%9C%E3%82%92peco%E3%81%A3%E3%81%A6%E7%88%86%E9%80%9F%E3%81%A7%E3%83%87%E3%82%A3%E3%83%AC%E3%82%AF%E3%83%88%E3%83%AA%E7%A7%BB%E5%8B%95%E3%81%99%E3%82%8B
#######
#function fzf-z
#    set -l query (commandline)
#
#    if test -n $query
#    set fzf_flags --query "$query"
#    end
#
#    z -l | fzf --reverse --select-1 --height 40% $fzf_flags | awk '{ print $2 }' | read recent
#    if [ $recent ]
#        cd $recent
#        commandline -r ''
#        commandline -f repaint
#    end
#end
#bind \cj 'zi'
#function zoxid_i
# zi
#  commandline -f repaint
#end
#bind \cj 'zoxid_i'

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
    exec tmux
end


#######
# direnv
#######
#set -x EDITOR vim
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

