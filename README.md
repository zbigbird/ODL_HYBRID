# ODL_HYBRID

WeKnora 的 **odl-hybrid**（OpenDataLoader PDF 混合解析后端）镜像构建仓库。

- 产物：`ghcr.io/zbigbird/odl_hybrid:<tag>`（同时维护 `:latest`）
- 服务端口：5002，健康检查：`GET /health`
- 默认启动参数：`--no-ocr`（数字版 PDF 已有文本层；扫描件再改 `ODL_HYBRID_EXTRA_ARGS`）

## 跟随上游

每周一 03:00 UTC 自动检查两条上游信号，任一变化即产生新 tag 并重建：

| 信号 | 来源 |
|---|---|
| `opendataloader-pdf` 版本 | PyPI `/pypi/opendataloader-pdf/json` → `info.version` |
| 上游 Dockerfile | `Tencent/WeKnora@main:docker/Dockerfile.odl-hybrid` 的 sha256 前 12 位 |

tag 形如 `odl2.4.7-w1a2b3c4d5e6f`；该 tag 已存在则跳过构建（幂等）。

## 手动触发

```bash
gh workflow run build.yml -R zbigbird/ODL_HYBRID -f force=true
gh run watch -R zbigbird/ODL_HYBRID
```

## 本地构建（等价）

```bash
docker build \
  --build-arg ODL_PDF_SPEC='opendataloader-pdf[hybrid]==2.4.7' \
  --build-arg PIP_INDEX_URL_CN='https://pypi.tuna.tsinghua.edu.cn/simple' \
  -t odl_hybrid:local .
```

## 在 WeKnora 栈里使用

```dotenv
ODL_HYBRID_IMAGE=ghcr.io/zbigbird/odl_hybrid:<tag>
```

公开包可直接匿名拉取；若仍是 private，需在塔上 `docker login ghcr.io`（PAT 带 `read:packages`）。

## 说明

本镜像的 Dockerfile 不 COPY 任何源码（上游 odl-hybrid 镜像同样不依赖源码树），
构建只需基础镜像 + Debian 包 + PyPI；CPU-only torch 让体积从 ~7-8 GB 降到 ~4-5 GB。
