# Cloud Study 云原生学习项目

本项目是一个全面的云原生技术学习和实践资源库，包含 Kubernetes、服务网格、容器等核心组件的配置、安装脚本和最佳实践。

## 📁 项目结构

```
cloud-study/
├── README.md          # 项目主文档
├── cicd/              # CI/CD 相关配置和工具
├── docker/            # Docker 相关配置和脚本
├── istio/             # Istio 服务网格相关配置
└── kind/              # Kind (Kubernetes in Docker) 相关配置
```

## 🚀 快速开始

### 前置条件

- Docker Desktop 或 Docker Engine
- Git（用于克隆项目）

### 基本工作流程

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd cloud-study
   ```

2. **安装 Kind**
   ```bash
   # Linux/macOS
   cd kind/scripts && chmod +x install-kind.sh && ./install-kind.sh
   
   # Windows
   cd kind/scripts && install-kind.bat
   ```

3. **创建 Kubernetes 集群**
   ```bash
   kind create cluster --config=kind/templates/kind-single-node.yaml
   ```

4. **验证集群**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

## 📦 组件说明

- **Kind**: 本地 Kubernetes 集群，用于学习和开发
- **Istio**: 服务网格，提供流量管理、安全、可观测性
- **Docker**: 容器平台，应用构建和运行
- **CI/CD**: 持续集成交付工具（Argo、Tekton）

## 🎯 学习路径

1. **容器基础** → Docker 容器概念
2. **Kind 集群** → 创建 Kubernetes 集群
3. **应用部署** → 部署应用到集群
4. **服务网格** → 安装配置 Istio
5. **CI/CD 集成** → 持续集成和部署

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

---

**祝您云原生学习之旅愉快！** 🎉
