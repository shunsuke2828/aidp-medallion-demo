# AIDP Medallion Demo - copy/paste cells

AIDP上でNotebook/Catalog/Schemaがまだ無い状態から始める場合は、以下のMarkdownセルとPython/SQLセルを順番に貼り付けて実行してください。

## Cell 00 - Markdown

# AIDP Medallion Architecture Demo for `<your_catalog>.production`

このNotebookは、AIDP Workbench上で **Raw files -> Bronze -> Silver -> Gold** の流れを、手元に実データがない状態から体験するためのデモです。

外部ファイルを事前に用意する必要はありません。Notebookの中で架空のEC/小売データを生成し、AIDPのManaged VolumeへRawファイルとして保存し、そのRawをBronze/Silver/GoldのManaged Tableへ段階的に加工します。

## このNotebookで体験すること

このデモのゴールは、単にCSVを読み込むことではありません。実務でよく必要になる次の流れを、AIDP上で小さく再現します。

1. **Catalog / Schema / Volumeを用意する**
   データ資産を置く入れ物をAIDP UIで作ります。
2. **RawファイルをVolumeへ置く**
   元データをCSV/JSONLとして保管します。
3. **Bronzeへ取り込む**
   Rawをなるべく壊さず、監査列を付けてテーブル化します。
4. **Silverで整える**
   型変換、重複排除、JOIN、データ品質チェックを行います。
5. **GoldでKPI化する**
   BIや業務ユーザーがそのまま見られる集計テーブルを作ります。
6. **PythonとSQLの両方で確認する**
   エンジニア向けのPySpark処理と、分析者向けのSQL抽出を両方残します。

## 先に押さえる全体像

AIDPでは、Catalogが最初の器です。その中にSchemaを作り、Schemaの中にVolumeとTableを作ります。

```text
Catalog: <your_catalog>
└── Schema: production
    ├── Volume: demo_raw_landing   <- Raw CSV/JSONLを置く場所
    ├── Volume: demo_artifacts     <- 出力CSVなどを置く場所
    ├── Table: demo_bronze_*       <- Rawに監査列を付けたテーブル
    ├── Table: demo_silver_*       <- 分析できる品質に整えたテーブル
    └── Table: demo_gold_*         <- BI/KPI向けに集計したテーブル
```

NotebookとSpark Computeは、このCatalog配下のVolumeを読み、同じCatalog配下にTableを書き込みます。

## このデモで使う名前

| 項目 | 値 | 説明 |
|---|---|---|
| Workspace folder | `/Shared/odisv/<your_name>` | 各自のNotebookを置くフォルダ |
| Notebook | `aidp_medallion_demo.ipynb` | AIDP上で実行するNotebook |
| Catalog | `<your_catalog>` | 各自の名前を含むCatalog名。例: `sniwa_test` |
| Schema | `production` | Demo Table/Volumeを置くSchema |
| Namespace | `<your_catalog>.production` | CatalogとSchemaを合わせた名前 |
| Raw Volume | `demo_raw_landing` | Raw CSV/JSONLの置き場 |
| Artifact Volume | `demo_artifacts` | 出力CSVや成果物の置き場 |

`<your_catalog>` は必ず自分のCatalog名に置き換えてください。例では `sniwa_test.production.demo_*` のような名前になります。

## 初心者向け 用語ミニ解説

| 用語 | このNotebookでの意味 |
|---|---|
| Catalog | データ資産を管理する一番大きな入れ物です。Schema、Table、Volumeをまとめます。 |
| Schema | Catalogの中の整理用フォルダのようなものです。このデモでは `production` を使います。 |
| Managed Volume | ファイル置き場です。CSVやJSONLなど、Tableになる前のRawファイルを置きます。 |
| Managed Table | Catalogに登録されるテーブルです。SQLで検索でき、Notebookからも参照できます。 |
| Spark Compute | Notebookの処理を実行する計算エンジンです。JOINや集計を分散処理します。 |
| PySpark | PythonからSparkを操作するためのAPIです。大量データ処理やETLに向いています。 |
| SQL | テーブルからデータを抽出・集計するための言語です。分析者やBI担当者に説明しやすいです。 |
| DQ | Data Qualityの略です。不正値、欠損、参照切れ、重複などを検出します。 |
| Fact | 売上や数量など、集計したい出来事の明細データです。このデモでは売上ファクトを作ります。 |
| Dimension | 顧客や商品など、Factを説明するマスタデータです。 |
| KPI | Key Performance Indicatorの略です。売上、粗利率、注文数など業務判断に使う指標です。 |
| Temporary View | Notebookセッション中だけ使うSQL用の一時的な名前です。永続Tableとは違います。 |

## 利用するRawファイル

| Raw file | Format | 主なカラム | 役割 |
|---|---|---|---|
| `customers_<RUN_DATE>.csv` | CSV | `customer_id`, `customer_name`, `email`, `prefecture`, `customer_segment`, `signup_date`, `birth_year` | 顧客マスタ。Silver顧客ディメンションとGold顧客360の基礎データ |
| `products_<RUN_DATE>.csv` | CSV | `product_id`, `category`, `sub_category`, `brand`, `product_name`, `list_price`, `cost`, `active_flag` | 商品マスタ。売上ファクト、商品別実績、レビュー集計に利用 |
| `orders_<RUN_DATE>.csv` | CSV | `order_id`, `customer_id`, `order_ts`, `channel`, `status`, `payment_method`, `coupon_code`, `order_total`, `updated_at` | 注文ヘッダ。注文日時、チャネル、ステータス、支払方法を管理 |
| `order_items_<RUN_DATE>.csv` | CSV | `order_id`, `line_no`, `product_id`, `quantity`, `unit_price`, `discount_amount` | 注文明細。商品別数量、単価、値引きから売上・粗利を計算 |
| `web_events_<RUN_DATE>.jsonl` | JSONL | `event_id`, `session_id`, `customer_id`, `event_ts`, `event_type`, `product_id`, `campaign_id`, `device`, `referrer` | Web行動ログ。閲覧、商品閲覧、カート追加、購入イベントからファネルを作成 |
| `reviews_<RUN_DATE>.csv` | CSV | `review_id`, `customer_id`, `product_id`, `review_ts`, `rating`, `review_text` | 商品レビュー。ratingとテキストからレビュー集計、簡易sentiment分類を作成 |

## 意図的に混ぜるデータ品質問題

Medallion Architectureの価値が見えるように、Rawには少量の不正データを混ぜます。実務でも、取り込んだデータには重複、型の揺れ、存在しないID、異常値がよく混ざります。

| 種類 | 例 | Silverでの扱い |
|---|---|---|
| 重複注文 | 同じ `order_id` が複数行 | 最新の `updated_at` を採用 |
| 存在しない顧客 | `customer_id = C99999` | DQ issueとして記録し、有効注文から除外 |
| 存在しない商品 | `product_id = P99999` | DQ issueとして記録し、有効明細から除外 |
| 不正な金額 | `order_total = -100.00` | DQ issueとして記録し、有効注文から除外 |
| 不正な数量 | `quantity = 0` | DQ issueとして記録し、有効明細から除外 |
| 不正な日時 | `order_ts = not_a_timestamp` / `event_ts = bad_ts` | DQ issueとして記録し、有効データから除外 |
| 不正なステータス | `status = unknown` | DQ issueとして記録し、有効注文から除外 |
| 不正なイベント | `event_type = teleport` | DQ issueとして記録し、有効Webイベントから除外 |
| 不正なレビュー評価 | `rating = 6` | DQ issueとして記録し、有効レビューから除外 |

## Raw/Bronze/Silver/Goldで何が変わるか

| Layer | 入力 | 主な処理 | 出力 | 見るポイント |
|---|---|---|---|---|
| Raw | Notebookで生成したCSV/JSONL | ファイルとして保存 | Volume上のRawファイル | 元データが消えずに残る |
| Bronze | Rawファイル | ほぼそのまま読み込み、監査列を付与 | `demo_bronze_*_raw` | `_source_file`, `_raw_line_hash` で追跡できる |
| Silver | Bronzeテーブル | 型変換、重複排除、参照整合性、DQ分離、JOIN | `demo_silver_*`, `demo_silver_sales_fact`, `demo_silver_dq_*` | 分析に使える品質になる |
| Gold | Silverテーブル | 日次、商品、顧客、ファネル、レビュー、経営KPIへ集計 | `demo_gold_*` | BIやSQLでそのまま読める |

## 最終的に見るGoldアウトプット

| Gold table | 内容 |
|---|---|
| `demo_gold_daily_sales` | 日次・チャネル別の注文数、顧客数、数量、売上、粗利、平均注文額 |
| `demo_gold_product_performance` | 商品別の販売数量、売上、粗利、レビュー件数、平均rating |
| `demo_gold_customer_360` | 顧客別の購入回数、LTV、粗利、初回/最終購入日、好みカテゴリ |
| `demo_gold_channel_funnel` | device/referrer別のセッション、閲覧、商品閲覧、カート追加、購入ファネル |
| `demo_gold_review_summary` | 商品別レビュー数、平均rating、positive/neutral/negative件数 |
| `demo_gold_executive_kpis` | 経営者向けの1行KPIサマリ |

## Notebookの読み方

各Python/SQL実行セルの直前に、そのセルで何をするかをMarkdownで説明しています。まずMarkdownを読んで目的を確認し、次の実行セルを実行してください。

迷ったら、各ステップで次の3点だけ見れば大丈夫です。

- **入力**: このセルは何を読み込むのか
- **処理**: 何を変換・集計・チェックするのか
- **出力**: どのTableやファイルができるのか

## Cell 01 - Markdown

## Step 00 - Create AIDP Assets From Scratch

このNotebookは、AIDP上に必要なアセットがまだ存在しない状態から始められるようにしています。

最初にAIDP UIで、データ資産を置く入れ物を作ります。ここはコードで自動作成せず、UIで確認しながら作る前提です。

## 作成するもの

| 作成順 | Asset | 例 | 役割 |
|---|---|---|---|
| 1 | Workspace folder | `/Shared/odisv/<your_name>` | 自分のNotebookを置く場所 |
| 2 | Notebook | `aidp_medallion_demo.ipynb` | このデモを実行する作業画面 |
| 3 | Spark Compute | 任意のCompute | NotebookのPySpark/SQL処理を動かす計算エンジン |
| 4 | Catalog | `<your_catalog>` | データ資産をまとめる最初の器 |
| 5 | Schema | `production` | Catalog内の整理用スペース |
| 6 | Managed Volume | `demo_raw_landing` | Raw CSV/JSONLを置く場所 |
| 7 | Managed Volume | `demo_artifacts` | 出力CSVなどを置く場所 |

## 重要: Catalogが先です

このデモでは、Catalogの中にSchemaを作り、そのSchemaの中にVolumeとTableを作ります。

```text
<your_catalog>
└── production
    ├── demo_raw_landing
    ├── demo_artifacts
    └── demo_* tables
```

つまり、`Volume -> Notebook -> Catalog` という作成順ではありません。作成順としては **Catalog -> Schema -> Volume -> Notebook実行でTable作成** です。

Notebookの処理では、すでに存在するCatalog/Schema/Volumeを使ってRawファイルを保存し、Bronze/Silver/Goldテーブルを作ります。

## AIDP UIでの作業目安

1. Workbench/Workspaceを開く、または新規作成する
2. Workspace内の `/Shared/odisv/` 配下に、各自の名前のフォルダを作成する。例: `/Shared/odisv/sniwa`
3. その個人フォルダ配下に `aidp_medallion_demo.ipynb` を作成、またはこのNotebookをインポートする
4. NotebookにSpark Computeをアタッチする
5. Master Catalogで各自のCatalogを作成する。例: `sniwa_test`
6. そのCatalogの中にSchema `production` を作成する
7. Schema `production` の中にManaged Volume `demo_raw_landing` と `demo_artifacts` を作成する

権限が足りない場合は、Catalog/Schema/Volumeの作成権限を管理者に付与してもらってください。

次の `Step 01 - Demo Configuration` では、ここで作ったCatalog名を `CATALOG` に設定します。

## Cell 02 - Markdown

## Step 01 - Demo Configuration

このセルでは、デモ全体で使う名前と実行条件を定義します。

ここで設定した `CATALOG`、`SCHEMA`、Volume名が、以降のTable名とファイルパスの基準になります。AIDP UIで作成した名前と一致していないと、後続セルでVolumeが見つからない、Tableを書けない、といったエラーになります。

## このセルで決まること

| 変数 | 意味 | 初心者向け説明 |
|---|---|---|
| `CATALOG` | 使用するCatalog名 | AIDP UIで作った各自のCatalog名に変更します |
| `SCHEMA` | 使用するSchema名 | このデモでは `production` 固定です |
| `RAW_VOLUME` | Rawファイル置き場 | CSV/JSONLを保存するVolumeです |
| `ARTIFACT_VOLUME` | 成果物置き場 | Gold出力CSVなどを保存するVolumeです |
| `TABLE_PREFIX` | テーブル名の接頭辞 | `demo_bronze_*` の `demo` 部分です |
| `RUN_DATE` | デモ上の日付 | ファイル名やデータ生成に使います |
| `RESET_DEMO` | 再作成フラグ | `True` の場合、既存のdemoテーブルを削除して作り直します |
| `INCLUDE_DIRTY_DATA` | 不正データ混入フラグ | `True` の場合、DQデモ用の汚いデータを混ぜます |

## パスの読み方

AIDPのVolumeは、Notebookから次のようなPOSIXパスで参照します。

```text
/Volumes/<catalog>/<schema>/<volume>/...
```

このNotebookではRawファイルを次の場所に置きます。

```text
/Volumes/<your_catalog>/production/demo_raw_landing/raw
```

## 実行前チェック

- `CATALOG` を自分のCatalog名に変更したか
- AIDP UI側にも同じCatalogがあるか
- Schema `production` とVolume `demo_raw_landing`, `demo_artifacts` を作成済みか
- 最初の実行では `RESET_DEMO = True` のままでよいか

## Cell 03 - Python

