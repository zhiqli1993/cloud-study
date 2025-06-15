# 任务：生成官方示例集合

## 目标
为指定的技术栈/项目创建官方示例（demo/examples）的快速获取、部署和执行方案，提供自动化脚本实现一键式的示例环境搭建和运行，帮助用户快速体验和学习技术特性。

## 任务执行要求

### 1. 目录结构
```
{project}/examples/
├── README.md                     # 示例总览和使用说明
├── scripts/                      # 自动化脚本
│   ├── fetch-examples.sh         # 获取官方示例脚本
│   ├── deploy-examples.sh        # 部署示例脚本
│   ├── run-examples.sh           # 运行示例脚本
│   ├── cleanup-examples.sh       # 清理示例脚本
│   └── common-functions.sh       # 公共函数库
├── official/                     # 官方示例存放目录
│   ├── basic/                    # 基础示例
│   ├── advanced/                 # 高级示例
│   └── integration/              # 集成示例
└── configs/                      # 配置文件
    └── examples-list.yaml        # 示例列表配置
```

### 2. README.md 标准内容

#### 2.1 快速开始指南
```markdown
# 官方示例集合

## 一键体验
```bash
# 获取所有官方示例
./scripts/fetch-examples.sh

# 部署示例环境
./scripts/deploy-examples.sh

# 运行指定示例
./scripts/run-examples.sh bookinfo

# 清理环境
./scripts/cleanup-examples.sh
```

## 支持的示例
| 示例名称 | 类型 | 说明 | 运行时间 |
|---------|------|------|---------|
| bookinfo | 微服务 | 图书信息应用 | 5分钟 |
| httpbin | 网络测试 | HTTP测试服务 | 2分钟 |
| helloworld | 基础 | Hello World应用 | 1分钟 |
```

#### 2.2 示例配置格式
```yaml
# configs/examples-list.yaml
examples:
  - name: bookinfo
    type: microservice
    source:
      url: "https://github.com/istio/istio.git"
      path: "samples/bookinfo"
    requirements:
      cpu: "2"
      memory: "4Gi"
```

### 3. 核心脚本规范

#### 3.1 获取脚本功能
- 从官方仓库自动获取示例代码
- 支持Git克隆和文件下载
- 验证示例完整性
- 组织示例目录结构

#### 3.2 部署脚本功能
- 检查Kubernetes集群连接
- 自动创建命名空间
- 应用示例配置文件
- 等待部署完成并验证

#### 3.3 运行脚本功能
- 启动和测试示例
- 配置端口转发
- 显示访问信息
- 查看日志和状态

#### 3.4 清理脚本功能
- 删除示例资源
- 清理命名空间
- 停止端口转发
- 重置环境状态

### 4. 质量要求

#### 4.1 自动化程度
- **一键执行**：所有操作都支持一键执行
- **错误处理**：完善的错误检查和提示
- **环境检测**：自动检测和准备运行环境

#### 4.2 用户体验
- **快速上手**：5分钟内可完成示例部署
- **清晰输出**：友好的命令行输出和提示
- **文档完整**：详细的使用说明和示例

### 5. 执行步骤

1. **环境准备**：检查运行环境和依赖工具
2. **示例获取**：从官方仓库获取最新示例代码
3. **自动部署**：一键部署示例到Kubernetes集群
4. **功能验证**：自动测试示例功能和可用性
5. **访问配置**：配置端口转发和访问方式
6. **清理环境**：提供完整的清理和重置功能

### 6. 输出验证

完成后的示例集合应能够：
- 快速获取和部署官方示例
- 提供一键式的示例体验环境
- 支持多平台的自动化脚本执行
- 实现示例的完整生命周期管理
- 确保示例的可用性和稳定性

## 适用范围

此任务模板适用于需要快速体验官方示例的各种技术栈，包括：
- Kubernetes和云原生技术示例
- 微服务架构和服务网格示例
- 分布式系统和中间件示例
- 开发框架和工具链示例
- 任何提供官方demo/examples的开源项目
