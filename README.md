# Rust App

## 1. 简介

Environment for **Rust** Application

为运行 **Rust** 应用程序而提供的环境。

镜像基于 alpine（musl），不包含编译工具链，只提供 Rust 应用运行所需的最小环境。
应用二进制通过挂载或二次构建注入，入口脚本位于 `/entrypoint.sh`（刻意放在挂载点之外，详见第 6 节）。

## 2. 特性

1. Alpine 3（musl），镜像约 52MB
2. TZ=Asia/Shanghai（tzdata 已保留，`TZ` 环境变量可正常生效）
3. LANG=C.UTF-8 / LC_ALL=C.UTF-8（此前仅在此声明、镜像内并未设置）
4. curl 及 telnet（busybox-extras）、bind-tools、openssl、brotli、zstd
5. gcompat：linux/amd64 变体额外提供 `/lib/ld-linux-x86-64.so.2`，可运行 glibc 动态链接的二进制
6. 当前工作路径：`/usr/local/myapp`
7. 程序路径：`/usr/local/myapp/myapp`
8. 支持参数传递：
   - `docker run 镜像名 --port 8080 --verbose`（参数**优先**）
   - `-e APP_ARGS='--msg "hello world"'`（支持引号，空格不会被拆散）

## 3. 编译应用（重要）

> 镜像是 musl 的。**请务必使用 musl 目标编译**，否则二进制无法启动。
> 典型现象是启动时报极具误导性的 `not found`（amd64 下为缺 `/lib/ld-linux-x86-64.so.2`，arm64 下为缺 `/lib/ld-linux-aarch64.so.1`）。
> 注意 gcompat 只对 linux/amd64 有效；**linux/arm64 变体必须用 musl 静态编译**，此点已实测确认。

```sh
# 推荐：musl 静态编译
cargo build --release --target aarch64-unknown-linux-musl   # arm64
cargo build --release --target x86_64-unknown-linux-musl    # amd64
```

微服务场景也可用 `cross` 或 docker 内编译：

```sh
docker run --rm --platform linux/arm64 -v "$PWD":/w -w /w rust:alpine cargo build --release
```

## 4. 编译并上传镜像

```sh
docker buildx build --platform linux/arm64,linux/amd64 -t nnzbz/rust-app:1.0.5 -t nnzbz/rust-app:latest . --push
```

一条命令打两个 tag，别写两遍（此前会把整个构建跑两次）。

## 5. 单机

```sh
docker run -d --name 容器名称 --init -p <宿主端口>:<容器端口> \
  -v /usr/local/外部程序所在目录:/usr/local/myapp \
  --restart=always nnzbz/rust-app:1.0.5
```

> 已去掉 `--net=host`。用 `-p 宿主端口:容器端口` 更安全、也便于与 Swarm 的 `ports:` 写法保持一致。

> ⚠️ **应用二进制必须以「已存在的文件」形式挂载**。若把宿主机上不存在的路径挂到 `/usr/local/myapp/myapp`，
> Docker 会创建一个同名**目录**，此时 `exec` 会报 `is a directory`，`chmod +x` 也会静默失败。
> 推荐做法如上：挂载应用**所在目录**到 `/usr/local/myapp`，目录里直接放 `myapp` 可执行文件。

启动失败时可直接看到原因，例如：

```
[entrypoint] 错误: 应用不存在: /usr/local/myapp/myapp
[entrypoint] 提示: 请用 -v 将编译好的二进制挂载到 /usr/local/myapp/myapp
```

## 6. 挂载与入口脚本说明（重要变更）

**旧版本 `entrypoint.sh` 生成在工作目录下，会被挂载覆盖导致容器启动即退出 127，现已修复。**

```
镜像内路径                 用途                      是否会被挂载覆盖
/entrypoint.sh             入口脚本（COPY 注入）      不会
/usr/local/myapp           工作目录 / APP_DIR          会被挂载覆盖
/usr/local/myapp/myapp     应用二进制                  随覆盖替换
/usr/local/myapp/init.sh   可选初始化脚本              随覆盖替换
```

`init.sh` 仍然放在工作目录中（方便通过挂载替换），但入口脚本会先判断它是否存在；
不存在就跳过，失败也只是一条警告，不会阻塞应用启动。

## 7. Swarm

- Docker Compose

```sh
mkdir -p /usr/local/myapp/
vi /usr/local/myapp/stack.yml
```

```yaml{.line-numbers}
services:
  svr:
    image: nnzbz/rust-app:1.0.5
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
      # 初始化脚本（可选）。注意：宿主机上该文件必须已存在，
      # 否则 Docker 会创建同名目录，脚本会被静默跳过
      #- ~/opt/myapp/init.sh:/usr/local/myapp/init.sh:z
      # 应用二进制，注意：~/opt/<应用目录>/app/<应用名称> 必须是已存在的文件
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

## 8. 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `APP_DIR` | `/usr/local/myapp` | 工作目录，应用二进制的挂载点 |
| `APP_NAME` | `myapp` | 入口脚本执行的二进制文件名 |
| `APP_ARGS` | 空 | 应用启动参数，支持引号 |
| `TZ` | `Asia/Shanghai` | 时区（依赖 tzdata，已安装） |
| `LANG` / `LC_ALL` | `C.UTF-8` | 字符集 |
| `RUST_LOG` | 未设置 | 应用日志级别，需应用自行读取 |
| `RUST_BACKTRACE` | 未设置 | `1` 为简略堆栈，`full` 为完整堆栈 |

参数优先级：`docker run` 尾部的参数 > `APP_ARGS`。

> **关于 root**：本镜像默认以 root 运行。这与 Docker 的默认行为一致，也是此类「运行时环境 + 挂载二进制」镜像的常见做法
> —— 入口脚本需要给挂载进来的文件补 `chmod +x`，而宿主文件通常属主是 root，非 root 用户改不了它的权限位
> （macOS 的 bind mount 强制 0755 且 `chmod` 恒返回 0，所以在 Mac 上测不出差异；Linux 上 0644 + root 属主会 EPERM）。
>
> 若部署环境要求非 root（如 K8s `restricted` 策略），可二次构建：
>
> ```dockerfile
> FROM nnzbz/rust-app:1.0.5
> RUN adduser -D -u 10001 app && chown -R app /usr/local/myapp
> USER app
> ```
>
> 此时宿主机上的二进制必须自带可执行权限：`chmod +x` 会失败（入口脚本会跳过并继续），
> 若文件本身没有 x 位，`exec` 会报 `Permission denied`。
