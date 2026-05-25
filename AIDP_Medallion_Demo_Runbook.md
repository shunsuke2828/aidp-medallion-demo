# AIDP Medallion Architecture Demo 実行手順書

## 1. 目的

この手順書は、AIDP Workbench上でNotebook、Catalog、Schema、Volumeを一から用意し、小さなECデータセットのメダリオンアーキテクチャを体験するためのものです。

このデモでは、以下の流れを実行します。

```text
Raw files on Volume
  -> Bronze managed tables
  -> Silver managed tables with data quality checks
  -> Gold managed tables for BI/KPI
```

## 2. データ変換イメージ

![AIDP Medallion Architecture data transformation flow](./aidp_medallion_data_transformation.svg)

この図は、Notebook内で生成したECデータがRawファイルとしてVolumeに配置され、Bronzeで監査列付きのRawテーブル、Silverで品質チェック済みの分析用テーブル、GoldでBI/KPI向けの集計テーブルへ変換される流れを示しています。

## 3. 作成するアセット名

| 項目 | 値 |
|---|---|
| Workspace | `/Shared/odisv/<your_name>` |
| Notebook | `aidp_medallion_demo.ipynb` |
| Catalog | `<your_catalog>`、例: `sniwa_test` |
| Schema | `production` |
| Raw Volume | `demo_raw_landing` |
| Artifact Volume | `demo_artifacts` |
| Main table prefix | `demo_*` |

AIDPのNotebookはCompute Clusterをアタッチして実行します。RawファイルはAIDP VolumeのPOSIXパス `/Volumes/<catalog>/<schema>/<volume>/...` から読み書きします。

Catalog名は各自の名前に合わせます。AIDP UIで各自のCatalogを作成したうえで、Notebookの `Step 01 - Demo Configuration` にある `CATALOG` を同じ名前に変更して上から順番に実行します。例: `sniwa_test`。SQLセルはBootstrapで設定した現在のCatalog/Schemaを使うため、Notebook内のSQLセルを個別に書き換える必要はありません。

## 4. 事前準備

### 4.1 WorkspaceとNotebookを作成

1. AIDP Workbenchで `Workspaces` を開きます。
2. `/Shared/odisv/` 配下に、各自の名前のフォルダを作成します。例: `/Shared/odisv/sniwa`
3. その個人フォルダ配下に `aidp_medallion_demo.ipynb` というNotebookを新規作成します。
4. もしくは、`aidp_medallion_demo_cells.ipynb` をインポートできる場合は、そのままNotebookとして取り込みます。

### 4.2 Catalog、Schema、Managed Volumeを作成

NotebookからCatalog/Schema/Volumeの作成DDLは実行しません。環境や権限で失敗しやすいため、以下のアセットはAIDP UIで事前に作成します。

1. `Master catalog` を開きます。
2. 各自のCatalogを作成します。例: `sniwa_test`
3. そのCatalogを開き、Schema `production` を作成します。
4. Schema `production` を開き、`Volumes` を開きます。
5. `Create volume` をクリックします。
6. Volume Typeは `Managed` を選びます。
7. 以下2つのVolumeを作成します。

| Volume name | 用途 |
|---|---|
| `demo_raw_landing` | Raw CSV/JSONLファイル置き場 |
| `demo_artifacts` | Gold出力CSVやデモ成果物置き場 |

### 4.3 Compute Clusterを起動またはアタッチ

1. 作成またはインポートしたNotebookを開きます。
2. NotebookにCompute Clusterをアタッチします。
3. ClusterがRunning/Active相当の状態になってから実行します。

## 5. Notebookの配置

方法は2つあります。

### 方法A: 新規 `aidp_medallion_demo.ipynb` にセルを貼る

`aidp_medallion_demo_cells.md` を開き、Cell 00からCell 90までを順番に貼り付けます。Markdownセルは説明用、PythonセルとSQLセルは実行用です。SQLセルは `%sql` で始まるセルとして用意しています。SQLセルではCatalog名を直書きせず、Bootstrapで設定した現在のCatalog/Schemaを使います。

### 方法B: Notebookファイルをインポートする

`aidp_medallion_demo_cells.ipynb` をAIDP Workbenchにアップロードまたはインポートできる場合は、そのままNotebookとして使えます。

## 6. 実行順序

