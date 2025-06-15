#!/bin/bash
#
# 脚本名称: install-kubernetes.sh
# 功能描述: Kubernetes 集群自动化安装脚本
# 创建时间: 2025-06-14
# 版本信息: v1.0.0
# 依赖条件: Docker, curl, systemctl
# 支持平台: Ubuntu 18.04+, CentOS 7+, RHEL 7+
#

# 获取脚本目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# 加载公共函数库
if [[ -f "$UTILS_DIR/common-functions.sh" ]]; then
    source "$UTILS_DIR/common-functions.sh"
else
    echo "错误: 无法找到公共函数库 $UTILS_DIR/common-functions.sh"
    exit 1
fi

# 全局变量
readonly K8S_VERSION="${K8S_VERSION:-1.28.0}"
readonly CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-containerd}"
readonly CNI_PLUGIN="${CNI_PLUGIN:-flannel}"
readonly CLUSTER_NAME="${CLUSTER_NAME:-kubernetes}"
readonly POD_SUBNET="${POD_SUBNET:-10.244.0.0/16}"
readonly SERVICE_SUBNET="${SERVICE_SUBNET:-10.96.0.0/12}"
readonly INSTALL_MODE="${INSTALL_MODE:-single-node}"
readonly MASTER_IP="${MASTER_IP:-}"
readonly NODE_TYPE="${NODE_TYPE:-master}"

# 配置文件路径
readonly KUBEADM_CONFIG="/tmp/kubeadm-config.yaml"
readonly CONTAINERD_CONFIG="/etc/containerd/config.toml"
readonly DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"

# 临时文件列表
TEMP_FILES=()

# 清理函数
cleanup() {
    log INFO "开始清理临时文件..."
    cleanup_resources "${TEMP_FILES[@]}"
}

# 设置清理陷阱
trap cleanup EXIT

# 显示帮助信息
show_help() {
    cat << EOF
Kubernetes 集群安装脚本

使用方法: $0 [选项]

选项:
    --version VERSION           Kubernetes 版本 (默认: $K8S_VERSION)
    --runtime RUNTIME           容器运行时 (containerd|docker, 默认: $CONTAINER_RUNTIME)
    --cni CNI                   CNI 插件 (flannel|calico|weave, 默认: $CNI_PLUGIN)
    --mode MODE                 安装模式 (single-node|multi-node, 默认: $INSTALL_MODE)
    --master-ip IP              主节点 IP 地址 (多节点模式必需)
    --node-type TYPE            节点类型 (master|worker, 默认: $NODE_TYPE)
    --pod-subnet CIDR           Pod 网络 CIDR (默认: $POD_SUBNET)
    --service-subnet CIDR       Service 网络 CIDR (默认: $SERVICE_SUBNET)
    --cluster-name NAME         集群名称 (默认: $CLUSTER_NAME)
    -v, --verbose               详细输出模式
    -d, --dry-run               干运行模式
    -h, --help                  显示帮助信息

示例:
    # 单节点集群安装
    $0 --mode single-node --cni flannel

    # 多节点主节点安装
    $0 --mode multi-node --node-type master --master-ip 192.168.1.100

    # 多节点工作节点安装
    $0 --mode multi-node --node-type worker --master-ip 192.168.1.100

环境变量:
    K8S_VERSION                 Kubernetes 版本
    CONTAINER_RUNTIME           容器运行时
    CNI_PLUGIN                  CNI 插件
    INSTALL_MODE                安装模式
    MASTER_IP                   主节点 IP
    NODE_TYPE                   节点类型
EOF
}

# 参数解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --cni)
                CNI_PLUGIN="$2"
                shift 2
                ;;
            --mode)
                INSTALL_MODE="$2"
                shift 2
                ;;
            --master-ip)
                MASTER_IP="$2"
                shift 2
                ;;
            --node-type)
                NODE_TYPE="$2"
                shift 2
                ;;
            --pod-subnet)
                POD_SUBNET="$2"
                shift 2
                ;;
            --service-subnet)
                SERVICE_SUBNET="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit $SUCCESS
                ;;
            *)
                log ERROR "未知参数: $1"
                show_help
                exit $ERR_GENERAL
                ;;
        esac
    done
}

