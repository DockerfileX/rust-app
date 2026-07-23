# 基础镜像
FROM alpine:latest

# 作者及邮箱
# 镜像的作者和邮箱
LABEL maintainer="nnzbz@163.com"
# 镜像的描述
LABEL description="Environment for Rust Appication\
    为运行Rust应用程序而提供的环境"

USER root
# 更新
RUN apk update && apk upgrade
# 设置时区
RUN apk add tzdata
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo "Asia/Shanghai" > /etc/timezone
RUN apk del tzdata
# 安装 telnet minicom curl brotli
RUN apk add busybox-extras && apk -U add minicom && apk add curl && apk add brotli && apk add zstd
# 删除缓存
RUN rm -rf /var/cache/apk/*

# 设置工作目录
ENV WORKDIR=/usr/local/myapp/
RUN mkdir -p ${WORKDIR}
WORKDIR ${WORKDIR}

# 运行命令的文件名
ENV APP_NAME=myapp
# 运行命令的参数
ENV APP_ARGS=""

# 生成init.sh文件
RUN touch init.sh

# 生成entrypoint.sh文件
RUN echo '#!/bin/sh' >> entrypoint.sh
RUN echo 'set +e' >> entrypoint.sh
RUN echo 'chmod +x ./init.sh' >> entrypoint.sh
RUN echo 'chmod +x ./${APP_NAME}' >> entrypoint.sh
RUN echo 'sh ./init.sh' >> entrypoint.sh
RUN echo 'echo "print working directory:"' >> entrypoint.sh
RUN echo 'pwd' >> entrypoint.sh
RUN echo 'CMD="exec ./${APP_NAME} ${APP_ARGS}"' >> entrypoint.sh
RUN echo 'echo "will run command: $CMD"' >> entrypoint.sh
RUN echo '$CMD' >> entrypoint.sh

# 授权执行
RUN chmod +x ./init.sh
RUN chmod +x ./entrypoint.sh

# 执行
ENTRYPOINT ["sh", "./entrypoint.sh"]