| 順番 | セル | 内容 | 期待結果 |
|---:|---|---|---|
| 1 | 00 | Intro | デモ概要とNotebookの読み方を確認できる |
| 2 | 01 | Create AIDP assets | 一から作る対象とUI手順を確認できる |
| 3 | 02-03 | Demo configuration | catalog/schema/volume/pathが表示される |
| 4 | 04-05 | Common imports/helpers | Batch IDが表示される |
| 5 | 06 | Catalog/Schema/Volume setup | UIで作成するCatalog/Schema/Volume名を確認できる |
| 6 | 07-08 | Bootstrap checks/cleanup | Volumeパス確認、既存demo_*削除 |
| 7 | 09-10 | Generate synthetic EC dataset | 顧客・商品・注文などの件数が表示される |
| 8 | 11-12 | Write raw files | Volume配下にCSV/JSONLが作成される |
| 9 | 13-14 | Inspect raw files | Rawファイル一覧とサンプルが表示される |
| 10 | 15-16 | Load Bronze | `demo_bronze_*` テーブルが作成される |
| 11 | 17-23 | Inspect Bronze | Bronze件数、取込監査、監査列付きサンプルを確認できる |
| 12 | 24-25 | Silver dimensions | `demo_silver_customers/products` が作成される |
| 13 | 26-27 | Silver facts/DQ | `demo_silver_*` とDQテーブルが作成される |
| 14 | 28-40 | Inspect Silver | Silver件数、型変換後のファクト、DQ結果を確認できる |
| 15 | 41-42 | Build Gold | `demo_gold_*` テーブルが作成される |
| 16 | 43-58 | Python/SQL equivalent extraction | PythonセルとSQLセルで同じ抽出を実行し、一致確認できる |
| 17 | 59-69 | Optional demo temporary views | 環境で一時Viewが使える場合だけ `demo_vw_*` を確認できる |
| 18 | 70-84 | Demo queries | Viewに依存せず、SQLセルでKPI、Lineage、DQレポートを確認できる |
| 19 | 85-86 | Optional charts | matplotlibがあればグラフ、なければ集計表が表示される |
| 20 | 87-88 | Export Gold | Artifact VolumeへCSVが出力される |
| 任意 | 89-90 | Cleanup | demo_*資産を削除できる |

## 7. 作成される主なアセット

### 7.1 Volumes

| アセット | 用途 |
|---|---|
| `<your_catalog>.production.demo_raw_landing` | Rawファイル置き場。例: `sniwa_test.production.demo_raw_landing` |
| `<your_catalog>.production.demo_artifacts` | CSVエクスポートなどの出力置き場。例: `sniwa_test.production.demo_artifacts` |

### 7.2 Raw files

| ファイル | 内容 |
|---|---|
| `raw/customers/customers_<RUN_DATE>.csv` | 顧客マスタ |
| `raw/products/products_<RUN_DATE>.csv` | 商品マスタ |
| `raw/orders/orders_<RUN_DATE>.csv` | 注文ヘッダ |
| `raw/order_items/order_items_<RUN_DATE>.csv` | 注文明細 |
| `raw/web_events/web_events_<RUN_DATE>.jsonl` | Web行動ログ |
| `raw/reviews/reviews_<RUN_DATE>.csv` | 商品レビュー |

### 7.3 Bronze tables

| テーブル | 内容 |
|---|---|
| `demo_bronze_customers_raw` | 顧客Raw |
| `demo_bronze_products_raw` | 商品Raw |
| `demo_bronze_orders_raw` | 注文Raw |
| `demo_bronze_order_items_raw` | 注文明細Raw |
| `demo_bronze_web_events_raw` | WebイベントRaw |
| `demo_bronze_reviews_raw` | レビューRaw |
| `demo_bronze_ingestion_audit` | 取込監査 |

### 7.4 Silver tables

| テーブル | 内容 |
|---|---|
| `demo_silver_customers` | 型変換・正規化済み顧客 |
| `demo_silver_products` | 型変換・正規化済み商品 |
| `demo_silver_orders` | 重複排除・DQ済み注文 |
| `demo_silver_order_items` | DQ済み注文明細 |
| `demo_silver_sales_fact` | 注文×明細×商品の売上ファクト |
| `demo_silver_web_events` | 整形済みWebイベント |
| `demo_silver_reviews` | 整形済みレビュー |
| `demo_silver_dq_issues` | 不正データ明細 |
| `demo_silver_dq_summary` | DQサマリ |

### 7.5 Gold tables

| テーブル | 内容 |
|---|---|
| `demo_gold_daily_sales` | 日次・チャネル別売上KPI |
| `demo_gold_product_performance` | 商品別売上・粗利・レビュー |
| `demo_gold_customer_360` | 顧客別購買サマリ |
| `demo_gold_channel_funnel` | Webファネル |
| `demo_gold_review_summary` | 商品レビュー集計 |
| `demo_gold_executive_kpis` | 経営向けKPI 1行サマリ |

## 8. デモで見せるポイント

### 8.1 Raw/Bronze

RawファイルはVolume上にあり、BronzeではほぼそのままDeltaテーブル化します。監査列として `_ingest_batch_id`, `_ingested_at`, `_source_file`, `_raw_line_hash` を付与します。

Bronze作成直後の確認フェーズでは、Bronzeテーブルごとの件数、`demo_bronze_ingestion_audit`、監査列付きの注文RawサンプルをSQLセルで確認します。