```python
# ============================================================
# 00. Demo configuration
# ============================================================
# AIDP UIで作成したCatalog/Schema/Volume名に合わせます。
# CATALOGは各自の名前のCatalog名に変更してください。例: "sniwa_test"

CATALOG = "sniwa_test"
SCHEMA = "production"

RAW_VOLUME = "demo_raw_landing"
ARTIFACT_VOLUME = "demo_artifacts"

TABLE_PREFIX = "demo"
RUN_DATE = "2026-05-21"

# Trueにすると、demo_*テーブルを削除してから作り直します。
# 再実行時に既存のdemo_*テーブルを残したい場合はFalseにしてください。
RESET_DEMO = True

# わざと不正データを混ぜて、Silver層のDQ処理を見せます。
INCLUDE_DIRTY_DATA = True

# デモ規模。大きくしすぎるとNotebook実行が長くなります。
CUSTOMER_COUNT = 200
PRODUCT_COUNT = 60
ORDER_COUNT = 1000
WEB_EVENT_COUNT = 5000
REVIEW_COUNT = 300
RANDOM_SEED = 42

# AIDPのVolume POSIXパス
BASE_RAW_PATH = f"/Volumes/{CATALOG}/{SCHEMA}/{RAW_VOLUME}/raw"
BASE_ARTIFACT_PATH = f"/Volumes/{CATALOG}/{SCHEMA}/{ARTIFACT_VOLUME}"

# Sparkの小規模デモ向け設定
spark.conf.set("spark.sql.shuffle.partitions", "8")

print("AIDP Medallion Demo configuration")
print(f"  catalog          = {CATALOG}")
print(f"  schema           = {SCHEMA}")
print(f"  raw volume       = {RAW_VOLUME}")
print(f"  artifact volume  = {ARTIFACT_VOLUME}")
print(f"  base raw path    = {BASE_RAW_PATH}")
print(f"  run date         = {RUN_DATE}")
print(f"  reset demo       = {RESET_DEMO}")
print(f"  dirty data       = {INCLUDE_DIRTY_DATA}")
```

## Cell 04 - Markdown

## Step 02 - Common Helpers

このセルでは、以降の処理で繰り返し使う共通関数を準備します。

処理そのものは少し技術的ですが、ここで覚えるべきことは「同じ処理を何度も安全に使えるように、便利関数を先に定義している」という点です。

## 主なヘルパーの役割

| 関数/仕組み | 何をするか | なぜ必要か |
|---|---|---|
| `fq(table_name)` | `<catalog>.<schema>.<table>` の完全修飾名を作る | Catalog名を変えても同じコードを使うため |
| `sql_quote(name)` | SQL内の名前をバッククォートで囲む | Catalog名やTable名を安全にSQLへ渡すため |
| `use_namespace()` | SQLの現在Catalog/Schemaを設定する | `%sql` セルで短いTable名を使いやすくするため |
| `add_bronze_audit_columns()` | Bronze用の監査列を付ける | どのファイルから来た行か追跡するため |
| `write_table()` | DataFrameをManaged Tableとして保存する | Bronze/Silver/Goldテーブルを作るため |
| `dq_issue_df()` | DQ issueの共通形式を作る | 不正データを同じ形式で記録するため |

## 用語補足

- **完全修飾名**: `catalog.schema.table` のように、どのCatalog/SchemaのTableかを省略せずに書いた名前です。
- **DataFrame**: Sparkで扱う表形式データです。SQLのTableに近いですが、Pythonコードの中で変換できます。
- **監査列**: `_source_file` や `_raw_line_hash` のように、データの来歴を追うための列です。
- **Batch ID**: 1回の取り込み処理を識別するIDです。再実行したときの区別に使います。

## 確認ポイント

- `Batch ID` が表示されること
- `BRONZE_TABLES`, `SILVER_TABLES`, `GOLD_TABLES` が定義されること
- このセルはTableを作るのではなく、後続セルで使う道具を準備するセルであること

## Cell 05 - Python

```python
# ============================================================
# 01. Common imports and helper functions
# ============================================================

import os
import csv
import json
import uuid
import shutil
import random
from pathlib import Path
from datetime import datetime, timedelta
from functools import reduce

from pyspark.sql import functions as F
from pyspark.sql.window import Window

BATCH_ID = f"batch_{RUN_DATE.replace('-', '')}_{uuid.uuid4().hex[:8]}"

BRONZE_TABLES = [
    "demo_bronze_customers_raw",
    "demo_bronze_products_raw",
    "demo_bronze_orders_raw",
    "demo_bronze_order_items_raw",
    "demo_bronze_web_events_raw",
    "demo_bronze_reviews_raw",
    "demo_bronze_ingestion_audit",
]

SILVER_TABLES = [
    "demo_silver_customers",
    "demo_silver_products",
    "demo_silver_orders",
    "demo_silver_order_items",
    "demo_silver_sales_fact",
    "demo_silver_web_events",
    "demo_silver_reviews",
    "demo_silver_dq_issues",
    "demo_silver_dq_summary",
]

GOLD_TABLES = [
    "demo_gold_daily_sales",
    "demo_gold_product_performance",
    "demo_gold_customer_360",
    "demo_gold_channel_funnel",
    "demo_gold_review_summary",
    "demo_gold_executive_kpis",
]

ALL_TABLES = BRONZE_TABLES + SILVER_TABLES + GOLD_TABLES


def fq(name: str) -> str:
    """Fully qualified name for DataFrame APIs."""
    return f"{CATALOG}.{SCHEMA}.{name}"


def qident(*parts: str) -> str:
    """Backtick-quoted identifier for SQL text."""
    return ".".join(f"`{p}`" for p in parts)


def qfq(name: str) -> str:
    return qident(CATALOG, SCHEMA, name)


def volume_root(volume_name: str) -> str:
    return f"/Volumes/{CATALOG}/{SCHEMA}/{volume_name}"


def safe_sql(sql_text: str, soft_fail: bool = True):
    """Run SQL. If soft_fail=True, print warning and continue on failure."""
    try:
        return spark.sql(sql_text)
    except Exception as e:
        if soft_fail:
            print("[WARN] SQL failed but continuing:")
            print(sql_text)
            print(str(e)[:2000])
            return None
        raise


def show_df(df, n: int = 20, truncate: bool = False):
    """Use AIDP display() if available; otherwise fall back to Spark show()."""
    try:
        display(df.limit(n))
    except Exception:
        df.show(n, truncate=truncate)


def read_raw_csv(path: str):
    return (
        spark.read
        .option("header", True)
        .option("inferSchema", False)
        .option("mode", "PERMISSIVE")
        .option("quote", '"')
        .option("escape", '"')
        .csv(path)
    )


def add_bronze_metadata(df, source_name: str):
    """Add common Bronze audit columns."""
    raw_cols = df.columns
    row_hash = F.sha2(
        F.concat_ws("||", *[F.coalesce(F.col(c).cast("string"), F.lit("")) for c in raw_cols]),
        256,
    )
    return (
        df
        .withColumn("_ingest_batch_id", F.lit(BATCH_ID))
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
        .withColumn("_source_name", F.lit(source_name))
        .withColumn("_raw_line_hash", row_hash)
    )


def write_delta_table(df, table_name: str, mode: str = "overwrite"):
    """Write a managed Delta table under the configured catalog/schema."""
    (
        df.write
        .format("delta")
        .mode(mode)
        .option("overwriteSchema", "true")
        .saveAsTable(fq(table_name))
    )
    row_count = spark.table(fq(table_name)).count()
    print(f"[OK] {fq(table_name)} : {row_count:,} rows")


def dq_issue(df, source_table: str, pk_col: str, condition, rule_name: str, detail_col=None, severity: str = "ERROR"):
    """Create a DQ issue dataframe with a common schema."""
    if detail_col is None:
        detail_col = F.lit(rule_name)
    return (
        df.filter(condition)
        .select(
            F.expr("uuid()").alias("issue_id"),
            F.lit(source_table).alias("source_table"),
            F.col(pk_col).cast("string").alias("source_pk"),
            F.lit(rule_name).alias("rule_name"),
            F.lit(severity).alias("severity"),
            detail_col.cast("string").alias("issue_detail"),
            F.lit(BATCH_ID).alias("_ingest_batch_id"),
            F.current_timestamp().alias("detected_at"),
        )
    )


def write_csv_file(path: str, rows: list[dict], fieldnames: list[str]):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_jsonl_file(path: str, rows: list[dict]):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

def set_sql_namespace():
    """Set current Catalog/Schema so later %sql cells can use unqualified demo_* names."""
    # AIDPでは `USE catalog.schema` が通る環境があるため、こちらを先に試します。
    try:
        spark.sql(f"USE {qident(CATALOG, SCHEMA)}")
        print(f"[OK] SQL namespace set to {CATALOG}.{SCHEMA}")
        return
    except Exception as first_error:
        print("[INFO] USE catalog.schema failed; trying USE CATALOG / USE SCHEMA instead.")
        print(str(first_error)[:1000])

    spark.sql(f"USE CATALOG {qident(CATALOG)}")
    spark.sql(f"USE SCHEMA {qident(SCHEMA)}")
    print(f"[OK] SQL namespace set to {CATALOG}.{SCHEMA}")


print(f"Batch ID: {BATCH_ID}")
```

## Cell 06 - Markdown

## Step 03 - Create Catalog, Schema, and Managed Volumes

このステップは、AIDP UIで作成するアセットの確認です。

Notebookから `CREATE VOLUME` やCatalog作成を実行できない環境があるため、このデモではCatalog/Schema/VolumeをUIで先に作る前提にしています。

## なぜUIで作るのか

AIDP環境によっては、NotebookからDDLを実行する権限やサポート範囲が異なります。特にVolume作成はPythonセルから実行できない場合があります。そのため、初心者向けデモでは「UIで器を作る」「Notebookで中身を作る」と分けたほうが安全です。

## 作成するアセット

| Asset | Name | 用途 |
|---|---|---|
| Catalog | `<your_catalog>` | 最初に作る大きな器。各自の名前を含めると衝突しにくいです |
| Schema | `production` | Demo用Table/Volumeをまとめる場所 |
| Managed Volume | `demo_raw_landing` | Raw CSV/JSONLファイル置き場 |
| Managed Volume | `demo_artifacts` | Gold出力CSVやデモ成果物置き場 |

## 作成後にできる構造

```text
<your_catalog>
└── production
    ├── Volumes
    │   ├── demo_raw_landing
    │   └── demo_artifacts
    └── Tables
        └── このあとNotebookが demo_* を作成
```

## 作成手順の目安

1. `Master Catalog` を開く
2. 各自のCatalogを作成する。例: `sniwa_test`
3. そのCatalogを開き、Schema `production` を作成する
4. Schema `production` を開き、`Volumes` を開く
5. `Create volume` をクリックする
6. Volume Type で `Managed` を選ぶ
7. `demo_raw_landing` と `demo_artifacts` を作成する

作成後、次の `Step 04 - Bootstrap Checks and Cleanup` の直後にあるPythonセルを実行し、NotebookからVolumeパスが見えるか確認します。

## Cell 07 - Markdown

## Step 04 - Bootstrap Checks and Cleanup

このセルでは、AIDP UIで作成したCatalog/Schema/VolumeがNotebookから見えるかを確認します。

最初に作るべき器が揃っていないと、Rawファイルを書き込めず、Bronze/Silver/Goldテーブルも作れません。ここで早めに確認します。

## このセルで行うこと

| 処理 | 内容 |
|---|---|
| Namespace確認 | `CATALOG` と `SCHEMA` をSQLで使える状態にします |
| Volumeパス確認 | `/Volumes/<catalog>/production/demo_raw_landing` が存在するか確認します |
| 既存demoテーブル削除 | `RESET_DEMO = True` の場合、既存の `demo_*` Tableを削除します |
| SQL用の現在Schema設定 | 後続の `%sql` セルが短いTable名で動くようにします |

## RESET_DEMOの考え方

- `RESET_DEMO = True`: デモを最初から作り直すときに使います。
- `RESET_DEMO = False`: 既存Tableを残して確認だけしたいときに使います。

このセルはCatalogやVolume自体は削除しません。削除対象はデモ用の `demo_*` Tableだけです。

## 確認ポイント

- `Bootstrap completed` と表示されること
- Raw path と Artifact path が `/Volumes/<CATALOG>/production/...` で表示されること
- `SQL namespace set to <CATALOG>.production` と表示されること
- パスが見つからない場合は、Step 03に戻ってAIDP UIでVolumeを作成すること

## Cell 08 - Python

```python
# ============================================================
# 02. Bootstrap checks and cleanup
# ============================================================
# Catalog/Schema/Managed VolumeはStep 03でAIDP UIから作成した前提です。
# このセルでは作成DDLは実行せず、パスの存在確認とdemo_*資産の初期化だけを行います。

# 後続のSQLセルが未修飾のdemo_*名で動くように、現在のCatalog/Schemaを設定します。
set_sql_namespace()

# demo_* Tableを作り直す
if RESET_DEMO:
    print("RESET_DEMO=True: dropping existing demo tables...")
    for table_name in reversed(ALL_TABLES):
        safe_sql(f"DROP TABLE IF EXISTS {qfq(table_name)}", soft_fail=True)

# Volumeパスの存在確認
missing_volume_paths = []
for root in [volume_root(RAW_VOLUME), volume_root(ARTIFACT_VOLUME)]:
    if not os.path.exists(root):
        missing_volume_paths.append(root)

if missing_volume_paths:
    raise FileNotFoundError(
        "AIDP Volume path was not found. Create Catalog, Schema, and Managed Volumes from UI first, then rerun this cell.\n"
        + "Missing paths:\n  - " + "\n  - ".join(missing_volume_paths) + "\n\n"
        + f"UI path: Master catalog > {CATALOG} > {SCHEMA} > Volumes > Create volume > Managed"
    )

Path(BASE_RAW_PATH).mkdir(parents=True, exist_ok=True)
Path(BASE_ARTIFACT_PATH).mkdir(parents=True, exist_ok=True)

print("[OK] Bootstrap completed")
print(f"Raw path      : {BASE_RAW_PATH}")
print(f"Artifact path : {BASE_ARTIFACT_PATH}")
```

## Cell 09 - Markdown

## Step 05 - Generate Synthetic EC Dataset

このセルでは、架空のEC/小売データをPythonのリストとして生成します。

ここではまだAIDP Tableは作りません。まずはRawファイルにする前の「元データ」をNotebook内で作ります。

## 作るデータ

| データ | 実務での意味 | 後続での使い道 |
|---|---|---|
| customers | 顧客マスタ | 顧客属性、都道府県、セグメント分析 |
| products | 商品マスタ | 商品カテゴリ、原価、定価、商品別集計 |
| orders | 注文ヘッダ | 注文日時、チャネル、支払方法、注文ステータス |
| order_items | 注文明細 | 商品別数量、単価、値引き、売上計算 |
| web_events | Web行動ログ | 閲覧、商品閲覧、カート追加、購入ファネル |
| reviews | 商品レビュー | rating、レビュー件数、簡易感情分類 |

## なぜ不正データを混ぜるのか

