# nginx-gateway

OpenCoin frontend 的独立 Nginx + Certbot 网关。

当前站点：

- 域名：`uniamm.com`
- 静态文件宿主机根目录：`/var/www/opencoin`
- test 静态文件目录：`/var/www/opencoin/test`
- prod 静态文件目录：`/var/www/opencoin/prod`
- 容器内静态目录：`/var/www/opencoin`
- test Docker network：`gateway_test`
- prod Docker network：`gateway_prod`
- 证书目录：`certbot/conf/live/uniamm.com/`

`opencoin-frontend` 的 workflow 会把 `dist/test/` 或 `dist/prod/` rsync 到对应 GitHub Environment 的 `DEPLOY_PATH`。网关挂载上层目录 `/var/www/opencoin`，Nginx 按 `APP_ENV` 使用 `/var/www/opencoin/test` 或 `/var/www/opencoin/prod` 作为 root。

## 目录结构

- `docker-compose.yml`：只运行 `nginx`，挂载 OpenCoin 静态目录和 Certbot 目录。
- `environments/test/gateway.env`：test 环境配置。
- `environments/prod/gateway.env`：prod 环境配置。
- `environments/<env>/routes/http-only/opencoin.conf`：未签发证书时的 HTTP 配置。
- `environments/<env>/routes/https/opencoin.conf`：证书存在后的 HTTPS 配置。
- `nginx/templates/preamble.conf`：Nginx 基础配置片段。
- `nginx/default.conf`：当前生效配置，由脚本生成。
- `scripts/render-nginx-conf.sh`：按证书状态渲染 HTTP 或 HTTPS。
- `scripts/request-cert.sh`：申请证书。
- `scripts/renew-cert.sh`：续签证书。
- `scripts/compose.sh`：按 `APP_ENV` 执行 Docker Compose。

## GitHub Environment

需要配置 GitHub Environments：`test` 和 `prod`。

`opencoin-frontend` variables：

- `DEPLOY_HOST`
- `DEPLOY_PORT`
- `DEPLOY_USER`
- `DEPLOY_PATH`
  - test：`/var/www/opencoin/test`
  - prod：`/var/www/opencoin/prod`

`opencoin-frontend` secrets：

- `SSH_PRIVATE_KEY`

`nginx-gateway` variables：

- `DEPLOY_HOST`
- `DEPLOY_PORT`
- `DEPLOY_USER`
- `DEPLOY_PATH`：nginx-gateway 部署目录，例如 `/opt/projects/nginx-gateway`

`nginx-gateway` secrets：

- `SSH_PRIVATE_KEY`
- `LETSENCRYPT_EMAIL`

兼容旧 secret 名：`SERVER_HOST`、`SERVER_PORT`、`SERVER_USER`、`SERVER_SSH_KEY`。

## 部署触发

- push `test` 分支：自动使用 GitHub Environment `test`
- 手动触发 prod workflow：仅允许 `main` 分支，使用 GitHub Environment `prod`

`opencoin-frontend`：

- `test` 分支构建 `dist/test/`，部署到 `/var/www/opencoin/test`
- prod 手动触发时构建 `dist/prod/`，部署到 `/var/www/opencoin/prod`

`nginx-gateway`：

- `test` 分支使用 `APP_ENV=test`
- prod 手动触发时使用 `APP_ENV=prod`

## 使用

```bash
APP_ENV=test ./scripts/bootstrap.sh
APP_ENV=prod ./scripts/bootstrap.sh
```

申请证书：

```bash
APP_ENV=test LETSENCRYPT_EMAIL=ops@example.com ./scripts/request-cert.sh
APP_ENV=prod LETSENCRYPT_EMAIL=ops@example.com ./scripts/request-cert.sh
```

## 验证

```bash
sh scripts/tests/source-layout-test.sh
sh scripts/tests/render-environments-test.sh
sh scripts/tests/compose-environments-test.sh
sh -n scripts/*.sh scripts/tests/*.sh
APP_ENV=test ./scripts/compose.sh config
APP_ENV=prod ./scripts/compose.sh config
```
