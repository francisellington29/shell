#!/bin/bash

# Linux Mirror Switch Script - 单文件版本
# 自动生成，请勿手动编辑
# 构建时间: Mon Jun 30 06:11:31 PM CST 2025

set -e

# ===== 配置模块 =====
# Mirror Switch Script - 全局配置
# 版本: 1.0.0
# 脚本信息
SCRIPT_NAME="Linux Mirror Switch"
SCRIPT_VERSION="1.0.0"
SCRIPT_AUTHOR="Mirror Proxy Team"
# 默认Worker域名 (用户需要修改)
DEFAULT_WORKER_DOMAIN="your-worker.workers.dev"
# 备份配置
BACKUP_DIR="/etc/apt/sources.list.backup"
BACKUP_KEEP_COUNT=3
# 颜色定义 - 更丰富的颜色方案
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
NC='\033[0m'
# 亮色版本
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_MAGENTA='\033[1;35m'
BRIGHT_CYAN='\033[1;36m'
BRIGHT_WHITE='\033[1;37m'
BRIGHT_PURPLE='\033[1;35m'
# 背景色
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_PURPLE='\033[45m'
# 文字颜色
BLACK='\033[0;30m'
WHITE='\033[0;37m'
# 文字样式
BOLD='\033[1m'
# 状态图标 - 更美观的图标
ICON_SUCCESS="${BRIGHT_GREEN}✅${NC}"
ICON_WARNING="${BRIGHT_YELLOW}⚠️${NC}"
ICON_INFO="${BRIGHT_BLUE}ℹ️${NC}"
ICON_ERROR="${BRIGHT_RED}❌${NC}"
ICON_QUESTION="${BRIGHT_CYAN}❓${NC}"
ICON_ROCKET="${BRIGHT_MAGENTA}🚀${NC}"
ICON_GEAR="${BRIGHT_YELLOW}⚙️${NC}"
ICON_SHIELD="${BRIGHT_GREEN}🛡️${NC}"
ICON_NETWORK="${BRIGHT_BLUE}🌐${NC}"
ICON_BACKUP="${BRIGHT_CYAN}💾${NC}"
# 支持的发行版
SUPPORTED_DISTROS=("debian" "ubuntu" "alpine")
# 配置文件路径
declare -A CONFIG_PATHS=(
    ["debian"]="/etc/apt/sources.list"
    ["ubuntu"]="/etc/apt/sources.list"
    ["alpine"]="/etc/apk/repositories"
)
# 包管理器命令
declare -A PKG_MANAGERS=(
    ["debian"]="apt"
    ["ubuntu"]="apt"
    ["alpine"]="apk"
)
# 更新命令
declare -A UPDATE_COMMANDS=(
    ["debian"]="apt update"
    ["ubuntu"]="apt update"
    ["alpine"]="apk update"
)
# ===== 工具函数模块 =====
# 工具函数模块
# 打印成功消息
echo_success() {
    echo -e "${ICON_SUCCESS} ${BRIGHT_GREEN}$1${NC}"
}
# 打印警告消息
echo_warning() {
    echo -e "${ICON_WARNING} ${BRIGHT_YELLOW}$1${NC}"
}
# 打印错误消息
echo_error() {
    echo -e "${ICON_ERROR} ${BRIGHT_RED}$1${NC}"
}
# 打印信息消息
echo_info() {
    echo -e "${ICON_INFO} ${BRIGHT_BLUE}$1${NC}"
}
# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
# 安全地创建目录
safe_mkdir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo_error "无法创建目录: $dir"
            return 1
        }
    fi
}
# 测试网络连接
test_connection() {
    local host="$1"
    local port="${2:-443}"
    local timeout="${3:-5}"
    
    if command_exists nc; then
        nc -z -w"$timeout" "$host" "$port" >/dev/null 2>&1
    elif command_exists telnet; then
        timeout "$timeout" telnet "$host" "$port" >/dev/null 2>&1
    else
        # 使用ping作为备选
        ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1
    fi
}
# 测试自定义源连接
test_worker_connection() {
    local worker_domain="$1"
    
    echo -e "${BRIGHT_BLUE}ℹ️${NC} ${BRIGHT_BLUE}测试自定义源:${NC} ${BRIGHT_YELLOW}$worker_domain${NC}"
    
    # 测试HTTPS连接
    if ! test_connection "$worker_domain" 443 10; then
        return 1
    fi
    
    # 测试状态接口
    local status_url="https://$worker_domain/status"
    if command_exists curl; then
        if curl -s --connect-timeout 10 --max-time 30 "$status_url" >/dev/null; then
            echo_success "自定义源状态正常"
        else
            echo_warning "自定义源状态测试失败，但域名可达"
        fi
    elif command_exists wget; then
        if wget -q --timeout=10 --tries=1 -O /dev/null "$status_url"; then
            echo_success "自定义源状态正常"
        else
            echo_warning "自定义源状态测试失败，但域名可达"
        fi
    else
        echo_warning "缺少curl或wget，跳过状态接口测试"
    fi
    
    return 0
}
# 验证域名格式
validate_domain() {
    local domain="$1"
    
    # 基本域名格式检查
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo_error "无效的域名格式: $domain"
        return 1
    fi
    
    # 检查是否为默认域名
    if [ "$domain" = "$DEFAULT_WORKER_DOMAIN" ]; then
        echo_warning "您正在使用默认域名，请确保已部署Worker"
    fi
    
    return 0
}
# 获取当前时间戳
get_timestamp() {
    date +%Y%m%d_%H%M%S
}
# 格式化时间戳显示
format_timestamp() {
    local timestamp="$1"
    local date_part=${timestamp%_*}
    local time_part=${timestamp#*_}
    local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
    local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
    echo "$formatted_date $formatted_time"
}
# ===== 系统检测模块 =====
# 系统检测模块
# 启动时更新软件包列表
update_package_list_on_startup() {
    echo_info "🔄 正在更新软件包列表..."
    local os=$(detect_os)
    case "$os" in
        debian|ubuntu)
            if command -v apt-get >/dev/null 2>&1; then
                echo "正在执行: apt-get update"
                if apt-get update; then
                    echo_success "软件包列表更新完成"
                else
                    echo_warning "软件包列表更新失败，但不影响继续运行"
                fi
            fi
            ;;
        alpine)
            if command -v apk >/dev/null 2>&1; then
                echo "正在执行: apk update"
                if apk update; then
                    echo_success "软件包索引更新完成"
                else
                    echo_warning "软件包索引更新失败，但不影响继续运行"
                fi
            fi
            ;;
        *)
            echo_info "跳过软件包列表更新（不支持的系统）"
            ;;
    esac
}
# 检测和安装依赖
check_and_install_dependencies() {
    echo_info "🔍 正在检测系统依赖..."
    # 定义必需的依赖
    local required_deps=("curl" "wget" "grep" "awk" "sed")
    local missing_deps=()
    local optional_deps=("free" "df" "ip")
    local missing_optional=()
    # 检测必需依赖
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    # 检测可选依赖
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        fi
    done
    # 如果有缺失的必需依赖
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo_warning "依赖缺失: ${missing_deps[*]}"
        # 根据系统类型安装依赖
        local os=$(detect_os)
        case "$os" in
            debian|ubuntu)
                if command -v apt-get >/dev/null 2>&1; then
                    echo "正在执行: apt-get update"
                    apt-get update
                    for dep in "${missing_deps[@]}"; do
                        echo_info "正在安装依赖 $dep"
                        echo "正在执行: apt-get install -y $dep"
                        if apt-get install -y "$dep"; then
                            echo_success "$dep 安装成功"
                        else
                            echo_error "$dep 安装失败"
                        fi
                    done
                fi
                ;;
            alpine)
                if command -v apk >/dev/null 2>&1; then
                    echo "正在执行: apk update"
                    apk update
                    for dep in "${missing_deps[@]}"; do
                        echo_info "正在安装依赖 $dep"
                        echo "正在执行: apk add $dep"
                        if apk add "$dep"; then
                            echo_success "$dep 安装成功"
                        else
                            echo_error "$dep 安装失败"
                        fi
                    done
                fi
                ;;
            *)
                echo_warning "无法自动安装依赖，请手动安装: ${missing_deps[*]}"
                ;;
        esac
        # 重新检测
        local still_missing=()
        for dep in "${missing_deps[@]}"; do
            if ! command -v "$dep" >/dev/null 2>&1; then
                still_missing+=("$dep")
            fi
        done
        if [ ${#still_missing[@]} -gt 0 ]; then
            echo_error "仍然缺少必需依赖: ${still_missing[*]}"
            echo_error "请手动安装这些依赖后重新运行脚本"
            exit 1
        fi
        # 安装完成后清屏
        clear
        # 重新检测并显示结果
        echo_info "🔍 正在检测系统依赖..."
        echo_success "系统所需依赖已安装"
    else
        echo_success "系统所需依赖已安装"
    fi
    # 提示可选依赖
    if [ ${#missing_optional[@]} -gt 0 ]; then
        echo_warning "缺少可选依赖: ${missing_optional[*]} (不影响核心功能)"
    fi
}
# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        local os_id=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        if [ -n "$os_id" ]; then
            echo "$os_id"
        else
            # 备选方案：使用source方式
            echo "${ID:-unknown}"
        fi
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}
# 检测系统版本
detect_version() {
    if [ -f /etc/os-release ]; then
        local version_id=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        if [ -n "$version_id" ]; then
            echo "$version_id"
        else
            # 备选方案：使用source方式
            echo "${VERSION_ID:-unknown}"
        fi
    elif [ -f /etc/debian_version ]; then
        cat /etc/debian_version
    elif [ -f /etc/alpine-release ]; then
        cat /etc/alpine-release
    else
        echo "unknown"
    fi
}
# 检测版本代号
detect_codename() {
    if [ -f /etc/os-release ]; then
        local codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        if [ -n "$codename" ]; then
            echo "$codename"
        else
            # 备选方案：使用source方式
            echo "${VERSION_CODENAME:-unknown}"
        fi
    else
        echo "unknown"
    fi
}
# 检测系统架构
detect_arch() {
    uname -m
}
# 检测是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_error "需要root权限运行此脚本"
        echo_info "请使用: sudo $0"
        exit 1
    fi
}
# 检测网络连接
check_network() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "114.114.114.114")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}
# 验证系统支持
validate_system_support() {
    local os=$(detect_os)
    
    for supported in "${SUPPORTED_DISTROS[@]}"; do
        if [ "$os" = "$supported" ]; then
            return 0
        fi
    done
    
    echo_error "不支持的操作系统: $os"
    echo_info "支持的系统: ${SUPPORTED_DISTROS[*]}"
    return 1
}
# 检测内核信息
detect_kernel() {
    uname -r 2>/dev/null || echo "unknown"
}
# 检测CPU信息
detect_cpu_info() {
    if command -v lscpu >/dev/null 2>&1; then
        local cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^[[:space:]]*//')
        local cpu_cores=$(lscpu | grep "^CPU(s):" | cut -d':' -f2 | sed 's/^[[:space:]]*//')
        echo "${cpu_model:-Unknown} (${cpu_cores:-?} cores)"
    else
        grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | sed 's/^[[:space:]]*//' || echo "unknown"
    fi
}
# 检测内存信息
detect_memory() {
    if command -v free >/dev/null 2>&1; then
        # 使用free命令获取内存信息并计算使用百分比
        local mem_info=$(free -h | grep "Mem:")
        local total=$(echo "$mem_info" | awk '{print $2}')
        local available=$(echo "$mem_info" | awk '{print $7}')
        local used_percent=$(free | grep "Mem:" | awk '{printf "%.0f", ($3/$2)*100}')
        echo "$total total, $available available (${used_percent}% used)"
    else
        awk '/MemTotal/ {total=$2/1024/1024; printf "%.1fGB total", total} /MemAvailable/ {avail=$2/1024/1024; printf ", %.1fGB available", avail}' /proc/meminfo 2>/dev/null || echo "unknown"
    fi
}
# 检测硬盘信息
detect_disk() {
    if command -v df >/dev/null 2>&1; then
        df -h / 2>/dev/null | tail -1 | awk '{print $2 " total, " $4 " free (" $5 " used)"}'
    else
        echo "unknown"
    fi
}
# 检测网络信息
detect_network() {
    local local_ipv4=""
    local local_ipv6=""
    local public_ipv4=""
    local public_ipv6=""
    # 获取本地IPv4地址（排除回环和Docker）
    if command -v ip >/dev/null 2>&1; then
        local_ipv4=$(ip route get 8.8.8.8 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p' | head -1)
        local_ipv6=$(ip -6 route get 2001:4860:4860::8888 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p' | head -1)
    fi
    # 备选方案获取本地IP
    if [ -z "$local_ipv4" ]; then
        local_ipv4=$(hostname -I 2>/dev/null | awk '{print $1}' | grep -v "^127\." | grep -v "^172\.17\." | head -1)
    fi
    # 使用缓存的公网IP（如果有的话）
    if [ -n "$PUBLIC_IP_CACHE" ]; then
        public_ipv4="$PUBLIC_IP_CACHE"
    fi
    # 显示格式：本地IP (公网IP)
    local ipv4_display="${local_ipv4:-none}"
    local ipv6_display="${local_ipv6:-none}"
    if [ -n "$public_ipv4" ] && [ "$public_ipv4" != "$local_ipv4" ]; then
        ipv4_display="$ipv4_display ($public_ipv4)"
    fi
    if [ -n "$public_ipv6" ] && [ "$public_ipv6" != "$local_ipv6" ]; then
        ipv6_display="$ipv6_display ($public_ipv6)"
    fi
    echo "$ipv4_display / $ipv6_display"
}
# 检测虚拟化类型
detect_virtualization() {
    # 检查systemd-detect-virt
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt=$(systemd-detect-virt 2>/dev/null)
        [ "$virt" != "none" ] && echo "$virt" && return
    fi
    # 检查DMI信息
    if [ -r /sys/class/dmi/id/product_name ]; then
        local product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        case "$product" in
            *VMware*) echo "vmware" ;;
            *VirtualBox*) echo "virtualbox" ;;
            *KVM*|*QEMU*) echo "kvm" ;;
            *Xen*) echo "xen" ;;
            *) echo "physical" ;;
        esac
    else
        echo "unknown"
    fi
}
# 获取系统信息摘要
get_system_info() {
    local os=$(detect_os)
    local version=$(detect_version)
    local codename=$(detect_codename)
    local arch=$(detect_arch)
    local kernel=$(detect_kernel)
    local cpu=$(detect_cpu_info)
    local memory=$(detect_memory)
    local disk=$(detect_disk)
    local network=$(detect_network)
    local virt=$(detect_virtualization)
    echo -e "${BRIGHT_BLUE}┌─ ${ICON_GEAR} 系统信息 ─────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}🖥️  操作系统:${NC} ${BRIGHT_WHITE}$os${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}📦  版本:${NC}     ${BRIGHT_WHITE}$version${NC}"
    [ "$codename" != "unknown" ] && echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}🏷️  代号:${NC}     ${BRIGHT_WHITE}$codename${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}⚙️  内核:${NC}     ${BRIGHT_WHITE}$kernel${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}🏗️  架构:${NC}     ${BRIGHT_WHITE}$arch${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}🔧  CPU:${NC}      ${BRIGHT_WHITE}$cpu${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}💾  内存:${NC}     ${BRIGHT_WHITE}$memory${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}💿  硬盘:${NC}     ${BRIGHT_WHITE}$disk${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}🌐  网络:${NC}     ${BRIGHT_WHITE}$network${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_GREEN}☁️  虚拟化:${NC}   ${BRIGHT_WHITE}$virt${NC}"
    echo -e "${BRIGHT_BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}
