function _fsi_secure_input_pid --description 'ioregが報告するSecure Input保持PIDを返す（なければ空）'
    ioreg -l -d 1 -w 0 \
        | string match -rg '"kCGSSessionSecureInputPID"=([0-9]+)' \
        | string match -rv '^0$' \
        | head -1
end

function _fsi_secure_input_enabled --description 'Secure Inputが有効なら0、無効なら1、判定不能なら2を返す'
    if not command -q python3
        return 2
    end
    command python3 -c '
import ctypes, sys
try:
    lib = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/Carbon.framework/Carbon")
    lib.IsSecureEventInputEnabled.restype = ctypes.c_bool
    sys.exit(0 if lib.IsSecureEventInputEnabled() else 1)
except Exception:
    sys.exit(2)
' 2>/dev/null
end

function _fsi_released --description 'Secure Inputが解放されていれば真'
    _fsi_secure_input_enabled
    switch $status
        case 1
            return 0
        case 0
            return 1
        case '*'
            # API判定不能: ioregにフォールバック
            set -l pid (_fsi_secure_input_pid)
            test -z "$pid"
    end
end

function _fsi_wait_released --description '指定秒数まで解放を待つ（解放されれば真）'
    set -l deadline (math (date +%s) + $argv[1])
    while true
        if _fsi_released
            return 0
        end
        if test (date +%s) -ge $deadline
            return 1
        end
        sleep 1
    end
end

function _fsi_app_name --description 'PIDから見やすいアプリ名を返す'
    set -l path (ps -p $argv[1] -o comm= 2>/dev/null | string trim)
    if test -z "$path"
        echo "(終了済みプロセス)"
        return
    end
    # /Applications/Google Chrome.app/Contents/MacOS/... -> Google Chrome
    set -l name (string match -rg '([^/]+)\.app/' -- $path | head -1)
    if test -z "$name"
        set name (basename -- $path)
    end
    echo $name
end

function _fsi_front_pid --description '最前面プロセスのPIDを返す（取得できなければ空）'
    for i in 1 2 3
        set -l out (osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null | string trim)
        if test -n "$out"
            echo $out
            return 0
        end
        sleep 0.3
    end
    return 1
end

function _fsi_ax_denied --description 'アクセシビリティ権限がない（エラー-1743）なら真'
    set -l err (osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>&1 >/dev/null)
    string match -q '*-1743*' -- "$err"
end

function _fsi_activate --description 'PIDのプロセスを最前面にする'
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $argv[1]) to true" >/dev/null 2>&1
end

function _fsi_set_visible --description 'PIDのプロセスの表示/非表示を切り替える'
    osascript -e "tell application \"System Events\" to set visible of (first process whose unix id is $argv[1]) to $argv[2]" >/dev/null 2>&1
end

function _fsi_restart_logi --description 'Logi Options+のエージェントを再起動する'
    set -l label com.logi.cp-dev-mgr
    echo "▶ Logi Options+ エージェント（$label）を再起動します..."
    if launchctl kickstart -k "gui/"(id -u)"/$label" 2>/dev/null
        echo "✅ 再起動しました"
    else
        echo "⚠️  再起動できませんでした（Logi Options+ が起動していない可能性があります）"
        return 1
    end
end

function _fsi_stuck --description 'スタック状態の案内とログアウト確認（$argv[1]=最後の保持PID/空, $argv[2]=check なら確認せず終了）'
    set -l pid $argv[1]
    echo ""
    echo "⚠️  Secure Input が有効なまま残っています（スタック状態）"
    if test -n "$pid"
        echo "   最後に保持していた PID: $pid（プロセスは既に終了しています）"
    else
        echo "   保持しているプロセスを特定できません"
    end
    echo "   保持していたアプリが解放せずに終了したため、アプリ操作では解除できません。"
    echo ""

    if test "$argv[2]" = check
        echo "   解除するにはログアウト（または再起動）が必要です。"
        return 1
    end

    read -l -P "   今すぐログアウトしますか？（開いているアプリはすべて終了します） [y/N] " answer
    if not string match -qir '^y' -- $answer
        echo "   中止しました。Appleメニュー > ログアウト、または再起動で解除できます。"
        return 1
    end
    osascript -e 'tell application "System Events" to log out' >/dev/null 2>&1
    echo "   ログアウトを要求しました。表示された確認ダイアログに応答してください。"
    return 0
end

