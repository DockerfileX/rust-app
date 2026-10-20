# 基础镜像
# 固定主版本号，避免 alpine:latest 漂移导致同一份 Dockerfile 每次构建内容不同
ARG ALPINE_VERSION=3
FROM alpine:${ALPINE_VERSION}

# 作者及邮箱
LABEL maintainer="nnzbz@163.com"
# 镜像的描述
LABEL description="Environment for Rust Application / 为运行 Rust 应用程序而提供的环境"

# 时区 + 字符集
# 原 README 宣称支持 C.UTF-8，但此前 Dockerfile 里从未设置过
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# 系统依赖：所有 apk 操作合并到同一层
#  - ca-certificates/openssl：HTTPS 与证书
#  - gcompat：仅对 linux/amd64 变体有效，提供 /lib/ld-linux-x86-64.so.2，
#    让 glibc 动态链接的二进制也能跑（本体是 musl，没有该文件会报
#    "not found" 这种极具误导性的错误）
#    注意：gcompat 不提供 ld-linux-aarch64.so.1，因此 linux/arm64 变体
#    下 glibc 二进制依然无法运行，必须使用 musl 目标交叉编译。
#    已实测确认（arm64 容器运行 aarch64 glibc 二进制失败：
#    Could not open '/lib/ld-linux-aarch64.so.1'）
#  - tzdata 必须保留：删除后 TZ 环境变量会静默失效，date/chrono 等
#    全部回落到 UTC（实测确认，勿删）
RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        tzdata \
        gcompat \
        libgcc \
        openssl \
        busybox-extras \
        bind-tools \
        minicom \
        curl \
        brotli \
        zstd; \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo "Asia/Shanghai" > /etc/timezone; \
    update-ca-certificates

# 设置工作目录（应用二进制的挂载点）
ENV APP_DIR=/usr/local/myapp
WORKDIR ${APP_DIR}

# 运行命令的文件名
ENV APP_NAME=myapp
# 运行命令的参数（支持引号，例如 APP_ARGS='--msg "hello world"'）
ENV APP_ARGS=""

# 入口脚本放在挂载点之外
# 关键修复：原先 entrypoint.sh 生成在 /usr/local/myapp/ 下，
# 一旦按 README 用 -v 把宿主目录挂到该路径，脚本就被覆盖，容器启动即 exit 127
COPY --chmod=0755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