# 检测包管理器
detect_package_manager() {
    local os=$(detect_os)
    echo "${PKG_MANAGERS[$os]:-unknown}"
}
# 检测配置文件路径
get_config_path() {
    local os=$(detect_os)
    echo "${CONFIG_PATHS[$os]:-unknown}"
}
# ===== 用户界面模块 =====
# 用户界面模块
# 显示标题
show_title() {
    echo
    echo -e "${BRIGHT_CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_CYAN}║${NC}  ${ICON_ROCKET} ${BRIGHT_WHITE}${BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${NC}                           ${BRIGHT_CYAN}║${NC}"
    echo -e "${BRIGHT_CYAN}║${NC}  ${BRIGHT_BLUE}🔧 智能Linux镜像源切换工具${NC}                              ${BRIGHT_CYAN}║${NC}"
    echo -e "${BRIGHT_CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}
# 显示帮助信息
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION
用法: $0 [选项] [自定义源域名]
选项:
  -h, --help              显示此帮助信息
  -v, --version           显示版本信息
  -d, --domain DOMAIN     指定自定义源域名
  -y, --yes               非交互模式，自动确认
  -n, --dry-run           预览模式，不实际修改文件
  -r, --restore [时间戳]   恢复备份
  -b, --backup            仅创建备份
  -t, --test              测试自定义源连接
  -l, --list              列出备份
示例:
  $0                                          # 交互式模式
  $0 -d mirror.yourdomain.com                # 指定自定义源域名
  $0 -y -d mirror.yourdomain.com             # 非交互模式
  $0 --test -d mirror.yourdomain.com         # 测试连接
  $0 --restore                                # 恢复最新备份
环境变量:
  WORKER_DOMAIN                               # 设置默认自定义源域名
功能特性:
  🚀 支持多种Linux发行版 (Debian, Ubuntu, Alpine等)
  ⚡ 智能速度测试，自动推荐最快镜像源
  🔄 一键切换国内外镜像源
  💾 自动备份，支持一键恢复
  🌐 支持自定义镜像源域名
  🎨 美观的交互式界面
EOF
}
# 显示版本信息
show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "作者: $SCRIPT_AUTHOR"
}
# 询问用户确认
ask_confirmation() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$FORCE_YES" = true ]; then
        echo_info "$message [自动确认]"
        return 0
    fi
    
    if [ "$default" = "y" ]; then
        read -p "$(echo -e "${ICON_QUESTION} $message [Y/n]: ")" response
        response=${response:-y}
    else
        read -p "$(echo -e "${ICON_QUESTION} $message [y/N]: ")" response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
