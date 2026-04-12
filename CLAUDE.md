# CLAUDE.md

## プロジェクト概要

Android MDM (Mobile Device Management) の自作Webアプリケーション。Ruby + Sinatra で構築。

## ホスティング

### Railway (本番)

- **プロジェクト:** iwaki-mdm
- **URL:** https://oreore-android-mdm-production.up.railway.app
- **Railway ダッシュボード:** https://railway.com/project/e7259edf-c46e-43a9-8e77-3ff210e2b6cf
- **ビルダー:** railpack（`railway.toml` で指定）
- **CLIリンク:** `railway link -p e7259edf-c46e-43a9-8e77-3ff210e2b6cf -s bc5bfac8-2ebd-4abc-b8c8-f21f02595320 -e dbb366d3-b78e-4752-8807-50b5b1b5ab8e`
- **デプロイ:** `railway up`

### Railway 注意事項

- **Dockerfile が存在すると railpack より優先されてしまう。** プロジェクトに `Dockerfile` という名前のファイルがあると、`railway.toml` で `builder = "railpack"` を指定していても Railway は Dockerfile ビルドを使う。そのため、ローカル開発用の Dockerfile は `Dockerfile.dev` にリネームし、`docker-compose.yml` で `dockerfile: Dockerfile.dev` を指定している。
- nixpacks は deprecated。ビルダーには railpack を使うこと。

## ローカル開発

- `docker-compose.yml` + `Dockerfile.dev` でローカル環境を構築
- `bundle exec rackup --host 0.0.0.0 --port 3000` で起動
