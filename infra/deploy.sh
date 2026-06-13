#!/usr/bin/env bash
# infra/deploy.sh — news-listen バックエンドを Cloud Run へデプロイ
#
# 実行内容:
#   1. Cloud Build で API・ジョブ両イメージをビルド & Artifact Registry へ push
#   2. API を Cloud Run サービスとしてデプロイ
#   3. RSS フェッチ / レコメンド / Podcast 生成を Cloud Run ジョブとしてデプロイ
#   4. （任意）Cloud Scheduler でジョブを定期実行（SETUP_SCHEDULER=1 のとき）
#
# 使い方:
#   bash infra/deploy.sh                 # フルデプロイ
#   DRY_RUN=1 bash infra/deploy.sh       # ドライラン（コマンド表示のみ）
#   SKIP_BUILD=1 bash infra/deploy.sh    # イメージビルドを省略（既存イメージで再デプロイ）
#   SETUP_SCHEDULER=1 bash infra/deploy.sh  # Cloud Scheduler も設定
#
# 前提:
#   - infra/setup.sh 実行済み（リソース・SA・シークレット作成済み）
#   - gcloud auth login 済み
#   - .env に必要な値が設定済み

set -euo pipefail

# ── 色付きログ ─────────────────────────────────────────────────
INFO()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
OK()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
WARN()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
ERROR() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
STEP()  { echo -e "\n\033[1;36m── $* ──\033[0m"; }

DRY_RUN="${DRY_RUN:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SETUP_SCHEDULER="${SETUP_SCHEDULER:-0}"

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "\033[2m[dry-run] $*\033[0m"
  else
    "$@"
  fi
}

# ── .env 読み込み ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  ERROR ".env ファイルが見つかりません: $ENV_FILE"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── 必須変数チェック ───────────────────────────────────────────
: "${GCP_PROJECT_ID:?GCP_PROJECT_ID が未設定です}"
: "${GCP_REGION:?GCP_REGION が未設定です}"
: "${GCP_BUCKET_NAME:?GCP_BUCKET_NAME が未設定です}"

AR_REPO="${GCP_AR_REPO:-news-listen}"
SA_EMAIL="news-listen-sa@$GCP_PROJECT_ID.iam.gserviceaccount.com"
AR_HOST="$GCP_REGION-docker.pkg.dev"
AR_BASE="$AR_HOST/$GCP_PROJECT_ID/$AR_REPO"

# 単一ユーザー MVP のため USER_ID は "default"。API・ジョブ全体で同一ユーザーの
# データを操作するため統一する。DEPLOY_USER_ID で上書き可能。
USER_ID="${DEPLOY_USER_ID:-default}"
DIFFICULTY="${DEPLOY_DIFFICULTY:-toeic_900}"

# Secret Manager 参照名
SECRET_API_KEY="${SECRET_NAME_API_KEY:-news-listen-api-key}"
SECRET_GEMINI="${SECRET_NAME_GEMINI:-news-listen-gemini-key}"

# イメージタグ（git short sha があれば使う。なければ latest）
TAG="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo latest)"

INFO "プロジェクト:  $GCP_PROJECT_ID"
INFO "リージョン:    $GCP_REGION"
INFO "イメージ:      $AR_BASE/{news-listen-api,news-listen-jobs}:$TAG"
INFO "USER_ID:       $USER_ID"
[[ "$DRY_RUN" == "1" ]] && WARN "ドライランモード — 実際の変更は行いません"

# ── 1. イメージビルド (Cloud Build) ───────────────────────────
STEP "1. Cloud Build でイメージをビルド & push"
if [[ "$SKIP_BUILD" == "1" ]]; then
  WARN "SKIP_BUILD=1 のためビルドをスキップ"
else
  run gcloud builds submit "$ROOT_DIR/backend" \
    --config="$ROOT_DIR/backend/cloudbuild.yaml" \
    --substitutions="_REGION=$GCP_REGION,_REPO=$AR_REPO,_TAG=$TAG" \
    --project="$GCP_PROJECT_ID"
  OK "イメージビルド完了"
fi

# ── 2. API サービスをデプロイ ─────────────────────────────────
STEP "2. API を Cloud Run サービスとしてデプロイ"
# --allow-unauthenticated: API は X-API-Key による独自認証を持つため、
#   Cloud Run の IAM 認証は無効化し、アプリ層で認証する。
run gcloud run deploy news-listen-api \
  --image="$AR_BASE/news-listen-api:$TAG" \
  --region="$GCP_REGION" \
  --platform=managed \
  --service-account="$SA_EMAIL" \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=3 \
  --timeout=300 \
  --set-env-vars="USER_ID=$USER_ID,GCS_BUCKET_NAME=$GCP_BUCKET_NAME,JOB_TRIGGER_BACKEND=cloud_run,GCP_REGION=$GCP_REGION,GCP_PROJECT_ID=$GCP_PROJECT_ID" \
  --set-secrets="API_KEY=$SECRET_API_KEY:latest" \
  --project="$GCP_PROJECT_ID"