# 输入Worker域名
input_worker_domain() {
    local current_domain="$1"
    if [ "$FORCE_YES" = true ] && [ -n "$current_domain" ]; then
        echo "$current_domain"
        return 0
    fi
    # 输出提示信息到stderr，避免污染函数返回值
    echo_info "请输入您的Cloudflare Worker域名" >&2
    echo_info "例如: mirror.yourdomain.com 或 your-worker.workers.dev" >&2
    if [ -n "$current_domain" ]; then
        read -p "$(echo -e "${ICON_QUESTION} Worker域名 [$current_domain]: ")" domain
        domain=${domain:-$current_domain}
    else
        read -p "$(echo -e "${ICON_QUESTION} Worker域名: ")" domain
    fi
    # 清理输入：去除前后空格和换行符
    domain=$(echo "$domain" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$domain"
}
# 显示进度
show_progress() {
    local message="$1"
    local step="$2"
    local total="$3"
    if [ -n "$step" ] && [ -n "$total" ]; then
        # 计算进度百分比
        local percent=$((step * 100 / total))
        local filled=$((percent / 5))  # 每5%一个方块
        local empty=$((20 - filled))
        # 构建进度条
        local progress_bar=""
        for ((i=0; i<filled; i++)); do
            progress_bar+="█"
        done
        for ((i=0; i<empty; i++)); do
            progress_bar+="░"
        done
        echo -e "${BRIGHT_BLUE}┌─ 进度 ───────────────────────────────────────────────────────┐${NC}"
        echo -e "${BRIGHT_BLUE}│${NC} ${ICON_GEAR} ${BRIGHT_WHITE}$message${NC}"
        echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_CYAN}[$step/$total]${NC} ${BRIGHT_GREEN}$progress_bar${NC} ${BRIGHT_WHITE}$percent%${NC}"
        echo -e "${BRIGHT_BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    else
        echo_info "$message"
    fi
}
# 显示当前源状态
show_current_status() {
    local config_path=$(get_config_path)
    local current_source="未知"
    local source_type="unknown"
    local worker_domain=""
    if [ -f "$config_path" ]; then
        # 检查是否是由本工具生成的配置
        if grep -q "Generated by Linux Mirror Switch" "$config_path" 2>/dev/null; then
            # 检查具体的镜像源类型
            if grep -q "Worker Domain:" "$config_path" 2>/dev/null; then
                worker_domain=$(grep "Worker Domain:" "$config_path" 2>/dev/null | cut -d':' -f2 | sed 's/^[[:space:]]*//')
                current_source="自定义源 ($worker_domain)"
                source_type="custom"
            elif grep -q "Aliyun mirror sources" "$config_path" 2>/dev/null; then
                current_source="阿里云 (mirrors.aliyun.com)"
                source_type="aliyun"
            elif grep -q "Tencent mirror sources" "$config_path" 2>/dev/null; then
                current_source="腾讯云 (mirrors.cloud.tencent.com)"
                source_type="tencent"
            elif grep -q "Huawei mirror sources" "$config_path" 2>/dev/null; then
                current_source="华为云 (mirrors.huaweicloud.com)"
                source_type="huawei"
            elif grep -q "Tsinghua University mirror sources" "$config_path" 2>/dev/null; then
                current_source="清华大学 (mirrors.tuna.tsinghua.edu.cn)"
                source_type="tsinghua"
            elif grep -q "USTC mirror sources" "$config_path" 2>/dev/null; then
                current_source="中科大 (mirrors.ustc.edu.cn)"
                source_type="ustc"
            elif grep -q "NetEase mirror sources" "$config_path" 2>/dev/null; then
                current_source="网易 (mirrors.163.com)"
                source_type="netease"
            elif grep -q "Official sources" "$config_path" 2>/dev/null; then
                local official_host=$(grep -o "deb\.debian\.org\|archive\.ubuntu\.com\|dl-cdn\.alpinelinux\.org" "$config_path" 2>/dev/null | head -1)
                if [ -n "$official_host" ]; then
                    current_source="官方源 ($official_host)"
                else
                    current_source="官方源"
                fi
                source_type="official"
            else
                current_source="本工具生成的配置"
                source_type="generated"
            fi
        else
            # 检查是否是官方源
            if grep -q "deb.debian.org\|archive.ubuntu.com\|dl-cdn.alpinelinux.org" "$config_path" 2>/dev/null; then
                local official_host=$(grep -o "deb\.debian\.org\|archive\.ubuntu\.com\|dl-cdn\.alpinelinux\.org" "$config_path" 2>/dev/null | head -1)
                current_source="官方源 ($official_host)"
                source_type="official"
            else
                # 检查其他镜像源
                local mirror_host=$(sed -n 's|.*https\{0,1\}://\([^/]*\).*|\1|p' "$config_path" 2>/dev/null | head -1)
                if [ -z "$mirror_host" ]; then
                    mirror_host=$(sed -n 's|.*http://\([^/]*\).*|\1|p' "$config_path" 2>/dev/null | head -1)
                fi
                if [ -n "$mirror_host" ]; then
                    current_source="第三方镜像源 ($mirror_host)"
                    source_type="third_party"
                else
                    current_source="自定义配置"
                    source_type="custom"
                fi
            fi
        fi
    else
        current_source="配置文件不存在"
        source_type="missing"
    fi
    echo -e "${BRIGHT_BLUE}┌─ 📊 当前源状态 ───────────────────────────────────────────────┐${NC}"
    case "$source_type" in
        "custom")
            echo -e "${BRIGHT_PURPLE}│${NC} ${BRIGHT_PURPLE}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_PURPLE}│${NC} ${BRIGHT_PURPLE}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_PURPLE}│${NC} ${BRIGHT_PURPLE}✅ 状态:${NC} ${BRIGHT_PURPLE}${BOLD} 自定义源已激活 ${NC}"
            ;;
        "aliyun"|"tencent"|"huawei"|"tsinghua"|"ustc"|"netease")
            echo -e "${BRIGHT_CYAN}│${NC} ${BRIGHT_CYAN}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_CYAN}│${NC} ${BRIGHT_CYAN}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_CYAN}│${NC} ${BRIGHT_CYAN}✅ 状态:${NC} ${BRIGHT_CYAN}${BOLD} 国内镜像源已激活 ${NC}"
            ;;
        "official")
            echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_GREEN}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_GREEN}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_GREEN}✅ 状态:${NC} ${BRIGHT_GREEN}${BOLD} 使用官方源 ${NC}"
            ;;
        "third_party")
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_MAGENTA}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_MAGENTA}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_MAGENTA}ℹ️ 状态:${NC} ${BRIGHT_MAGENTA}使用第三方镜像源${NC}"
            ;;
        "missing")
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_RED}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_RED}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_RED}❌ 状态:${NC} ${BRIGHT_RED}配置文件缺失${NC}"
            ;;
        *)
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_WHITE}🌐 当前源:${NC} ${BRIGHT_WHITE}$current_source${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_WHITE}📁 配置文件:${NC} ${BRIGHT_WHITE}$config_path${NC}"
            echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_WHITE}ℹ️ 状态:${NC} ${BRIGHT_WHITE}自定义配置${NC}"
            ;;
    esac
    echo -e "${BRIGHT_BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}