# 验证参数
validate_parameters() {
    log INFO "验证安装参数..."
    
    # 验证 Kubernetes 版本格式
    if [[ ! "$K8S_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error_exit "无效的 Kubernetes 版本格式: $K8S_VERSION" $ERR_CONFIG
    fi
    
    # 验证容器运行时
    case $CONTAINER_RUNTIME in
        containerd|docker)
            ;;
        *)
            error_exit "不支持的容器运行时: $CONTAINER_RUNTIME" $ERR_CONFIG
            ;;
    esac
    
    # 验证 CNI 插件
    case $CNI_PLUGIN in
        flannel|calico|weave)
            ;;
        *)
            error_exit "不支持的 CNI 插件: $CNI_PLUGIN" $ERR_CONFIG
            ;;
    esac
    
    # 验证安装模式
    case $INSTALL_MODE in
        single-node|multi-node)
            ;;
        *)
            error_exit "不支持的安装模式: $INSTALL_MODE" $ERR_CONFIG
            ;;
    esac
    
    # 验证节点类型
    case $NODE_TYPE in
        master|worker)
            ;;
        *)
            error_exit "不支持的节点类型: $NODE_TYPE" $ERR_CONFIG
            ;;
    esac
    
    # 多节点模式必须指定主节点 IP
    if [[ "$INSTALL_MODE" == "multi-node" && -z "$MASTER_IP" ]]; then
        error_exit "多节点模式必须指定主节点 IP (--master-ip)" $ERR_CONFIG
    fi
    
    # 验证网络 CIDR 格式
    if [[ ! "$POD_SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error_exit "无效的 Pod 网络 CIDR: $POD_SUBNET" $ERR_CONFIG
    fi
    
    if [[ ! "$SERVICE_SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error_exit "无效的 Service 网络 CIDR: $SERVICE_SUBNET" $ERR_CONFIG
    fi
    
    log INFO "参数验证完成"
}

# 系统准备
prepare_system() {
    log INFO "准备系统环境..."
    
    # 禁用 swap
    log INFO "禁用 swap..."
    execute_command "swapoff -a"
    execute_command "sed -i '/swap/d' /etc/fstab"
    
    # 加载必要的内核模块
    log INFO "加载内核模块..."
    cat << EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF
    
    execute_command "modprobe br_netfilter"
    execute_command "modprobe overlay"
    
    # 配置内核参数
    log INFO "配置内核参数..."
    cat << EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    execute_command "sysctl --system"
    
    # 配置防火墙
    configure_firewall
    
    log INFO "系统环境准备完成"
}

# 配置防火墙
configure_firewall() {
    log INFO "配置防火墙规则..."
    
    # 检测防火墙服务
    if systemctl is-active --quiet firewalld; then
        log INFO "配置 firewalld..."
        
        # Kubernetes Master 节点端口
        if [[ "$NODE_TYPE" == "master" ]]; then
            local master_ports=(
                "6443/tcp"      # kube-apiserver
                "2379-2380/tcp" # etcd
                "10250/tcp"     # kubelet
                "10251/tcp"     # kube-scheduler
                "10252/tcp"     # kube-controller-manager
            )
            
            for port in "${master_ports[@]}"; do
                execute_command "firewall-cmd --permanent --add-port=$port"
            done
        fi
        
        # 所有节点共同端口
        local common_ports=(
            "10250/tcp"     # kubelet
            "30000-32767/tcp" # NodePort 服务
        )
        
        for port in "${common_ports[@]}"; do
            execute_command "firewall-cmd --permanent --add-port=$port"
        done
        
        # CNI 插件特定端口
        case $CNI_PLUGIN in
            flannel)
                execute_command "firewall-cmd --permanent --add-port=8285/udp"
                execute_command "firewall-cmd --permanent --add-port=8472/udp"
                ;;
            calico)
                execute_command "firewall-cmd --permanent --add-port=179/tcp"
                execute_command "firewall-cmd --permanent --add-port=4789/udp"
                ;;
        esac
        
        execute_command "firewall-cmd --reload"
        
    elif systemctl is-active --quiet ufw; then
        log INFO "配置 ufw..."
        
        # 基本端口配置
        execute_command "ufw allow 6443/tcp"
        execute_command "ufw allow 10250/tcp"
        execute_command "ufw allow 30000:32767/tcp"
        
        if [[ "$NODE_TYPE" == "master" ]]; then
            execute_command "ufw allow 2379:2380/tcp"
            execute_command "ufw allow 10251/tcp"
            execute_command "ufw allow 10252/tcp"
        fi
        
    else
        log WARN "未检测到防火墙服务，请手动配置防火墙规则"
    fi
}

# 安装容器运行时
install_container_runtime() {
    log INFO "安装容器运行时: $CONTAINER_RUNTIME"
    
    case $CONTAINER_RUNTIME in
        containerd)
            install_containerd
            ;;
        docker)
            install_docker
            ;;
    esac
}