OK "API サービスデプロイ完了"

# ── 3. Cloud Run ジョブをデプロイ ─────────────────────────────
STEP "3. バッチジョブを Cloud Run ジョブとしてデプロイ"

# deploy_job <ジョブ名> <JOB_MODULE> <追加env> <secrets> <timeout> <memory>
deploy_job() {
  local name="$1" module="$2" extra_env="$3" secrets="$4" timeout="$5" memory="$6"
  local env_vars="JOB_MODULE=$module,USER_ID=$USER_ID"
  [[ -n "$extra_env" ]] && env_vars="$env_vars,$extra_env"

  local args=(
    run jobs deploy "$name"
    --image="$AR_BASE/news-listen-jobs:$TAG"
    --region="$GCP_REGION"
    --service-account="$SA_EMAIL"
    --set-env-vars="$env_vars"
    --max-retries=1
    --task-timeout="$timeout"
    --memory="$memory"
    --project="$GCP_PROJECT_ID"
  )
  [[ -n "$secrets" ]] && args+=(--set-secrets="$secrets")
  run gcloud "${args[@]}"
  OK "ジョブデプロイ完了: $name"
}

# rss-fetcher: feedparser + trafilatura + Firestore（Gemini 不使用）
deploy_job "rss-fetcher" "jobs.rss_fetcher.main" \
  "" "" "900" "1Gi"

# recommendation: Gemini でスコアリング
deploy_job "recommendation" "jobs.recommendation.main" \
  "" "GEMINI_API_KEY=$SECRET_GEMINI:latest" "900" "1Gi"

# podcast-generator: Gemini（スクリプト + TTS）+ Cloud Storage アップロード
deploy_job "podcast-generator" "jobs.podcast_generator.main" \
  "DIFFICULTY=$DIFFICULTY,GCS_BUCKET_NAME=$GCP_BUCKET_NAME" \
  "GEMINI_API_KEY=$SECRET_GEMINI:latest" "3600" "1Gi"

# ── 4. Cloud Scheduler（任意） ────────────────────────────────
if [[ "$SETUP_SCHEDULER" == "1" ]]; then
  STEP "4. Cloud Scheduler でジョブを定期実行"
  # Cloud Run ジョブを Scheduler から起動するための実行 URL
  RUN_JOB_URL_BASE="https://$GCP_REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$GCP_PROJECT_ID/jobs"

  create_schedule() {
    local job_name="$1" cron="$2"
    local sched_name="trigger-$job_name"
    if gcloud scheduler jobs describe "$sched_name" --location="$GCP_REGION" --project="$GCP_PROJECT_ID" &>/dev/null; then
      OK "Scheduler ジョブは既に存在: $sched_name"
    else
      run gcloud scheduler jobs create http "$sched_name" \
        --location="$GCP_REGION" \
        --schedule="$cron" \
        --time-zone="Asia/Tokyo" \
        --uri="$RUN_JOB_URL_BASE/$job_name:run" \
        --http-method=POST \
        --oauth-service-account-email="$SA_EMAIL" \
        --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" \
        --project="$GCP_PROJECT_ID"
      OK "Scheduler ジョブ作成: $sched_name ($cron)"
    fi
  }

  # 毎朝のパイプライン: 6:00 RSS → 6:30 レコメンド → 7:00 Podcast 生成
  create_schedule "rss-fetcher"       "0 6 * * *"
  create_schedule "recommendation"    "30 6 * * *"
  create_schedule "podcast-generator" "0 7 * * *"
else
  WARN "Cloud Scheduler 設定をスキップ（SETUP_SCHEDULER=1 で有効化）"
fi

# ── 完了サマリー ───────────────────────────────────────────────
if [[ "$DRY_RUN" != "1" ]]; then
  API_URL="$(gcloud run services describe news-listen-api \
    --region="$GCP_REGION" --project="$GCP_PROJECT_ID" \
    --format='value(status.url)' 2>/dev/null || echo '(取得失敗)')"
else
  API_URL="(dry-run)"
fi

echo ""
echo -e "\033[1;32m════════════════════════════════════════\033[0m"
echo -e "\033[1;32m  デプロイ完了\033[0m"
echo -e "\033[1;32m════════════════════════════════════════\033[0m"
echo ""
echo "  API URL:    $API_URL"
echo "  ジョブ:     rss-fetcher / recommendation / podcast-generator"
echo ""
echo "  ジョブ手動実行例:"
echo "    gcloud run jobs execute rss-fetcher --region=$GCP_REGION"
echo ""
echo "  ヘルスチェック:"
echo "    curl \$API_URL/health"
echo ""
