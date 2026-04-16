# nginx-gateway

独立网关项目，承接以下逻辑：
- `go-server` 反向代理（`api.md-zgxt.com`）
- `go-admin-ui` 反向代理（`admin.md-zgxt.com`）
- `dex-ui` 反向代理（`swap.md-zgxt.com`）
- `mid-route` 反向代理（`mid-route.site` -> `host:8080`）
- `certbot` 证书签发与续签
- `/upload/` 静态文件直出（映射 go-server 上传目录）

## 目录结构

- `docker-compose.yml`：网关运行编排
- `nginx/templates/http-only.conf`：无证书时配置
- `nginx/templates/https.conf`：有证书时配置
- `nginx/default.conf`：当前生效配置（由脚本切换）
- `scripts/bootstrap.sh`：启动并自动按证书状态切换
- `scripts/request-cert.sh`：按主域名证书组申请/刷新证书并切换 HTTPS
- `scripts/renew-cert.sh`：按主域名证书组续签证书并重启网关
- `scripts/common.sh`：固定证书组清单（每个主域名一张证书，覆盖其子域名）

## 前置条件

- `go-server`、`go-admin-ui`、`dex-ui` 容器已运行，并在同一个 Docker 网络：`rwat-edge`
- 上传目录固定为：`/opt/projects/rwat/app/upload`（容器内映射为 `/var/www/rwat/upload`）
- `mid-route.site` 目标服务监听宿主机 `8080` 端口
- `bootstrap/request-cert/renew-cert` 脚本会自动检查并创建 `rwat-edge` 网络

## 服务器固定目录

- 网关部署目录：`/opt/projects/nginx-gateway`
- 业务栈上传目录：`/opt/projects/rwat/app/upload`

## GitHub Actions Secrets

- 必填：`SERVER_HOST`
- 必填：`SERVER_PORT`
- 必填：`SERVER_USER`
- 必填：`SERVER_SSH_KEY`
- 可选：`LETSENCRYPT_EMAIL`

## 使用

1. 首次启动（HTTP 或 HTTPS 自动切换）

```bash
./scripts/bootstrap.sh
```

2. 手动申请证书（可选传邮箱）

```bash
LETSENCRYPT_EMAIL=ops@example.com ./scripts/request-cert.sh
```

不传邮箱也可以（脚本会走 `--register-unsafely-without-email`）：

```bash
./scripts/request-cert.sh
```

3. 手动续签证书

```bash
./scripts/renew-cert.sh
```

## 证书目录

- 每个主域名一套证书目录：`certbot/conf/live/<cert_name>/`
- 当前示例：`certbot/conf/live/md-zgxt.com/fullchain.pem`
- 新增示例：`certbot/conf/live/mid-route.site/fullchain.pem`

## 多主域名扩展

- 在 `scripts/common.sh` 的 `CERT_GROUP_NAMES` 追加第二个主域名
- 在 `domains_for_group()` 中补充该主域名对应的子域名列表

## 常见排查

```bash
cd nginx-gateway
docker compose -f docker-compose.yml config
docker compose -f docker-compose.yml logs -f nginx
```