# 安装 containerd
install_containerd() {
    log INFO "安装 containerd..."
    
    # 检查是否已安装
    if command -v containerd >/dev/null 2>&1; then
        log INFO "containerd 已安装"
        return $SUCCESS
    fi
    
    # 根据系统类型安装
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                install_containerd_ubuntu
                ;;
            centos|rhel|rocky|almalinux)
                install_containerd_rhel
                ;;
            *)
                error_exit "不支持的操作系统: $ID" $ERR_GENERAL
                ;;
        esac
    fi
    
    # 配置 containerd
    configure_containerd
    
    # 启动服务
    execute_command "systemctl enable containerd"
    execute_command "systemctl start containerd"
    
    # 验证安装
    if ! execute_command "containerd --version"; then
        error_exit "containerd 安装失败" $ERR_GENERAL
    fi
    
    log INFO "containerd 安装完成"
}

# Ubuntu/Debian 系统安装 containerd
install_containerd_ubuntu() {
    log INFO "在 Ubuntu/Debian 系统安装 containerd..."
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装依赖
    execute_command "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release"
    
    # 添加 Docker 官方 GPG 密钥
    execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    
    # 添加 Docker 软件源
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装 containerd
    execute_command "apt-get install -y containerd.io"
}

# RHEL/CentOS 系统安装 containerd
install_containerd_rhel() {
    log INFO "在 RHEL/CentOS 系统安装 containerd..."
    
    # 安装依赖
    execute_command "yum install -y yum-utils"
    
    # 添加 Docker 软件源
    execute_command "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
    
    # 安装 containerd
    execute_command "yum install -y containerd.io"
}

