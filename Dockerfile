# =============================================================================
# WeKnora odl-hybrid (OpenDataLoader hybrid backend for docreader)
# 对应上游 Tencent/WeKnora 的 docker/Dockerfile.odl-hybrid 思路，差异：
#   ① python:3.10-slim 基座（上游为 3.10.18-bookworm）
#   ② 先装 CPU-only torch/torchvision，避免 PyPI 默认 wheel 拖入数 GB nvidia-*
#   ③ 版本由 CI 传入（ODL_PDF_SPEC，精确 == 锁定），可复现
# 上游 Dockerfile 无 COPY/ADD，本文件同样不依赖任何源码树。
# =============================================================================
FROM python:3.10-slim-bookworm

ARG ODL_PDF_SPEC="opendataloader-pdf[hybrid]>=2.4.7"
ARG PIP_INDEX_URL_CN=""
ARG UPSTREAM_SHA=""

LABEL org.opencontainers.image.title="weknora-odl-hybrid" \
      org.opencontainers.image.description="OpenDataLoader PDF hybrid backend (5002) for WeKnora docreader" \
      org.opencontainers.image.source="https://github.com/zbigbird/ODL_HYBRID" \
      org.opencontainers.image.revision="${UPSTREAM_SHA}" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    ODL_HYBRID_EXTRA_ARGS="--no-ocr" \
    ODL_HYBRID_PORT=5002 \
    HF_HOME=/root/.cache/huggingface

# docling 的表格/版面模型运行期要 import cv2，需要 libGL（即使 --no-ocr）
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates libgl1 libglib2.0-0 libgomp1 libsm6 \
    && rm -rf /var/lib/apt/lists/*

# ① CPU-only torch。
#    PyTorch 的 cpu 索引对“依赖包”只是按需转链，部分条目只有 sdist（如 typing_extensions 4.16.0），
#    构建这些 sdist 需要 flit_core 等后端 —— 该索引本身不提供，会报
#      ERROR: Could not find a version that satisfies the requirement flit_core<4,>=3.11
#    所以：先装构建后端（走 PyPI），再用 cpu 索引装 torch，并允许 PyPI 作为依赖兜底。
#    安装后用 torch.version.cuda is None 断言“确实是 CPU 版”，防止 PyPI 上更高版本的
#    CUDA wheel 被误选（真被选中时构建直接失败，而不是悄悄产出 8 GB 镜像）。
ARG TORCH_SPEC="torch torchvision"
RUN pip install --no-cache-dir --index-url https://pypi.org/simple \
        flit_core setuptools wheel hatchling poetry-core packaging setuptools_scm \
    && pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cpu \
        --extra-index-url https://pypi.org/simple \
        ${TORCH_SPEC} \
    && python -c "import torch; assert torch.version.cuda is None, f'CUDA build leaked: {torch.__version__}'; print('torch', torch.__version__)"

# ② opendataloader-pdf[hybrid]：torch/torchvision 已满足，不会回退去拉 CUDA 版
RUN if [ -n "$PIP_INDEX_URL_CN" ]; then \
        pip install -i "$PIP_INDEX_URL_CN" "$ODL_PDF_SPEC"; \
    else \
        pip install "$ODL_PDF_SPEC"; \
    fi

# ③ 构建期自检：CLI 存在 + 关键依赖可 import（坏构建在这一层失败，而不是运行期才发现）
RUN opendataloader-pdf-hybrid --help >/dev/null \
    && python -c "import torch, torchvision, docling; print('torch', torch.__version__)"

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=180s \
    CMD curl -fsS http://localhost:5002/health || exit 1

CMD ["bash", "-c", "exec opendataloader-pdf-hybrid --host 0.0.0.0 --port 5002 ${ODL_HYBRID_EXTRA_ARGS}"]
