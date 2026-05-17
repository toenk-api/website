#!/bin/bash
# ============================================
# TOENK 一键部署 — 全量升级
# 在任意一台服务器上执行（需 SSH 互通）
# 用法: bash deploy-all.sh
# ============================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

echo "============================================"
echo " TOENK 全量升级部署"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# ============================================
# 1. 创建网站目录结构
# ============================================
log "Step 1: Creating website directory structure..."

mkdir -p /var/www/toenk/{en,zh,models,playground,api,pricing,blog,docs,security,about,contact,changelog,legal}
chown -R www-data:www-data /var/www/toenk 2>/dev/null || true
chmod -R 755 /var/www/toenk

# ============================================
# 2. 部署网站文件（内嵌 Base64 编码的网站文件）
# ============================================
log "Step 2: Deploying website files..."

# --- robots.txt ---
cat > /var/www/toenk/robots.txt << 'ROBOTS'
User-agent: *
Allow: /
Sitemap: https://toenk-api.com/sitemap.xml
ROBOTS

# --- sitemap.xml ---
cat > /var/www/toenk/sitemap.xml << 'SITEMAP'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://toenk-api.com/</loc><priority>1.0</priority></url>
  <url><loc>https://toenk-api.com/zh/</loc><priority>1.0</priority></url>
  <url><loc>https://toenk-api.com/models</loc><priority>0.9</priority></url>
  <url><loc>https://toenk-api.com/pricing</loc><priority>0.9</priority></url>
  <url><loc>https://toenk-api.com/docs</loc><priority>0.8</priority></url>
  <url><loc>https://toenk-api.com/playground</loc><priority>0.8</priority></url>
  <url><loc>https://toenk-api.com/security</loc><priority>0.7</priority></url>
  <url><loc>https://toenk-api.com/blog</loc><priority>0.7</priority></url>
  <url><loc>https://toenk-api.com/about</loc><priority>0.5</priority></url>
</urlset>
SITEMAP

# --- Health endpoint ---
cat > /var/www/toenk/api/public-models.json << 'MODELS'
{
  "object":"list","data":[
    {"id":"deepseek-v4-flash","owned_by":"DeepSeek","pricing":{"prompt":70000,"completion":280000},"context_length":131072},
    {"id":"deepseek-v4-pro","owned_by":"DeepSeek","pricing":{"prompt":280000,"completion":1120000},"context_length":131072},
    {"id":"deepseek-reasoner","owned_by":"DeepSeek","pricing":{"prompt":550000,"completion":2200000},"context_length":65536},
    {"id":"deepseek-chat","owned_by":"DeepSeek","pricing":{"prompt":140000,"completion":280000},"context_length":65536},
    {"id":"gpt-4o","owned_by":"OpenAI","pricing":{"prompt":2500000,"completion":10000000},"context_length":131072},
    {"id":"claude-sonnet-4.6","owned_by":"Anthropic","pricing":{"prompt":3000000,"completion":15000000},"context_length":1048576},
    {"id":"gemini-2.5-flash","owned_by":"Google","pricing":{"prompt":70000,"completion":560000},"context_length":1048576},
    {"id":"qwen3.6-max","owned_by":"Alibaba","pricing":{"prompt":400000,"completion":1600000},"context_length":131072},
    {"id":"glm-5","owned_by":"Zhipu","pricing":{"prompt":700000,"completion":2800000},"context_length":131072},
    {"id":"kimi-k2.6","owned_by":"Moonshot","pricing":{"prompt":500000,"completion":2000000},"context_length":131072},
    {"id":"doubao-1.5-pro-256k","owned_by":"ByteDance","pricing":{"prompt":350000,"completion":1400000},"context_length":262144},
    {"id":"ernie-4.0-turbo","owned_by":"Baidu","pricing":{"prompt":600000,"completion":2400000},"context_length":8192},
    {"id":"text-embedding-v3","owned_by":"—","pricing":{"prompt":10000,"completion":0},"context_length":8192}
  ]
}
MODELS

log "Static files deployed."

# ============================================
# 3. 提示：主 HTML 文件需从开发机 scp 过来
# ============================================
warn "Step 3: Copy HTML files from your dev machine:"
echo ""
echo "  scp website/index.html root@SERVER:/var/www/toenk/en/index.html"
echo "  scp website/zh/index.html root@SERVER:/var/www/toenk/zh/index.html"
echo "  scp website/models/index.html root@SERVER:/var/www/toenk/models/index.html"
echo "  scp website/playground/index.html root@SERVER:/var/www/toenk/playground/index.html"
echo "  scp website/nginx-toenk-api.conf root@SERVER:/etc/nginx/sites-available/toenk-api"
echo ""

# ============================================
# 4. Nginx 配置
# ============================================
log "Step 4: Applying nginx configuration..."

if [ -f /etc/nginx/sites-available/toenk-api ]; then
    # Backup
    cp /etc/nginx/sites-available/toenk-api /etc/nginx/sites-available/toenk-api.bak.$(date +%Y%m%d%H%M%S)
    log "Nginx config backed up"
    
    # Enable site
    ln -sf /etc/nginx/sites-available/toenk-api /etc/nginx/sites-enabled/toenk-api
    rm -f /etc/nginx/sites-enabled/default
    
    # Test
    nginx -t && systemctl reload nginx && log "Nginx reloaded" || err "Nginx config error — check syntax"
else
    err "nginx config file not found at /etc/nginx/sites-available/toenk-api"
    err "Please scp the config file first (see Step 3)"
fi

# ============================================
# 5. SSL 证书（如果没有）
# ============================================
log "Step 5: Checking SSL certificates..."

if [ -f /etc/letsencrypt/live/toenk-api.com/fullchain.pem ]; then
    log "SSL certificate found"
    CERT_DAYS=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/toenk-api.com/fullchain.pem | cut -d= -f2)
    log "Certificate expires: $CERT_DAYS"
else
    warn "No SSL certificate found. Install certbot and run:"
    echo "  apt install -y certbot python3-certbot-nginx"
    echo "  certbot --nginx -d toenk-api.com -d www.toenk-api.com"
fi

# ============================================
# 6. 验证
# ============================================
log "Step 6: Verifying deployment..."

sleep 2

echo ""
echo "--- Health Check ---"
curl -s https://localhost/health -k 2>/dev/null && log "Health: OK" || warn "Health check failed (expected if no local HTTPS)"

echo ""
echo "--- Security Headers ---"
curl -sI https://localhost -k 2>/dev/null | grep -iE '(server:|strict|frame|content-type-options|xss|referrer|permissions|cross-origin|permitted|csp)' || warn "Could not verify headers locally"

echo ""
echo "============================================"
log "Deployment complete!"
echo ""
echo "Verify externally:"
echo "  curl -sI https://toenk-api.com/ -k | grep -i server"
echo "  curl -sI https://43.164.128.112 -k | grep -i server"
echo "  curl -sI https://43.160.200.196 -k | grep -i server"
echo "============================================"
