#!/bin/sh
#
# 容器入口脚本
#   1. 执行可选的 init.sh（用户可通过挂载提供）
#   2. 检查应用二进制是否存在
#   3. 启动应用
#
# 注意：此文件通过 COPY 放到 /entrypoint.sh，刻意不放在工作目录下，
# 因为用户通常把应用目录整体挂载到 $APP_DIR，放在那里会被覆盖。
#
set -u

APP_NAME="${APP_NAME:-myapp}"
APP_ARGS="${APP_ARGS:-}"
APP_DIR="${APP_DIR:-/usr/local/myapp}"

log() { echo "[entrypoint] $*"; }

cd "$APP_DIR" || {
    log "错误: 无法进入工作目录: $APP_DIR"
    exit 1
}

# 1. 可选的初始化脚本
if [ -f ./init.sh ]; then
    log "执行 init.sh"
    if ! sh ./init.sh; then
        log "警告: init.sh 执行失败，继续启动应用"
    fi
fi

# 2. 应用二进制检查
if [ ! -f "./$APP_NAME" ]; then
    log "错误: 应用不存在: $APP_DIR/$APP_NAME"
    log "提示: 请用 -v 将编译好的二进制挂载到 $APP_DIR/$APP_NAME"
    exit 127
fi

chmod +x "./$APP_NAME" 2>/dev/null || true

log "工作目录: $(pwd)"

# 3. 启动应用
#    - docker run 后面跟的参数优先级高于 APP_ARGS
#    - eval 会重新解析引号，因此 APP_ARGS 可以写成 '--msg "hello world"'
#      APP_ARGS 仅用于内部受控配置，不要传入不可信内容
if [ "$#" -gt 0 ]; then
    log "启动: ./$APP_NAME $*"
    exec "./$APP_NAME" "$@"
fi

log "启动: ./$APP_NAME $APP_ARGS"
eval "exec \"./$APP_NAME\" $APP_ARGS"