# 配置 containerd
configure_containerd() {
    log INFO "配置 containerd..."
    
    # 创建配置目录
    execute_command "mkdir -p /etc/containerd"
    
    # 生成默认配置
    execute_command "containerd config default > $CONTAINERD_CONFIG"
    
    # 配置 systemd cgroup 驱动
    execute_command "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' $CONTAINERD_CONFIG"
    
    # 配置镜像加速器（如果在中国）
    if [[ $(curl -s http://ip-api.com/json | jq -r .country) == "China" ]]; then
        log INFO "配置镜像加速器..."
        
        # 添加镜像加速配置
        cat << 'EOF' >> "$CONTAINERD_CONFIG"

[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://registry.docker-cn.com", "https://docker.mirrors.ustc.edu.cn"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
    endpoint = ["https://registry.aliyuncs.com/k8sxio"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
    endpoint = ["https://gcr.mirrors.ustc.edu.cn"]
EOF
    fi
    
    log INFO "containerd 配置完成"
}

# 安装 Docker
install_docker() {
    log INFO "安装 Docker..."
    
    # 检查是否已安装
    if command -v docker >/dev/null 2>&1; then
        log INFO "Docker 已安装"
        return $SUCCESS
    fi
    
    # 根据系统类型安装
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                install_docker_ubuntu
                ;;
            centos|rhel|rocky|almalinux)
                install_docker_rhel
                ;;
            *)
                error_exit "不支持的操作系统: $ID" $ERR_GENERAL
                ;;
        esac
    fi
    
    # 配置 Docker
    configure_docker
    
    # 启动服务
    execute_command "systemctl enable docker"
    execute_command "systemctl start docker"
    
    # 将当前用户添加到 docker 组
    if [[ $EUID -ne 0 ]]; then
        execute_command "usermod -aG docker $USER"
        log WARN "请重新登录以使 docker 组权限生效"
    fi
    
    # 验证安装
    if ! execute_command "docker --version"; then
        error_exit "Docker 安装失败" $ERR_GENERAL
    fi
    
    log INFO "Docker 安装完成"
}

# Ubuntu/Debian 系统安装 Docker
install_docker_ubuntu() {
    log INFO "在 Ubuntu/Debian 系统安装 Docker..."
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装依赖
    execute_command "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release"
    
    # 添加 Docker 官方 GPG 密钥
    execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    
    # 添加 Docker 软件源
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装 Docker
    execute_command "apt-get install -y docker-ce docker-ce-cli containerd.io"
}

# RHEL/CentOS 系统安装 Docker
install_docker_rhel() {
    log INFO "在 RHEL/CentOS 系统安装 Docker..."
    
    # 安装依赖
    execute_command "yum install -y yum-utils"
    
    # 添加 Docker 软件源
    execute_command "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
    
    # 安装 Docker
    execute_command "yum install -y docker-ce docker-ce-cli containerd.io"
}

# 配置 Docker
configure_docker() {
    log INFO "配置 Docker..."
    
    # 创建配置目录
    execute_command "mkdir -p /etc/docker"
    
    # 创建 Docker daemon 配置
    cat << EOF > "$DOCKER_DAEMON_CONFIG"
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    
    # 如果在中国，添加镜像加速器
    if [[ $(curl -s http://ip-api.com/json | jq -r .country) == "China" ]]; then
        log INFO "配置 Docker 镜像加速器..."
        
        # 更新配置添加镜像加速器
        cat << EOF > "$DOCKER_DAEMON_CONFIG"
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "registry-mirrors": [
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ]
}
EOF
    fi
    
    log INFO "Docker 配置完成"
}

# 安装 Kubernetes 组件
install_kubernetes() {
    log INFO "安装 Kubernetes 组件..."
    
    # 根据系统类型安装
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                install_kubernetes_ubuntu
                ;;
            centos|rhel|rocky|almalinux)
                install_kubernetes_rhel
                ;;
            *)
                error_exit "不支持的操作系统: $ID" $ERR_GENERAL
                ;;
        esac
    fi
    
    # 锁定版本，防止自动更新
    hold_kubernetes_packages
    
    log INFO "Kubernetes 组件安装完成"
}

# Ubuntu/Debian 系统安装 Kubernetes
install_kubernetes_ubuntu() {
    log INFO "在 Ubuntu/Debian 系统安装 Kubernetes..."
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装依赖
    execute_command "apt-get install -y apt-transport-https ca-certificates curl"
    
    # 添加 Kubernetes 官方 GPG 密钥
    execute_command "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
    
    # 添加 Kubernetes 软件源
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    
    # 更新包列表
    execute_command "apt-get update"
    
    # 安装指定版本的 Kubernetes 组件
    local k8s_package_version="${K8S_VERSION}-00"
    execute_command "apt-get install -y kubelet=$k8s_package_version kubeadm=$k8s_package_version kubectl=$k8s_package_version"
    
    # 启用 kubelet 服务
    execute_command "systemctl enable kubelet"
}

# RHEL/CentOS 系统安装 Kubernetes
install_kubernetes_rhel() {
    log INFO "在 RHEL/CentOS 系统安装 Kubernetes..."
    
    # 添加 Kubernetes 软件源
    cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
    
    # 安装指定版本的 Kubernetes 组件
    execute_command "yum install -y kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION"
    
    # 启用 kubelet 服务
    execute_command "systemctl enable kubelet"
}

# 锁定 Kubernetes 包版本
hold_kubernetes_packages() {
    log INFO "锁定 Kubernetes 包版本..."
    
    if command -v apt-mark >/dev/null 2>&1; then
        execute_command "apt-mark hold kubelet kubeadm kubectl"
    elif command -v yum >/dev/null 2>&1; then
        execute_command "yum versionlock add kubelet kubeadm kubectl"
    fi
}

# 初始化 Kubernetes 集群
initialize_cluster() {
    log INFO "初始化 Kubernetes 集群..."
    
    case $INSTALL_MODE in
        single-node)
            initialize_single_node
            ;;
        multi-node)
            case $NODE_TYPE in
                master)
                    initialize_master_node
                    ;;
                worker)
                    join_worker_node
                    ;;
            esac
            ;;
    esac
}

