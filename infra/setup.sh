#!/usr/bin/env bash
# infra/setup.sh — news-listen GCP リソース一括セットアップ
#
# 使い方:
#   bash infra/setup.sh          # 通常実行
#   DRY_RUN=1 bash infra/setup.sh  # ドライラン（コマンドを表示するだけ）
#
# 前提:
#   - gcloud auth login 済み
#   - .env ファイルに必要な値が設定済み
#   - gcloud config set project $GCP_PROJECT_ID 済み

set -euo pipefail

# ── 色付きログ ─────────────────────────────────────────────────
INFO()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
OK()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
WARN()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
ERROR() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
STEP()  { echo -e "\n\033[1;36m── $* ──\033[0m"; }

# ドライランモード
DRY_RUN="${DRY_RUN:-0}"
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "\033[2m[dry-run] $*\033[0m"
  else
    "$@"
  fi
}

# ── .env 読み込み ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  ERROR ".env ファイルが見つかりません: $ENV_FILE"
  ERROR "cp .env.example .env を実行して値を設定してください"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── 必須変数チェック ───────────────────────────────────────────
REQUIRED_VARS=(
  GCP_PROJECT_ID
  GCP_REGION
  GCP_BUCKET_NAME
  GEMINI_API_KEY
  API_KEY
)

# OPENAI_API_KEY は MVP では任意（Gemini TTS のみで動作可能）
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" || "$val" == your-* || "$val" == AIza... || "$val" == sk-... ]]; then
    ERROR "$var が未設定です (.env を確認してください)"
    MISSING=1
  fi
done
[[ "$MISSING" == "1" ]] && exit 1

INFO "プロジェクト: $GCP_PROJECT_ID"
INFO "リージョン:   $GCP_REGION"
INFO "バケット:     $GCP_BUCKET_NAME"
[[ "$DRY_RUN" == "1" ]] && WARN "ドライランモード — 実際の変更は行いません"
echo ""

# ── 1. gcloud プロジェクト設定 ────────────────────────────────
STEP "1. gcloud プロジェクト設定"

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [[ "$CURRENT_PROJECT" != "$GCP_PROJECT_ID" ]]; then
  run gcloud config set project "$GCP_PROJECT_ID"
fi
OK "プロジェクト設定完了: $GCP_PROJECT_ID"

# ── 2. GCP API 有効化 ─────────────────────────────────────────
STEP "2. GCP API 有効化"

APIS=(
  firestore.googleapis.com
  storage.googleapis.com
  run.googleapis.com
  cloudscheduler.googleapis.com
  cloudtasks.googleapis.com
  aiplatform.googleapis.com
  secretmanager.googleapis.com
  artifactregistry.googleapis.com
  cloudbuild.googleapis.com
  iam.googleapis.com
  # 署名付き URL を IAM signBlob で生成するために必要
  iamcredentials.googleapis.com
)

for api in "${APIS[@]}"; do
  INFO "有効化: $api"
  run gcloud services enable "$api" --project="$GCP_PROJECT_ID"
done
OK "API 有効化完了"

# ── 3. Firestore データベース作成 ─────────────────────────────
STEP "3. Firestore データベース作成"

if gcloud firestore databases list --project="$GCP_PROJECT_ID" 2>/dev/null | grep -q "(default)"; then
  OK "Firestore データベースはすでに存在します"
else
  run gcloud firestore databases create \
    --location="$GCP_REGION" \
    --project="$GCP_PROJECT_ID"
  OK "Firestore データベース作成完了"
fi

# ── 4. Cloud Storage バケット作成 ─────────────────────────────
STEP "4. Cloud Storage バケット作成"

if gsutil ls "gs://$GCP_BUCKET_NAME" &>/dev/null; then
  OK "バケットはすでに存在します: gs://$GCP_BUCKET_NAME"
else
  run gsutil mb -l "$GCP_REGION" "gs://$GCP_BUCKET_NAME"
  OK "バケット作成完了: gs://$GCP_BUCKET_NAME"
fi

# 30日後自動削除のライフサイクルルールを設定
INFO "ライフサイクルルール設定（30日後に削除）"
LIFECYCLE_JSON=$(cat <<'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF
)
if [[ "$DRY_RUN" == "1" ]]; then
  echo -e "\033[2m[dry-run] gsutil lifecycle set <lifecycle.json> gs://$GCP_BUCKET_NAME\033[0m"
else
  echo "$LIFECYCLE_JSON" | gsutil lifecycle set /dev/stdin "gs://$GCP_BUCKET_NAME"
fi
OK "ライフサイクルルール設定完了"

# ── 5. サービスアカウント作成 ─────────────────────────────────
STEP "5. サービスアカウント作成"

SA_NAME="news-listen-sa"
SA_EMAIL="$SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$GCP_PROJECT_ID" &>/dev/null; then
  OK "サービスアカウントはすでに存在します: $SA_EMAIL"
else
  run gcloud iam service-accounts create "$SA_NAME" \
    --display-name="news-listen App" \
    --project="$GCP_PROJECT_ID"
  OK "サービスアカウント作成完了: $SA_EMAIL"
fi

