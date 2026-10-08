function prrange --description 'PR のコミット範囲（origin/<base>..origin/<head>）をクリップボードにコピーする'
    # 引数なしなら現在のブランチの PR を対象にする
    set -l info (gh pr view $argv[1] --json baseRefName,headRefName --jq '.baseRefName, .headRefName')
    or return 1

    set -l base $info[1]
    set -l head $info[2]

    # リモート参照が古いと範囲がずれるので、両ブランチを取得し直す
    git fetch --quiet origin $base $head
    or return 1

    set -l range "origin/$base..origin/$head"
    printf '%s' $range | pbcopy
    echo "$range をコピーしました"
end