きれいなデータだけでは、Silver層やDQテーブルの価値が見えません。実務では、存在しない顧客ID、日付として読めない文字列、負の金額、範囲外のratingなどが混ざることがあります。

このNotebookでは `INCLUDE_DIRTY_DATA = True` により、あえて少量の不正データを混ぜます。後続のSilver層で、それらを検出してDQテーブルに記録します。

## 確認ポイント

- customers/products/orders/order_items/web_events/reviews の件数が表示されること
- 不正データはここではまだ除外されないこと
- 後続のSilver DQで、ここで混ぜた不正データが見えること

## Cell 10 - Python

```python
# ============================================================
# 03. Generate synthetic EC dataset
# ============================================================
# ここではPythonだけでダミーデータを作ります。
# 実業務の取り込みに置き換える場合、このセルをObject StorageやDBからのreadに差し替えます。

random.seed(RANDOM_SEED)
base_dt = datetime.strptime(RUN_DATE, "%Y-%m-%d")

prefectures = [
    "Tokyo", "Kanagawa", "Chiba", "Saitama", "Osaka", "Kyoto", "Hyogo",
    "Aichi", "Fukuoka", "Hokkaido", "Miyagi", "Hiroshima",
]
segments = ["new", "regular", "vip"]
channels = ["web", "mobile", "store", "call_center"]
payment_methods = ["credit_card", "bank_transfer", "paypay", "cash_on_delivery"]

category_map = {
    "Electronics": ["Laptop", "Tablet", "Accessory", "Camera"],
    "Home": ["Kitchen", "Storage", "Cleaning", "Furniture"],
    "Beauty": ["Skincare", "Haircare", "Makeup"],
    "Sports": ["Outdoor", "Fitness", "Running"],
    "Books": ["Business", "Tech", "Novel"],
}
brands = ["Aster", "Belltree", "Cielo", "Delta", "Eastline", "Fabrik", "Greenon"]

# Customers
customers = []
for i in range(1, CUSTOMER_COUNT + 1):
    cid = f"C{i:05d}"
    signup_dt = base_dt - timedelta(days=random.randint(1, 900))
    customers.append({
        "customer_id": cid,
        "customer_name": f"Demo Customer {i:05d}",
        "email": f"customer{i:05d}@example.com",
        "prefecture": random.choice(prefectures),
        "customer_segment": random.choices(segments, weights=[0.25, 0.60, 0.15])[0],
        "signup_date": signup_dt.strftime("%Y-%m-%d"),
        "birth_year": str(random.randint(1955, 2005)),
    })

# Products
products = []
cat_sub_pairs = [(c, s) for c, subs in category_map.items() for s in subs]
for i in range(1, PRODUCT_COUNT + 1):
    pid = f"P{i:05d}"
    category, sub_category = random.choice(cat_sub_pairs)
    price = round(random.choice([980, 1480, 1980, 2980, 4980, 7980, 12800, 24800, 49800]) * random.uniform(0.90, 1.15), 2)
    cost = round(price * random.uniform(0.45, 0.78), 2)
    products.append({
        "product_id": pid,
        "category": category,
        "sub_category": sub_category,
        "brand": random.choice(brands),
        "product_name": f"{category} {sub_category} Item {i:03d}",
        "list_price": f"{price:.2f}",
        "cost": f"{cost:.2f}",
        "active_flag": random.choices(["Y", "N"], weights=[0.94, 0.06])[0],
    })

# Orders and order items
orders = []
order_items = []
for i in range(1, ORDER_COUNT + 1):
    order_id = f"O{i:06d}"
    customer = random.choice(customers)
    order_dt = base_dt - timedelta(days=random.randint(0, 13), minutes=random.randint(0, 1439))
    updated_dt = order_dt + timedelta(minutes=random.randint(1, 180))
    status = random.choices(["completed", "cancelled", "refunded", "pending"], weights=[0.82, 0.08, 0.05, 0.05])[0]
    channel = random.choices(channels, weights=[0.46, 0.34, 0.14, 0.06])[0]
    payment = random.choice(payment_methods)
    coupon = random.choice(["", "WELCOME10", "SPRING5", "VIP15", "FREESHIP"])

    n_items = random.randint(1, 5)
    order_total = 0.0
    for line_no in range(1, n_items + 1):
        product = random.choice(products)
        quantity = random.choice([1, 1, 1, 2, 2, 3, 4])
        unit_price = round(float(product["list_price"]) * random.uniform(0.82, 1.00), 2)
        discount_amount = round(unit_price * quantity * random.choice([0, 0, 0, 0.05, 0.10, 0.15]), 2)
        line_net = quantity * unit_price - discount_amount
        order_total += line_net
        order_items.append({
            "order_id": order_id,
            "line_no": str(line_no),
            "product_id": product["product_id"],
            "quantity": str(quantity),
            "unit_price": f"{unit_price:.2f}",
            "discount_amount": f"{discount_amount:.2f}",
        })

    orders.append({
        "order_id": order_id,
        "customer_id": customer["customer_id"],
        "order_ts": order_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "channel": channel,
        "status": status,
        "payment_method": payment,
        "coupon_code": coupon,
        "order_total": f"{order_total:.2f}",
        "updated_at": updated_dt.strftime("%Y-%m-%d %H:%M:%S"),
    })

# Web events
web_events = []
event_types = ["view", "search", "product_view", "add_to_cart", "purchase"]
devices = ["pc", "ios", "android"]
referrers = ["direct", "search", "email", "social", "ad"]
for i in range(1, WEB_EVENT_COUNT + 1):
    session_id = f"S{random.randint(1, 1800):06d}"
    event_dt = base_dt - timedelta(days=random.randint(0, 13), minutes=random.randint(0, 1439), seconds=random.randint(0, 59))
    maybe_customer = random.choice(customers)["customer_id"] if random.random() < 0.72 else ""
    maybe_product = random.choice(products)["product_id"] if random.random() < 0.65 else ""
    event_type = random.choices(event_types, weights=[0.45, 0.16, 0.24, 0.10, 0.05])[0]
    web_events.append({
        "event_id": f"E{i:07d}",
        "session_id": session_id,
        "customer_id": maybe_customer,
        "event_ts": event_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "event_type": event_type,
        "product_id": maybe_product,
        "campaign_id": random.choice(["", "CMP_SPRING", "CMP_RETARGET", "CMP_VIP"]),
        "device": random.choice(devices),
        "referrer": random.choice(referrers),
    })

# Reviews
positive_texts = [
    "Great quality and fast delivery.",
    "Very useful. I would buy it again.",
    "Good value for money.",
]
neutral_texts = [
    "It is okay, nothing special.",
    "Average product for daily use.",
    "Packaging was fine but delivery was slow.",
]
negative_texts = [
    "Quality was below expectation.",
    "I had trouble using this item.",
    "Not worth the price.",
]
reviews = []
for i in range(1, REVIEW_COUNT + 1):
    rating = random.choices([1, 2, 3, 4, 5], weights=[0.06, 0.10, 0.22, 0.34, 0.28])[0]
    if rating >= 4:
        text = random.choice(positive_texts)
    elif rating == 3:
        text = random.choice(neutral_texts)
    else:
        text = random.choice(negative_texts)
    review_dt = base_dt - timedelta(days=random.randint(0, 13), minutes=random.randint(0, 1439))
    reviews.append({
        "review_id": f"R{i:06d}",
        "customer_id": random.choice(customers)["customer_id"],
        "product_id": random.choice(products)["product_id"],
        "review_ts": review_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "rating": str(rating),
        "review_text": text,
    })

# Inject intentionally dirty data
if INCLUDE_DIRTY_DATA:
    # duplicate order_id: latest updated_at should win in Silver
    duplicate_order = dict(orders[0])
    duplicate_order["status"] = "refunded"
    duplicate_order["updated_at"] = (base_dt + timedelta(hours=2)).strftime("%Y-%m-%d %H:%M:%S")
    orders.append(duplicate_order)

    # invalid customer, invalid amount, invalid timestamp, invalid status
    bad1 = dict(orders[1])
    bad1["order_id"] = "O_BAD_CUSTOMER"
    bad1["customer_id"] = "C99999"
    orders.append(bad1)

    bad2 = dict(orders[2])
    bad2["order_id"] = "O_BAD_AMOUNT"
    bad2["order_total"] = "-100.00"
    orders.append(bad2)

    bad3 = dict(orders[3])
    bad3["order_id"] = "O_BAD_TS"
    bad3["order_ts"] = "not_a_timestamp"
    orders.append(bad3)

    bad4 = dict(orders[4])
    bad4["order_id"] = "O_BAD_STATUS"
    bad4["status"] = "unknown"
    orders.append(bad4)

    # invalid order items
    order_items.append({
        "order_id": orders[5]["order_id"],
        "line_no": "99",
        "product_id": "P99999",
        "quantity": "1",
        "unit_price": "1000.00",
        "discount_amount": "0.00",
    })
    order_items.append({
        "order_id": orders[6]["order_id"],
        "line_no": "99",
        "product_id": products[0]["product_id"],
        "quantity": "0",
        "unit_price": "1000.00",
        "discount_amount": "0.00",
    })
    order_items.append({
        "order_id": "O_NOT_EXISTS",
        "line_no": "1",
        "product_id": products[1]["product_id"],
        "quantity": "1",
        "unit_price": "1000.00",
        "discount_amount": "0.00",
    })

    # invalid web event and invalid review
    web_events.append({
        "event_id": "E_BAD_TS",
        "session_id": "S_BAD",
        "customer_id": customers[0]["customer_id"],
        "event_ts": "bad_ts",
        "event_type": "teleport",
        "product_id": products[0]["product_id"],
        "campaign_id": "CMP_BAD",
        "device": "pc",
        "referrer": "direct",
    })
    reviews.append({
        "review_id": "R_BAD_RATING",
        "customer_id": customers[0]["customer_id"],
        "product_id": products[0]["product_id"],
        "review_ts": base_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "rating": "6",
        "review_text": "Rating is intentionally invalid.",
    })

print("Generated in-memory raw data")
print(f"  customers   : {len(customers):,}")
print(f"  products    : {len(products):,}")
print(f"  orders      : {len(orders):,}")
print(f"  order_items : {len(order_items):,}")
print(f"  web_events  : {len(web_events):,}")
print(f"  reviews     : {len(reviews):,}")
```

## Cell 11 - Markdown

## Step 06 - Write Raw Files to Volume

このセルでは、生成した架空データをAIDP Managed Volume上のRawファイルとして保存します。

Rawは「まだ加工していない元データ」です。ここではCSVとJSONLとして、`BASE_RAW_PATH` 配下に書き出します。

## このセルの入力と出力

| 種類 | 内容 |
|---|---|
| 入力 | Step 05で作ったPythonリストのデータ |
| 処理 | CSV/JSONL形式へ変換してVolumeへ書き出し |
| 出力 | `/Volumes/<your_catalog>/production/demo_raw_landing/raw/...` 配下のRawファイル |

## CSVとJSONLの違い

- **CSV**: カンマ区切りの表形式ファイルです。顧客、商品、注文、注文明細、レビューに使います。
- **JSONL**: 1行に1つのJSONが入る形式です。ログやイベントのようなデータに向いています。このデモではWeb行動ログに使います。

## 確認ポイント

- `Raw files written` と表示されること
- customers/products/orders/order_items/reviews はCSVとして出力されること
- web_events はJSONLとして出力されること
- ここで作ったRawファイルが、次のBronzeロードの入力になること

## Cell 12 - Python

```python
# ============================================================
# 04. Write raw files to AIDP Volume
# ============================================================
# RawファイルをVolume配下に配置します。
# これがBronzeロードの入力になります。

raw_root = Path(BASE_RAW_PATH)

if RESET_DEMO and raw_root.exists():
    print(f"Removing previous raw files: {raw_root}")
    shutil.rmtree(str(raw_root))

# File paths
paths = {
    "customers": f"{BASE_RAW_PATH}/customers/customers_{RUN_DATE}.csv",
    "products": f"{BASE_RAW_PATH}/products/products_{RUN_DATE}.csv",
    "orders": f"{BASE_RAW_PATH}/orders/orders_{RUN_DATE}.csv",
    "order_items": f"{BASE_RAW_PATH}/order_items/order_items_{RUN_DATE}.csv",
    "web_events": f"{BASE_RAW_PATH}/web_events/web_events_{RUN_DATE}.jsonl",
    "reviews": f"{BASE_RAW_PATH}/reviews/reviews_{RUN_DATE}.csv",
}

write_csv_file(paths["customers"], customers, [
    "customer_id", "customer_name", "email", "prefecture", "customer_segment", "signup_date", "birth_year"
])
write_csv_file(paths["products"], products, [
    "product_id", "category", "sub_category", "brand", "product_name", "list_price", "cost", "active_flag"
])
write_csv_file(paths["orders"], orders, [
    "order_id", "customer_id", "order_ts", "channel", "status", "payment_method", "coupon_code", "order_total", "updated_at"
])
write_csv_file(paths["order_items"], order_items, [
    "order_id", "line_no", "product_id", "quantity", "unit_price", "discount_amount"
])
write_jsonl_file(paths["web_events"], web_events)
write_csv_file(paths["reviews"], reviews, [
    "review_id", "customer_id", "product_id", "review_ts", "rating", "review_text"
])

print("[OK] Raw files written")
for k, p in paths.items():
    print(f"  {k:12s} {p}")
```

## Cell 13 - Markdown

## Step 07 - Inspect Raw Files

このセルでは、Volumeに作成されたRawファイルを確認します。

Raw層では、まだTable化していません。まずは「AIDP Volumeにファイルとして置かれている」ことを確認します。

## このセルで見るもの

| 確認内容 | 見る理由 |
|---|---|
| ファイル一覧 | 6種類のRawファイルが作られたか確認するため |
| ファイルサイズ | 空ファイルではないことを確認するため |
| CSVサンプル | 顧客データなどが想定通り入っているか確認するため |
| JSONLサンプル | Webイベントが1行1JSONの形式になっているか確認するため |

## 初心者向け補足

Rawファイルは、あとで処理ロジックを変えたくなったときに再処理するための原本です。最初から上書き加工してしまうと、どこで数字が変わったのか説明しにくくなります。

## 確認ポイント

- Raw配下に6種類のファイルが見えること
- customersとweb_eventsのサンプルが表示されること
- この時点では不正データもRawに残っていること

## Cell 14 - Python