# IAM ロール付与
ROLES=(
  roles/datastore.user
  roles/storage.objectAdmin
  roles/secretmanager.secretAccessor
  roles/cloudtasks.enqueuer
  roles/aiplatform.user
  # api サービスと Cloud Scheduler が Cloud Run Jobs を起動する（run.jobs.run）ために必要。
  roles/run.developer
)

for role in "${ROLES[@]}"; do
  INFO "IAM ロール付与: $role"
  run gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --condition=None \
    --quiet
done
OK "IAM ロール付与完了"

# 署名付き URL 生成（IAM signBlob）用に SA が自分自身へ署名できる権限を付与する。
# Cloud Run のコンピュート認証情報は秘密鍵を持たず、generate_signed_url() は
# signBlob API 経由で署名するため roles/iam.serviceAccountTokenCreator が必要。
# プロジェクト全体ではなく SA リソースへバインドし、他 SA への署名権限は与えない（最小権限）。
INFO "IAM ロール付与（SA 自身へ・signBlob 用）: roles/iam.serviceAccountTokenCreator"
run gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="$GCP_PROJECT_ID" \
  --quiet
OK "signBlob 用ロール付与完了"

# ── 6. Secret Manager にシークレット登録 ──────────────────────
STEP "6. Secret Manager にシークレット登録"

store_secret() {
  local name="$1"
  local value="$2"
  if gcloud secrets describe "$name" --project="$GCP_PROJECT_ID" &>/dev/null; then
    INFO "シークレットを更新: $name"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo -e "\033[2m[dry-run] echo -n '<value>' | gcloud secrets versions add $name --data-file=-\033[0m"
    else
      echo -n "$value" | gcloud secrets versions add "$name" \
        --data-file=- \
        --project="$GCP_PROJECT_ID"
    fi
  else
    INFO "シークレットを作成: $name"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo -e "\033[2m[dry-run] echo -n '<value>' | gcloud secrets create $name --data-file=-\033[0m"
    else
      echo -n "$value" | gcloud secrets create "$name" \
        --data-file=- \
        --replication-policy=automatic \
        --project="$GCP_PROJECT_ID"
    fi
  fi
  OK "シークレット完了: $name"
}

store_secret "${SECRET_NAME_API_KEY:-news-listen-api-key}"    "$API_KEY"
store_secret "${SECRET_NAME_GEMINI:-news-listen-gemini-key}"  "$GEMINI_API_KEY"
if [[ -n "$OPENAI_API_KEY" ]]; then
  store_secret "${SECRET_NAME_OPENAI:-news-listen-openai-key}"  "$OPENAI_API_KEY"
else
  WARN "OPENAI_API_KEY が未設定のため Secret Manager への登録をスキップ（MVP では不要）"
fi

# ── 7. Artifact Registry リポジトリ作成 ───────────────────────
STEP "7. Artifact Registry リポジトリ作成"

AR_REPO="${GCP_AR_REPO:-news-listen}"

if gcloud artifacts repositories describe "$AR_REPO" \
    --location="$GCP_REGION" \
    --project="$GCP_PROJECT_ID" &>/dev/null; then
  OK "Artifact Registry リポジトリはすでに存在します: $AR_REPO"
else
  run gcloud artifacts repositories create "$AR_REPO" \
    --repository-format=docker \
    --location="$GCP_REGION" \
    --description="news-listen Docker images" \
    --project="$GCP_PROJECT_ID"
  OK "Artifact Registry リポジトリ作成完了: $AR_REPO"
fi

# Docker 認証設定
run gcloud auth configure-docker "$GCP_REGION-docker.pkg.dev" --quiet
OK "Docker 認証設定完了"

# ── 8. Cloud Tasks キュー作成 ─────────────────────────────────
STEP "8. Cloud Tasks キュー作成"

QUEUE_NAME="podcast-generation"

if gcloud tasks queues describe "$QUEUE_NAME" \
    --location="$GCP_REGION" \
    --project="$GCP_PROJECT_ID" &>/dev/null; then
  OK "Cloud Tasks キューはすでに存在します: $QUEUE_NAME"
else
  run gcloud tasks queues create "$QUEUE_NAME" \
    --location="$GCP_REGION" \
    --max-dispatches-per-second=10 \
    --max-concurrent-dispatches=5 \
    --max-attempts=3 \
    --min-backoff=10s \
    --max-backoff=300s \
    --project="$GCP_PROJECT_ID"
  OK "Cloud Tasks キュー作成完了: $QUEUE_NAME"
fi

# ── 完了サマリー ───────────────────────────────────────────────
echo ""
echo -e "\033[1;32m════════════════════════════════════════\033[0m"
echo -e "\033[1;32m  セットアップ完了\033[0m"
echo -e "\033[1;32m════════════════════════════════════════\033[0m"
echo ""
echo "  プロジェクト:      $GCP_PROJECT_ID"
echo "  リージョン:        $GCP_REGION"
echo "  バケット:          gs://$GCP_BUCKET_NAME"
echo "  サービスアカウント: $SA_EMAIL"
echo "  Artifact Registry: $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/$AR_REPO"
echo "  Cloud Tasks キュー: $QUEUE_NAME"
echo ""
echo "次のステップ:"
echo "  1. backend/ ディレクトリを実装"
echo "  2. docker build -f backend/Dockerfile.api -t <image> ."
echo "  3. gcloud run deploy で API をデプロイ"
echo ""