function fix-secure-input --description 'Secure Inputを掴んだままのアプリを特定し、Logi Options+のショートカットを復旧する'
    argparse h/help c/check l/restart-logi -- $argv
    or return 2

    if set -q _flag_help
        echo "使用方法: fix-secure-input [オプション]"
        echo ""
        echo "macOSのSecure Inputを保持したままのアプリを特定し、段階的に解放する。"
        echo "Secure Inputが有効な間、Logi Options+のキーボードショートカットや"
        echo "ジェスチャー、デバイス検出が効かなくなる。"
        echo "参考: https://support.logi.com/hc/en-us/articles/360023189334"
        echo ""
        echo "保持プロセスが生きている場合の復旧の段階:"
        echo "  段階1  該当アプリにフォーカスを移して戻す（アプリは終了しない）"
        echo "  段階2  該当アプリを一度隠して再表示する"
        echo "  段階3  確認のうえアプリを終了する（それでも残れば強制終了を再確認）"
        echo ""
        echo "※ Secure Input が有効な間は他プロセスからの合成キーストロークがブロックされるため、"
        echo "   Escape送信のようなキー操作による復旧は行わない。"
        echo ""
        echo "保持プロセスが既に終了しているのにSecure Inputが有効な場合（スタック状態）は、"
        echo "アプリ操作では解除できないため、確認のうえログアウトを提案する。"
        echo ""
        echo "オプション:"
        echo "  -c, --check         診断のみ。有効なままなら終了ステータス1を返す"
        echo "  -l, --restart-logi  解放後にLogi Options+エージェントも再起動する"
        echo "  -h, --help          このヘルプを表示"
        return 0
    end

    set -l check_mode interactive
    if set -q _flag_check
        set check_mode check
    end

    set -l pid (_fsi_secure_input_pid)
    _fsi_secure_input_enabled
    set -l enabled $status # 0=有効 1=無効 2=判定不能

    # 無効、または根拠がまったくない場合は正常
    if test $enabled -eq 1; or begin
            test $enabled -eq 2; and test -z "$pid"
        end
        echo "✅ Secure Input は有効になっていません"
        if test $enabled -eq 1; and test -n "$pid"
            echo "   （ioregは PID $pid を報告していますが、これは解放済みの古い値です）"
        end
        if set -q _flag_restart_logi
            _fsi_restart_logi
        end
        return 0
    end

    # 保持プロセスが既に死んでいる/特定できない
    # 解放には数秒のラグがあるため、待ってから判定する
    if test -z "$pid"; or not kill -0 $pid 2>/dev/null
        echo "ℹ️  保持していたプロセスは既に終了しています。解放を待っています..."
        if _fsi_wait_released 10
            echo "✅ Secure Input が解放されました"
            if set -q _flag_restart_logi
                _fsi_restart_logi
            end
            return 0
        end
        _fsi_stuck "$pid" $check_mode
        return $status
    end

    set -l app (_fsi_app_name $pid)
    set -l started (ps -p $pid -o lstart= 2>/dev/null | string trim)
    echo "⚠️  Secure Input を保持中: $app (PID: $pid)"
    if test -n "$started"
        echo "   起動時刻: $started"
    end

    # 保持者が既知の常習犯なら、終了せずに直す道を案内する
    switch $app
        case '1Password*'
            echo ""
            echo "   💡 1Password のロック解除プロンプト（Touch ID / マスターパスワード）が"
            echo "      表示されたまま放置されていると Secure Input を保持し続けます。"
            echo "      プロンプトに応答するかキャンセルすれば、終了せずに解放されます。"
        case SecurityAgent loginwindow
            echo ""
            echo "   💡 システムのパスワード入力プロンプトが残っています。"
            echo "      応答するか閉じれば解放されます。"
    end

    if set -q _flag_check
        return 1
    end

    set -l released false
    set -l front_pid (_fsi_front_pid)
    set -l skip_focus false

    if test -z "$front_pid"
        if _fsi_ax_denied
            set skip_focus true
            echo ""
            echo "⚠️  アクセシビリティ権限がないため、フォーカス操作による復旧を飛ばします。"
            echo "   システム設定 > プライバシーとセキュリティ > アクセシビリティ で"
            echo "   ターミナルアプリを許可すると、アプリを終了せずに直せる場合があります。"
        else
            echo ""
            echo "ℹ️  最前面アプリを特定できませんでした。フォーカスの戻り先を Finder にします。"
        end
    end

    if not $skip_focus
        for stage in 1 2
            echo ""
            switch $stage
                case 1
                    echo "▶ 段階1: $app にフォーカスを移して戻します"
                case 2
                    echo "▶ 段階2: $app を一度隠して再表示します"
            end

            _fsi_activate $pid
            sleep 0.8
            if test $stage -eq 2
                _fsi_set_visible $pid false
                sleep 0.8
                _fsi_set_visible $pid true
                sleep 0.8
            end
            if test -n "$front_pid"
                _fsi_activate $front_pid
            else
                osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1
            end
            sleep 0.8

            if _fsi_released
                set released true
                echo "   解放されました（$app は終了していません）"
                break
            end
            echo "   まだ保持されています"
        end
    end

    if not $released
        echo ""
        echo "▶ 段階3: フォーカス操作では解放されませんでした"
        echo "   注意: アプリが解放せずに終了すると Secure Input が残り、ログアウトが必要になります。"
        read -l -P "   $app (PID: $pid) を終了しますか？ [y/N] " answer
        if not string match -qir '^y' -- $answer
            echo "   中止しました。$app を手動で終了すると解放されます。"
            return 1
        end

        echo "   $app を終了しています..."
        if not osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to quit" >/dev/null 2>&1
            kill -TERM $pid 2>/dev/null
        end

        # 最大10秒待つ
        for i in (seq 20)
            if not kill -0 $pid 2>/dev/null
                break
            end
            sleep 0.5
        end

        if kill -0 $pid 2>/dev/null
            read -l -P "   終了しませんでした。強制終了（kill -9）しますか？ [y/N] " force
            if not string match -qir '^y' -- $force
                echo "   中止しました。"
                return 1
            end
            kill -9 $pid 2>/dev/null
            sleep 1
        end

        echo "   解放を待っています..."
        if _fsi_wait_released 10
            set released true
        else
            # 終了したのに解放されない = スタック状態に移行
            _fsi_stuck "$pid" $check_mode
            return $status
        end
    end

    echo ""
    echo "✅ Secure Input が解放されました。Logi Options+ のショートカットが復旧するはずです。"
    if set -q _flag_restart_logi
        _fsi_restart_logi
    end
    return 0
end
