#!/bin/bash

# ================================================
# 服务器监控系统 v2.0 - 客户端一键安装/升级脚本
# 零依赖，纯Python标准库
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
║   服务器监控系统 v2.0 - 客户端一键安装         ║
║   Server Monitor v2.0 - Client Installer       ║
╚════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

INSTALL_DIR="/opt/server-monitor-client"

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        VERSION=$(sw_vers -productVersion)
    else
        echo -e "${RED}无法检测操作系统类型${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 检测到操作系统: $OS $VERSION${NC}"
}

# 检查是否为升级
check_existing() {
    if [ -f "$INSTALL_DIR/config.env" ]; then
        echo -e "${YELLOW}! 检测到已安装版本${NC}"
        echo -e "${YELLOW}→ 将进行升级安装（保留配置）${NC}"
        IS_UPGRADE=true
        
        # 备份配置
        sudo cp "$INSTALL_DIR/config.env" "/tmp/monitor_config_backup.env"
    else
        echo -e "${GREEN}→ 全新安装${NC}"
        IS_UPGRADE=false
    fi
}

# 检查 Python
check_python() {
    echo -e "\n${YELLOW}→ 检查 Python 环境...${NC}"
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        echo -e "${GREEN}✓ Python 已安装: $PYTHON_VERSION${NC}"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
        PYTHON_VERSION=$(python --version | awk '{print $2}')
        echo -e "${GREEN}✓ Python 已安装: $PYTHON_VERSION${NC}"
    else
        echo -e "${YELLOW}! 未检测到 Python，正在安装...${NC}"
        install_python
    fi
}

# 安装 Python
install_python() {
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y python3
        PYTHON_CMD="python3"
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
        sudo yum install -y python3
        PYTHON_CMD="python3"
    elif [[ "$OS" == "macos" ]]; then
        brew install python3
        PYTHON_CMD="python3"
    fi
    echo -e "${GREEN}✓ Python 安装完成${NC}"
}

# 获取用户配置
get_user_config() {
    if [ "$IS_UPGRADE" = true ]; then
        echo -e "\n${GREEN}→ 使用现有配置（如需修改请编辑 $INSTALL_DIR/config.env）${NC}"
        source "/tmp/monitor_config_backup.env"
        SERVER_URL=$MONITOR_SERVER_URL
        TOKEN=$MONITOR_TOKEN
        SERVER_NAME=$MONITOR_SERVER_NAME
        INTERVAL=$MONITOR_INTERVAL
        return
    fi
    
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}            配置客户端信息              ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
    
    # 服务端地址
    echo -e "${YELLOW}请输入服务端地址 (例: http://192.168.1.100:3000):${NC}"
    read -p "服务端地址: " SERVER_URL
    
    if [ -z "$SERVER_URL" ]; then
        echo -e "${RED}✗ 服务端地址不能为空${NC}"
        exit 1
    fi
    
    # 主密钥
    echo -e "\n${YELLOW}请输入主密钥 (从服务端后台获取):${NC}"
    read -p "主密钥: " MASTER_KEY
    
    if [ -z "$MASTER_KEY" ]; then
        echo -e "${RED}✗ 主密钥不能为空${NC}"
        exit 1
    fi
    
    # 服务器名称
    echo -e "\n${YELLOW}请输入服务器名称 (例: MyServer-01):${NC}"
    read -p "服务器名称: " SERVER_NAME
    
    if [ -z "$SERVER_NAME" ]; then
        SERVER_NAME=$(hostname)
        echo -e "${GREEN}→ 使用主机名: $SERVER_NAME${NC}"
    fi
    
    # 商家名称
    echo -e "\n${YELLOW}请输入商家名称 (可选):${NC}"
    read -p "商家名称: " MERCHANT
    
    # 国家代码
    echo -e "\n${YELLOW}请输入国家代码 (例: US, CN, JP, HK, 默认: US):${NC}"
    read -p "国家代码: " COUNTRY
    COUNTRY=${COUNTRY:-US}
    
    # 操作系统
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]] || [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
        OS_TYPE="linux"
    elif [[ "$OS" == "macos" ]]; then
        OS_TYPE="macos"
    else
        OS_TYPE="linux"
    fi
    echo -e "${GREEN}→ 操作系统: $OS_TYPE${NC}"
    
    # 采集间隔
    echo -e "\n${YELLOW}请输入采集间隔（秒，默认: 60，建议 30-120）:${NC}"
    read -p "采集间隔: " INTERVAL
    INTERVAL=${INTERVAL:-60}
    
    echo -e "\n${GREEN}✓ 配置信息收集完成${NC}"
}

