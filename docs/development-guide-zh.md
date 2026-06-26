# App Reporting Pack — 从零开发指南与技术文档

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈与依赖](#2-技术栈与依赖)
3. [项目结构](#3-项目结构)
4. [架构设计](#4-架构设计)
5. [核心数据流](#5-核心数据流)
6. [模块详解](#6-模块详解)
7. [配置系统](#7-配置系统)
8. [SQL 查询体系](#8-sql-查询体系)
9. [Python 脚本详解](#9-python-脚本详解)
10. [BigQuery 数据模型](#10-bigquery-数据模型)
11. [部署方式](#11-部署方式)
12. [测试体系](#12-测试体系)
13. [从零开发步骤](#13-从零开发步骤)
14. [常见问题与排障](#14-常见问题与排障)

---

## 1. 项目概述

### 1.1 项目定位

App Reporting Pack (ARP) 是一个 Google Ads App 广告系列的集中化报表平台。它解决的核心问题是：Google Ads UI 中 App 广告系列的关键数据分散在多个页面，难以获取全局洞察。

ARP 通过以下方式解决：
- 从 Google Ads API 拉取原始数据
- 在 BigQuery 中进行数据转换和聚合
- 输出结构化表供 Looker Studio 仪表盘展示

### 1.2 核心交付物

**BigQuery 输出表：**
- `ad_group_network_split` — 广告组级别按网络拆分的效果数据
- `asset_performance` — 素材级别效果数据（含队列分析）
- `creative_excellence` — 广告系列创意健康度评分
- `approval_statuses` — 广告审核状态追踪
- `change_history` — 出价/预算变更历史
- `performance_grouping_history` — 素材效果分组趋势
- `geo_performance` — 地理位置效果数据
- `ios_skan_decoder` — iOS SKAdNetwork 转化值解码

### 1.3 版本历史

| 版本 | 日期 | 关键变更 |
|------|------|----------|
| 1.4.0 | 2024-06-25 | 升级安装流程、自定义转化映射、API v16 |
| 1.3.0 | 2023-11-01 | 增量保存、模块化、回填机制 |
| 1.2.0 | 2023-07-31 | iOS SKAN 支持 |
| 1.1.0 | 2022-11-23 | 基础版本 |

---

## 2. 技术栈与依赖

### 2.1 语言与运行时

| 技术 | 用途 |
|------|------|
| Bash (Shell) | 主编排脚本、部署自动化 |
| SQL (GAQL + BigQuery) | 数据提取与转换 |
| Python 3.11 | 数据处理脚本 |
| Node.js | GCP Cloud Function (VM 创建) |
| Jinja2 | SQL 模板引擎 |

### 2.2 核心 Python 依赖

```
# app/requirements.in
google-ads-api-report-fetcher[bq]   # gaarf — Google Ads API 报表拉取
garf-executors[bq]                   # BigQuery 查询执行器
garf_youtube_data_api                # YouTube Data API 集成
pandas / numpy                       # 数据处理
pyyaml                               # YAML 配置解析
smart_open[gcs]                      # GCS 文件读写
google-api-python-client             # GCP API 客户端
db-dtypes                            # BigQuery 数据类型支持
```

### 2.3 CLI 工具

- `gaarf` — 执行 GAQL 查询，将 Google Ads 数据写入 BigQuery
- `gaarf-bq` — 执行 Jinja2 模板化的 BigQuery SQL
- `gaarf-simulator` — 模拟 API 查询用于测试（不实际调用 API）

### 2.4 GCP 服务

| 服务 | 用途 |
|------|------|
| BigQuery | 数据仓库（原始表 + 输出表 + 快照表） |
| Google Ads API | 广告数据源 |
| YouTube Data API | 视频素材元数据（可选） |
| Compute Engine | 运行 Docker 容器的临时 VM |
| Cloud Functions | Pub/Sub 触发的 VM 编排 |
| Cloud Scheduler | 定时触发执行 |
| Artifact Registry | Docker 镜像存储 |
| Cloud Storage | 配置文件和脚本存储 |
| Cloud Logging | 执行日志收集 |

---

## 3. 项目结构

```
app-reporting-pack/
├── app/                              # 主应用代码
│   ├── run-local.sh                  # ★ 主入口脚本
│   ├── requirements.in               # Python 依赖（未锁定）
│   ├── requirements.txt              # Python 依赖（锁定 + hash）
│   ├── config.yaml.template          # 配置模板
│   │
│   ├── core/                         # 核心模块：广告组效果
│   │   ├── google_ads_queries/       #   GAQL 查询（从 Ads API 拉数据）
│   │   └── bq_queries/              #   BigQuery 转换查询
│   │       ├── views/               #     视图 + UDF 函数
│   │       ├── snapshots/           #     每日快照
│   │       ├── incremental/         #     增量处理
│   │       └── legacy_views/        #     旧版兼容视图
│   │
│   ├── assets/                       # 素材模块：素材级效果 + 创意评分
│   │   ├── google_ads_queries/
│   │   └── bq_queries/
│   │
│   ├── geo/                          # 地理模块：按地区的效果
│   │   ├── google_ads_queries/
│   │   └── bq_queries/
│   │
│   ├── ios_skan/                     # iOS SKAN 模块：SKAdNetwork 数据
│   │   ├── google_ads_queries/
│   │   └── bq_queries/
│   │
│   ├── disapprovals/                 # 审核模块：广告审批状态
│   │   ├── google_ads_queries/
│   │   └── bq_queries/
│   │
│   ├── aggregate/                    # 聚合模块：跨模块汇总
│   │   └── bq_queries/
│   │
│   ├── conversion_lag_performance/   # 转化延迟模块
│   │   ├── google_ads_queries/
│   │   └── bq_queries/
│   │
│   └── scripts/                      # Python 脚本 + Shell 工具
│       ├── backfill_snapshots.py     #   快照回填
│       ├── conv_lag_adjustment.py    #   转化延迟调整
│       ├── create_skan_schema.py     #   SKAN 模式管理
│       ├── fetch_video_orientation.py #  视频方向获取
│       ├── create_dashboard.sh       #   仪表盘创建
│       ├── src/                      #   Python 库
│       │   ├── conv_lag_builder.py   #     延迟系数计算
│       │   └── queries.py           #     查询类定义
│       ├── shell_utils/              #   Shell 工具函数
│       │   ├── functions.sh          #     通用工具
│       │   ├── gaarf.sh             #     gaarf 封装
│       │   └── app_reporting_pack.sh #     ARP 配置逻辑
│       └── data/
│           └── conversion_lag_mapping.csv
│
├── gcp/                              # GCP 部署相关
│   ├── settings.ini                  #   部署配置
│   ├── install.sh                    #   安装脚本
│   ├── setup.sh                      #   部署自动化（432行）
│   ├── upgrade.sh                    #   升级脚本
│   ├── cloudbuild.yaml               #   Cloud Build 配置
│   ├── cloud-functions/create-vm/    #   Cloud Function（Node.js）
│   └── workload-vm/                  #   VM 工作负载
│       ├── Dockerfile
│       └── main.sh
│
├── tests/
│   ├── unit/                         # 单元测试
│   ├── end-to-end/                   # 端到端测试
│   └── test_google_queries.sh        # GAQL 查询验证
│
├── docs/                             # 文档 + 截图
├── Dockerfile                        # 主 Docker 镜像
├── docker-compose.yaml
├── .github/workflows/                # CI/CD
└── .pre-commit-config.yaml           # 代码质量钩子
```

## 4. 架构设计

### 4.1 整体架构

ARP 采用 Shell 编排 + 模块化插件 的架构模式：

```
┌─────────────────────────────────────────────────────────┐
│                   run-local.sh (编排层)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ functions.sh  │  │  gaarf.sh    │  │ app_report.. │   │
│  │ (通用工具)     │  │ (CLI 封装)   │  │ (ARP 配置)   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
├─────────────────────────────────────────────────────────┤
│                      模块层 (Modules)                     │
│  ┌──────┐ ┌──────┐ ┌─────┐ ┌──────┐ ┌──────┐ ┌─────┐  │
│  │ core │ │assets│ │ geo │ │ skan │ │disap.│ │aggr.│  │
│  └──┬───┘ └──┬───┘ └──┬──┘ └──┬───┘ └──┬───┘ └──┬──┘  │
│     │        │        │       │        │        │      │
├─────┼────────┼────────┼───────┼────────┼────────┼──────┤
│     ▼        ▼        ▼       ▼        ▼        ▼      │
│  ┌─────────────────┐  ┌──────────────────────────┐     │
│  │ google_ads_queries│  │     bq_queries            │     │
│  │ (GAQL → gaarf)   │  │ (Jinja2 SQL → gaarf-bq)   │     │
│  └────────┬────────┘  └────────────┬─────────────┘     │
│           │                        │                    │
│  ┌────────▼────────┐  ┌───────────▼──────────────┐     │
│  │ Python 中间件    │  │ BigQuery                   │     │
│  │ (conv_lag, video │  │ views → snapshots → output │     │
│  │  orientation...) │  │                            │     │
│  └─────────────────┘  └────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### 4.2 编排层

`run-local.sh` 是唯一入口，加载三个 Shell 库：

| 库文件 | 职责 |
|--------|------|
| `functions.sh` | 配置解析、gaarf 版本检查、增量快照检测、BQ 上传 |
| `gaarf.sh` | `fetch_reports()` 和 `generate_output_tables()` 封装 |
| `app_reporting_pack.sh` | SKAN 配置、cohort 设置、BQ 宏生成、日期校验 |

两个核心复用函数驱动所有模块执行：
- `run_google_ads_queries(module)` — 执行 `{module}/google_ads_queries/*.sql`
- `run_bq_queries(module)` — 按顺序执行 snapshots → views → 主查询 → legacy_views → incremental

### 4.3 模块化插件模式

每个模块遵循统一的目录约定：

```
{module}/
├── google_ads_queries/    # GAQL 查询文件（可选，aggregate 模块无此目录）
│   ├── query_1.sql
│   └── query_2.sql
└── bq_queries/
    ├── views/             # 视图和 UDF
    ├── snapshots/         # 每日快照
    ├── incremental/       # 增量处理（initial_load.sql + incremental_saving.sql）
    ├── legacy_views/      # 旧版兼容视图
    ├── output_query.sql   # 主输出查询
    └── ...
```

默认模块列表：`core,assets,disapprovals,ios_skan,geo,aggregate`
可通过 `--modules` 参数自定义。

### 4.4 模块间数据依赖

```
core ──────► assets ──────► aggregate
  │              │
  │              ├──► disapprovals
  │              │
  ▼              ▼
 (views)    (AssetCohorts)
```

- `core` 创建基础视图（`AppCampaignSettingsView`、`GeoLanguageView`、`ConversionLagAdjustments`）
- 其他模块通过 BigQuery JOIN 引用这些视图
- `aggregate` 模块 UNION 合并 assets/video/display 输出表

---

## 5. 核心数据流

### 5.1 完整执行序列

`run_with_config()` 函数（`run-local.sh`）按以下顺序执行：

**Phase 0 — 预检查**
- 对每个模块调用 `check_initial_load` 和 `check_missing_incremental_snapshot`
- 检测增量快照表是否存在、是否有间隔
- `define_runtime_config` 根据检测结果调整 `start_date`

**Phase 1 — Core 模块**
1. `run_google_ads_queries "core"` — 拉取 13 个 GAQL 查询到 BQ 原始表
2. `conv_lag_adjustment.py` — 从 Ads API 获取 180 天转化延迟数据，计算调整系数
3. `gaarf-bq core/bq_queries/snapshots/*.sql` — 创建 `bid_budgets_{date_iso}` 快照
4. `backfill_snapshots.py --restore-bid-budgets` — 回填最近 28 天缺失的出价/预算快照
5. `run_bq_queries "core"` — 创建视图 → UDF → 输出表 → 旧版视图 → 增量保存

**Phase 2 — Assets 模块**
1. `run_google_ads_queries "assets"` — 拉取 8 个 GAQL 查询
2. `fetch_video_orientation.py` — 从 YouTube Data API 获取视频方向
3. `backfill_snapshots.py --restore-cohorts` — 回填最近 5 天缺失的转化延迟队列快照
4. `run_bq_queries "assets"` — 创建快照 → 视图 → 输出表

**Phase 3 — Disapprovals 模块**
1. `run_google_ads_queries "disapprovals"` — 拉取广告审核状态
2. `run_bq_queries "disapprovals"` — 创建快照 → 输出 `approval_statuses`

**Phase 4 — Geo 模块**
1. `run_google_ads_queries "geo"` — 拉取地理效果数据
2. `run_bq_queries "geo"` — 输出 `geo_performance`

**Phase 5 — iOS SKAN 模块**
1. `run_google_ads_queries "ios_skan"` — 拉取 SKAN 回传数据
2. `create_skan_schema.py` — 创建/复制 SKAN 模式表
3. `run_bq_queries "ios_skan"` — 输出 `skan_decoder`

**Phase 6 — Aggregate 模块**
1. `run_bq_queries "aggregate"` — 动态 UNION 合并素材效果表

**Phase 7 — 收尾**
- `upload_last_run_to_bq` — 写入 `last_run` 表记录执行时间

### 5.2 数据集命名约定

| 数据集 | 默认名 | 内容 |
|--------|--------|------|
| `{bq_dataset}` | `arp` | 原始数据 + 中间表 + 视图 + 快照 |
| `{bq_dataset}_output` | `arp_output` | 最终输出表（供仪表盘使用） |
| `{bq_dataset}_legacy` | `arp_legacy` | 旧版兼容视图 |

### 5.3 数据流图

```
Google Ads API                    YouTube Data API
      │                                  │
      ▼                                  ▼
  gaarf CLI ──► {bq_dataset}        video_orientation
  (GAQL)        (原始表)                  │
      │              │                    │
      │         ┌────┴────┐               │
      │         ▼         ▼               │
      │    views/UDF   snapshots          │
      │         │     (bid_budgets_*      │
      │         │      conversion_lags_*) │
      │         ▼         │               │
      │    Python 脚本 ◄──┘               │
      │    (conv_lag,                     │
      │     backfill)                     │
      │         │                         │
      │         ▼                         │
      └──► gaarf-bq ◄────────────────────┘
           (Jinja2 SQL)
                │
                ▼
        {bq_dataset}_output
        (最终输出表)
                │
                ▼
          Looker Studio
```

---

## 6. 模块详解

### 6.1 Core 模块

**GAQL 查询**（13 个）：

| 查询文件 | 说明 |
|----------|------|
| `account_campaign_ad_group_mapping.sql` | 账户/广告系列/广告组层级映射 |
| `ad_group_conversion_split.sql` | 按广告组、网络、转化操作拆分的转化数据 |
| `ad_group_performance.sql` | 广告组级别点击/展示/花费/视频观看 |
| `app_campaign_settings.sql` | 广告系列类型、app_id、出价策略、目标转化 |
| `app_conversions_mapping.sql` | 转化来源/名称/类型/ID 映射 |
| `bid_budget.sql` | 启用状态广告系列的当前出价和预算 |
| `campaign_geo_targets.sql` | 广告系列地理定向标准 |
| `campaign_languages.sql` | 广告系列语言定向 |
| `display_campaign_performance.sql` | Display 广告系列效果（含视频四分位） |
| `geo_target_constant.sql` | 地理目标常量参考数据 |
| `ocid_mapping.sql` | OCID 映射（builtin 查询） |
| `action_items.sql` | 广告组操作建议 |
| `ad_group_ad_mapping.sql` | 广告组到广告映射（仅 VIDEO 类型） |

**BQ 转换**：
- `views/functions.sql` — 创建 UDF：`NormalizeMillis`（微分单位转换）、`ConvertAdNetwork`（网络枚举转换）、`BinText`/`BinBanners`（素材数量分箱）等
- `views/views.sql` — 创建视图：`AppCampaignSettingsView`（丰富的广告系列设置）、`GeoLanguageView`（聚合地理/语言定向）、`ConversionLagAdjustments`（延迟查找表）
- `snapshots/bid_budget_snapshot.sql` — 创建 `bid_budgets_{date_iso}` 每日快照
- `ad_group_network_split.sql` — 主输出：JOIN 效果 + 转化 + 映射 + 设置 + 地理/语言，应用转化延迟调整
- `change_history.sql` — 广告系列级别变更历史（出价/预算追踪、预算超限标记、CPA 偏离检测）

**输出表**：`ad_group_network_split`、`change_history`

### 6.2 Assets 模块

**GAQL 查询**（8 个）：

| 查询文件 | 说明 |
|----------|------|
| `asset_performance.sql` | 素材级别点击/展示/花费/安装/应用内 |
| `asset_mapping.sql` | 素材元数据（文本、图片尺寸、YouTube 视频信息） |
| `asset_reference.sql` | 素材状态：启用、效果标签、审核/审查状态 |
| `asset_structure.sql` | 广告结构（每种广告类型的标题/描述/图片/视频数量） |
| `asset_conversion_split.sql` | 按网络/转化操作拆分的素材级转化 |
| `ad_strength.sql` | 广告强度评分 |
| `mediafile.sql` | 媒体文件元数据（图片 URL、视频 ID、时长） |
| `video.sql` | 视频广告系列效果（含四分位完播率） |

**BQ 转换**：
- `snapshots/conversion_lags.sql` — 每日转化延迟快照
- `snapshots/asset_approval_statuses_snapshot.sql` — 素材审核状态快照
- `views/views.sql` — 创建 `AssetCohorts` 视图（展开 1-90 天延迟，向前填充，构造 STRUCT 数组）
- `asset_performance.sql` — 主输出：丰富的素材效果含队列数据、视频方向、尺寸、自定义转化
- `creative_excellence.sql` — 创意健康度：素材数量、预算充足性、广告强度、7 天效果评估

**输出表**：`asset_performance`、`creative_excellence`、`change_history`、`performance_grouping_history`、`asset_conversion_split`、`display_asset_performance`、`video_campaign_asset_performance`

### 6.3 Geo 模块

**GAQL 查询**（2 个）：
- `geo_performance.sql` — 用户位置视图（按国家的展示/点击/花费）
- `geo_performance_conversion_split.sql` — 地理转化分类拆分

**BQ 转换**：JOIN 地理效果 + 转化拆分 + 映射 + 广告系列设置 + 地理目标常量

**输出表**：`geo_performance`

### 6.4 iOS SKAN 模块

**GAQL 查询**（1 个）：
- `ios_campaign_skan_performance.sql` — SKAN 回传数据（按广告系列、转化值、来源应用、用户类型）

**BQ 转换**：使用 schema 输入表解码 SKAN 转化值，按出价策略（tCPI、tCPA、tROAS）分段

**输出表**：`skan_decoder`

### 6.5 Disapprovals 模块

**GAQL 查询**（1 个）：
- `ad_group_ad_disapprovals.sql` — 广告组审核/审查状态及政策主题

**BQ 转换**：创建每日审核快照 → 合并广告组和素材审核数据

**输出表**：`approval_statuses`

### 6.6 Aggregate 模块

**GAQL 查询**：无（纯 BQ 模块）

**BQ 转换**：`aggregate_performance.sql` — 使用动态 SQL（`DECLARE`/`IF`/`EXECUTE IMMEDIATE`）检测源表是否存在，将 `asset_performance`、`video_campaign_asset_performance`、`display_asset_performance` UNION 合并

**输出表**：`aggregate_asset_performance`

### 6.7 Conversion Lag Performance 模块

**GAQL 查询**（2 个）：
- `ad_group_conversion_lag.sql` — 按延迟桶、网络、转化操作拆分的转化
- `account_conversion_action_settings.sql` — 转化操作配置详情

**BQ 转换**：JOIN 延迟数据 + 转化操作设置，将延迟桶枚举映射为可读范围

**输出表**：`conversion_lag_performance`

> **注意**：此模块不在默认模块列表中，需通过 `--modules` 显式启用。

---

## 7. 配置系统

### 7.1 主配置文件 (`app/config.yaml.template`)

配置分为三个顶级段落：

**`gaarf` 段 — 控制 Google Ads API 数据拉取**：

```yaml
gaarf:
  output: bq
  bq:
    project: your-gcp-project
    dataset: arp                          # 原始数据集
  api_version: "21"                       # 支持 19, 20, 21
  account: 123-456-7890                   # MCC 或子账户 ID
  customer_ids_query: >-                  # 账户过滤查询
    SELECT customer.id FROM campaign
    WHERE campaign.advertising_channel_type IN ("MULTI_CHANNEL")
  params:
    macro:
      start_date: ":YYYYMMDD-90"          # 开始日期（默认 90 天前）
      end_date: ":YYYYMMDD-1"             # 结束日期（默认昨天）
```

**`gaarf-bq` 段 — 控制 BigQuery 转换**：

```yaml
gaarf-bq:
  project: your-gcp-project
  params:
    macro:
      bq_dataset: arp                     # 源数据集
      target_dataset: arp_output          # 输出数据集
      legacy_dataset: arp_legacy          # 旧版数据集
      skan_schema_input_table: ""         # SKAN 模式表引用
    template:
      cohort_days: "0,1,3,5,7,14,30"      # 队列延迟天数
      has_skan: true                       # 启用 SKAN 解码
      incremental: false                   # 启用增量存储
```

**运行时标志**：

```yaml
scripts:
  skan_mode:
    mode: placeholders                    # placeholders 或 table
incremental: false
legacy: false
backfill: true
```

### 7.2 GCP 部署配置 (`gcp/settings.ini`)

```ini
[config]
name=arp
config-file=app_reporting_pack.yaml

[repository]
name=arp
image=arp-image
location=us-docker.pkg.dev

[function]
name=arp-cf
region=us-central1

[pubsub]
topic=arp-topic

[scheduler]
name=arp-scheduler
schedule=0 0 * * *                        # 每天午夜执行
region=us-central1

[compute]
name=arp-vm
machine-type=e2-standard-2
region=us-central1
zone=us-central1-c
no-public-ip=false
```

### 7.3 CLI 参数

| 参数 | 说明 |
|------|------|
| `-c, --config` | 配置文件路径 |
| `-a, --account-id` | MCC/子账户 ID |
| `-q, --quiet` | 跳过确认提示 |
| `-g, --google-ads-config` | google-ads.yaml 路径 |
| `-l, --loglevel` | 日志级别（DEBUG/INFO/WARNING/ERROR） |
| `--legacy` | 生成旧版兼容视图 |
| `--backfill / --no-backfill` | 控制出价/预算回填 |
| `--initial-load` | 执行历史数据初始加载 |
| `--backfill-only` | 仅执行快照回填 |
| `--generate-config-only` | 仅生成配置不拉取数据 |
| `--modules` | 逗号分隔的模块列表 |
| `--api-version` | 覆盖 API 版本 |
| `--reset-incremental-performance-snapshots` | 删除增量快照表 |

---

## 8. SQL 查询体系

### 8.1 GAQL 查询模式

所有 GAQL 查询遵循标准 Google Ads 查询语言，常见模式：

```sql
-- 广告系列类型过滤
WHERE campaign.advertising_channel_type IN ("MULTI_CHANNEL", "DEMAND_GEN", "SEARCH")

-- 日期范围宏
AND segments.date >= "{start_date}" AND segments.date <= "{end_date}"

-- 资源 ID 提取（波浪线语法）
segments.conversion_action~0 AS conversion_id

-- 嵌套字段访问（冒号语法）
change_event.old_resource:campaign_budget.amount_micros

-- 策略摘要数组
ad_group_ad_asset_view.policy_summary:policy_topic_entries.type
```

### 8.2 BigQuery 查询模式

**视图（views/）**：
```sql
CREATE OR REPLACE VIEW `{bq_dataset}.AppCampaignSettingsView` AS
SELECT ... FROM `{bq_dataset}.app_campaign_settings` ...
```

**快照（snapshots/）**：
```sql
CREATE OR REPLACE TABLE `{bq_dataset}.bid_budgets_{date_iso}` AS
SELECT ... FROM `{bq_dataset}.bid_budget`
```

**增量处理（incremental/）**：
- `incremental_saving.sql` — 将 `start_date` 之前的数据归档到 `{table}_{yesterday_iso}`，之后的数据到 `{table}_{date_iso}`
- `initial_load.sql` — 首次加载时按初始日期边界拆分数据

**Jinja2 模板**：
```sql
-- 条件表名（增量模式）
{% if incremental == "true" %}
  CREATE OR REPLACE TABLE `{target_dataset}.ad_group_network_split_{date_iso}`
{% else %}
  CREATE OR REPLACE TABLE `{target_dataset}.ad_group_network_split`
{% endif %}

-- 动态自定义转化列
{% for custom_conversion in custom_conversions %}
  SUM(IF(conversion_name = "{{custom_conversion}}", conversions, 0))
    AS conversions_{{custom_conversion}},
{% endfor %}

-- 动态队列天数
{% for day in cohort_days %}
  cohorts.installs_{{day}}_days_ago,
{% endfor %}
```

**动态 SQL（aggregate）**：
```sql
DECLARE union_query STRING DEFAULT "";
IF EXISTS(SELECT 1 FROM `{target_dataset}.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = "asset_performance") THEN
  SET union_query = CONCAT(union_query, "SELECT ... FROM ...");
END IF;
EXECUTE IMMEDIATE union_query;
```

**UDF 函数**：
```sql
-- BigQuery 标准函数
CREATE OR REPLACE FUNCTION `{bq_dataset}.NormalizeMillis`(value INT64)
  AS (value / 1e6);

-- JavaScript UDF
CREATE OR REPLACE FUNCTION `{bq_dataset}.equalsArr`(x ARRAY<STRING>, y ARRAY<STRING>)
  RETURNS BOOL
  LANGUAGE js AS r"""...""";
```

---

## 9. Python 脚本详解

### 9.1 conv_lag_adjustment.py

- **作用**：计算每个网络和 conversion_id 的转化延迟调整系数
- **输入**：Google Ads API 数据（180 天窗口，30 天偏移），通过 `ConversionLagQuery` 获取
- **处理流程**：
  1. 读取 `conversion_lag_mapping.csv` 将延迟桶枚举映射为数值
  2. 计算累积转化百分比
  3. 展开延迟桶为 1-90 天的每日粒度
  4. 计算增量延迟调整值
- **输出**：BQ 表 `conversion_lag_adjustments`（列：`network`, `conversion_id`, `lag_day`, `lag_adjustment`）
- **调用时机**：Core 模块执行阶段

### 9.2 fetch_video_orientation.py

- **作用**：判断 YouTube 视频素材的方向（Landscape/Portrait/Square）
- **输入**：查询 `asset_mapping` 表获取 YouTube 视频 ID
- **处理**：调用 YouTube Data API 获取嵌入尺寸，计算宽高比。API 失败时回退为 "Unknown"
- **输出**：BQ 表 `video_orientation`（列：`video_id`, `video_orientation`）
- **调用时机**：Assets 模块执行阶段

### 9.3 create_skan_schema.py

- **作用**：创建或复制 SKAN 转化值模式表
- **模式**：
  - `placeholders` — 创建示例值的占位表
  - `table` — 从用户指定的 BQ 表复制
- **输出**：BQ 表 `skan_schema_input_table`
- **调用时机**：iOS SKAN 模块执行阶段

### 9.4 backfill_snapshots.py

三种独立的回填操作：

| 标志 | 说明 | 窗口 |
|------|------|------|
| `--restore-bid-budgets` | 从变更历史 API 恢复缺失的出价/预算快照 | 28 天 |
| `--restore-cohorts` | 从最近可用快照复制缺失的转化延迟队列快照 | 5 天 |
| `--restore-incremental-snapshots` | 检测增量快照间隔，输出新的 start_date | — |

### 9.5 辅助模块

**`src/queries.py`** — 定义 GAQL 查询类：
- `ConversionLagQuery` — 转化延迟数据查询
- `ChangeHistory` — 出价/预算变更历史查询
- `BidsBudgetsActiveCampaigns` / `BidsBudgetsInactiveCampaigns` — 出价预算查询
- `CampaignsWithSpend` — 有花费的广告系列查询

**`src/conv_lag_builder.py`** — 核心延迟计算逻辑：
- `ConversionLagBuilder` 类接收延迟数据 DataFrame 和分组列
- 计算累积转化百分比 → 展开为每日粒度 → 产出调整系数

**`scripts/create_dashboard.sh`** — 生成 Looker Studio 仪表盘克隆 URL

---

## 10. BigQuery 数据模型

### 10.1 表命名约定

| 类型 | 格式 | 示例 |
|------|------|------|
| 原始表 | `{bq_dataset}.{table_name}` | `arp.ad_group_performance` |
| 输出表 | `{target_dataset}.{table_name}` | `arp_output.ad_group_network_split` |
| 增量表 | `{target_dataset}.{table_name}_{date_iso}` | `arp_output.ad_group_network_split_20240101` |
| 快照表 | `{bq_dataset}.{table_name}_{date_iso}` | `arp.bid_budgets_20240101` |
| 旧版视图 | `{legacy_dataset}.{view_name}` | `arp_legacy.change_history` |
| 视图 | `{bq_dataset}.{ViewName}` (PascalCase) | `arp.AppCampaignSettingsView` |
| 函数 | `{bq_dataset}.{FunctionName}` (PascalCase) | `arp.NormalizeMillis` |

### 10.2 模式约定

- **货币值**：原始表存储为 micros（INT64），输出表通过 `NormalizeMillis`（÷1e6）转换
- **网络枚举**：原始存储为字符串（`CONTENT`、`SEARCH`），通过 `ConvertAdNetwork` 转换
- **日期**：原始表为 `YYYY-MM-DD` 字符串，输出表解析为 DATE 类型
- **通配符访问**：`{bq_dataset}.bid_budgets_*` 配合 `_TABLE_SUFFIX` 过滤

### 10.3 快照策略

| 快照表 | 说明 | 回填窗口 |
|--------|------|----------|
| `bid_budgets_{date_iso}` | 每日出价/预算状态 | 28 天（通过变更历史） |
| `conversion_lags_{date_iso}` | 素材转化延迟数据 | 5 天（从最近可用快照复制） |
| `ad_group_approval_statuses_{date_iso}` | 广告组审核快照 | — |
| `asset_approval_statuses_{date_iso}` | 素材审核快照 | — |
| `asset_structure_snapshot` | 结构快照 | — |
| `performance_grouping_snapshots` | 效果分组快照 | — |

### 10.4 增量策略

当 `incremental=true` 时：
1. 输出表获得 `_{date_iso}` 后缀
2. `incremental_saving.sql` 将旧数据（start_date 之前）归档到 `_{yesterday_iso}`，新数据到 `_{date_iso}`
3. `initial_load.sql` 处理首次历史数据加载
4. `check_missing_incremental_snapshot` 检测间隔并调整 start_date
5. 通配符查询（`{table}_*`）跨所有日期后缀表读取

---

## 11. 部署方式

### 11.1 本地执行

```bash
# 安装依赖
pip install -r app/requirements.txt

# 运行
bash app/run-local.sh \
  --config app/config.yaml \
  --google-ads-config google-ads.yaml \
  --account-id 123-456-7890
```

**前提条件**：
- Python 3.11+，已安装 `gaarf` CLI 工具
- `google-ads.yaml`（含 OAuth 凭据）
- GCP 项目（已启用 BigQuery 访问）

### 11.2 Docker 本地

**Dockerfile**（根目录）：
- 基础镜像：`python:3.11-slim-buster`
- 使用 `uv` 包管理器加速依赖安装
- 入口：`./app/run-local.sh --quiet`

```bash
# docker-compose.yaml 挂载三个卷
docker-compose run arp \
  --google-ads-config /google-ads.yaml \
  --config /app_reporting_pack.yaml
```

### 11.3 GCP 云端部署

`gcp/setup.sh` 自动化完整部署流水线：

```
┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│ Cloud        │───►│ Pub/Sub     │───►│ Cloud        │
│ Scheduler    │    │ Topic       │    │ Function     │
│ (每天午夜)    │    │             │    │ (create-vm)  │
└──────────────┘    └─────────────┘    └──────┬───────┘
                                              │
                                              ▼
                                     ┌──────────────┐
                                     │ Compute      │
                                     │ Engine VM    │
                                     │ (临时, 运行   │
                                     │  Docker 容器) │
                                     └──────┬───────┘
                                              │
                                     ┌────────▼───────┐
                                     │ BigQuery       │
                                     │ (输出表)        │
                                     └────────────────┘
```

**部署步骤**：
1. `enable_apis` — 启用 BigQuery、Compute、Artifact Registry、Cloud Functions 等 API
2. `set_iam_permissions` — 授予 Compute SA 必要角色
3. `deploy_files` — 上传应用脚本和配置到 GCS
4. `create_registry` — 创建 Artifact Registry Docker 仓库
5. `build_docker_image` — 通过 Cloud Build 构建并推送镜像
6. `deploy_cf` — 部署 Cloud Function（Pub/Sub 触发）
7. `schedule_run` — 创建 Cloud Scheduler 定时任务

**安装一键命令**：
```bash
bash gcp/install.sh
```

**升级**：
```bash
bash gcp/upgrade.sh
```

---

## 12. 测试体系

### 12.1 单元测试

位于 `tests/unit/`，使用 `pytest`：

- `test_backfill_snapshots.py` — 测试出价/预算历史恢复、队列快照回填、边界条件处理
- 测试数据：`tests/unit/data/` 下的 YAML 配置夹具
- `pytest.ini` 设置 `pythonpath=app` 以直接导入脚本

```bash
pytest tests/unit/
```

### 12.2 端到端测试

位于 `tests/end-to-end/test_app.py`：

- **需要真实 GCP 项目和 Google Ads 账户**
- 环境变量：`ARP_TEST_ACCOUNT`、`ARP_TEST_PROJECT`
- 使用 Jinja2 模板（`.j2` 文件）生成测试配置
- 测试场景：
  - `test_core_module_with_no_missing_runs` — 模拟 3 天连续运行，验证增量快照
  - `test_core_module_with_one_missing_run` — 模拟跳过 1 天运行，验证间隔恢复
- 验证查询：`validation_query_core.sql`、`validation_query_full.sql`
- 清理：测试后删除 BQ 数据集

### 12.3 GAQL 查询验证

```bash
bash tests/test_google_queries.sh
```

使用 `gaarf-simulator` 验证所有 GAQL 查询的语法正确性，无需实际 API 调用。

### 12.4 CI/CD 工作流

**`test-google-ads-queries.yaml`**：
- 触发：推送到 `**/google_ads_queries/*.sql` 文件或每日定时
- 矩阵策略：测试 API 版本 19、20、21

**`test-scripts.yaml`**：
- 触发：推送到 `app/scripts/**` 文件
- 运行 `pytest tests/unit/`

**`pre-commit`**（`.pre-commit-config.yaml`）：
- SQL 文件末尾空行检查
- YAML 格式验证
- 大文件检测

---

## 13. 从零开发步骤

### 13.1 环境准备

```bash
# 1. 克隆项目
git clone https://github.com/google-marketing-solutions/app-reporting-pack.git
cd app-reporting-pack

# 2. 创建 Python 虚拟环境
python3.11 -m venv .venv
source .venv/bin/activate

# 3. 安装依赖
pip install -r app/requirements.txt

# 4. 准备 Google Ads API 凭据
# 创建 google-ads.yaml（参考 Google Ads API 文档）
```

### 13.2 配置

```bash
# 1. 从模板创建配置
cp app/config.yaml.template app/config.yaml

# 2. 编辑配置（设置 GCP 项目、数据集、账户 ID）
vi app/config.yaml
```

### 13.3 首次运行

```bash
# 带交互提示的完整运行
bash app/run-local.sh \
  --config app/config.yaml \
  --google-ads-config google-ads.yaml

# 仅运行特定模块
bash app/run-local.sh \
  --config app/config.yaml \
  --google-ads-config google-ads.yaml \
  --modules core,assets

# 静默模式（无交互提示）
bash app/run-local.sh \
  --config app/config.yaml \
  --google-ads-config google-ads.yaml \
  --quiet
```

### 13.4 添加新模块

1. 创建模块目录结构：
```bash
mkdir -p app/new_module/google_ads_queries
mkdir -p app/new_module/bq_queries/{views,snapshots,incremental,legacy_views}
```

2. 编写 GAQL 查询（`app/new_module/google_ads_queries/your_query.sql`）

3. 编写 BQ 转换查询（`app/new_module/bq_queries/your_output.sql`）

4. 在 `run-local.sh` 的 `run_with_config()` 函数中添加模块调用：
```bash
if [[ "${modules}" == *"new_module"* ]]; then
  run_google_ads_queries "new_module"
  run_bq_queries "new_module"
fi
```

5. 将模块名称添加到默认模块列表或通过 `--modules` 显式启用

### 13.5 添加新查询

**添加 GAQL 查询**：
```sql
-- app/{module}/google_ads_queries/new_query.sql
SELECT
  campaign.id AS campaign_id,
  segments.date AS date,
  metrics.clicks AS clicks
FROM campaign
WHERE campaign.advertising_channel_type IN ("MULTI_CHANNEL")
  AND segments.date >= "{start_date}"
  AND segments.date <= "{end_date}"
```

**添加 BQ 输出查询**：
```sql
-- app/{module}/bq_queries/new_output.sql
{% if incremental == "true" %}
CREATE OR REPLACE TABLE `{target_dataset}.new_output_{date_iso}` AS
{% else %}
CREATE OR REPLACE TABLE `{target_dataset}.new_output` AS
{% endif %}
SELECT
  ...
FROM `{bq_dataset}.raw_table`
```

### 13.6 GCP 部署

```bash
# 一键安装（首次）
bash gcp/install.sh

# 升级现有部署
bash gcp/upgrade.sh
```

---

## 14. 常见问题与排障

### Q1: gaarf 命令找不到？
```bash
pip install google-ads-api-report-fetcher[bq]
```

### Q2: API 版本不兼容？
检查 `config.yaml` 中的 `api_version` 设置。当前支持版本：19、20、21。升级 API 版本后需运行 `gaarf-simulator` 验证查询：
```bash
bash tests/test_google_queries.sh
```

### Q3: 增量快照间隔导致数据缺失？
使用 `--initial-load` 重新执行历史数据加载，或使用 `--reset-incremental-performance-snapshots` 重置增量快照。

### Q4: SKAN 数据全是占位符？
确认 `config.yaml` 中 `skan_mode.mode` 设置为 `table` 并提供了有效的 `skan_schema_input_table`。

### Q5: 出价/预算变更历史缺失？
确保 `--backfill` 标志已启用（默认启用）。变更历史 API 仅保留最近 28 天数据。

### Q6: Docker 构建失败？
确保使用 Python 3.11 兼容的基础镜像。检查 `requirements.txt` 是否有 hash 不匹配：
```bash
pip-compile --generate-hashes app/requirements.in -o app/requirements.txt
```

### Q7: BigQuery 权限不足？
确保服务账户具有以下角色：
- `roles/bigquery.dataEditor`
- `roles/bigquery.jobUser`
- 对目标数据集的 `WRITER` 权限

### Q8: 如何添加自定义转化列？
在 `config.yaml` 的 `gaarf-bq.params.template` 下添加 `custom_conversions` 列表：
```yaml
params:
  template:
    custom_conversions:
      - "my_conversion_action_1"
      - "my_conversion_action_2"
```