# 显示主菜单
show_main_menu() {
    echo -e "${BRIGHT_CYAN}┌─ 📋 操作菜单 ─────────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}                                                             ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}1.${NC} ${BRIGHT_GREEN}🔄 切换镜像源${NC}                                      ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}2.${NC} ${BRIGHT_YELLOW}🏠 恢复官方源${NC}                                      ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}3.${NC} ${BRIGHT_BLUE}💾 备份当前配置${NC}                                    ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}4.${NC} ${BRIGHT_MAGENTA}🔙 恢复备份配置${NC}                                    ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}5.${NC} ${BRIGHT_YELLOW}📋 查看备份列表${NC}                                    ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}6.${NC} ${BRIGHT_GREEN}🌐 测试网络连接${NC}                                    ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}7.${NC} ${BRIGHT_BLUE}❓ 显示帮助${NC}                                        ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}  ${BRIGHT_WHITE}0.${NC} ${BRIGHT_RED}🚪 退出程序${NC}                                        ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}│${NC}                                                             ${BRIGHT_CYAN}│${NC}"
    echo -e "${BRIGHT_CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}
# 全局变量存储测试结果
declare -A MIRROR_SPEEDS
declare -A MIRROR_TESTED
# 在脚本启动时测试镜像源速度
test_mirrors_on_startup() {
    # 如果已经测试过，直接返回
    if [ "${MIRROR_TESTED[done]}" = "true" ]; then
        return
    fi
    declare -A mirror_names=(
        ["mirrors.aliyun.com"]="阿里云"
        ["mirrors.cloud.tencent.com"]="腾讯云"
        ["mirrors.huaweicloud.com"]="华为云"
        ["mirrors.tuna.tsinghua.edu.cn"]="清华大学"
        ["mirrors.ustc.edu.cn"]="中科大"
        ["mirrors.163.com"]="网易"
    )
    local fastest_time=9999
    local slowest_time=0
    for host in "${!mirror_names[@]}"; do
        local url="https://$host/debian"
        # 使用time命令测量，兼容BusyBox
        local start_time=$(date +%s)
        if curl -s --connect-timeout 2 --max-time 5 "$url/dists/" >/dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$(( (end_time - start_time) * 1000 ))
            # 如果时间差为0，使用curl的time功能进行更精确测量
            if [ "$duration" -eq 0 ]; then
                local time_total=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 2 --max-time 5 "$url/dists/" 2>/dev/null)
                # 将秒转换为毫秒，使用shell算术
                duration=$(echo "$time_total" | sed 's/\.//' | sed 's/^0*//' | head -c 4)
                [ -z "$duration" ] && duration=1
            fi
            MIRROR_SPEEDS[$host]=$duration
            if [ "$duration" -lt "$fastest_time" ]; then
                fastest_time="$duration"
            fi
            if [ "$duration" -gt "$slowest_time" ]; then
                slowest_time="$duration"
            fi
        else
            MIRROR_SPEEDS[$host]="failed"
        fi
    done
    # 标记已测试
    MIRROR_TESTED[done]="true"
    MIRROR_TESTED[fastest]="$fastest_time"
    MIRROR_TESTED[slowest]="$slowest_time"
}
# 获取源的速度显示
get_speed_display() {
    local host="$1"
    local speed="${MIRROR_SPEEDS[$host]}"
    if [ "$speed" = "failed" ]; then
        echo "${BRIGHT_RED}(连接失败)${NC}"
    elif [ -n "$speed" ]; then
        local label=""
        if [ "$speed" = "${MIRROR_TESTED[fastest]}" ]; then
            label=" ${BRIGHT_GREEN}(最快)${NC}"
        elif [ "$speed" = "${MIRROR_TESTED[slowest]}" ]; then
            label=" ${BRIGHT_RED}(最慢)${NC}"
        fi
        echo "${BRIGHT_YELLOW}(${speed}ms)${NC}$label"
    else
        echo ""
    fi
}
# 显示镜像源选择菜单
show_mirror_menu() {
    echo -e "${BRIGHT_GREEN}┌─ 🔄 镜像源选择 ───────────────────────────────────────────────┐${NC}"
    # 显示各个镜像源及其速度
    local aliyun_speed=$(get_speed_display "mirrors.aliyun.com")
    local tencent_speed=$(get_speed_display "mirrors.cloud.tencent.com")
    local huawei_speed=$(get_speed_display "mirrors.huaweicloud.com")
    local tsinghua_speed=$(get_speed_display "mirrors.tuna.tsinghua.edu.cn")
    local ustc_speed=$(get_speed_display "mirrors.ustc.edu.cn")
    local netease_speed=$(get_speed_display "mirrors.163.com")
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}1.${NC} ${BRIGHT_BLUE}🇨🇳 阿里云${NC} $aliyun_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}2.${NC} ${BRIGHT_BLUE}🇨🇳 腾讯云${NC} $tencent_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}3.${NC} ${BRIGHT_BLUE}🇨🇳 华为云${NC} $huawei_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}4.${NC} ${BRIGHT_BLUE}🇨🇳 清华大学${NC} $tsinghua_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}5.${NC} ${BRIGHT_BLUE}🇨🇳 中科大${NC} $ustc_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}6.${NC} ${BRIGHT_BLUE}🇨🇳 网易${NC} $netease_speed"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}7.${NC} ${BRIGHT_PURPLE}🌐 自定义源${NC}                                        ${BRIGHT_GREEN}│${NC}"
    echo -e "${BRIGHT_GREEN}│${NC}  ${BRIGHT_WHITE}0.${NC} ${BRIGHT_YELLOW}↩️ 返回主菜单${NC}                                      ${BRIGHT_GREEN}│${NC}"
    echo -e "${BRIGHT_GREEN}└─────────────────────────────────────────────────────────────┘${NC}"
}
# 显示备份选择菜单
show_backup_menu() {
    local backups=($(list_backup_timestamps))
    echo -e "${BRIGHT_MAGENTA}┌─ 🔙 备份恢复选择 ─────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_MAGENTA}│${NC}                                                             ${BRIGHT_MAGENTA}│${NC}"
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${BRIGHT_MAGENTA}│${NC}  ${BRIGHT_RED}❌ 没有可用的备份${NC}                                      ${BRIGHT_MAGENTA}│${NC}"
    else
        local i=1
        for backup in "${backups[@]}"; do
            local formatted_time=$(format_backup_time "$backup")
            local label=""
            if [ $i -eq 1 ]; then
                label=" ${BRIGHT_GREEN}(最新)${NC}"
            elif [ $i -eq ${#backups[@]} ]; then
                label=" ${BRIGHT_YELLOW}(最老)${NC}"
            fi
            echo -e "${BRIGHT_MAGENTA}│${NC}  ${BRIGHT_WHITE}$i.${NC} ${BRIGHT_CYAN}$formatted_time${NC}$label"
            ((i++))
        done
    fi
    echo -e "${BRIGHT_MAGENTA}│${NC}  ${BRIGHT_WHITE}0.${NC} ${BRIGHT_YELLOW}↩️ 返回主菜单${NC}                                      ${BRIGHT_MAGENTA}│${NC}"
    echo -e "${BRIGHT_MAGENTA}│${NC}                                                             ${BRIGHT_MAGENTA}│${NC}"
    echo -e "${BRIGHT_MAGENTA}└─────────────────────────────────────────────────────────────┘${NC}"
}
# 显示完成信息
show_completion() {
    local worker_domain="$1"
    echo
    echo -e "${BRIGHT_GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_GREEN}║${NC}  ${ICON_SUCCESS} ${BRIGHT_WHITE}${BOLD}换源完成！${NC}                                        ${BRIGHT_GREEN}║${NC}"
    echo -e "${BRIGHT_GREEN}║${NC}  ${BRIGHT_GREEN}🎉 已成功切换到Worker镜像源${NC}                          ${BRIGHT_GREEN}║${NC}"
    echo -e "${BRIGHT_GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BRIGHT_BLUE}┌─ 配置详情 ───────────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_CYAN}🌐 Worker域名:${NC} ${BRIGHT_WHITE}$worker_domain${NC}"
    echo -e "${BRIGHT_BLUE}│${NC} ${BRIGHT_CYAN}📁 配置文件:${NC} ${BRIGHT_WHITE}$(get_config_path)${NC}"
    echo -e "${BRIGHT_BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${BRIGHT_YELLOW}💡 ${BOLD}提示:${NC} ${YELLOW}如需恢复原有配置，请运行:${NC}"
    echo -e "   ${BRIGHT_WHITE}$0 --restore${NC}"
    echo
}
# ===== 备份恢复模块 =====
# 备份恢复模块
# 创建备份目录
create_backup_dir() {
    safe_mkdir "$BACKUP_DIR"
}
# 备份配置文件
backup_config() {
    local os=$(detect_os)
    local config_path=$(get_config_path)
    local timestamp=$(get_timestamp)
    
    create_backup_dir
    
    if [ ! -f "$config_path" ]; then
        echo_warning "配置文件不存在: $config_path"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/$(basename "$config_path").$timestamp"
    
    if cp "$config_path" "$backup_file"; then
        echo_success "已备份配置文件到: $backup_file"
        
        # 记录最新备份
        echo "$timestamp" > "$BACKUP_DIR/latest"
        
        # 清理旧备份
        cleanup_old_backups
        
        return 0
    else
        echo_error "备份失败: $config_path"
        return 1
    fi
}
# 备份sources.list.d目录 (仅Debian/Ubuntu)
backup_sources_dir() {
    local os=$(detect_os)
    local timestamp=$(get_timestamp)
    
    if [ "$os" != "debian" ] && [ "$os" != "ubuntu" ]; then
        return 0
    fi
    
    local sources_dir="/etc/apt/sources.list.d"
    
    if [ -d "$sources_dir" ] && [ "$(ls -A "$sources_dir" 2>/dev/null)" ]; then
        local backup_dir="$BACKUP_DIR/sources.list.d.$timestamp"
        
        if cp -r "$sources_dir" "$backup_dir"; then
            echo_success "已备份sources.list.d目录"
        else
            echo_warning "备份sources.list.d目录失败"
        fi
    fi
}
# 完整备份
full_backup() {
    echo_info "创建配置备份..."
    
    if backup_config; then
        backup_sources_dir
        echo_success "备份完成"
        return 0
    else
        return 1
    fi
}
# 列出所有备份
list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo_warning "没有找到备份目录"
        return 1
    fi
    
    local os=$(detect_os)
    local config_name=$(basename "$(get_config_path)")
    
    echo_info "可用的备份:"
    # 获取所有备份并排序
    local backups=()
    for backup_file in "$BACKUP_DIR"/$config_name.*; do
        if [ -f "$backup_file" ]; then
            local timestamp=$(basename "$backup_file" | sed "s/^$config_name\.//")
            if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
                backups+=("$timestamp")
            fi
        fi
    done
    if [ ${#backups[@]} -eq 0 ]; then
        echo_warning "没有找到备份文件"
        return 1
    else
        # 按时间戳排序（最新的在前）
        IFS=$'\n' backups=($(sort -r <<< "${backups[*]}"))
        unset IFS
        local i=0
        for timestamp in "${backups[@]}"; do
            local formatted_time=$(format_timestamp "$timestamp")
            local label=""
            if [ $i -eq 0 ]; then
                label=" ${BRIGHT_GREEN}(最新)${NC}"
            elif [ $i -eq $((${#backups[@]} - 1)) ] && [ ${#backups[@]} -gt 1 ]; then
                label=" ${BRIGHT_YELLOW}(最老)${NC}"
            fi
            echo -e "  $timestamp ($formatted_time)$label"
            ((i++))
        done
    fi
    return 0
    
    return 0
}
# 恢复配置
restore_config() {
    local timestamp="$1"
    local os=$(detect_os)
    local config_path=$(get_config_path)
    local config_name=$(basename "$config_path")
    
    # 如果没有指定时间戳，使用最新备份
    if [ -z "$timestamp" ]; then
        if [ -f "$BACKUP_DIR/latest" ]; then
            timestamp=$(cat "$BACKUP_DIR/latest")
            echo_info "使用最新备份: $timestamp"
        else
            echo_error "没有找到备份记录"
            return 1
        fi
    fi
    
    local backup_file="$BACKUP_DIR/$config_name.$timestamp"
    
    if [ ! -f "$backup_file" ]; then
        echo_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 恢复主配置文件
    if cp "$backup_file" "$config_path"; then
        echo_success "已恢复配置文件: $config_path"
    else
        echo_error "恢复配置文件失败"
        return 1
    fi
    
    # 恢复sources.list.d目录 (仅Debian/Ubuntu)
    if [ "$os" = "debian" ] || [ "$os" = "ubuntu" ]; then
        local sources_backup="$BACKUP_DIR/sources.list.d.$timestamp"
        if [ -d "$sources_backup" ]; then
            rm -rf /etc/apt/sources.list.d
            if cp -r "$sources_backup" /etc/apt/sources.list.d; then
                echo_success "已恢复sources.list.d目录"
            else
                echo_warning "恢复sources.list.d目录失败"
            fi
        fi
    fi
    
    echo_success "恢复完成，时间戳: $timestamp"
    return 0
}
# 交互式恢复
interactive_restore() {
    if ! list_backups; then
        return 1
    fi
    
    echo
    if [ "$FORCE_YES" = true ]; then
        echo_info "非交互模式，使用最新备份"
        restore_config
    else
        read -p "$(echo -e "${ICON_QUESTION} 请输入要恢复的备份时间戳 (留空使用最新备份): ")" timestamp
        restore_config "$timestamp"
    fi
}
# 获取备份时间戳列表
list_backup_timestamps() {
    local backup_dir="/etc/apt/sources.list.backup"
    if [ ! -d "$backup_dir" ]; then
        return 1
    fi
    find "$backup_dir" -name "sources.list.*" -type f | \
        sed 's|.*/sources\.list\.||' | \
        sort -r
}
# 格式化备份时间显示
format_backup_time() {
    local timestamp="$1"
    if [[ "$timestamp" =~ ^([0-9]{8})_([0-9]{6})$ ]]; then
        local date_part="${BASH_REMATCH[1]}"
        local time_part="${BASH_REMATCH[2]}"
        local year="${date_part:0:4}"
        local month="${date_part:4:2}"
        local day="${date_part:6:2}"
        local hour="${time_part:0:2}"
        local minute="${time_part:2:2}"
        local second="${time_part:4:2}"
        echo "$timestamp ($year-$month-$day $hour:$minute:$second)"
    else
        echo "$timestamp"
    fi
}
# 清理旧备份
cleanup_old_backups() {
    local os=$(detect_os)
    local config_name=$(basename "$(get_config_path)")
    
    # 获取所有备份文件，按时间排序
    local backup_files=()
    for backup_file in "$BACKUP_DIR"/$config_name.*; do
        if [ -f "$backup_file" ]; then
            local timestamp=$(basename "$backup_file" | sed "s/^$config_name\.//")
            if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
                backup_files+=("$backup_file")
            fi
        fi
    done
    
    # 如果备份数量超过限制，删除最旧的
    local backup_count=${#backup_files[@]}
    if [ "$backup_count" -gt "$BACKUP_KEEP_COUNT" ]; then
        # 按文件名排序（时间戳排序）
        IFS=$'\n' backup_files=($(sort <<<"${backup_files[*]}"))
        unset IFS
        
        local delete_count=$((backup_count - BACKUP_KEEP_COUNT))
        for ((i=0; i<delete_count; i++)); do
            local file_to_delete="${backup_files[$i]}"
            local timestamp=$(basename "$file_to_delete" | sed "s/^$config_name\.//")
            
            rm -f "$file_to_delete"
            
            # 同时删除对应的sources.list.d备份
            local sources_backup="$BACKUP_DIR/sources.list.d.$timestamp"
            [ -d "$sources_backup" ] && rm -rf "$sources_backup"
        done
        
        echo_info "已清理 $delete_count 个旧备份，保留最新 $BACKUP_KEEP_COUNT 个"
    fi
}
# ===== 源配置模块 =====
# 源配置生成模块
# 生成Debian源配置
generate_debian_sources() {
    local worker_domain="$1"
    local codename="$2"
    
    cat << EOF
# Generated by $SCRIPT_NAME v$SCRIPT_VERSION
# Worker Domain: $worker_domain
# Date: $(date)
# System: Debian $codename
deb https://$worker_domain/debian $codename main contrib non-free non-free-firmware
deb https://$worker_domain/debian $codename-updates main contrib non-free non-free-firmware
deb https://$worker_domain/debian $codename-backports main contrib non-free non-free-firmware
deb https://$worker_domain/debian-security $codename-security main contrib non-free non-free-firmware
EOF
}
# 生成Ubuntu源配置
generate_ubuntu_sources() {
    local worker_domain="$1"
    local codename="$2"
    
    cat << EOF
# Generated by $SCRIPT_NAME v$SCRIPT_VERSION
# Worker Domain: $worker_domain
# Date: $(date)
# System: Ubuntu $codename
deb https://$worker_domain/ubuntu $codename main restricted universe multiverse
deb https://$worker_domain/ubuntu $codename-updates main restricted universe multiverse
deb https://$worker_domain/ubuntu $codename-backports main restricted universe multiverse
deb https://$worker_domain/ubuntu-security $codename-security main restricted universe multiverse
EOF
}
# 生成Alpine源配置
generate_alpine_sources() {
    local worker_domain="$1"
    local version="$2"
    
    # Alpine版本处理
    local major_version
    if [[ "$version" =~ ^([0-9]+\.[0-9]+) ]]; then
        major_version="${BASH_REMATCH[1]}"
    else
        major_version="3.19"  # 默认版本
        echo_warning "无法确定Alpine版本，使用默认版本: $major_version"
    fi
    
    cat << EOF
# Generated by $SCRIPT_NAME v$SCRIPT_VERSION
# Worker Domain: $worker_domain
# Date: $(date)
# System: Alpine Linux $version
https://$worker_domain/alpine/v$major_version/main
https://$worker_domain/alpine/v$major_version/community
EOF
}
# 根据系统生成源配置
generate_sources_config() {
    local worker_domain="$1"
    local os=$(detect_os)
    local version=$(detect_version)
    local codename=$(detect_codename)
    
    case "$os" in
        debian)
            if [ "$codename" = "unknown" ]; then
                # 根据版本号推断代号
                case "$version" in
                    12*) codename="bookworm" ;;
                    11*) codename="bullseye" ;;
                    10*) codename="buster" ;;
                    *) 
                        echo_error "无法确定Debian版本代号"
                        return 1
                        ;;
                esac
                echo_warning "自动推断Debian代号: $codename"
            fi
            generate_debian_sources "$worker_domain" "$codename"
            ;;
        ubuntu)
            if [ "$codename" = "unknown" ]; then
                # 根据版本号推断代号
                case "$version" in
                    24.04) codename="noble" ;;
                    22.04) codename="jammy" ;;
                    20.04) codename="focal" ;;
                    18.04) codename="bionic" ;;
                    *) 
                        echo_error "无法确定Ubuntu版本代号"
                        return 1
                        ;;
                esac
                echo_warning "自动推断Ubuntu代号: $codename"
            fi
            generate_ubuntu_sources "$worker_domain" "$codename"
            ;;
        alpine)
            generate_alpine_sources "$worker_domain" "$version"
            ;;
        *)
            echo_error "不支持的操作系统: $os"
            return 1
            ;;
    esac
}
# 预览源配置
preview_sources_config() {
    local worker_domain="$1"
    
    echo_info "预览新的源配置:"
    echo "----------------------------------------"
    generate_sources_config "$worker_domain"
    echo "----------------------------------------"
}
# 应用源配置
apply_sources_config() {
    local worker_domain="$1"
    local config_path=$(get_config_path)
    local temp_file="/tmp/sources_config_$$"
    
    # 生成新配置到临时文件
    if ! generate_sources_config "$worker_domain" > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi
    
    # 验证临时文件
    if [ ! -s "$temp_file" ]; then
        echo_error "生成的配置文件为空"
        rm -f "$temp_file"
        return 1
    fi
    
    # 应用配置
    if cp "$temp_file" "$config_path"; then
        echo_success "已更新配置文件: $config_path"
        rm -f "$temp_file"
        return 0
    else
        echo_error "更新配置文件失败"
        rm -f "$temp_file"
        return 1
    fi
}
# 生成官方源配置
generate_official_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# Official sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb http://deb.debian.org/debian $codename main contrib non-free non-free-firmware"
            echo "deb http://deb.debian.org/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb http://security.debian.org/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb http://archive.ubuntu.com/ubuntu $codename main restricted universe multiverse"
            echo "deb http://archive.ubuntu.com/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb http://archive.ubuntu.com/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成阿里云镜像源配置
