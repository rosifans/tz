#!/bin/bash

# ================================================
# 服务器监控系统 v2.0 - 服务端一键安装/升级脚本
# 支持全新安装和在线升级
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════╗
║   服务器监控系统 v2.0 - 服务端一键安装         ║
║   Server Monitor v2.0 - Auto Installer         ║
╚════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

INSTALL_DIR="/opt/server-monitor"
BACKUP_DIR="/opt/server-monitor-backup-$(date +%Y%m%d_%H%M%S)"

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}无法检测操作系统类型${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 检测到操作系统: $OS $VERSION${NC}"
}

# 检查是否为升级
check_existing() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}! 检测到已安装版本${NC}"
        echo -e "${YELLOW}→ 将进行升级安装${NC}"
        IS_UPGRADE=true
        
        # 备份
        echo -e "${YELLOW}→ 正在备份现有数据...${NC}"
        sudo mkdir -p "$BACKUP_DIR"
        if [ -f "$INSTALL_DIR/monitor.db" ]; then
            sudo cp "$INSTALL_DIR/monitor.db" "$BACKUP_DIR/"
            echo -e "${GREEN}✓ 数据库已备份到: $BACKUP_DIR${NC}"
        fi
        if [ -f "$INSTALL_DIR/package.json" ]; then
            sudo cp "$INSTALL_DIR/package.json" "$BACKUP_DIR/"
        fi
    else
        echo -e "${GREEN}→ 全新安装${NC}"
        IS_UPGRADE=false
    fi
}

# 安装 Node.js
install_nodejs() {
    echo -e "\n${YELLOW}→ 检查 Node.js...${NC}"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 14 ]; then
            echo -e "${GREEN}✓ Node.js 已安装 ($(node -v))${NC}"
            return
        fi
    fi

    echo -e "${YELLOW}→ 正在安装 Node.js...${NC}"
    
    if [[ "$OS" == "ubuntu" ]] && [[ "$VERSION" == "18.04" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - 2>&1 | grep -v "^$" || true
        sudo apt-get install -y nodejs || install_nodejs_via_nvm
    elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - 2>&1 | grep -v "^$" || true
        sudo apt-get install -y nodejs || install_nodejs_via_nvm
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash - 2>&1 | grep -v "^$" || true
        sudo yum install -y nodejs || install_nodejs_via_nvm
    fi

    if ! command -v node &> /dev/null; then
        install_nodejs_via_nvm
    else
        echo -e "${GREEN}✓ Node.js 安装完成 ($(node -v))${NC}"
    fi
}

# NVM 备用安装
install_nodejs_via_nvm() {
    echo -e "${YELLOW}→ 使用 NVM 安装 Node.js...${NC}"
    export HOME=/root
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>&1 | grep -v "^$" || true
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install 16 2>&1 | grep -v "^$" || true
    nvm use 16
    nvm alias default 16
    
    NODE_PATH=$(nvm which 16)
    NPM_PATH=$(dirname $NODE_PATH)/npm
    
    sudo ln -sf "$NODE_PATH" /usr/local/bin/node
    sudo ln -sf "$NPM_PATH" /usr/local/bin/npm
    
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
    export PATH="/usr/local/bin:$PATH"
    
    echo -e "${GREEN}✓ Node.js 通过 NVM 安装完成${NC}"
}

# 创建项目目录
create_project() {
    echo -e "\n${YELLOW}→ 准备项目目录...${NC}"
    
    sudo mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    # 恢复数据库
    if [ "$IS_UPGRADE" = true ] && [ -f "$BACKUP_DIR/monitor.db" ]; then
        sudo cp "$BACKUP_DIR/monitor.db" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ 数据库已恢复${NC}"
    fi
    
    echo -e "${GREEN}✓ 项目目录: $INSTALL_DIR${NC}"
}

# 创建 package.json
create_package_json() {
    echo -e "\n${YELLOW}→ 创建 package.json...${NC}"
    
    cat > package.json << 'PACKAGE_EOF'
{
  "name": "server-monitor",
  "version": "2.0.0",
  "description": "Server monitoring system v2.0 with admin panel",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "sqlite3": "^5.1.6",
    "ws": "^8.14.2",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2"
  }
}
PACKAGE_EOF

    echo -e "${GREEN}✓ package.json 创建完成${NC}"
}

