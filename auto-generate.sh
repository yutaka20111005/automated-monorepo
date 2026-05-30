#!/bin/bash
# auto-generate.sh

set -e

if [ "$#" -ne 4 ]; then
    echo "使用法: $0 <ブランチ名> <ワークツリーディレクトリ名> <出力ファイル名> <プロンプト>"
    exit 1
fi

BRANCH_NAME=$1
TARGET_DIR=$2
FILE_NAME=$3
USER_PROMPT=$4

# 1. ワークツリーの作成
git branch "$BRANCH_NAME" 2>/dev/null || true
git worktree add "../$TARGET_DIR" "$BRANCH_NAME"

# 2. 作業ディレクトリへ移動
cd "../$TARGET_DIR"

# 3. curlを使用してGemini API経由でコード生成
echo "Generating code for $FILE_NAME..."

JSON_PAYLOAD=$(jq -n \
  --arg prompt "いかなる説明やMarkdownのコードブロックも省き、純粋なコードのみを出力してください。要件: $USER_PROMPT" \
  '{"contents":[{"parts":[{"text":$prompt}]}]}')

curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$JSON_PAYLOAD" \
  | jq -r '.candidates[0].content.parts[0].text' > "$FILE_NAME"

# 4. コミット、プッシュ、およびPull Requestの作成
git add "$FILE_NAME"
if ! git diff --staged --quiet; then
    git commit -m "Auto-generated $FILE_NAME via Gemini API"
    git push -f -u origin "$BRANCH_NAME"
    echo "Successfully pushed to $BRANCH_NAME"

    # --- ここからPull Requestの自動作成処理 ---
    # すでに同じブランチのPRが存在しないか確認
    if ! gh pr view "$BRANCH_NAME" &>/dev/null; then
        echo "Creating Pull Request..."
        gh pr create \
          --title "【AI自動生成】$FILE_NAME の追加" \
          --body "Gemini APIによって自動生成されたコード（$FILE_NAME）です。コードを確認し、問題がなければマージしてください。"$'\n\n'強度プロンプト: "$USER_PROMPT" \
          --base master \
          --head "$BRANCH_NAME"
    else
        echo "Pull Request already exists. Skipping creation."
    fi
    # -------------------------------------
else
    echo "No changes generated. Skipping push and PR."
fi

# 5. ワークツリーのクリーンアップ
cd - > /dev/null
git worktree remove "../$TARGET_DIR" --force
