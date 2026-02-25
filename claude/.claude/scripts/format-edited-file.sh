#!/bin/bash

# ログ出力設定（デフォルト: OFF）
# 有効にするには: export CLAUDE_HOOK_LOGGING=true
ENABLE_LOGGING=${CLAUDE_HOOK_LOGGING:-false}

# ログ出力関数
log_message() {
    if [ "$ENABLE_LOGGING" = "true" ]; then
        echo "$1" >> ~/.claude/format-hook.log
    fi
}

# PostToolUseフックから渡されるJSONを読み込む
json_input=$(cat)

# ツール名を取得
tool_name=$(echo "$json_input" | jq -r '.tool_name')

# Edit, MultiEdit, Writeツールの場合のみ処理
if [[ "$tool_name" =~ ^(Edit|MultiEdit|Write)$ ]]; then
    # ファイルパスを取得
    file_path=$(echo "$json_input" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    
    # ファイルパスが取得できた場合
    if [ -n "$file_path" ] && [ -f "$file_path" ]; then
        # ファイルの拡張子を取得
        extension="${file_path##*.}"
        
        # ファイルが存在するディレクトリを取得
        file_dir=$(dirname "$file_path")
        
        # プロジェクトルートを探す（package.jsonがある場所を探す）
        project_root=""
        current_dir="$file_dir"
        while [ "$current_dir" != "/" ]; do
            if [ -f "$current_dir/package.json" ]; then
                project_root="$current_dir"
                break
            fi
            current_dir=$(dirname "$current_dir")
        done
        
        # プロジェクトルートが見つかった場合
        if [ -n "$project_root" ]; then
            cd "$project_root"
            
            # package.jsonにformatスクリプトがあるか確認
            has_format=$(jq -r '.scripts["format"] // ""' package.json)
            
            if [ -n "$has_format" ]; then
                # TypeScript/JavaScriptファイルの場合
                if [[ "$extension" =~ ^(ts|tsx|js|jsx|mjs|cjs)$ ]]; then
                    # macOS対応: 相対パスを手動で計算
                    if [[ "$file_path" == "$project_root"* ]]; then
                        relative_path="${file_path#$project_root/}"
                    else
                        relative_path="$file_path"
                    fi
                    
                    # 相対パスが空でないことを確認
                    if [ -n "$relative_path" ] && [ -f "$project_root/$relative_path" ]; then
                        # formatを実行（ファイルパスをクォート）
                        log_message "[$(date)] Running format on: $relative_path"
                        if [ "$ENABLE_LOGGING" = "true" ]; then
                            npm run format -- "$relative_path" 2>&1 >> ~/.claude/format-hook.log
                        else
                            npm run format -- "$relative_path" 2>&1 > /dev/null
                        fi
                        
                        # 結果をログ出力
                        log_message "[$(date)] Formatted: $file_path (project: $project_root)"
                    else
                        log_message "[$(date)] Invalid relative path: $relative_path (file: $file_path)"
                    fi
                fi
            else
                log_message "[$(date)] No format script found in $project_root"
            fi
        else
            log_message "[$(date)] No project root found for $file_path"
        fi
    else
        log_message "[$(date)] File not found or invalid path: $file_path"
    fi
fi

# 常に成功として終了（フックがClaude Codeの動作を妨げないように）
exit 0