# 初始化单节点集群
initialize_single_node() {
    log INFO "初始化单节点集群..."
    
    # 生成 kubeadm 配置文件
    generate_kubeadm_config
    
    # 初始化集群
    execute_command "kubeadm init --config=$KUBEADM_CONFIG"
    
    # 配置 kubectl
    setup_kubectl
    
    # 移除主节点污点，允许调度 Pod
    execute_command "kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
    
    # 安装 CNI 插件
    install_cni_plugin
    
    log INFO "单节点集群初始化完成"
}

# 初始化主节点
initialize_master_node() {
    log INFO "初始化主节点..."
    
    # 生成 kubeadm 配置文件
    generate_kubeadm_config
    
    # 初始化集群
    execute_command "kubeadm init --config=$KUBEADM_CONFIG"
    
    # 配置 kubectl
    setup_kubectl
    
    # 安装 CNI 插件
    install_cni_plugin
    
    # 生成加入集群的命令
    generate_join_command
    
    log INFO "主节点初始化完成"
}

# 工作节点加入集群
join_worker_node() {
    log INFO "工作节点加入集群..."
    
    # 这里需要从主节点获取 join 命令
    # 在实际部署中，可以通过共享存储或其他方式获取
    local join_command_file="/tmp/kubeadm-join-command"
    
    if [[ -f "$join_command_file" ]]; then
        log INFO "执行加入集群命令..."
        execute_command "$(cat $join_command_file)"
    else
        log ERROR "未找到加入集群的命令文件: $join_command_file"
        log INFO "请从主节点执行以下命令获取加入命令:"
        log INFO "kubeadm token create --print-join-command"
        error_exit "工作节点加入集群失败" $ERR_CONFIG
    fi
    
    log INFO "工作节点加入集群完成"
}

# 生成 kubeadm 配置文件
generate_kubeadm_config() {
    log INFO "生成 kubeadm 配置文件..."
    
    local api_server_ip
    if [[ "$INSTALL_MODE" == "multi-node" ]]; then
        api_server_ip="$MASTER_IP"
    else
        api_server_ip=$(hostname -I | awk '{print $1}')
    fi
    
    cat << EOF > "$KUBEADM_CONFIG"
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $api_server_ip
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v$K8S_VERSION
clusterName: $CLUSTER_NAME
controlPlaneEndpoint: $api_server_ip:6443
networking:
  serviceSubnet: $SERVICE_SUBNET
  podSubnet: $POD_SUBNET
  dnsDomain: cluster.local
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
    
    TEMP_FILES+=("$KUBEADM_CONFIG")
    log INFO "kubeadm 配置文件生成完成: $KUBEADM_CONFIG"
}