# 注册服务器
register_server() {
    if [ "$IS_UPGRADE" = true ]; then
        echo -e "\n${GREEN}→ 升级模式，跳过注册${NC}"
        return
    fi
    
    echo -e "\n${YELLOW}→ 正在向服务端注册...${NC}"
    
    REGISTER_DATA=$(cat <<REGISTER_EOF
{
  "name": "$SERVER_NAME",
  "merchant": "$MERCHANT",
  "country": "$COUNTRY",
  "os": "$OS_TYPE",
  "masterKey": "$MASTER_KEY"
}
REGISTER_EOF
)
    
    REGISTER_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/register" \
        -H "Content-Type: application/json" \
        -d "$REGISTER_DATA" 2>&1)
    
    TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}✗ 注册失败${NC}"
        echo -e "${RED}错误信息: $REGISTER_RESPONSE${NC}"
        echo -e "${YELLOW}请检查:${NC}"
        echo -e "${YELLOW}1. 服务端地址是否正确${NC}"
        echo -e "${YELLOW}2. 服务端是否正在运行${NC}"
        echo -e "${YELLOW}3. 主密钥是否正确${NC}"
        echo -e "${YELLOW}4. 网络连通性: ping $(echo $SERVER_URL | sed 's|http://||' | sed 's|:.*||')${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ 注册成功${NC}"
    echo -e "${GREEN}✓ Token: ${TOKEN:0:16}...${NC}"
}

# 创建客户端脚本
create_client_script() {
    echo -e "\n${YELLOW}→ 创建客户端脚本...${NC}"
    
    sudo mkdir -p $INSTALL_DIR
    
    # 下载或创建客户端脚本
    # 这里应该下载 "轻量级客户端 v2.0 (TCPing)" 的代码
    echo -e "${YELLOW}! 请将轻量级客户端 v2.0 代码保存为:${NC}"
    echo -e "${YELLOW}  $INSTALL_DIR/monitor_client.py${NC}"
    
    read -p "文件已创建？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}安装已取消${NC}"
        exit 1
    fi
    
    sudo chmod +x $INSTALL_DIR/monitor_client.py
    echo -e "${GREEN}✓ 客户端脚本创建完成${NC}"
}

# 创建配置文件
create_config_file() {
    echo -e "\n${YELLOW}→ 创建配置文件...${NC}"
    
    cat | sudo tee $INSTALL_DIR/config.env > /dev/null << CONFIG_EOF
MONITOR_SERVER_URL=$SERVER_URL
MONITOR_TOKEN=$TOKEN
MONITOR_SERVER_NAME=$SERVER_NAME
MONITOR_INTERVAL=$INTERVAL
CONFIG_EOF

    echo -e "${GREEN}✓ 配置文件创建完成${NC}"
    
    # 清理临时备份
    if [ -f "/tmp/monitor_config_backup.env" ]; then
        rm "/tmp/monitor_config_backup.env"
    fi
}

# 创建 systemd 服务
create_systemd_service() {
    echo -e "\n${YELLOW}→ 创建系统服务...${NC}"
    
    cat | sudo tee /etc/systemd/system/monitor-client.service > /dev/null << SERVICE_EOF
[Unit]
Description=Server Monitor Client v2.0
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/config.env
ExecStart=$PYTHON_CMD $INSTALL_DIR/monitor_client.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    sudo systemctl daemon-reload
    sudo systemctl enable monitor-client
    echo -e "${GREEN}✓ 系统服务创建完成${NC}"
}

# 启动服务
start_service() {
    echo -e "\n${YELLOW}→ 启动监控客户端...${NC}"
    
    if [ "$IS_UPGRADE" = true ]; then
        sudo systemctl restart monitor-client
    else
        sudo systemctl start monitor-client
    fi
    
    sleep 3
    
    if sudo systemctl is-active --quiet monitor-client; then
        echo -e "${GREEN}✓ 客户端启动成功${NC}"
    else
        echo -e "${RED}✗ 客户端启动失败${NC}"
        echo -e "${YELLOW}查看日志: journalctl -u monitor-client -n 50${NC}"
        exit 1
    fi
}

# 显示完成信息
show_completion() {
    echo -e "\n${GREEN}"
    cat << EOF
╔════════════════════════════════════════════════╗
║              🎉 安装完成！                     ║
╠════════════════════════════════════════════════╣
║                                                ║
║  ✅ 客户端已成功安装并启动                     ║
║                                                ║
║  📋 管理命令:                                  ║
║     启动: systemctl start monitor-client      ║
║     停止: systemctl stop monitor-client       ║
║     重启: systemctl restart monitor-client    ║
║     状态: systemctl status monitor-client     ║
║     日志: journalctl -u monitor-client -f     ║
║                                                ║
║  📝 配置信息:                                  ║
║     服务端: $SERVER_URL
║     服务器名: $SERVER_NAME
║     Token: ${TOKEN:0:16}...
║     间隔: ${INTERVAL}秒
║                                                ║
║  📂 文件位置:                                  ║
║     程序: $INSTALL_DIR/monitor_client.py
║     配置: $INSTALL_DIR/config.env
║                                                ║
║  🌐 现在访问 Web 面板查看监控数据！            ║
║                                                ║
╚════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    if [ "$IS_UPGRADE" = true ]; then
        echo -e "${GREEN}✓ 升级完成！配置已保留${NC}"
    else
        echo -e "${GREEN}✓ 全新安装完成！${NC}"
    fi
}

# 主流程
main() {
    echo -e "${BLUE}开始安装...${NC}\n"
    
    detect_os
    check_existing
    check_python
    get_user_config
    register_server
    create_client_script
    create_config_file
    create_systemd_service
    start_service
    show_completion
    
    echo -e "\n${GREEN}全部完成！${NC}"
}

main
