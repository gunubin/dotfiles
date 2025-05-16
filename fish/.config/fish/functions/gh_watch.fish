function gh_watch
    if test (count $argv) -eq 0
        echo "使用方法: gh_watch \"ワークフロー名\" [間隔(秒)]"
        return 1
    end

    set workflow_name $argv[1]
    set interval 5  # デフォルト間隔は10秒

    if test (count $argv) -ge 2
        set interval $argv[2]
    end

    set run_id (gh run list --workflow $workflow_name --limit 1 --json databaseId --jq ".[0].databaseId")

    if test -z "$run_id"
        echo "エラー: '$workflow_name'という名前のワークフローの実行が見つかりませんでした。"
        return 1
    end

    echo "$workflow_name (ID: $run_id) を$interval秒間隔で監視します..."
    gh run watch $run_id -i$interval
end