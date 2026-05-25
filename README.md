# Rust App

## 1. 简介

Environment for **Rust** Appication

为运行 **Rust** 应用而提供的环境

## 2. 特性

1. Alpine
2. TZ=Asia/Shanghai
3. C.UTF-8
4. curl和telnet
5. 当前工作路径: /usr/local/myapp/
6. 应用程序路径：/usr/local/myapp/myapp

## 3. 编译并上传镜像

```sh
docker buildx build --platform linux/arm64,linux/amd64 -t nnzbz/rust-app:1.0.2 . --push
docker buildx build --platform linux/arm64,linux/amd64 -t nnzbz/rust-app:latest . --push
```

## 4. 单机

```sh
docker run -d --net=host --name 容器名称 --init -v /usr/local/外部程序所在目录:/usr/local/myapp --restart=always nnzbz/rust-app:1.0.2
```

## 5. Swarm

- Docker Compose

```sh
mkdir -p /usr/local/myapp/
vi /usr/local/myapp/stack.yml
```

```yaml{.line-numbers}
services:
  svr:
    image: nnzbz/rust-app:1.0.2
    init: true
    hostname: <应用名称>
    # 端口
    ports:
      - <外部端口>:<内部端口>
    environment:
      # 日志级别
      - RUST_LOG=debug
      # 打印堆栈，如果全部打印设置为full
      - RUST_BACKTRACE=1
    volumes:
      # 初始化脚本
      #- ~/opt/myapp/init.sh:/usr/local/myapp/init.sh:z
      # 应用目录
      - ~/opt/<应用目录>/app/<应用名称>:/usr/local/myapp/myapp:z
      - ~/opt/<应用目录>/app/<应用名称>.toml:/usr/local/myapp/myapp.toml:z
    deploy:
      placement:
        constraints:
          # 部署指定角色的节点
          - node.labels.role==<节点角色>
    logging:
      options:
        max-size: 8m

networks:
  default:
    external: true
    name: rebue
```

- 部署

```sh
docker stack deploy -c /usr/local/myapp/stack.yml myapp
```