```python
# ============================================================
# 05. Inspect raw files
# ============================================================
# Volumeに置かれたファイルを確認します。

file_rows = []
for root, dirs, files in os.walk(BASE_RAW_PATH):
    for name in files:
        full_path = os.path.join(root, name)
        file_rows.append((full_path, os.path.getsize(full_path)))

file_df = spark.createDataFrame(file_rows, "path string, size_bytes long")
show_df(file_df.orderBy("path"), 50)

print("Customers sample from raw CSV:")
show_df(read_raw_csv(f"{BASE_RAW_PATH}/customers/*.csv"), 5)

print("Web events sample from raw JSONL:")
show_df(spark.read.json(f"{BASE_RAW_PATH}/web_events/*.jsonl"), 5)
```

## Cell 15 - Markdown

## Step 08 - Load Bronze Tables

このセルでは、RawファイルをBronzeテーブルに取り込みます。

Bronzeは「Rawをなるべくそのまま保持する層」です。分析向けにきれいにする前に、まずRawをTableとして検索できる状態にします。

## このセルの入力と出力

| 種類 | 内容 |
|---|---|
| 入力 | Volume上のRaw CSV/JSONL |
| 処理 | Sparkで読み込み、監査列を付ける |
| 出力 | `demo_bronze_*_raw` と `demo_bronze_ingestion_audit` |

## Bronzeで追加する監査列

| 監査列 | 意味 |
|---|---|
| `_ingest_batch_id` | どの取り込みバッチで入ったか |
| `_ingested_at` | いつ取り込んだか |
| `_source_file` | どのRawファイルから来たか |
| `_source_name` | customers/ordersなどのソース名 |
| `_raw_line_hash` | Raw行を識別するためのハッシュ |

## なぜBronzeで不正データを消さないのか

Bronzeの目的は、きれいにすることではなく、Rawを追跡可能な形で残すことです。不正データもBronzeには残し、Silverで理由付きで分離します。

## 確認ポイント

- `demo_bronze_*_raw` テーブルが作成されること
- `demo_bronze_ingestion_audit` にソース別の取り込み件数が入ること
- 不正データもBronzeには残っていること

## Cell 16 - Python

```python
# ============================================================
# 06. Load Bronze tables
# ============================================================
# BronzeではRawデータをなるべくそのまま取り込み、監査列を付与します。

bronze_customers = add_bronze_metadata(
    read_raw_csv(f"{BASE_RAW_PATH}/customers/*.csv"),
    "customers",
)
bronze_products = add_bronze_metadata(
    read_raw_csv(f"{BASE_RAW_PATH}/products/*.csv"),
    "products",
)
bronze_orders = add_bronze_metadata(
    read_raw_csv(f"{BASE_RAW_PATH}/orders/*.csv"),
    "orders",
)
bronze_order_items = add_bronze_metadata(
    read_raw_csv(f"{BASE_RAW_PATH}/order_items/*.csv"),
    "order_items",
)
bronze_web_events = add_bronze_metadata(
    spark.read.option("mode", "PERMISSIVE").json(f"{BASE_RAW_PATH}/web_events/*.jsonl"),
    "web_events",
)
bronze_reviews = add_bronze_metadata(
    read_raw_csv(f"{BASE_RAW_PATH}/reviews/*.csv"),
    "reviews",
)

write_delta_table(bronze_customers, "demo_bronze_customers_raw")
write_delta_table(bronze_products, "demo_bronze_products_raw")
write_delta_table(bronze_orders, "demo_bronze_orders_raw")
write_delta_table(bronze_order_items, "demo_bronze_order_items_raw")
write_delta_table(bronze_web_events, "demo_bronze_web_events_raw")
write_delta_table(bronze_reviews, "demo_bronze_reviews_raw")

# Ingestion audit table
audit_rows = [
    (BATCH_ID, "customers", paths["customers"], bronze_customers.count()),
    (BATCH_ID, "products", paths["products"], bronze_products.count()),
    (BATCH_ID, "orders", paths["orders"], bronze_orders.count()),
    (BATCH_ID, "order_items", paths["order_items"], bronze_order_items.count()),
    (BATCH_ID, "web_events", paths["web_events"], bronze_web_events.count()),
    (BATCH_ID, "reviews", paths["reviews"], bronze_reviews.count()),
]
bronze_audit = (
    spark.createDataFrame(audit_rows, "ingest_batch_id string, source_name string, source_path string, row_count long")
    .withColumn("audit_created_at", F.current_timestamp())
)
write_delta_table(bronze_audit, "demo_bronze_ingestion_audit")

print("Bronze audit:")
show_df(spark.table(fq("demo_bronze_ingestion_audit")).orderBy("source_name"), 20)
```

## Cell 17 - Markdown

## Step 09 - Inspect Bronze Tables

Bronze作成直後に、RawファイルがどのようにManaged Tableへ取り込まれたかを確認します。

Bronzeは、RawファイルをTableとして扱えるようにした状態です。ただし、まだ分析用に型変換したり、不正データを除外したりはしていません。

## このステップで理解したいこと

| 観点 | Bronzeでの状態 |
|---|---|
| データの意味 | Rawに近い。まだ文字列中心 |
| 品質チェック | 本格的にはまだ行わない |
| 追跡性 | `_source_file` や `_raw_line_hash` で追える |
| 不正データ | 消さずに残す |
| 使い道 | 再処理、監査、Raw確認 |

## この後のSQLセルで見るもの

- Bronzeテーブルごとの行数
- 取り込み監査テーブル
- orders Rawのサンプル
- 監査列が付いていること

## 確認ポイント

- RawファイルごとのBronzeテーブル件数が見えること
- `demo_bronze_ingestion_audit` でソース別件数が見えること
- `_ingest_batch_id`, `_ingested_at`, `_source_file`, `_raw_line_hash` が付いていること
- `not_a_timestamp` や存在しないIDなども、この時点では残っていること

## Cell 18 - Markdown

## SQL Cell - Bronze Row Counts

Bronzeテーブルごとの行数を確認します。

RawファイルがManaged Tableとして取り込まれたかを、まず件数で確認します。ここではデータの中身の正しさではなく、「読み込めたか」「想定した種類のテーブルがあるか」を見ます。

見るポイント:

- customers/products/orders/order_items/web_events/reviews のBronzeテーブルが表示されること
- 件数が0ではないこと
- 後続のSilverで件数が変わる可能性があること

## Cell 19 - SQL

```sql
%sql
SELECT 'customers_raw' AS object_name, COUNT(*) AS row_count FROM `demo_bronze_customers_raw`
UNION ALL SELECT 'products_raw', COUNT(*) FROM `demo_bronze_products_raw`
UNION ALL SELECT 'orders_raw', COUNT(*) FROM `demo_bronze_orders_raw`
UNION ALL SELECT 'order_items_raw', COUNT(*) FROM `demo_bronze_order_items_raw`
UNION ALL SELECT 'web_events_raw', COUNT(*) FROM `demo_bronze_web_events_raw`
UNION ALL SELECT 'reviews_raw', COUNT(*) FROM `demo_bronze_reviews_raw`
UNION ALL SELECT 'ingestion_audit', COUNT(*) FROM `demo_bronze_ingestion_audit`
ORDER BY object_name
```

## Cell 20 - Markdown

## SQL Cell - Bronze Ingestion Audit

取込バッチ、ソースパス、ソース別件数を確認します。

`demo_bronze_ingestion_audit` は、どのRawソースをいつ何件取り込んだかを記録する監査テーブルです。デモでは、Bronzeが単なるコピーではなく、再処理や説明に使える履歴を持つことを見せます。

## Cell 21 - SQL

```sql
%sql
SELECT
  ingest_batch_id,
  source_name,
  source_path,
  row_count,
  audit_created_at
FROM `demo_bronze_ingestion_audit`
ORDER BY source_name
```

## Cell 22 - Markdown

## SQL Cell - Bronze Orders Sample

注文Rawのサンプルを確認します。

Bronzeでは値がまだ文字列中心で、`_source_file` や `_raw_line_hash` のような監査列が付いていることを見ます。不正日時や未知の顧客IDがあっても、この段階では消さずに残します。

## Cell 23 - SQL

```sql
%sql
SELECT
  order_id,
  customer_id,
  order_ts,
  status,
  order_total,
  _source_name,
  regexp_extract(_source_file, '[^/]+$', 0) AS source_file_name,
  _ingest_batch_id,
  _ingested_at,
  _raw_line_hash
FROM `demo_bronze_orders_raw`
ORDER BY order_id
LIMIT 20
```

## Cell 24 - Markdown

## Step 10 - Build Silver Dimensions

このセルでは、顧客と商品マスタをSilver層へ整形します。

Silverは「分析に使える品質へ整える層」です。ここでは顧客と商品という、売上ファクトを説明するためのマスタデータを作ります。

## 用語補足: Dimensionとは

Dimensionは、Factを説明するための属性データです。

例:

- 売上Factに `customer_id` がある
- 顧客Dimensionを見ると、その顧客の都道府県、会員区分、登録日が分かる
- 売上Factに `product_id` がある
- 商品Dimensionを見ると、その商品のカテゴリ、ブランド、原価が分かる

## このセルで行う処理

| 対象 | 主な処理 |
|---|---|
| customers | 文字列trim、メール小文字化、日付変換、年齢計算、重複排除 |
| products | 金額をdecimalへ変換、active flag正規化、重複排除 |

## なぜ型変換するのか

Raw/BronzeではCSV由来の値が文字列として入ることがあります。文字列のままだと、日付の大小比較や金額の合計が正しくできない場合があります。そのためSilverで、日付はdate/timestamp、金額はdecimal、数量はintegerのように変換します。

## 確認ポイント

- `demo_silver_customers` が作成されること
- `demo_silver_products` が作成されること
- 型変換後のサンプルが表示されること
- 顧客/商品マスタが後続の売上FactでJOINされること

## Cell 25 - Python

```python
# ============================================================
# 07. Transform Silver dimensions: customers and products
# ============================================================
# Silverでは型変換、正規化、重複排除を行います。

customers_raw = spark.table(fq("demo_bronze_customers_raw"))
products_raw = spark.table(fq("demo_bronze_products_raw"))

silver_customers = (
    customers_raw
    .select(
        F.trim(F.col("customer_id")).alias("customer_id"),
        F.trim(F.col("customer_name")).alias("customer_name"),
        F.lower(F.trim(F.col("email"))).alias("email"),
        F.trim(F.col("prefecture")).alias("prefecture"),
        F.lower(F.trim(F.col("customer_segment"))).alias("customer_segment"),
        F.to_date(F.expr("try_to_timestamp(signup_date)")).alias("signup_date"),
        F.expr("try_cast(birth_year as int)").alias("birth_year"),
        F.col("_ingest_batch_id"),
        F.col("_ingested_at"),
    )
    .dropDuplicates(["customer_id"])
)

silver_products = (
    products_raw
    .select(
        F.trim(F.col("product_id")).alias("product_id"),
        F.trim(F.col("category")).alias("category"),
        F.trim(F.col("sub_category")).alias("sub_category"),
        F.trim(F.col("brand")).alias("brand"),
        F.trim(F.col("product_name")).alias("product_name"),
        F.expr("try_cast(list_price as double)").alias("list_price"),
        F.expr("try_cast(cost as double)").alias("cost"),
        (F.upper(F.trim(F.col("active_flag"))) == F.lit("Y")).alias("is_active"),
        F.col("_ingest_batch_id"),
        F.col("_ingested_at"),
    )
    .dropDuplicates(["product_id"])
)

write_delta_table(silver_customers, "demo_silver_customers")
write_delta_table(silver_products, "demo_silver_products")

show_df(spark.table(fq("demo_silver_customers")), 5)
show_df(spark.table(fq("demo_silver_products")), 5)
```

## Cell 26 - Markdown

## Step 11 - Build Silver Facts and Data Quality Tables

このセルでは、注文・注文明細・Webイベント・レビューをSilver化し、データ品質問題を検出します。

このNotebookの中で、Medallion Architectureらしい一番重要な処理です。Raw/Bronzeに残っていた不正データを、理由付きでDQテーブルへ分離します。

## 用語補足

| 用語 | 意味 |
|---|---|
| Fact | 売上やイベントなど、集計したい出来事の明細データ |
| DQ issue | Data Qualityの問題として検出したレコード |
| 参照整合性 | 注文に出てくる `customer_id` が顧客マスタに存在する、などの整合性 |
| 重複排除 | 同じIDが複数ある場合に、1件へ絞る処理 |
| JOIN | 注文、明細、商品、顧客など別テーブルを結合する処理 |

## このセルで行う主な処理

| 処理 | 例 | 出力先 |
|---|---|---|
| 注文ID重複排除 | 同じ `order_id` は最新 `updated_at` を採用 | `demo_silver_orders` |
| 日付型変換 | `order_ts` をtimestamp/dateへ変換 | `demo_silver_orders` |
| 金額/数量型変換 | `order_total`, `quantity` を数値へ変換 | `demo_silver_orders`, `demo_silver_order_items` |
| 参照整合性チェック | 存在しない顧客ID/商品IDを検出 | `demo_silver_dq_issues` |
| 不正値検出 | 負の金額、不正status、rating=6など | `demo_silver_dq_summary` |
| 売上Fact作成 | 注文 x 明細 x 商品 x 顧客をJOIN | `demo_silver_sales_fact` |

## なぜDQテーブルに残すのか

不正データを黙って捨てると、後で「なぜ件数が減ったのか」「なぜ売上に入っていないのか」を説明できません。このデモでは、Gold KPIには不正データを入れない一方で、DQテーブルに理由を残します。

## 確認ポイント

- `demo_silver_orders`, `demo_silver_order_items`, `demo_silver_sales_fact` が作成されること
- `demo_silver_dq_issues` に不正データの明細が出ること
- `demo_silver_dq_summary` にルール別件数が出ること
- Bronzeには残っていた不正値が、Silverでは有効データとDQに分かれること

## Cell 27 - Python