generate_aliyun_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# Aliyun mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.aliyun.com/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.aliyun.com/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.aliyun.com/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.aliyun.com/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.aliyun.com/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.aliyun.com/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.aliyun.com/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.aliyun.com/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成腾讯云镜像源配置
generate_tencent_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# Tencent mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.cloud.tencent.com/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.cloud.tencent.com/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.cloud.tencent.com/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.cloud.tencent.com/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.cloud.tencent.com/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.cloud.tencent.com/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.cloud.tencent.com/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.cloud.tencent.com/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成华为云镜像源配置
generate_huawei_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# Huawei mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.huaweicloud.com/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.huaweicloud.com/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.huaweicloud.com/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.huaweicloud.com/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.huaweicloud.com/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.huaweicloud.com/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.huaweicloud.com/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.huaweicloud.com/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成清华大学镜像源配置
generate_tsinghua_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# Tsinghua University mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成中科大镜像源配置
generate_ustc_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# USTC mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.ustc.edu.cn/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.ustc.edu.cn/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.ustc.edu.cn/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.ustc.edu.cn/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.ustc.edu.cn/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.ustc.edu.cn/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.ustc.edu.cn/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.ustc.edu.cn/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 生成网易镜像源配置
generate_netease_sources() {
    local os="$1"
    local version="$2"
    local codename="$3"
    echo "# NetEase mirror sources for $os $version ($codename)"
    echo "# Generated by Linux Mirror Switch v$SCRIPT_VERSION"
    echo "# Date: $(date)"
    echo ""
    case "$os" in
        "debian")
            echo "deb https://mirrors.163.com/debian $codename main contrib non-free non-free-firmware"
            echo "deb https://mirrors.163.com/debian $codename-updates main contrib non-free non-free-firmware"
            echo "deb https://mirrors.163.com/debian $codename-backports main contrib non-free non-free-firmware"
            echo "deb https://mirrors.163.com/debian-security $codename-security main contrib non-free non-free-firmware"
            ;;
        "ubuntu")
            echo "deb https://mirrors.163.com/ubuntu $codename main restricted universe multiverse"
            echo "deb https://mirrors.163.com/ubuntu $codename-updates main restricted universe multiverse"
            echo "deb https://mirrors.163.com/ubuntu $codename-backports main restricted universe multiverse"
            echo "deb https://mirrors.163.com/ubuntu $codename-security main restricted universe multiverse"
            ;;
    esac
}
# 更新软件包列表
update_package_list() {
    local os=$(detect_os)
    local update_cmd="${UPDATE_COMMANDS[$os]}"
    
    if [ -z "$update_cmd" ]; then
        echo_warning "未知的包管理器，跳过更新"
        return 0
    fi
    
    echo_info "正在更新软件包列表..."
    echo "正在执行: $update_cmd"
    if $update_cmd; then
        echo_success "软件包列表更新成功"
        return 0
    else
        echo_warning "软件包列表更新失败，可能需要手动运行: $update_cmd"
        return 1
    fi
}
# 验证源配置
validate_sources_config() {
    local worker_domain="$1"
    local os=$(detect_os)
    
    # 基本格式验证
    local config_content
    if ! config_content=$(generate_sources_config "$worker_domain"); then
        return 1
    fi
    
    # 检查是否包含Worker域名
    if ! echo "$config_content" | grep -q "$worker_domain"; then
        echo_error "配置中未找到Worker域名"
        return 1
    fi
    
    # 系统特定验证
    case "$os" in
        debian|ubuntu)
            if ! echo "$config_content" | grep -q "^deb "; then
                echo_error "Debian/Ubuntu配置格式错误"
                return 1
            fi
            ;;
        alpine)
            if ! echo "$config_content" | grep -q "^https://"; then
                echo_error "Alpine配置格式错误"
                return 1
            fi
            ;;
    esac
    
    return 0
}
# ===== 主程序 =====
# 全局变量
WORKER_DOMAIN=""
PUBLIC_IP_CACHE=""
DRY_RUN=false
FORCE_YES=false
OPERATION=""

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--domain)
                WORKER_DOMAIN="$2"
                shift 2
                ;;
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--restore)
                OPERATION="restore"
                if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
                    RESTORE_TIMESTAMP="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -b|--backup)
                OPERATION="backup"
                shift
                ;;
            -t|--test)
                OPERATION="test"
                shift
                ;;
            -l|--list)
                OPERATION="list"
                shift
                ;;
            -*)
                echo_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # Worker域名
                if [ -z "$WORKER_DOMAIN" ]; then
                    WORKER_DOMAIN="$1"
                fi
                shift
                ;;
        esac
    done
}

