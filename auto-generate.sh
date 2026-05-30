#!/bin/bash
# auto-generate.sh

set -e # エラーが発生した時点でスクリプトを停止

if [ "$#" -ne 4 ]; then
    echo "使用法: $0 <ブランチ名> <ワークツリーディレクトリ名> <出力ファイル名> <プロンプト>"
    exit 1
fi

BRANCH_NAME=$1
TARGET_DIR=$2
FILE_NAME=$3
USER_PROMPT=$4

# 常に安全にコードだけを出力させるためのシステムプロンプト
SYSTEM_PROMPT="いかなるツールやエージェント機能（write_file等）も絶対に使用しないでください。説明やMarkdownのコードブロックを省いた、純粋なコードのみを標準出力（画面）にテキストとして出力してください。"

# 1. ワークツリーの作成（既にブランチが存在する場合はエラーを無視して続行）
git branch "$BRANCH_NAME" 2>/dev/null || true
git worktree add "../$TARGET_DIR" "$BRANCH_NAME"

# 2. 作業ディレクトリへ移動
cd "../$TARGET_DIR"

# 3. Gemini CLIによるコード生成
echo "Generating code for $FILE_NAME..."
gemini "$SYSTEM_PROMPT 要件: $USER_PROMPT" > "$FILE_NAME"

# 4. コミットとプッシュ
git add "$FILE_NAME"
# 差分がある場合のみコミットとプッシュを実行
if ! git diff --staged --quiet; then
    git commit -m "Auto-generated $FILE_NAME via Gemini CLI"
    git push -u origin "$BRANCH_NAME"
    echo "Successfully pushed to $BRANCH_NAME"
else
    echo "No changes generated. Skipping push."
fi

# 5. ワークツリーのクリーンアップ
cd - > /dev/null
git worktree remove "../$TARGET_DIR" --force