```python
# ============================================================
# 08. Transform Silver facts and collect DQ issues
# ============================================================
# 注文・明細・Webイベント・レビューをSilver化し、不正データをdemo_silver_dq_issuesへ隔離します。

orders_raw = spark.table(fq("demo_bronze_orders_raw"))
items_raw = spark.table(fq("demo_bronze_order_items_raw"))
web_raw = spark.table(fq("demo_bronze_web_events_raw"))
reviews_raw = spark.table(fq("demo_bronze_reviews_raw"))
customers_s = spark.table(fq("demo_silver_customers"))
products_s = spark.table(fq("demo_silver_products"))

# ---- Orders ----
valid_statuses = ["completed", "cancelled", "refunded", "pending"]

orders_typed = (
    orders_raw
    .withColumn("order_id", F.trim(F.col("order_id")))
    .withColumn("customer_id", F.trim(F.col("customer_id")))
    .withColumn("order_ts_parsed", F.expr("try_to_timestamp(order_ts)"))
    .withColumn("updated_at_parsed", F.expr("try_to_timestamp(updated_at)"))
    .withColumn("channel_norm", F.lower(F.trim(F.col("channel"))))
    .withColumn("status_norm", F.lower(F.trim(F.col("status"))))
    .withColumn("order_total_num", F.expr("try_cast(order_total as double)"))
)

# Duplicate order_id handling: keep latest updated_at
order_window = Window.partitionBy("order_id").orderBy(F.col("updated_at_parsed").desc_nulls_last(), F.col("_ingested_at").desc_nulls_last())
orders_latest = (
    orders_typed
    .withColumn("_rn", F.row_number().over(order_window))
    .filter(F.col("_rn") == 1)
    .drop("_rn")
)

orders_checked = (
    orders_latest
    .join(customers_s.select("customer_id").withColumn("_customer_exists", F.lit(True)), on="customer_id", how="left")
)

order_issue_frames = [
    dq_issue(
        orders_checked,
        "demo_bronze_orders_raw",
        "order_id",
        F.col("order_ts_parsed").isNull(),
        "invalid_order_timestamp",
        F.concat(F.lit("order_ts="), F.coalesce(F.col("order_ts"), F.lit("<null>"))),
    ),
    dq_issue(
        orders_checked,
        "demo_bronze_orders_raw",
        "order_id",
        ~F.col("status_norm").isin(valid_statuses),
        "invalid_order_status",
        F.concat(F.lit("status="), F.coalesce(F.col("status"), F.lit("<null>"))),
    ),
    dq_issue(
        orders_checked,
        "demo_bronze_orders_raw",
        "order_id",
        F.col("order_total_num").isNull() | (F.col("order_total_num") < 0),
        "invalid_order_total",
        F.concat(F.lit("order_total="), F.coalesce(F.col("order_total"), F.lit("<null>"))),
    ),
    dq_issue(
        orders_checked,
        "demo_bronze_orders_raw",
        "order_id",
        F.col("_customer_exists").isNull(),
        "unknown_customer_id",
        F.concat(F.lit("customer_id="), F.coalesce(F.col("customer_id"), F.lit("<null>"))),
    ),
]

valid_orders = (
    orders_checked
    .filter(F.col("order_ts_parsed").isNotNull())
    .filter(F.col("status_norm").isin(valid_statuses))
    .filter(F.col("order_total_num").isNotNull() & (F.col("order_total_num") >= 0))
    .filter(F.col("_customer_exists").isNotNull())
    .select(
        "order_id",
        "customer_id",
        F.col("order_ts_parsed").alias("order_ts"),
        F.col("channel_norm").alias("channel"),
        F.col("status_norm").alias("status"),
        F.lower(F.trim(F.col("payment_method"))).alias("payment_method"),
        F.trim(F.col("coupon_code")).alias("coupon_code"),
        F.round(F.col("order_total_num"), 2).alias("order_total"),
        F.col("updated_at_parsed").alias("updated_at"),
        "_ingest_batch_id",
        "_ingested_at",
    )
)

write_delta_table(valid_orders, "demo_silver_orders")

# ---- Order items ----
items_typed = (
    items_raw
    .withColumn("order_id", F.trim(F.col("order_id")))
    .withColumn("product_id", F.trim(F.col("product_id")))
    .withColumn("line_no_int", F.expr("try_cast(line_no as int)"))
    .withColumn("quantity_int", F.expr("try_cast(quantity as int)"))
    .withColumn("unit_price_num", F.expr("try_cast(unit_price as double)"))
    .withColumn("discount_amount_num", F.expr("try_cast(discount_amount as double)"))
    .withColumn("item_pk", F.concat_ws(":", F.col("order_id"), F.col("line_no")))
)

items_checked = (
    items_typed
    .join(products_s.select("product_id").withColumn("_product_exists", F.lit(True)), on="product_id", how="left")
    .join(valid_orders.select("order_id").withColumn("_order_exists", F.lit(True)), on="order_id", how="left")
)

item_issue_frames = [
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("line_no_int").isNull(),
        "invalid_line_no",
        F.concat(F.lit("line_no="), F.coalesce(F.col("line_no"), F.lit("<null>"))),
    ),
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("quantity_int").isNull() | (F.col("quantity_int") <= 0),
        "invalid_quantity",
        F.concat(F.lit("quantity="), F.coalesce(F.col("quantity"), F.lit("<null>"))),
    ),
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("unit_price_num").isNull() | (F.col("unit_price_num") < 0),
        "invalid_unit_price",
        F.concat(F.lit("unit_price="), F.coalesce(F.col("unit_price"), F.lit("<null>"))),
    ),
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("discount_amount_num").isNull() | (F.col("discount_amount_num") < 0),
        "invalid_discount_amount",
        F.concat(F.lit("discount_amount="), F.coalesce(F.col("discount_amount"), F.lit("<null>"))),
    ),
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("_product_exists").isNull(),
        "unknown_product_id",
        F.concat(F.lit("product_id="), F.coalesce(F.col("product_id"), F.lit("<null>"))),
    ),
    dq_issue(
        items_checked,
        "demo_bronze_order_items_raw",
        "item_pk",
        F.col("_order_exists").isNull(),
        "unknown_or_invalid_order_id",
        F.concat(F.lit("order_id="), F.coalesce(F.col("order_id"), F.lit("<null>"))),
    ),
]

valid_items = (
    items_checked
    .filter(F.col("line_no_int").isNotNull())
    .filter(F.col("quantity_int").isNotNull() & (F.col("quantity_int") > 0))
    .filter(F.col("unit_price_num").isNotNull() & (F.col("unit_price_num") >= 0))
    .filter(F.col("discount_amount_num").isNotNull() & (F.col("discount_amount_num") >= 0))
    .filter(F.col("_product_exists").isNotNull())
    .filter(F.col("_order_exists").isNotNull())
    .select(
        "order_id",
        F.col("line_no_int").alias("line_no"),
        "product_id",
        F.col("quantity_int").alias("quantity"),
        F.round(F.col("unit_price_num"), 2).alias("unit_price"),
        F.round(F.col("discount_amount_num"), 2).alias("discount_amount"),
        "_ingest_batch_id",
        "_ingested_at",
    )
)

write_delta_table(valid_items, "demo_silver_order_items")

# ---- Sales fact ----
silver_sales_fact = (
    valid_items.alias("i")
    .join(valid_orders.alias("o"), on="order_id", how="inner")
    .join(products_s.alias("p"), on="product_id", how="left")
    .select(
        F.col("o.order_id"),
        F.col("i.line_no"),
        F.col("o.customer_id"),
        F.col("p.product_id"),
        F.col("p.category"),
        F.col("p.sub_category"),
        F.col("p.brand"),
        F.col("p.product_name"),
        F.col("o.order_ts"),
        F.to_date(F.col("o.order_ts")).alias("order_date"),
        F.col("o.channel"),
        F.col("o.status"),
        F.col("o.payment_method"),
        F.col("o.coupon_code"),
        F.col("i.quantity"),
        F.col("i.unit_price"),
        F.col("i.discount_amount"),
        F.round(F.col("i.quantity") * F.col("i.unit_price"), 2).alias("gross_sales"),
        F.round(F.col("i.quantity") * F.col("i.unit_price") - F.col("i.discount_amount"), 2).alias("net_sales"),
        F.round(F.col("i.quantity") * F.col("p.cost"), 2).alias("cost_amount"),
        F.round((F.col("i.quantity") * F.col("i.unit_price") - F.col("i.discount_amount")) - (F.col("i.quantity") * F.col("p.cost")), 2).alias("gross_margin"),
        F.col("o._ingest_batch_id").alias("_ingest_batch_id"),
        F.current_timestamp().alias("_transformed_at"),
    )
)
write_delta_table(silver_sales_fact, "demo_silver_sales_fact")

# ---- Web events ----
valid_event_types = ["view", "search", "product_view", "add_to_cart", "purchase"]
web_typed = (
    web_raw
    .withColumn("event_id", F.trim(F.col("event_id")))
    .withColumn("event_ts_parsed", F.expr("try_to_timestamp(event_ts)"))
    .withColumn("event_type_norm", F.lower(F.trim(F.col("event_type"))))
)

web_issue_frames = [
    dq_issue(
        web_typed,
        "demo_bronze_web_events_raw",
        "event_id",
        F.col("event_ts_parsed").isNull(),
        "invalid_event_timestamp",
        F.concat(F.lit("event_ts="), F.coalesce(F.col("event_ts"), F.lit("<null>"))),
    ),
    dq_issue(
        web_typed,
        "demo_bronze_web_events_raw",
        "event_id",
        ~F.col("event_type_norm").isin(valid_event_types),
        "invalid_event_type",
        F.concat(F.lit("event_type="), F.coalesce(F.col("event_type"), F.lit("<null>"))),
    ),
]

silver_web_events = (
    web_typed
    .filter(F.col("event_ts_parsed").isNotNull())
    .filter(F.col("event_type_norm").isin(valid_event_types))
    .select(
        "event_id",
        F.trim(F.col("session_id")).alias("session_id"),
        F.when(F.trim(F.col("customer_id")) == "", F.lit(None)).otherwise(F.trim(F.col("customer_id"))).alias("customer_id"),
        F.col("event_ts_parsed").alias("event_ts"),
        F.to_date(F.col("event_ts_parsed")).alias("event_date"),
        F.col("event_type_norm").alias("event_type"),
        F.when(F.trim(F.col("product_id")) == "", F.lit(None)).otherwise(F.trim(F.col("product_id"))).alias("product_id"),
        F.when(F.trim(F.col("campaign_id")) == "", F.lit(None)).otherwise(F.trim(F.col("campaign_id"))).alias("campaign_id"),
        F.lower(F.trim(F.col("device"))).alias("device"),
        F.lower(F.trim(F.col("referrer"))).alias("referrer"),
        "_ingest_batch_id",
        "_ingested_at",
    )
)
write_delta_table(silver_web_events, "demo_silver_web_events")

# ---- Reviews ----
reviews_typed = (
    reviews_raw
    .withColumn("review_id", F.trim(F.col("review_id")))
    .withColumn("customer_id", F.trim(F.col("customer_id")))
    .withColumn("product_id", F.trim(F.col("product_id")))
    .withColumn("review_ts_parsed", F.expr("try_to_timestamp(review_ts)"))
    .withColumn("rating_int", F.expr("try_cast(rating as int)"))
)

reviews_checked = (
    reviews_typed
    .join(customers_s.select("customer_id").withColumn("_customer_exists", F.lit(True)), on="customer_id", how="left")
    .join(products_s.select("product_id").withColumn("_product_exists", F.lit(True)), on="product_id", how="left")
)

review_issue_frames = [
    dq_issue(
        reviews_checked,
        "demo_bronze_reviews_raw",
        "review_id",
        F.col("review_ts_parsed").isNull(),
        "invalid_review_timestamp",
        F.concat(F.lit("review_ts="), F.coalesce(F.col("review_ts"), F.lit("<null>"))),
    ),
    dq_issue(
        reviews_checked,
        "demo_bronze_reviews_raw",
        "review_id",
        F.col("rating_int").isNull() | (F.col("rating_int") < 1) | (F.col("rating_int") > 5),
        "invalid_rating",
        F.concat(F.lit("rating="), F.coalesce(F.col("rating"), F.lit("<null>"))),
    ),
    dq_issue(
        reviews_checked,
        "demo_bronze_reviews_raw",
        "review_id",
        F.col("_customer_exists").isNull(),
        "unknown_review_customer_id",
        F.concat(F.lit("customer_id="), F.coalesce(F.col("customer_id"), F.lit("<null>"))),
    ),
    dq_issue(
        reviews_checked,
        "demo_bronze_reviews_raw",
        "review_id",
        F.col("_product_exists").isNull(),
        "unknown_review_product_id",
        F.concat(F.lit("product_id="), F.coalesce(F.col("product_id"), F.lit("<null>"))),
    ),
]

silver_reviews = (
    reviews_checked
    .filter(F.col("review_ts_parsed").isNotNull())
    .filter(F.col("rating_int").between(1, 5))
    .filter(F.col("_customer_exists").isNotNull())
    .filter(F.col("_product_exists").isNotNull())
    .select(
        "review_id",
        "customer_id",
        "product_id",
        F.col("review_ts_parsed").alias("review_ts"),
        F.to_date(F.col("review_ts_parsed")).alias("review_date"),
        F.col("rating_int").alias("rating"),
        F.trim(F.col("review_text")).alias("review_text"),
        F.when(F.col("rating_int") >= 4, "positive")
         .when(F.col("rating_int") == 3, "neutral")
         .otherwise("negative").alias("sentiment_label"),
        "_ingest_batch_id",
        "_ingested_at",
    )
)
write_delta_table(silver_reviews, "demo_silver_reviews")

# ---- DQ issue and summary tables ----
dq_frames = order_issue_frames + item_issue_frames + web_issue_frames + review_issue_frames
dq_all = reduce(lambda a, b: a.unionByName(b, allowMissingColumns=True), dq_frames)
write_delta_table(dq_all, "demo_silver_dq_issues")

silver_dq_summary = (
    dq_all
    .groupBy("source_table", "rule_name", "severity")
    .agg(
        F.count("*").alias("issue_count"),
        F.max("detected_at").alias("last_detected_at"),
    )
    .orderBy(F.desc("issue_count"), "source_table", "rule_name")
)
write_delta_table(silver_dq_summary, "demo_silver_dq_summary")

print("DQ summary:")
show_df(spark.table(fq("demo_silver_dq_summary")), 50)
```

## Cell 28 - Markdown

## Step 12 - Inspect Silver Tables

Silver作成直後に、Raw/Bronzeから分析可能な形へ整えた結果を確認します。

ここでは、Silverで何が良くなったのかをSQLで見ます。BronzeとSilverの差分を意識すると、Medallion Architectureの意味が分かりやすくなります。

## BronzeとSilverの違い

| 観点 | Bronze | Silver |
|---|---|---|
| 値の状態 | Rawに近い。文字列中心 | 日付・数値など分析しやすい型 |
| 不正データ | 残す | 有効データとDQ issueに分離 |
| 結合 | 基本しない | 注文、明細、商品、顧客をJOIN |
| 使い道 | 原本確認、監査、再処理 | 分析、集計、Gold作成の入力 |

## この後のSQLセルで見るもの

- Silverテーブルごとの行数
- 売上Factのスキーマ
- 売上Factのサンプル
- DQサマリ
- DQ明細
- Bronze件数とSilver有効件数の比較

## 確認ポイント

