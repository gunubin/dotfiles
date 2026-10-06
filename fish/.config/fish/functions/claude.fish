function claude --wraps claude --description '端末ローカルの autoMode 設定があれば --settings で読み込んで claude を起動する'
    # autoMode は ~/.claude/settings.json（PUBLICな dotfiles で管理）に書けないため、
    # 端末ローカルのファイルに分離して --settings で渡す
    set -l local_settings ~/.claude/automode.local.json
    if test -f $local_settings
        command claude --settings $local_settings $argv
    else
        command claude $argv
    end
end