# 执行备份操作
do_backup() {
    echo_info "正在创建备份..."

    if full_backup; then
        echo_success "备份操作完成"
    else
        echo_error "备份操作失败"
        exit 1
    fi
}

# 执行恢复操作
do_restore() {
    echo_info "正在恢复配置..."

    if [ -n "$RESTORE_TIMESTAMP" ]; then
        restore_config "$RESTORE_TIMESTAMP"
    else
        interactive_restore
    fi

    if [ $? -eq 0 ]; then
        echo_info "正在更新软件包列表..."
        update_package_list
        echo_success "恢复操作完成"
    else
        echo_error "恢复操作失败"
        exit 1
    fi
}

# 执行测试操作
do_test() {
    local domain="${WORKER_DOMAIN:-$DEFAULT_WORKER_DOMAIN}"
    
    if [ -z "$domain" ] || [ "$domain" = "$DEFAULT_WORKER_DOMAIN" ]; then
        domain=$(input_worker_domain "$domain")
    fi
    
    if test_worker_connection "$domain"; then
        echo_success "自定义源连接测试通过"
    else
        echo_error "自定义源连接测试失败"
        exit 1
    fi
}

# 执行列表操作
do_list() {
    list_backups || true  # 确保不会因为返回值导致退出
}

# 执行换源操作
do_switch() {
    local domain="$WORKER_DOMAIN"
    
    # 获取Worker域名
    if [ -z "$domain" ]; then
        domain="${WORKER_DOMAIN:-$DEFAULT_WORKER_DOMAIN}"

        # 获取域名
        domain=$(input_worker_domain "$domain")
    fi
    
    # 预览模式
    if [ "$DRY_RUN" = true ]; then
        echo_info "预览模式 - 不会实际修改文件"
        preview_sources_config "$domain"
        return 0
    fi
    
    # 测试连接
    echo_info "正在测试自定义源连接..."
    if ! test_worker_connection "$domain"; then
        echo_error "自定义源连接测试失败"
        return 0  # 返回到镜像源选择菜单
    fi

    # 验证配置
    echo_info "正在验证源配置..."
    if ! validate_sources_config "$domain"; then
        echo_error "源配置验证失败"
        exit 1
    fi

    # 创建备份
    echo_info "正在创建备份..."
    if ! full_backup; then
        echo_error "备份失败，操作终止"
        exit 1
    fi

    # 应用新配置
    echo_info "正在应用新配置..."
    if ! apply_sources_config "$domain"; then
        echo_error "应用配置失败"
        echo_info "尝试恢复备份..."
        restore_config
        exit 1
    fi

    # 更新软件包列表
    echo_info "正在更新软件包列表..."
    update_package_list
    
    # 显示完成信息
    show_completion "$domain"
}