- `demo_silver_sales_fact` が注文・明細・商品を結合した分析用Factになっていること
- DQテーブルに意図的に混ぜた不正データが記録されていること
- Bronzeに残したRawと、Silverで利用可能になったデータの違いが見えること

## Cell 29 - Markdown

## SQL Cell - Silver Row Counts

Silverテーブルごとの行数を確認します。

DQで除外された行や重複排除された行があるため、Bronzeと件数差が出るテーブルがあります。件数が減ること自体は異常ではなく、Silverで品質を上げた結果です。

## Cell 30 - SQL

```sql
%sql
SELECT 'customers' AS object_name, COUNT(*) AS row_count FROM `demo_silver_customers`
UNION ALL SELECT 'products', COUNT(*) FROM `demo_silver_products`
UNION ALL SELECT 'orders', COUNT(*) FROM `demo_silver_orders`
UNION ALL SELECT 'order_items', COUNT(*) FROM `demo_silver_order_items`
UNION ALL SELECT 'sales_fact', COUNT(*) FROM `demo_silver_sales_fact`
UNION ALL SELECT 'web_events', COUNT(*) FROM `demo_silver_web_events`
UNION ALL SELECT 'reviews', COUNT(*) FROM `demo_silver_reviews`
UNION ALL SELECT 'dq_issues', COUNT(*) FROM `demo_silver_dq_issues`
UNION ALL SELECT 'dq_summary', COUNT(*) FROM `demo_silver_dq_summary`
ORDER BY object_name
```

## Cell 31 - Markdown

## SQL Cell - Silver Sales Fact Schema

売上ファクトの列と型を確認します。

`DESCRIBE TABLE` は、テーブルのカラム名とデータ型を見るSQLです。Bronzeの文字列Rawから、日付・数値・結合済みの分析用データになったことを確認します。

## Cell 32 - SQL

```sql
%sql
DESCRIBE TABLE `demo_silver_sales_fact`
```

## Cell 33 - Markdown

## SQL Cell - Silver Sales Fact Sample

売上ファクトのサンプルを確認します。

Factは、売上や数量など集計したい出来事の明細です。このサンプルでは、注文、商品、チャネル、数量、売上、粗利が1行で見られる形になっていることを確認します。

## Cell 34 - SQL

```sql
%sql
SELECT
  order_id,
  line_no,
  customer_id,
  product_id,
  category,
  sub_category,
  order_date,
  channel,
  status,
  quantity,
  unit_price,
  discount_amount,
  net_sales,
  gross_margin
FROM `demo_silver_sales_fact`
ORDER BY order_date, order_id, line_no
LIMIT 20
```

## Cell 35 - Markdown

## SQL Cell - Silver Data Quality Summary

DQルール別に検出件数を確認します。

`demo_silver_dq_summary` は、不正データの種類ごとの件数をまとめたテーブルです。Rawに混ぜた問題がここで可視化されます。デモでは、品質問題を隠さず説明できることがポイントです。

## Cell 36 - SQL

```sql
%sql
SELECT
  source_table,
  rule_name,
  severity,
  issue_count,
  last_detected_at
FROM `demo_silver_dq_summary`
ORDER BY issue_count DESC, source_table, rule_name
```

## Cell 37 - Markdown

## SQL Cell - Silver Data Quality Issue Samples

DQ明細を確認します。

`demo_silver_dq_issues` は、どのRawテーブルのどのキーが、どのルールに引っかかったかを記録するテーブルです。Summaryが集計、Issuesが明細、という関係です。

## Cell 38 - SQL

```sql
%sql
SELECT
  source_table,
  source_pk,
  rule_name,
  severity,
  issue_detail,
  detected_at
FROM `demo_silver_dq_issues`
ORDER BY source_table, rule_name, source_pk
LIMIT 50
```

## Cell 39 - Markdown

## SQL Cell - Bronze to Silver Order Count Comparison

注文データについて、BronzeのRaw件数、Silverの有効注文件数、DQ issue件数を並べて見ます。

この比較を見ると、「Bronzeでは残しているが、Silverでは有効データから外した」ものがあることを説明できます。

## Cell 40 - SQL

```sql
%sql
SELECT 'bronze_orders_raw' AS metric, COUNT(*) AS count_value FROM `demo_bronze_orders_raw`
UNION ALL SELECT 'silver_valid_orders', COUNT(*) FROM `demo_silver_orders`
UNION ALL SELECT 'order_dq_issues', COUNT(*) FROM `demo_silver_dq_issues` WHERE source_table = 'demo_bronze_orders_raw'
ORDER BY metric
```

## Cell 41 - Markdown

## Step 13 - Build Gold Tables

このセルでは、BIや業務ユーザー向けのGoldテーブルを作成します。

Goldは、Silverの明細データを業務で見やすい単位へ集計した完成データです。ここがデモの最終アウトプットです。

## SilverとGoldの違い

| 観点 | Silver | Gold |
|---|---|---|
| 粒度 | 注文・明細など細かい粒度 | 日次、商品、顧客、チャネルなど業務粒度 |
| 主な利用者 | データエンジニア、分析者 | BI利用者、業務担当者、管理者 |
| 主な目的 | 正しい分析用データを作る | すぐ見られるKPIを提供する |
| 例 | `demo_silver_sales_fact` | `demo_gold_daily_sales` |

## 作成するGoldテーブル

| Gold table | 内容 | デモで見るポイント |
|---|---|---|
| `demo_gold_daily_sales` | 日次・チャネル別売上 | 売上、粗利、平均注文額 |
| `demo_gold_product_performance` | 商品別実績 | 売上上位商品、レビュー評価 |
| `demo_gold_customer_360` | 顧客別集計 | LTV、購入回数、好みカテゴリ |
| `demo_gold_channel_funnel` | Webファネル | 閲覧から購入までの流れ |
| `demo_gold_review_summary` | 商品レビュー集計 | rating、positive/neutral/negative |
| `demo_gold_executive_kpis` | 経営KPI | 1行で全体感を説明 |

## 確認ポイント

- 上記6つのGoldテーブルが作成されること
- Executive KPIsが1行で表示されること
- DQで除外された不正データがGold KPIに混ざっていないこと

## Cell 42 - Python

```python
# ============================================================
# 09. Build Gold tables
# ============================================================
# GoldはBIや業務利用向けの完成データです。

sales = spark.table(fq("demo_silver_sales_fact"))
orders_s = spark.table(fq("demo_silver_orders"))
customers_s = spark.table(fq("demo_silver_customers"))
products_s = spark.table(fq("demo_silver_products"))
reviews_s = spark.table(fq("demo_silver_reviews"))
web_s = spark.table(fq("demo_silver_web_events"))
dq_summary = spark.table(fq("demo_silver_dq_summary"))

completed_sales = sales.filter(F.col("status") == "completed")

# 1) Daily sales by channel
order_level_sales = (
    completed_sales
    .groupBy("order_date", "channel", "order_id", "customer_id")
    .agg(
        F.sum("quantity").alias("order_units"),
        F.round(F.sum("net_sales"), 2).alias("order_net_sales"),
        F.round(F.sum("gross_margin"), 2).alias("order_gross_margin"),
    )
)

gold_daily_sales = (
    order_level_sales
    .groupBy("order_date", "channel")
    .agg(
        F.countDistinct("order_id").alias("order_count"),
        F.countDistinct("customer_id").alias("customer_count"),
        F.sum("order_units").alias("units_sold"),
        F.round(F.sum("order_net_sales"), 2).alias("net_sales"),
        F.round(F.sum("order_gross_margin"), 2).alias("gross_margin"),
    )
    .withColumn("avg_order_value", F.round(F.col("net_sales") / F.col("order_count"), 2))
    .withColumn("gross_margin_rate", F.round(F.col("gross_margin") / F.col("net_sales"), 4))
    .orderBy("order_date", "channel")
)
write_delta_table(gold_daily_sales, "demo_gold_daily_sales")

# 2) Product performance
review_by_product = (
    reviews_s
    .groupBy("product_id")
    .agg(
        F.count("*").alias("review_count"),
        F.round(F.avg("rating"), 2).alias("avg_rating"),
        F.sum(F.when(F.col("sentiment_label") == "positive", 1).otherwise(0)).alias("positive_reviews"),
        F.sum(F.when(F.col("sentiment_label") == "negative", 1).otherwise(0)).alias("negative_reviews"),
    )
)

gold_product_performance = (
    completed_sales
    .groupBy("product_id", "product_name", "category", "sub_category", "brand")
    .agg(
        F.countDistinct("order_id").alias("order_count"),
        F.sum("quantity").alias("units_sold"),
        F.round(F.sum("net_sales"), 2).alias("net_sales"),
        F.round(F.sum("gross_margin"), 2).alias("gross_margin"),
    )
    .withColumn("gross_margin_rate", F.round(F.col("gross_margin") / F.col("net_sales"), 4))
    .join(review_by_product, on="product_id", how="left")
    .na.fill({"review_count": 0, "positive_reviews": 0, "negative_reviews": 0})
    .orderBy(F.desc("net_sales"))
)
write_delta_table(gold_product_performance, "demo_gold_product_performance")

# 3) Customer 360
customer_sales = (
    completed_sales
    .groupBy("customer_id")
    .agg(
        F.countDistinct("order_id").alias("total_orders"),
        F.sum("quantity").alias("total_units"),
        F.round(F.sum("net_sales"), 2).alias("lifetime_value"),
        F.round(F.sum("gross_margin"), 2).alias("lifetime_gross_margin"),
        F.min("order_date").alias("first_order_date"),
        F.max("order_date").alias("last_order_date"),
    )
)

customer_category_sales = (
    completed_sales
    .groupBy("customer_id", "category")
    .agg(F.round(F.sum("net_sales"), 2).alias("category_sales"))
)
category_rank_window = Window.partitionBy("customer_id").orderBy(F.col("category_sales").desc_nulls_last())
favorite_category = (
    customer_category_sales
    .withColumn("rn", F.row_number().over(category_rank_window))
    .filter(F.col("rn") == 1)
    .select("customer_id", F.col("category").alias("favorite_category"))
)

gold_customer_360 = (
    customers_s
    .join(customer_sales, on="customer_id", how="left")
    .join(favorite_category, on="customer_id", how="left")
    .withColumn("total_orders", F.coalesce(F.col("total_orders"), F.lit(0)))
    .withColumn("total_units", F.coalesce(F.col("total_units"), F.lit(0)))
    .withColumn("lifetime_value", F.coalesce(F.col("lifetime_value"), F.lit(0.0)))
    .withColumn("lifetime_gross_margin", F.coalesce(F.col("lifetime_gross_margin"), F.lit(0.0)))
    .withColumn("avg_order_value", F.when(F.col("total_orders") > 0, F.round(F.col("lifetime_value") / F.col("total_orders"), 2)).otherwise(F.lit(0.0)))
    .select(
        "customer_id", "customer_name", "prefecture", "customer_segment", "signup_date", "birth_year",
        "total_orders", "total_units", "lifetime_value", "lifetime_gross_margin", "avg_order_value",
        "first_order_date", "last_order_date", "favorite_category",
    )
    .orderBy(F.desc("lifetime_value"))
)
write_delta_table(gold_customer_360, "demo_gold_customer_360")

# 4) Channel funnel from web events
funnel = (
    web_s
    .groupBy("event_date", "device", "referrer")
    .agg(
        F.countDistinct("session_id").alias("sessions"),
        F.countDistinct(F.when(F.col("event_type") == "view", F.col("session_id"))).alias("view_sessions"),
        F.countDistinct(F.when(F.col("event_type") == "product_view", F.col("session_id"))).alias("product_view_sessions"),
        F.countDistinct(F.when(F.col("event_type") == "add_to_cart", F.col("session_id"))).alias("add_to_cart_sessions"),
        F.countDistinct(F.when(F.col("event_type") == "purchase", F.col("session_id"))).alias("purchase_sessions"),
    )
    .withColumn("view_to_product_view_rate", F.round(F.col("product_view_sessions") / F.col("view_sessions"), 4))
    .withColumn("product_view_to_cart_rate", F.round(F.col("add_to_cart_sessions") / F.col("product_view_sessions"), 4))
    .withColumn("cart_to_purchase_rate", F.round(F.col("purchase_sessions") / F.col("add_to_cart_sessions"), 4))
    .orderBy("event_date", "device", "referrer")
)
write_delta_table(funnel, "demo_gold_channel_funnel")

# 5) Review summary
products_for_reviews = products_s.select("product_id", "product_name", "category", "sub_category", "brand")
gold_review_summary = (
    reviews_s
    .join(products_for_reviews, on="product_id", how="left")
    .groupBy("product_id", "product_name", "category", "sub_category", "brand")
    .agg(
        F.count("review_id").alias("review_count"),
        F.round(F.avg("rating"), 2).alias("avg_rating"),
        F.sum(F.when(F.col("sentiment_label") == "positive", 1).otherwise(0)).alias("positive_reviews"),
        F.sum(F.when(F.col("sentiment_label") == "neutral", 1).otherwise(0)).alias("neutral_reviews"),
        F.sum(F.when(F.col("sentiment_label") == "negative", 1).otherwise(0)).alias("negative_reviews"),
    )
    .withColumn("positive_rate", F.round(F.col("positive_reviews") / F.col("review_count"), 4))
    .orderBy(F.desc("review_count"), F.desc("avg_rating"))
)
write_delta_table(gold_review_summary, "demo_gold_review_summary")

# 6) Executive KPIs
sales_kpi = (
    completed_sales
    .agg(
        F.countDistinct("order_id").alias("completed_orders"),
        F.countDistinct("customer_id").alias("active_customers"),
        F.sum("quantity").alias("units_sold"),
        F.round(F.sum("net_sales"), 2).alias("net_sales"),
        F.round(F.sum("gross_margin"), 2).alias("gross_margin"),
        F.round(F.sum("discount_amount"), 2).alias("discount_amount"),
    )
    .withColumn("avg_order_value", F.round(F.col("net_sales") / F.col("completed_orders"), 2))
    .withColumn("gross_margin_rate", F.round(F.col("gross_margin") / F.col("net_sales"), 4))
)

order_status_kpi = (
    orders_s
    .agg(
        F.count("*").alias("valid_order_records"),
        F.sum(F.when(F.col("status") == "refunded", 1).otherwise(0)).alias("refunded_orders"),
        F.sum(F.when(F.col("status") == "cancelled", 1).otherwise(0)).alias("cancelled_orders"),
    )
    .withColumn("refund_rate", F.round(F.col("refunded_orders") / F.col("valid_order_records"), 4))
    .withColumn("cancel_rate", F.round(F.col("cancelled_orders") / F.col("valid_order_records"), 4))
)

dq_issue_count = dq_summary.agg(F.coalesce(F.sum("issue_count"), F.lit(0)).alias("dq_issue_count")).collect()[0]["dq_issue_count"]

gold_executive_kpis = (
    sales_kpi.crossJoin(order_status_kpi)
    .withColumn("run_date", F.lit(RUN_DATE).cast("date"))
    .withColumn("dq_issue_count", F.lit(int(dq_issue_count)))
    .select(
        "run_date", "completed_orders", "active_customers", "units_sold", "net_sales", "gross_margin",
        "gross_margin_rate", "discount_amount", "avg_order_value", "valid_order_records", "refunded_orders",
        "cancelled_orders", "refund_rate", "cancel_rate", "dq_issue_count",
    )
)
write_delta_table(gold_executive_kpis, "demo_gold_executive_kpis")

print("Gold executive KPIs:")
show_df(spark.table(fq("demo_gold_executive_kpis")), 10)
```