# 配置 kubectl
setup_kubectl() {
    log INFO "配置 kubectl..."
    
    # 为 root 用户配置
    execute_command "mkdir -p /root/.kube"
    execute_command "cp -i /etc/kubernetes/admin.conf /root/.kube/config"
    execute_command "chown root:root /root/.kube/config"
    
    # 为当前用户配置（如果不是 root）
    if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
        local user_home=$(eval echo ~$SUDO_USER)
        execute_command "mkdir -p $user_home/.kube"
        execute_command "cp -i /etc/kubernetes/admin.conf $user_home/.kube/config"
        execute_command "chown $SUDO_USER:$SUDO_USER $user_home/.kube/config"
    fi
    
    log INFO "kubectl 配置完成"
}

# 安装 CNI 插件
install_cni_plugin() {
    log INFO "安装 CNI 插件: $CNI_PLUGIN"
    
    case $CNI_PLUGIN in
        flannel)
            install_flannel
            ;;
        calico)
            install_calico
            ;;
        weave)
            install_weave
            ;;
    esac
    
    # 等待 CNI 插件就绪
    wait_for_cni_ready
}

# 安装 Flannel CNI
install_flannel() {
    log INFO "安装 Flannel CNI..."
    
    local flannel_yaml="/tmp/flannel.yaml"
    download_file "https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml" "$flannel_yaml" "Flannel YAML"
    
    # 修改 Pod CIDR（如果需要）
    if [[ "$POD_SUBNET" != "10.244.0.0/16" ]]; then
        execute_command "sed -i 's|10.244.0.0/16|$POD_SUBNET|g' $flannel_yaml"
    fi
    
    execute_command "kubectl apply -f $flannel_yaml"
    TEMP_FILES+=("$flannel_yaml")
    
    log INFO "Flannel CNI 安装完成"
}

# 安装 Calico CNI
install_calico() {
    log INFO "安装 Calico CNI..."
    
    local calico_yaml="/tmp/calico.yaml"
    download_file "https://raw.githubusercontent.com/projectcalico/calico/master/manifests/tigera-operator.yaml" "$calico_yaml" "Calico Operator"
    
    execute_command "kubectl apply -f $calico_yaml"
    
    # 创建 Calico 配置
    local calico_config="/tmp/calico-config.yaml"
    cat << EOF > "$calico_config"
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: $POD_SUBNET
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
    
    execute_command "kubectl apply -f $calico_config"
    TEMP_FILES+=("$calico_yaml" "$calico_config")
    
    log INFO "Calico CNI 安装完成"
}

# 安装 Weave CNI
install_weave() {
    log INFO "安装 Weave CNI..."
    
    local weave_yaml="/tmp/weave.yaml"
    download_file "https://cloud.weave.works/k8s/net?k8s-version=1.28.0&env.IPALLOC_RANGE=$POD_SUBNET" "$weave_yaml" "Weave Net"
    
    execute_command "kubectl apply -f $weave_yaml"
    TEMP_FILES+=("$weave_yaml")
    
    log INFO "Weave CNI 安装完成"
}

# 等待 CNI 就绪
wait_for_cni_ready() {
    log INFO "等待 CNI 插件就绪..."
    
    local timeout=300
    local interval=10
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
        local total_nodes=$(kubectl get nodes --no-headers | wc -l)
        
        if [[ $ready_nodes -eq $total_nodes ]]; then
            log INFO "所有节点已就绪"
            return $SUCCESS
        fi
        
        log DEBUG "等待节点就绪: $ready_nodes/$total_nodes (已等待 ${elapsed}s)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    log WARN "CNI 插件启动超时，请检查网络配置"
    return $ERR_GENERAL
}