# 交互式镜像源选择
interactive_mirror_selection() {
    while true; do
        show_mirror_menu
        read -p "$(echo -e "${BRIGHT_GREEN}❓ 请选择镜像源 [1-7,0]: ${NC}")" choice

        echo
        case "$choice" in
            "1")
                echo_info "🇨🇳 切换到阿里云镜像源..."
                switch_to_builtin_mirror "aliyun"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "2")
                echo_info "🇨🇳 切换到腾讯云镜像源..."
                switch_to_builtin_mirror "tencent"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "3")
                echo_info "🇨🇳 切换到华为云镜像源..."
                switch_to_builtin_mirror "huawei"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "4")
                echo_info "🇨🇳 切换到清华大学镜像源..."
                switch_to_builtin_mirror "tsinghua"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "5")
                echo_info "🇨🇳 切换到中科大镜像源..."
                switch_to_builtin_mirror "ustc"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "6")
                echo_info "🇨🇳 切换到网易镜像源..."
                switch_to_builtin_mirror "netease"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "7")
                echo_info "🌐 自定义源..."
                echo_info "请输入您的镜像源域名"
                echo_info "例如: mirror.yourdomain.com 或 your-worker.workers.dev"
                read -p "$(echo -e "${BRIGHT_PURPLE}❓ 域名: ${NC}")" custom_domain

                if [ -z "$custom_domain" ]; then
                    echo_error "域名不能为空"
                    echo
                    read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                    continue
                fi

                # 验证域名格式
                if ! validate_domain "$custom_domain"; then
                    echo
                    read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                    continue
                fi

                # 将自定义域名当作Worker域名处理
                WORKER_DOMAIN="$custom_domain"
                do_switch

                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                return
                ;;
            "0")
                return
                ;;
            *)
                echo_error "❌ 无效选择，请输入 0-7 之间的数字"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
        esac
    done
}


# 交互式备份恢复
interactive_backup_restore() {
    while true; do
        show_backup_menu
        local backups=($(list_backup_timestamps))
        local max_choice=${#backups[@]}

        read -p "$(echo -e "${BRIGHT_MAGENTA}❓ 请选择备份 [1-$max_choice,0]: ${NC}")" choice

        echo
        if [ "$choice" = "0" ]; then
            return
        elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
            local selected_backup="${backups[$((choice-1))]}"
            echo_info "🔙 恢复备份: $(format_backup_time "$selected_backup")"
            restore_config "$selected_backup"
            if [ $? -eq 0 ]; then
                update_package_list
                echo_success "恢复操作完成"
            else
                echo_error "恢复操作失败"
            fi
            echo
            read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
            return
        else
            echo_error "❌ 无效选择，请输入 0-$max_choice 之间的数字"
            echo
            read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
        fi
    done
}

# 切换到内置镜像源
switch_to_builtin_mirror() {
    local mirror_type="$1"
    local os=$(detect_os)
    local version=$(detect_version)
    local codename=$(detect_codename)
    local config_path=$(get_config_path)

    # 创建备份
    if ! full_backup; then
        echo_error "备份失败，操作终止"
        return 1
    fi

    # 根据镜像类型生成配置
    case "$mirror_type" in
        "aliyun")
            generate_aliyun_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到阿里云镜像源"
            ;;
        "tencent")
            generate_tencent_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到腾讯云镜像源"
            ;;
        "huawei")
            generate_huawei_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到华为云镜像源"
            ;;
        "tsinghua")
            generate_tsinghua_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到清华大学镜像源"
            ;;
        "ustc")
            generate_ustc_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到中科大镜像源"
            ;;
        "netease")
            generate_netease_sources "$os" "$version" "$codename" > "$config_path"
            echo_success "已切换到网易镜像源"
            ;;
        *)
            echo_error "不支持的镜像源类型: $mirror_type"
            return 1
            ;;
    esac

    # 更新软件包列表
    if [ "$PREVIEW_MODE" != true ]; then
        update_package_list
    fi
}