# 下载代码文件
download_code() {
    echo -e "\n${YELLOW}→ 正在下载代码文件...${NC}"
    
    # 这里应该从GitHub或其他地方下载
    # 暂时使用占位符，实际部署时替换为真实下载链接
    echo -e "${YELLOW}! 请手动复制以下文件到 $INSTALL_DIR:${NC}"
    echo -e "${YELLOW}  1. server.js (完整服务端代码 v2.0)${NC}"
    echo -e "${YELLOW}  2. public/index.html (前端首页 v2.0)${NC}"
    echo -e "${YELLOW}  3. public/admin.html (管理后台)${NC}"
    
    read -p "文件已复制完成？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}安装已取消${NC}"
        exit 1
    fi
}

# 创建前端目录
create_frontend() {
    echo -e "\n${YELLOW}→ 创建前端目录...${NC}"
    sudo mkdir -p public
    echo -e "${GREEN}✓ 前端目录创建完成${NC}"
    echo -e "${YELLOW}! 请将 index.html 和 admin.html 放入 public 目录${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "\n${YELLOW}→ 安装项目依赖...${NC}"
    echo -e "${YELLOW}(这可能需要几分钟，请耐心等待)${NC}"
    
    npm install --production 2>&1 | grep -E "added|removed|updated|^npm" || true
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
}

# 创建启动脚本
create_start_script() {
    echo -e "\n${YELLOW}→ 创建启动脚本...${NC}"
    
    cat > start.sh << 'START_EOF'
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /opt/server-monitor
node server.js
START_EOF

    chmod +x start.sh
    echo -e "${GREEN}✓ 启动脚本创建完成${NC}"
}

# 创建 systemd 服务
create_systemd_service() {
    echo -e "\n${YELLOW}→ 创建系统服务...${NC}"
    
    cat | sudo tee /etc/systemd/system/server-monitor.service > /dev/null << SERVICE_EOF
[Unit]
Description=Server Monitor System v2.0
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash $INSTALL_DIR/start.sh
Restart=always
RestartSec=10
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    sudo systemctl daemon-reload
    sudo systemctl enable server-monitor
    echo -e "${GREEN}✓ 系统服务创建完成${NC}"
}

# 配置防火墙
configure_firewall() {
    echo -e "\n${YELLOW}→ 配置防火墙...${NC}"
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 3000/tcp 2>/dev/null || true
        echo -e "${GREEN}✓ UFW 防火墙规则已添加${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=3000/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        echo -e "${GREEN}✓ Firewalld 规则已添加${NC}"
    else
        echo -e "${YELLOW}! 未检测到防火墙，请手动开放 3000 端口${NC}"
    fi
}

# 启动服务
start_service() {
    echo -e "\n${YELLOW}→ 启动服务...${NC}"
    
    if [ "$IS_UPGRADE" = true ]; then
        sudo systemctl restart server-monitor
    else
        sudo systemctl start server-monitor
    fi
    
    sleep 3
    
    if sudo systemctl is-active --quiet server-monitor; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
        echo -e "${YELLOW}查看日志: journalctl -u server-monitor -n 50${NC}"
        exit 1
    fi
}

# 显示完成信息
show_completion() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}"
    cat << EOF
╔════════════════════════════════════════════════╗
║              🎉 安装完成！                     ║
╠════════════════════════════════════════════════╣
║                                                ║
║  📱 访问地址:                                  ║
║     前端: http://$SERVER_IP:3000          ║
║     后台: http://$SERVER_IP:3000/admin    ║
║                                                ║
║  🔐 首次访问:                                  ║
║     访问后台设置管理员账号密码                 ║
║                                                ║
║  📋 管理命令:                                  ║
║     启动: systemctl start server-monitor      ║
║     停止: systemctl stop server-monitor       ║
║     重启: systemctl restart server-monitor    ║
║     状态: systemctl status server-monitor     ║
║     日志: journalctl -u server-monitor -f     ║
║                                                ║
║  📂 文件位置:                                  ║
║     程序: $INSTALL_DIR
║     数据库: $INSTALL_DIR/monitor.db
EOF

    if [ "$IS_UPGRADE" = true ]; then
        echo "║     备份: $BACKUP_DIR"
    fi
    
    cat << EOF
║                                                ║
╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    if [ "$IS_UPGRADE" = true ]; then
        echo -e "${GREEN}✓ 升级完成！原有数据已保留${NC}"
    else
        echo -e "${GREEN}✓ 全新安装完成！${NC}"
    fi
}

# 主流程
main() {
    echo -e "${BLUE}开始安装...${NC}\n"
    
    detect_os
    check_existing
    install_nodejs
    create_project
    create_package_json
    create_frontend
    download_code
    install_dependencies
    create_start_script
    create_systemd_service
    configure_firewall
    start_service
    show_completion
    
    echo -e "\n${GREEN}全部完成！${NC}"
}

main