# 生成加入集群的命令
generate_join_command() {
    log INFO "生成加入集群的命令..."
    
    local join_command_file="/tmp/kubeadm-join-command"
    execute_command "kubeadm token create --print-join-command > $join_command_file"
    
    log INFO "加入集群的命令已保存到: $join_command_file"
    log INFO "在工作节点执行以下命令加入集群:"
    cat "$join_command_file"
}

# 验证安装
verify_installation() {
    log INFO "验证 Kubernetes 安装..."
    
    # 检查集群状态
    log INFO "检查集群状态..."
    execute_command "kubectl cluster-info"
    
    # 检查节点状态
    log INFO "检查节点状态..."
    execute_command "kubectl get nodes -o wide"
    
    # 检查系统 Pod 状态
    log INFO "检查系统 Pod 状态..."
    execute_command "kubectl get pods -n kube-system"
    
    # 运行简单测试
    run_basic_test
    
    log INFO "Kubernetes 安装验证完成"
}

# 运行基础测试
run_basic_test() {
    log INFO "运行基础功能测试..."
    
    # 创建测试命名空间
    execute_command "kubectl create namespace test-k8s || true"
    
    # 部署测试 Pod
    local test_pod="/tmp/test-pod.yaml"
    cat << EOF > "$test_pod"
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-k8s
spec:
  containers:
  - name: test-container
    image: nginx:alpine
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF
    
    execute_command "kubectl apply -f $test_pod"
    TEMP_FILES+=("$test_pod")
    
    # 等待 Pod 运行
    log INFO "等待测试 Pod 运行..."
    execute_command "kubectl wait --for=condition=Ready pod/test-pod -n test-k8s --timeout=60s"
    
    # 检查 Pod 状态
    execute_command "kubectl get pod test-pod -n test-k8s"
    
    # 清理测试资源
    execute_command "kubectl delete namespace test-k8s"
    
    log INFO "基础功能测试完成"
}

# 显示安装总结
show_summary() {
    log INFO "Kubernetes 安装总结"
    
    cat << EOF

🎉 Kubernetes 集群安装完成！

安装信息:
  - Kubernetes 版本: $K8S_VERSION
  - 容器运行时: $CONTAINER_RUNTIME
  - CNI 插件: $CNI_PLUGIN
  - 安装模式: $INSTALL_MODE
  - 节点类型: $NODE_TYPE
  - Pod 网络: $POD_SUBNET
  - Service 网络: $SERVICE_SUBNET

常用命令:
  # 查看集群状态
  kubectl cluster-info
  
  # 查看节点状态
  kubectl get nodes
  
  # 查看系统 Pod
  kubectl get pods -n kube-system
  
  # 部署应用示例
  kubectl create deployment nginx --image=nginx
  kubectl expose deployment nginx --port=80 --type=NodePort

配置文件位置:
  - kubectl 配置: ~/.kube/config
  - kubeadm 配置: /etc/kubernetes/
  - 容器运行时配置: $CONTAINERD_CONFIG

日志文件: $LOG_FILE

EOF

    if [[ "$INSTALL_MODE" == "multi-node" && "$NODE_TYPE" == "master" ]]; then
        log INFO "主节点初始化完成，工作节点可以使用以下命令加入集群:"
        cat /tmp/kubeadm-join-command 2>/dev/null || log WARN "加入命令文件不存在"
    fi
}

# 主函数
main() {
    log INFO "开始 Kubernetes 安装..."
    
    # 解析参数
    parse_arguments "$@"
    
    # 验证参数
    validate_parameters
    
    # 系统检查
    check_system
    check_dependencies
    
    # 准备系统
    prepare_system
    
    # 安装容器运行时
    install_container_runtime
    
    # 安装 Kubernetes 组件
    install_kubernetes
    
    # 初始化集群
    initialize_cluster
    
    # 验证安装
    verify_installation
    
    # 显示总结
    show_summary
    
    log INFO "Kubernetes 安装完成！"
}

# 执行主函数
main "$@"