# 恢复官方源
restore_official_sources() {
    local os=$(detect_os)
    local version=$(detect_version)
    local codename=$(detect_codename)
    local config_path=$(get_config_path)

    # 创建备份
    if ! full_backup; then
        echo_error "备份失败，操作终止"
        return 1
    fi

    # 生成官方源配置
    generate_official_sources "$os" "$version" "$codename" > "$config_path"
    echo_success "已恢复官方源"

    # 更新软件包列表
    update_package_list
}

# 测试网络连接
test_network_connectivity() {
    echo -e "${BRIGHT_GREEN}┌─ 🌐 网络连接测试 ─────────────────────────────────────────────┐${NC}"
    echo -e "${BRIGHT_GREEN}│${NC}                                                             ${BRIGHT_GREEN}│${NC}"

    # 测试基本网络连接
    echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_CYAN}🔍 测试基本网络连接...${NC}"
    if check_network; then
        echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_GREEN}✅ 基本网络连接正常${NC}"
    else
        echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_RED}❌ 基本网络连接异常${NC}"
    fi



    # 获取当前使用的源
    local config_path=$(get_config_path)
    local current_source=""
    if [ -f "$config_path" ]; then
        if grep -q "mirrors.aliyun.com" "$config_path" 2>/dev/null; then
            current_source="mirrors.aliyun.com"
        elif grep -q "mirrors.cloud.tencent.com" "$config_path" 2>/dev/null; then
            current_source="mirrors.cloud.tencent.com"
        elif grep -q "mirrors.huaweicloud.com" "$config_path" 2>/dev/null; then
            current_source="mirrors.huaweicloud.com"
        elif grep -q "mirrors.tuna.tsinghua.edu.cn" "$config_path" 2>/dev/null; then
            current_source="mirrors.tuna.tsinghua.edu.cn"
        elif grep -q "mirrors.ustc.edu.cn" "$config_path" 2>/dev/null; then
            current_source="mirrors.ustc.edu.cn"
        elif grep -q "mirrors.163.com" "$config_path" 2>/dev/null; then
            current_source="mirrors.163.com"
        elif grep -q "deb.debian.org" "$config_path" 2>/dev/null; then
            current_source="deb.debian.org"
        fi
    fi

    # 定义所有镜像源
    declare -A mirror_sources=(
        ["mirrors.aliyun.com"]="阿里云"
        ["mirrors.cloud.tencent.com"]="腾讯云"
        ["mirrors.huaweicloud.com"]="华为云"
        ["mirrors.tuna.tsinghua.edu.cn"]="清华大学"
        ["mirrors.ustc.edu.cn"]="中科大"
        ["mirrors.163.com"]="网易"
        ["deb.debian.org"]="官方源"
    )

    # 测试所有镜像源
    echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_CYAN}🔍 测试所有镜像源连接和速度...${NC}"

    for host in "${!mirror_sources[@]}"; do
        local source_name="${mirror_sources[$host]}"
        local url="https://$host/debian"
        if [[ "$host" == "deb.debian.org" ]]; then
            url="http://$host/debian"
        fi

        # 使用curl的内置时间测量，兼容BusyBox
        local duration=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 3 --max-time 8 "$url/dists/" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$duration" ]; then
            # 将秒转换为毫秒，兼容BusyBox
            duration=$(echo "$duration 1000" | awk '{print int($1*$2)}' 2>/dev/null)
            [ -z "$duration" ] && duration=0

            # 判断是否是当前使用的源
            local is_current=""
            if [[ "$host" == "$current_source" ]]; then
                is_current=" ${BRIGHT_BLUE}(当前)${NC}"
            fi

            if [ "$duration" -lt 1000 ]; then
                echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_GREEN}✅ $source_name $host 连接正常 (${duration}ms)${NC}$is_current"
            elif [ "$duration" -lt 3000 ]; then
                echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_YELLOW}⚠️ $source_name $host 连接较慢 (${duration}ms)${NC}$is_current"
            else
                echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_RED}🐌 $source_name $host 连接很慢 (${duration}ms)${NC}$is_current"
            fi
        else
            local is_current=""
            if [[ "$host" == "$current_source" ]]; then
                is_current=" ${BRIGHT_BLUE}(当前)${NC}"
            fi
            echo -e "${BRIGHT_GREEN}│${NC} ${BRIGHT_RED}❌ $source_name $host 连接失败${NC}$is_current"
        fi
    done

    echo -e "${BRIGHT_GREEN}│${NC}                                                             ${BRIGHT_GREEN}│${NC}"
    echo -e "${BRIGHT_GREEN}└─────────────────────────────────────────────────────────────┘${NC}"
}

# 交互式主菜单
interactive_menu() {
    while true; do
        # 显示当前状态
        show_current_status

        # 显示主菜单
        show_main_menu

        # 获取用户选择
        read -p "$(echo -e "${BRIGHT_CYAN}❓ 请选择操作 [1-7,0]: ${NC}")" choice

        echo
        case "$choice" in
            "1")
                interactive_mirror_selection
                ;;
            "2")
                echo_info "🏠 恢复官方源..."
                restore_official_sources
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
            "3")
                echo_info "💾 开始备份当前配置..."
                do_backup
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
            "4")
                interactive_backup_restore
                ;;
            "5")
                echo_info "📋 查看备份列表..."
                do_list
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
            "6")
                echo_info "🌐 测试网络连接..."
                test_network_connectivity
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
            "7")
                show_help
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
            "0")
                echo_info "👋 感谢使用 Linux Mirror Switch！"
                exit 0
                ;;
            *)
                echo_error "❌ 无效选择，请输入 0-7 之间的数字"
                echo
                read -p "$(echo -e "${BRIGHT_CYAN}按回车键继续...${NC}")"
                ;;
        esac

        # 清屏并重新显示标题
        clear
        show_title
        get_system_info
        echo
    done
}

# 并行执行后台任务
run_background_tasks() {
    # 创建临时文件存储结果
    local public_ip_file="/tmp/mirror_switch_public_ip_$$"
    local mirror_test_file="/tmp/mirror_switch_mirror_test_$$"

    # 后台获取公网IP
    (
        if command -v curl >/dev/null 2>&1; then
            curl -s --connect-timeout 1 --max-time 2 ipv4.icanhazip.com 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > "$public_ip_file" 2>/dev/null
        fi
    ) &
    local ip_pid=$!

    # 后台测试镜像源速度
    (
        test_mirrors_on_startup
        echo "done" > "$mirror_test_file"
    ) &
    local mirror_pid=$!

    # 等待两个任务完成
    wait $ip_pid 2>/dev/null
    wait $mirror_pid 2>/dev/null

    # 读取公网IP结果并存储到全局变量
    if [ -f "$public_ip_file" ]; then
        PUBLIC_IP_CACHE=$(cat "$public_ip_file" 2>/dev/null)
        rm -f "$public_ip_file" 2>/dev/null
    fi

    # 清理临时文件
    rm -f "$mirror_test_file" 2>/dev/null
}

# 主函数
main() {
    # 解析参数
    parse_arguments "$@"

    # 检查root权限
    check_root

    # 验证系统支持
    if ! validate_system_support; then
        exit 1
    fi

    # 先更新软件包列表
    update_package_list_on_startup

    # 检测和安装依赖
    check_and_install_dependencies

    # 检测系统配置
    echo_info "🔍 正在检测系统配置..."

    # 并行执行公网IP检测和镜像源测速
    run_background_tasks

    echo_success "系统配置检测完成"

    # 清屏并显示标题
    clear
    show_title

    # 显示系统信息
    get_system_info

    # 检查网络连接
    if ! check_network; then
        echo_warning "网络连接异常，可能影响操作"
        if ! ask_confirmation "是否继续？"; then
            exit 1
        fi
    fi

    # 如果没有指定操作且不是强制模式，进入交互式菜单
    if [ -z "$OPERATION" ] && [ -z "$WORKER_DOMAIN" ] && [ "$PREVIEW_MODE" != true ] && [ "$FORCE_YES" != true ]; then
        interactive_menu
        return
    fi

    # 根据操作类型执行
    case "$OPERATION" in
        backup)
            do_backup
            ;;
        restore)
            do_restore
            ;;
        test)
            do_test
            ;;
        list)
            do_list
            ;;
        *)
            do_switch
            ;;
    esac
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