## Cell 43 - Markdown

## Step 14 - Equivalent Extraction With Python and SQL Cells

このステップでは、同じGoldテーブルに対して、PySpark DataFrame APIによる抽出とSQLセルによる抽出を両方残します。

AIDPでは、Python/PySparkでデータ加工を行い、SQLで結果確認や分析を行う、という使い分けができます。このデモでは、同じ結果がPythonでもSQLでも得られることを確認します。

## PythonとSQLの使い分け

| 方法 | 向いていること | このデモでの例 |
|---|---|---|
| Python / PySpark | 複雑な変換、関数化、再利用、条件分岐 | DataFrameでGoldテーブルを抽出し一時Viewへ保存 |
| SQL | 表示、抽出、集計、BI利用者への説明 | `%sql` セルで日次売上やTop商品を抽出 |

## ここで比較する3つの結果

- 日次・チャネル別売上
- 売上上位商品Top 10
- DQサマリ

## 用語補足: 一時View

一時Viewは、Notebookセッション内だけで使えるSQL用の名前です。Catalog上に永続的なViewを作るわけではありません。AIDP Catalogが永続Viewをサポートしない環境でも、セッション内の比較用途なら使いやすいです。

## 確認ポイント

- Python版とSQL版の抽出セルが別々に残っていること
- SQL版は `spark.sql(...)` ではなくSQLセルとして書かれていること
- 最後の比較セルで `[OK] ... results match` と表示されること

## Cell 44 - Python

```python
# ============================================================
# 10a. Python DataFrame API extraction
# ============================================================
# SQLセルとの比較用に、Python版の抽出結果を一時Viewとして保存します。

python_daily_sales_extract = (
    spark.table(fq("demo_gold_daily_sales"))
    .select(
        "order_date",
        "channel",
        "order_count",
        "customer_count",
        "units_sold",
        "net_sales",
        "gross_margin",
        "avg_order_value",
    )
)
python_daily_sales_extract.createOrReplaceTempView("demo_cmp_python_daily_sales")
print("Python DataFrame API result: daily sales")
show_df(python_daily_sales_extract.orderBy("order_date", "channel"), 20)

python_top_products_extract = (
    spark.table(fq("demo_gold_product_performance"))
    .select(
        "product_id",
        "product_name",
        "category",
        "sub_category",
        "brand",
        "units_sold",
        "net_sales",
        "gross_margin",
        "avg_rating",
    )
    .orderBy(F.desc("net_sales"), "product_id")
    .limit(10)
)
python_top_products_extract.createOrReplaceTempView("demo_cmp_python_top_products")
print("Python DataFrame API result: top products")
show_df(python_top_products_extract, 10)

python_dq_summary_extract = (
    spark.table(fq("demo_silver_dq_summary"))
    .select("source_table", "rule_name", "severity", "issue_count", "last_detected_at")
)
python_dq_summary_extract.createOrReplaceTempView("demo_cmp_python_dq_summary")
print("Python DataFrame API result: DQ summary")
show_df(python_dq_summary_extract.orderBy(F.desc("issue_count"), "source_table", "rule_name"), 50)
```

## Cell 45 - Markdown

## SQL Cell - Daily Sales Extraction

このSQLセルでは、日次・チャネル別売上をSQLで抽出し、比較用の一時View `demo_cmp_sql_daily_sales` を作成します。

Python側でも同じ抽出を行っているため、後で両者の結果が一致するか確認します。

## Cell 46 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW demo_cmp_sql_daily_sales AS
SELECT
  order_date,
  channel,
  order_count,
  customer_count,
  units_sold,
  net_sales,
  gross_margin,
  avg_order_value
FROM `demo_gold_daily_sales`
```

## Cell 47 - Markdown

## SQL Cell - Daily Sales Result

SQLで抽出した日次・チャネル別売上を表示します。

日付とチャネルごとに、注文数、顧客数、数量、売上、粗利、平均注文額を確認します。BIで最も見せやすいGoldテーブルの例です。

## Cell 48 - SQL

```sql
%sql
SELECT
  order_date,
  channel,
  order_count,
  customer_count,
  units_sold,
  net_sales,
  gross_margin,
  avg_order_value
FROM demo_cmp_sql_daily_sales
ORDER BY order_date, channel
```

## Cell 49 - Markdown

## SQL Cell - Top Products Extraction

このSQLセルでは、売上上位商品Top 10をSQLで抽出し、比較用の一時View `demo_cmp_sql_top_products` を作成します。

商品別の売上ランキングは、業務ユーザーにも分かりやすいGold活用例です。

## Cell 50 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW demo_cmp_sql_top_products AS
SELECT
  product_id,
  product_name,
  category,
  sub_category,
  brand,
  units_sold,
  net_sales,
  gross_margin,
  avg_rating
FROM `demo_gold_product_performance`
ORDER BY net_sales DESC, product_id
LIMIT 10
```

## Cell 51 - Markdown

## SQL Cell - Top Products Result

SQLで抽出した売上上位商品Top 10を表示します。

売上、粗利、レビュー評価を並べて見ることで、単に売れている商品だけでなく、利益や評価も一緒に確認できます。

## Cell 52 - SQL

```sql
%sql
SELECT
  product_id,
  product_name,
  category,
  sub_category,
  brand,
  units_sold,
  net_sales,
  gross_margin,
  avg_rating
FROM demo_cmp_sql_top_products
ORDER BY net_sales DESC, product_id
```

## Cell 53 - Markdown

## SQL Cell - DQ Summary Extraction

このSQLセルでは、DQサマリをSQLで抽出し、比較用の一時View `demo_cmp_sql_dq_summary` を作成します。

品質問題の件数も、SQLで説明できるレポートとして残します。

## Cell 54 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW demo_cmp_sql_dq_summary AS
SELECT
  source_table,
  rule_name,
  severity,
  issue_count,
  last_detected_at
FROM `demo_silver_dq_summary`
```

## Cell 55 - Markdown

## SQL Cell - DQ Summary Result

SQLで抽出したDQサマリを表示します。

どのルールに何件引っかかったかを確認します。データ品質の説明では、Gold KPIとあわせてこの表を見せると分かりやすいです。

## Cell 56 - SQL

```sql
%sql
SELECT
  source_table,
  rule_name,
  severity,
  issue_count,
  last_detected_at
FROM demo_cmp_sql_dq_summary
ORDER BY issue_count DESC, source_table, rule_name
```

## Cell 57 - Markdown

## Step 14b - Compare Python and SQL Results

最後に、Pythonセルで作った一時ViewとSQLセルで作った一時Viewを比較します。

この比較は「PythonとSQLのどちらを使っても、同じGoldテーブルから同じ結果が得られる」ことを確認するためのものです。

## このセルで行うこと

| 比較対象 | Python側 | SQL側 |
|---|---|---|
| 日次売上 | `demo_cmp_python_daily_sales` | `demo_cmp_sql_daily_sales` |
| Top商品 | `demo_cmp_python_top_products` | `demo_cmp_sql_top_products` |
| DQサマリ | `demo_cmp_python_dq_summary` | `demo_cmp_sql_dq_summary` |

## 見方

- `[OK] ... results match` と表示されれば、Python抽出とSQL抽出が一致しています。
- 差分が出た場合は、ORDER BY、丸め、NULL、型の違いなどを確認します。

このデモでは、SQL利用者とPython利用者が同じGoldデータを共有できることを見せるのが目的です。

## Cell 58 - Python

```python
# ============================================================
# 10b. Compare Python and SQL extraction results
# ============================================================
# SQLセルで作った一時Viewと、Pythonセルで作った一時Viewを比較します。


def assert_same_result(left_df, right_df, label: str):
    """Compare two Spark DataFrames as unordered row sets."""
    left_minus_right = left_df.exceptAll(right_df).count()
    right_minus_left = right_df.exceptAll(left_df).count()
    if left_minus_right or right_minus_left:
        raise AssertionError(
            f"{label}: results differ "
            f"(python_minus_sql={left_minus_right}, sql_minus_python={right_minus_left})"
        )
    print(f"[OK] {label}: Python DataFrame API and SQL cell results match")


compare_specs = [
    (
        "daily_sales",
        "demo_cmp_python_daily_sales",
        "demo_cmp_sql_daily_sales",
        ["order_date", "channel", "order_count", "customer_count", "units_sold", "net_sales", "gross_margin", "avg_order_value"],
    ),
    (
        "top_products",
        "demo_cmp_python_top_products",
        "demo_cmp_sql_top_products",
        ["product_id", "product_name", "category", "sub_category", "brand", "units_sold", "net_sales", "gross_margin", "avg_rating"],
    ),
    (
        "dq_summary",
        "demo_cmp_python_dq_summary",
        "demo_cmp_sql_dq_summary",
        ["source_table", "rule_name", "severity", "issue_count", "last_detected_at"],
    ),
]

for label, python_view, sql_view, cols in compare_specs:
    assert_same_result(
        spark.table(python_view).select(*cols),
        spark.table(sql_view).select(*cols),
        label,
    )
```

## Cell 59 - Markdown

## Step 15 - Create Demo Temporary Views With SQL Cells

このステップでは、GoldやDQテーブルを参照する確認用の一時ViewをSQLセルで作成します。

AIDP Catalogが永続Viewをサポートしない環境でも動くように、`CREATE OR REPLACE TEMP VIEW` を使います。

## なぜ一時Viewを使うのか

永続Viewを作れないCatalog環境でも、Notebookの中で見せるためのSQL名を一時的に作れます。デモ中に `demo_vw_dashboard_sales` のような分かりやすい名前で参照できるため、説明がしやすくなります。

## 注意点

一時ViewはNotebookセッション内だけの存在です。Notebookを再起動したり、別のセッションで実行したりすると見えなくなる場合があります。

AIDP環境によっては、一時Viewが後続SQLセルから見えない場合があります。その場合、このStep 15はスキップして構いません。次のStep 16は、ViewではなくGold/DQテーブルを直接参照する形にしているため、デモは続行できます。

## 作成する一時View

| Temporary View | 元データ | 用途 |
|---|---|---|
| `demo_vw_dashboard_sales` | `demo_gold_daily_sales` | ダッシュボード向け日次売上 |
| `demo_vw_top_products` | `demo_gold_product_performance` | 売上上位商品 |
| `demo_vw_customer_segments` | `demo_gold_customer_360` | 顧客セグメント集計 |
| `demo_vw_dq_report` | `demo_silver_dq_summary` | DQレポート |
| `demo_vw_medallion_lineage` | Bronze/Silver/Gold各テーブル | 層ごとの件数確認 |

## Cell 60 - Markdown

## SQL Cell - Create Dashboard Sales Temporary View

このSQLセルを実行して、日次売上ダッシュボード向けの一時Viewを作成します。

永続Viewではなく、一時Viewです。Notebookセッション内で見せやすい名前を付けるために使います。

## Cell 61 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW `demo_vw_dashboard_sales` AS
SELECT
  order_date,
  channel,
  order_count,
  customer_count,
  units_sold,
  net_sales,
  gross_margin,
  avg_order_value,
  gross_margin_rate
FROM `demo_gold_daily_sales`
```

## Cell 62 - Markdown

## SQL Cell - Create Top Products Temporary View

このSQLセルを実行して、売上上位商品向けの一時Viewを作成します。

商品別の売上、粗利、レビュー評価をデモで見せやすい列に絞ります。

## Cell 63 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW `demo_vw_top_products` AS
SELECT
  product_id,
  product_name,
  category,
  sub_category,
  brand,
  order_count,
  units_sold,
  net_sales,
  gross_margin,
  gross_margin_rate,
  review_count,
  avg_rating
FROM `demo_gold_product_performance`
```

## Cell 64 - Markdown

## SQL Cell - Create Customer Segments Temporary View

このSQLセルを実行して、顧客セグメント集計用の一時Viewを作成します。

顧客360をそのまま見るだけでなく、セグメントや都道府県別にまとめる例です。

## Cell 65 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW `demo_vw_customer_segments` AS
SELECT
  customer_segment,
  prefecture,
  COUNT(*) AS customer_count,
  SUM(total_orders) AS total_orders,
  ROUND(SUM(lifetime_value), 2) AS lifetime_value,
  ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM `demo_gold_customer_360`
GROUP BY customer_segment, prefecture
```

## Cell 66 - Markdown

## SQL Cell - Create DQ Report Temporary View

このSQLセルを実行して、DQレポート用の一時Viewを作成します。

DQサマリをデモで見せやすい名前にしておきます。

## Cell 67 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW `demo_vw_dq_report` AS
SELECT
  source_table,
  rule_name,
  severity,
  issue_count,
  last_detected_at