確認SQL:

```sql
USE `<your_catalog>`.`production`;

SELECT * FROM demo_bronze_ingestion_audit;
```

### 8.2 Silver

Silverでは以下を実行します。

- 文字列の日付・数値を適切な型へ変換
- `order_id` 重複を最新 `updated_at` で解決
- 不正な顧客ID、商品ID、数量、金額、日時、status、ratingを検出
- 不正データを `demo_silver_dq_issues` に分離
- 正常データから `demo_silver_sales_fact` を作成

Silver作成直後の確認フェーズでは、Silverテーブルごとの件数、`demo_silver_sales_fact` のスキーマとサンプル、DQサマリ/明細、BronzeからSilverへの注文件数比較をSQLセルで確認します。

確認SQL:

```sql
SELECT *
FROM demo_silver_dq_summary
ORDER BY issue_count DESC;
```

### 8.3 Gold

Goldでは業務向けの集計済みデータを作成します。

確認SQL:

```sql
SELECT * FROM demo_gold_executive_kpis;

SELECT *
FROM demo_gold_daily_sales
ORDER BY order_date, channel;

SELECT *
FROM demo_gold_product_performance
ORDER BY net_sales DESC
LIMIT 10;
```

### 8.4 PythonとSQLの同等抽出

Gold作成後の `Python/SQL equivalent extraction` セル群では、同じ抽出をPySpark DataFrame API版とSQLセル版で残します。SQL版はPythonセル内の `spark.sql(...)` ではなく、`%sql` で始まるSQLセルとして用意しています。

確認対象:

- 日次・チャネル別売上
- 売上上位商品Top 10
- DQサマリ

各抽出で `exceptAll` による差分確認を行い、結果が一致すると `[OK] ... Python DataFrame API and SQL cell results match` と表示されます。

## 9. よくあるエラーと対処

### 9.1 Volume path was not found

原因: 各自のCatalog、Schema `production`、または `demo_raw_landing` / `demo_artifacts` Volumeが存在しません。

対処: `Master catalog` から各自のCatalog、Schema `production`、Managed Volume `demo_raw_landing` / `demo_artifacts` を作成してください。例: Catalog `sniwa_test`。

### 9.2 Permission denied / authorization error

原因: Catalog/Schema/Table/Volumeに対する権限不足です。

対処: AIDPのRole/Permissionsで、対象Catalog/Schemaに対する作成・読み書き権限を付与してください。

### 9.3 Volume setup

NotebookからCatalog/Schema/Volumeの作成DDLは実行しません。NotebookのStep 00とStep 03のMarkdown手順に従って、UIから作成してください。

Volumeが存在すれば、以降のPythonセルは `/Volumes/<your_catalog>/production/...` のPOSIXパスを使ってRawファイルとArtifactを書き込みます。例: `/Volumes/sniwa_test/production/...`。

### 9.4 Catalog does not support views / Viewが作成できない

AIDP Catalogが永続Viewをサポートしない環境があります。また、環境によっては一時Viewが後続SQLセルから見えない場合もあります。このNotebookではStep 16のデモクエリをGold/DQテーブル直接参照にしているため、Step 15の `demo_vw_*` が使えなくてもデモは続行できます。

### 9.5 matplotlib is not installed

原因: Computeに `matplotlib` がインストールされていません。

対処: Optional chartsセルは失敗せず、グラフ用の集計表を表示します。Notebookの結果表示にVisualization機能がある場合は、その表から折れ線・棒グラフを作成してください。確認方法はNotebookのStep 17にも記載しています。Computeへのライブラリ追加が許可されている環境では、`matplotlib` を追加すると同じセルでグラフ表示できます。

## 10. クリーンアップ

Notebook末尾の `Step 19 - Optional Cleanup` のPythonセルで以下を変更して実行します。

```python
RUN_CLEANUP = True
DROP_VOLUMES_TOO = False
```

Volume上のRawファイルやArtifactも削除する場合だけ、以下にします。

```python
RUN_CLEANUP = True
DROP_VOLUMES_TOO = True
```

通常は `DROP_VOLUMES_TOO = False` のままにして、テーブルだけ削除するのがおすすめです。一時ViewはNotebookセッション終了時にも消えます。

## 11. デモ説明トーク例

1. `demo_raw_landing` のCSV/JSONLがRawデータです。
2. BronzeはRawをできるだけそのまま保持し、再処理できる状態にしています。
3. Silverは分析に耐えるように型変換、重複排除、DQチェックを行います。
4. GoldはBIや業務ユーザー向けのKPIテーブルです。
5. `demo_silver_dq_summary` を見ると、Rawに混ぜた不正データが検出されていることがわかります。
6. `demo_gold_executive_kpis` や `demo_gold_daily_sales` が最終アウトプットです。
