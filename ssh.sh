#!/bin/bash
# 一键配置 SSH 保持长连接脚本

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
   echo "此脚本需要 root 权限运行，请使用 sudo 或切换到 root 用户"
   exit 1
fi

# 备份 SSH 配置文件
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    echo "已备份 SSH 配置文件到 ${SSHD_CONFIG}.bak"
else
    echo "未找到 SSH 配置文件 $SSHD_CONFIG"
    exit 1
fi

# 配置 ClientAliveInterval 和 ClientAliveCountMax
if grep -q "ClientAliveInterval" "$SSHD_CONFIG"; then
    sed -i 's/^.*ClientAliveInterval.*/ClientAliveInterval 60/' "$SSHD_CONFIG"
else
    echo "ClientAliveInterval 60" >> "$SSHD_CONFIG"
fi

if grep -q "ClientAliveCountMax" "$SSHD_CONFIG"; then
    sed -i 's/^.*ClientAliveCountMax.*/ClientAliveCountMax 3/' "$SSHD_CONFIG"
else
    echo "ClientAliveCountMax 3" >> "$SSHD_CONFIG"
fi

echo "已配置 SSH 心跳：ClientAliveInterval 60, ClientAliveCountMax 3"

# 重启 SSH 服务
systemctl restart sshd
if [ $? -eq 0 ]; then
    echo "SSH 服务重启成功"
else
    echo "SSH 服务重启失败，请检查配置"
    exit 1
fi

# 可选：安装 tmux
read -p "是否安装 tmux 以支持断线重连？(y/n): " install_tmux
if [ "$install_tmux" = "y" ] || [ "$install_tmux" = "Y" ]; then
    apt update && apt install -y tmux
    if [ $? -eq 0 ]; then
        echo "tmux 安装成功，使用 'tmux' 启动会话，断开后用 'tmux attach' 恢复"
    else
        echo "tmux 安装失败，请检查网络或包管理器"
    fi
fi

# 可选：安装 mosh
read -p "是否安装 mosh 以支持更稳定的连接？(y/n): " install_mosh
if [ "$install_mosh" = "y" ] || [ "$install_mosh" = "Y" ]; then
    apt update && apt install -y mosh
    if [ $? -eq 0 ]; then
        echo "mosh 安装成功，使用 'mosh user@hostname' 连接"
        echo "注意：请确保服务器防火墙开放 UDP 60000-61000 端口"
    else
        echo "mosh 安装失败，请检查网络或包管理器"
    fi
fi

echo "SSH 保持长连接配置完成！"
echo "客户端可配置 ~/.ssh/config 添加："
echo "Host *"
echo "    ServerAliveInterval 60"
echo "    ServerAliveCountMax 3"