FROM `demo_silver_dq_summary`
```

## Cell 68 - Markdown

## SQL Cell - Create Medallion Lineage Temporary View

このSQLセルを実行して、Medallion各層の件数を確認する一時Viewを作成します。

ここでのLineageは厳密な自動リネージ機能ではなく、Bronze/Silver/GoldのどのTableに何件あるかを説明するための簡易一覧です。

## Cell 69 - SQL

```sql
%sql
CREATE OR REPLACE TEMP VIEW `demo_vw_medallion_lineage` AS
SELECT 'bronze' AS layer, 'customers_raw' AS object_name, COUNT(*) AS row_count FROM `demo_bronze_customers_raw`
UNION ALL SELECT 'bronze', 'products_raw', COUNT(*) FROM `demo_bronze_products_raw`
UNION ALL SELECT 'bronze', 'orders_raw', COUNT(*) FROM `demo_bronze_orders_raw`
UNION ALL SELECT 'bronze', 'order_items_raw', COUNT(*) FROM `demo_bronze_order_items_raw`
UNION ALL SELECT 'silver', 'customers', COUNT(*) FROM `demo_silver_customers`
UNION ALL SELECT 'silver', 'products', COUNT(*) FROM `demo_silver_products`
UNION ALL SELECT 'silver', 'orders', COUNT(*) FROM `demo_silver_orders`
UNION ALL SELECT 'silver', 'order_items', COUNT(*) FROM `demo_silver_order_items`
UNION ALL SELECT 'silver', 'sales_fact', COUNT(*) FROM `demo_silver_sales_fact`
UNION ALL SELECT 'gold', 'daily_sales', COUNT(*) FROM `demo_gold_daily_sales`
UNION ALL SELECT 'gold', 'product_performance', COUNT(*) FROM `demo_gold_product_performance`
UNION ALL SELECT 'gold', 'customer_360', COUNT(*) FROM `demo_gold_customer_360`
```

## Cell 70 - Markdown

## Step 16 - Demo Queries With SQL Cells

このステップでは、デモで見せる代表的な確認SQLをSQLセルとして実行します。

Pythonセルのループではなく、1つずつSQLセルとして残しているため、AIDP Notebook上でSQLの実行結果をそのまま見せられます。

## このステップで見せること

| SQL | 目的 |
|---|---|
| `SHOW TABLES LIKE 'demo_*'` | デモで作成したTable一覧を見る |
| Medallion lineage row counts | Bronze/Silver/Goldそれぞれの件数を見る |
| Executive KPIs | 経営向け1行KPIを見る |
| Daily sales by channel | 日次・チャネル別売上を見る |
| Top products | 売上上位商品を見る |
| Customer 360 | 顧客別LTVや購入回数を見る |
| Data Quality Report | DQ検出結果を見る |

## 初心者向けの見方

まずはGoldテーブルを見ると、業務ユーザーに見せる完成形が分かります。その後、DQ summaryを見ると「なぜ一部のRawデータがGoldに入っていないのか」を説明できます。

AIDP環境によっては永続Viewや一時Viewが使えないことがあるため、このステップのSQLは `demo_vw_*` に依存せず、Gold/DQテーブルを直接参照します。

## 確認ポイント

- Bronze/Silver/Goldのテーブルが一覧に出ること
- Medallion lineageで各層の行数が見えること
- DQ summaryに意図的な不正データの検出結果が出ること
- GoldテーブルがBI/KPIとして読みやすい形になっていること

## Cell 71 - Markdown

## SQL Cell - Show Demo Tables

このSQLセルを実行して、作成済みの `demo_*` テーブル一覧を確認します。

Catalog上にBronze/Silver/Goldのテーブルが作られていることを最初に確認するセルです。

## Cell 72 - SQL

```sql
%sql
SHOW TABLES LIKE 'demo_*'
```

## Cell 73 - Markdown

## SQL Cell - Medallion Lineage Row Counts

このSQLセルを実行して、Bronze/Silver/Gold各層の代表テーブル件数を確認します。

RawからGoldまで、データがどの層にどのくらい存在するかを見せるための一覧です。

## Cell 74 - SQL

```sql
%sql
SELECT 'bronze' AS layer, 'customers_raw' AS object_name, COUNT(*) AS row_count FROM `demo_bronze_customers_raw`
UNION ALL SELECT 'bronze', 'products_raw', COUNT(*) FROM `demo_bronze_products_raw`
UNION ALL SELECT 'bronze', 'orders_raw', COUNT(*) FROM `demo_bronze_orders_raw`
UNION ALL SELECT 'bronze', 'order_items_raw', COUNT(*) FROM `demo_bronze_order_items_raw`
UNION ALL SELECT 'silver', 'customers', COUNT(*) FROM `demo_silver_customers`
UNION ALL SELECT 'silver', 'products', COUNT(*) FROM `demo_silver_products`
UNION ALL SELECT 'silver', 'orders', COUNT(*) FROM `demo_silver_orders`
UNION ALL SELECT 'silver', 'order_items', COUNT(*) FROM `demo_silver_order_items`
UNION ALL SELECT 'silver', 'sales_fact', COUNT(*) FROM `demo_silver_sales_fact`
UNION ALL SELECT 'gold', 'daily_sales', COUNT(*) FROM `demo_gold_daily_sales`
UNION ALL SELECT 'gold', 'product_performance', COUNT(*) FROM `demo_gold_product_performance`
UNION ALL SELECT 'gold', 'customer_360', COUNT(*) FROM `demo_gold_customer_360`
ORDER BY layer, object_name
```

## Cell 75 - Markdown

## SQL Cell - Executive KPIs

このSQLセルを実行して、経営者向けの1行KPIを確認します。

売上、注文数、顧客数、粗利など、デモ全体の結果を一目で説明できます。

## Cell 76 - SQL

```sql
%sql
SELECT *
FROM `demo_gold_executive_kpis`
```

## Cell 77 - Markdown

## SQL Cell - Daily Sales by Channel

このSQLセルを実行して、日次・チャネル別売上を確認します。

折れ線グラフや棒グラフにしやすい、BI向けの代表的なGoldテーブルです。

## Cell 78 - SQL

```sql
%sql
SELECT *
FROM `demo_gold_daily_sales`
ORDER BY order_date, channel
LIMIT 50
```

## Cell 79 - Markdown

## SQL Cell - Top Products

このSQLセルを実行して、売上上位の商品を確認します。

商品別の売上、粗利、レビュー評価をまとめて見られるため、業務デモで説明しやすい表です。

## Cell 80 - SQL

```sql
%sql
SELECT *
FROM `demo_gold_product_performance`
ORDER BY net_sales DESC, product_id
LIMIT 10
```

## Cell 81 - Markdown

## SQL Cell - Customer 360 Top Customers

このSQLセルを実行して、LTVが高い顧客を確認します。

Customer 360は、顧客ごとの購買回数、売上、粗利、最終購入日、好みカテゴリなどをまとめたものです。

## Cell 82 - SQL

```sql
%sql
SELECT *
FROM `demo_gold_customer_360`
ORDER BY lifetime_value DESC, customer_id
LIMIT 10
```

## Cell 83 - Markdown

## SQL Cell - Data Quality Report

このSQLセルを実行して、DQサマリを確認します。

Gold KPIだけでなく、どのような不正データを検出・除外したかを一緒に見せることで、データの信頼性を説明できます。

## Cell 84 - SQL

```sql
%sql
SELECT *
FROM `demo_silver_dq_summary`
ORDER BY issue_count DESC, source_table, rule_name
LIMIT 50
```

## Cell 85 - Markdown

## Step 17 - Optional Charts or Chart-Ready Tables

このセルでは、Goldテーブルから可視化用の集計データを作ります。

Notebook環境によっては `matplotlib` が入っていないことがあります。その場合でもセルが失敗しないようにし、グラフ化しやすい集計表を表示します。

## このセルで作る表

| 表 | 内容 | 可視化するなら |
|---|---|---|
| daily sales | 日付別売上 | 折れ線グラフ。X軸=`order_date`, Y軸=`net_sales` |
| category sales | カテゴリ別売上 | 棒グラフ。X軸=`category`, Y軸=`net_sales` |
| funnel | Webファネル | 棒グラフ。X軸=`step`, Y軸=`sessions` |

## matplotlibが無い場合

`matplotlib is not installed` と表示されても問題ありません。AIDP Notebookの結果表として、可視化しやすい形のデータを表示します。

## AIDP Notebook側のVisualization確認方法

1. 表形式の結果が表示されているかを見る
2. 結果エリアの上部または右側に、`Visualization`、`Chart`、棒グラフのアイコン、または表示形式を切り替えるタブがあるかを見る
3. メニューがあれば、Line chartやBar chartを選ぶ
4. X軸に `order_date` / `category` / `step`、Y軸に `net_sales` / `sessions` を指定する
5. ボタンやタブが見当たらない場合、そのNotebook UIでは結果表からの可視化が無効、または未提供の可能性があります

## 確認ポイント

- `matplotlib is not installed` と出てもセルが失敗しないこと
- daily/category/funnel の集計表が表示されること
- 表をもとにNotebook UI側でグラフ化できるか確認できること

## Cell 86 - Python

```python
# ============================================================
# 13. Optional charts in Notebook
# ============================================================
# matplotlibが使えるComputeであれば、Notebook上で簡易グラフを表示します。
# matplotlibが入っていないComputeでは、集計結果を表として表示します。

try:
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ModuleNotFoundError:
    HAS_MATPLOTLIB = False
    print("[INFO] matplotlib is not installed on this AIDP Compute.")
    print("[INFO] Showing chart-ready aggregate tables instead. Use the Notebook result visualization if available.")

daily_sales_for_chart = (
    spark.table(fq("demo_gold_daily_sales"))
    .groupBy("order_date")
    .agg(F.round(F.sum("net_sales"), 2).alias("net_sales"))
    .orderBy("order_date")
)

category_sales_for_chart = (
    spark.table(fq("demo_gold_product_performance"))
    .groupBy("category")
    .agg(F.round(F.sum("net_sales"), 2).alias("net_sales"))
    .orderBy(F.desc("net_sales"))
)

funnel_for_chart = (
    spark.table(fq("demo_gold_channel_funnel"))
    .agg(
        F.sum("view_sessions").alias("view"),
        F.sum("product_view_sessions").alias("product_view"),
        F.sum("add_to_cart_sessions").alias("add_to_cart"),
        F.sum("purchase_sessions").alias("purchase"),
    )
    .selectExpr(
        "stack(4, "
        "'view', view, "
        "'product_view', product_view, "
        "'add_to_cart', add_to_cart, "
        "'purchase', purchase"
        ") as (step, sessions)"
    )
)

if HAS_MATPLOTLIB:
    # Daily net sales trend
    pdf_daily = daily_sales_for_chart.toPandas()
    ax = pdf_daily.plot(kind="line", x="order_date", y="net_sales", marker="o", legend=False)
    ax.set_title("Daily net sales")
    ax.set_xlabel("Order date")
    ax.set_ylabel("Net sales")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

    # Category sales
    pdf_category = category_sales_for_chart.toPandas()
    ax = pdf_category.plot(kind="bar", x="category", y="net_sales", legend=False)
    ax.set_title("Net sales by category")
    ax.set_xlabel("Category")
    ax.set_ylabel("Net sales")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

    # Funnel summary
    pdf_funnel = funnel_for_chart.toPandas()
    ax = pdf_funnel.plot(kind="bar", x="step", y="sessions", legend=False)
    ax.set_title("Web funnel sessions")
    ax.set_xlabel("Funnel step")
    ax.set_ylabel("Sessions")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()
else:
    print("Daily net sales chart data:")
    show_df(daily_sales_for_chart, 50)

    print("Category sales chart data:")
    show_df(category_sales_for_chart, 50)

    print("Web funnel chart data:")
    show_df(funnel_for_chart, 10)
```

## Cell 87 - Markdown

## Step 18 - Export Gold Results to Artifact Volume

このセルでは、Goldテーブルの一部をArtifact VolumeへCSV出力します。

GoldテーブルはCatalog上のManaged Tableとして残りますが、デモ成果物としてCSVを出したい場合があります。このセルは、その例です。

## このセルの入力と出力

| 種類 | 内容 |
|---|---|
| 入力 | `demo_gold_executive_kpis` |
| 処理 | SparkでCSV形式へ書き出し |
| 出力 | `/Volumes/<your_catalog>/production/demo_artifacts/exports/...` |

## Artifact Volumeとは

Rawファイル置き場とは別に、出力ファイルや共有用成果物を置くためのVolumeです。このデモでは `demo_artifacts` を使います。

## 確認ポイント

- `Exported executive KPIs` と表示されること
- Artifact Volume配下にCSV partファイルが作られること
- Catalog上のGold Tableと、ファイルとして出力したCSVの違いを説明できること

## Cell 88 - Python

```python
# ============================================================
# 14. Export selected Gold results to artifact volume
# ============================================================
# Goldテーブルの一部をCSVとしてdemo_artifacts Volumeにも出力します。
# BI連携前の確認やレポート共有のサンプルとして使えます。

export_dir = f"{BASE_ARTIFACT_PATH}/exports/run_date={RUN_DATE}/gold_executive_kpis"

(
    spark.table(fq("demo_gold_executive_kpis"))
    .coalesce(1)
    .write
    .mode("overwrite")
    .option("header", True)
    .csv(export_dir)
)

print(f"[OK] Exported executive KPIs to: {export_dir}")
print("Files:")
for root, dirs, files in os.walk(export_dir):
    for name in files:
        print(" ", os.path.join(root, name))
```

## Cell 89 - Markdown

## Step 19 - Optional Cleanup

このセルは任意のクリーンアップ用です。

通常のデモ実行では、このセルを実行しても何も削除されない設定にしています。誤って作成済みアセットを削除しないよう、デフォルトでは `RUN_CLEANUP = False` です。

## 削除対象の考え方

| 設定 | 削除されるもの | 使う場面 |
|---|---|---|
| `RUN_CLEANUP = False` | 何も削除しない | 通常はこちら |
| `RUN_CLEANUP = True` | `demo_*` Tableを削除 | デモ後にTableを消したい場合 |
| `DROP_VOLUMES_TOO = True` | Volumeも削除対象にする | 本当にVolumeまで消したい場合だけ |

## 注意

CatalogやSchemaには、他のユーザーや別デモの資産が入っている可能性があります。このセルはデモ用の `demo_*` を対象にしていますが、設定変更時は必ず内容を確認してください。

## 確認ポイント

- 通常は `RUN_CLEANUP=False: no cleanup executed` と表示されること
- 本当に削除したいときだけ設定を変更すること
- Volume削除は慎重に行うこと

## Cell 90 - Python

```python
# ============================================================
# 99. Optional cleanup
# ============================================================
# 誤実行防止のため、デフォルトでは何もしません。
# デモ資産を消したい場合は RUN_CLEANUP = True に変更して実行してください。

RUN_CLEANUP = False
DROP_VOLUMES_TOO = False  # TrueにするとRawファイルとartifactも削除されます。通常はFalse推奨。

if RUN_CLEANUP:
    print("Dropping demo tables...")
    for table_name in reversed(ALL_TABLES):
        safe_sql(f"DROP TABLE IF EXISTS {qfq(table_name)}", soft_fail=True)

    if DROP_VOLUMES_TOO:
        print("Dropping demo volumes...")
        for v in [RAW_VOLUME, ARTIFACT_VOLUME]:
            safe_sql(f"DROP VOLUME IF EXISTS {qident(CATALOG, SCHEMA, v)}", soft_fail=True)

    print("[OK] Cleanup completed")
else:
    print("RUN_CLEANUP=False: no cleanup executed")
```
