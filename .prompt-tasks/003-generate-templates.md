# 任务：生成模板集合

## 目标
为指定的技术栈/项目创建配置模板集合，包括配置文件模板、部署模板、监控模板等可复用的模板文件，帮助用户快速搭建标准化环境，确保配置的一致性和最佳实践的执行。

## 任务执行要求

### 1. 目录结构
```
{project}/templates/
├── README.md                     # 模板总览和使用说明
├── configuration/                # 配置文件模板
│   ├── {component}-config.yaml
│   └── README.md
├── deployment/                   # 部署模板
│   ├── kubernetes/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── docker/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   └── terraform/
│       ├── main.tf
│       └── variables.tf
├── monitoring/                   # 监控模板
│   ├── prometheus/
│   │   ├── prometheus.yaml
│   │   └── alerting-rules.yaml
│   └── grafana/
│       └── dashboard.json
├── security/                     # 安全配置模板
│   ├── rbac/
│   │   ├── role.yaml
│   │   └── rolebinding.yaml
│   └── network-policy/
│       └── network-policy.yaml
└── ci-cd/                        # CI/CD模板
    ├── github-actions/
    │   └── ci.yml
    └── gitlab-ci/
        └── .gitlab-ci.yml
```

### 2. README.md 必须包含的内容结构

#### 2.1 模板集合概述
- **模板分类**：按功能和使用场景对模板进行分类
- **参数化机制**：模板变量和参数替换机制
- **使用指南**：模板使用的基本流程和注意事项

#### 2.2 模板功能矩阵
创建模板功能索引表格，包含：
- 模板名称
- 模板类型（配置/部署/监控/安全）
- 技术栈（Kubernetes/Docker/Terraform等）
- 适用场景（开发/测试/生产）
- 参数数量

#### 2.3 关键模板场景
- **快速启动**：新项目或新环境的快速搭建
- **标准化部署**：生产环境的标准化部署配置
- **环境一致性**：确保不同环境配置的一致性

### 3. 模板标准规范

#### 3.1 配置文件模板
```yaml
# Template: {component}-config.yaml
# Description: {component} 服务配置模板
# Parameters: [参数列表]

metadata:
  name: "{{ SERVICE_NAME | default('my-service') }}"
  namespace: "{{ NAMESPACE | default('default') }}"
  labels:
    app: "{{ APP_LABEL | default('my-app') }}"
    environment: "{{ ENVIRONMENT | default('development') }}"

spec:
  replicas: {{ REPLICAS | default(3) }}
  selector:
    matchLabels:
      app: "{{ APP_LABEL | default('my-app') }}"
```

#### 3.2 Kubernetes部署模板
```yaml
# Template: deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ APP_NAME }}
  namespace: {{ NAMESPACE | default('default') }}
spec:
  replicas: {{ REPLICAS | default(3) }}
  selector:
    matchLabels:
      app: {{ APP_NAME }}
  template:
    metadata:
      labels:
        app: {{ APP_NAME }}
    spec:
      containers:
      - name: {{ CONTAINER_NAME | default(APP_NAME) }}
        image: {{ IMAGE_REPOSITORY }}/{{ IMAGE_NAME }}:{{ IMAGE_TAG }}
        ports:
        - containerPort: {{ CONTAINER_PORT | default(8080) }}
        resources:
          requests:
            memory: {{ MEMORY_REQUEST | default('256Mi') }}
            cpu: {{ CPU_REQUEST | default('250m') }}
          limits:
            memory: {{ MEMORY_LIMIT | default('512Mi') }}
            cpu: {{ CPU_LIMIT | default('500m') }}
```

#### 3.3 Docker模板
```dockerfile
# Template: Dockerfile
FROM {{ BASE_IMAGE | default('openjdk:11-jre-slim') }}
WORKDIR /app
COPY {{ JAR_FILE | default('app.jar') }} app.jar
EXPOSE {{ CONTAINER_PORT | default(8080) }}
ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### 3.4 监控模板
```yaml
# Template: prometheus.yaml
global:
  scrape_interval: {{ SCRAPE_INTERVAL | default('15s') }}

scrape_configs:
  - job_name: '{{ APP_NAME }}'
    static_configs:
      - targets: ['{{ APP_HOST }}:{{ APP_PORT }}']
```

### 4. 质量要求

#### 4.1 标准化要求
- **格式统一**：模板文件格式和结构的统一性
- **参数规范**：参数命名和使用的规范性
- **文档完善**：详细的模板说明和使用文档
- **配置项说明**：每个配置项都必须有详细的说明和作用描述

#### 4.2 可复用性要求
- **参数化设计**：高度参数化和可配置
- **模块化结构**：模块化设计和组合使用
- **场景适配**：适配不同使用场景和环境

#### 4.3 配置项文档要求
- **参数说明**：每个模板参数都必须包含详细说明
- **作用描述**：明确说明每个配置项的具体作用和影响范围
- **默认值说明**：为每个配置项提供合理的默认值并说明选择原因
- **使用示例**：提供配置项的使用示例和最佳实践

### 5. 执行步骤

1. **需求分析**：分析目标技术栈的模板需求和使用场景
2. **模板设计**：设计模板的结构、参数和功能特性
3. **模板开发**：按标准开发各类模板文件
4. **参数化处理**：实现模板的参数化和配置机制
5. **测试验证**：在不同场景下测试模板的有效性
6. **文档编写**：编写详细的模板使用文档

### 6. 输出验证

完成后的模板集合应能够：
- 提供完整的配置和部署模板覆盖
- 支持快速的环境搭建和配置生成
- 确保配置的标准化和一致性
- 实现最佳实践的模板化固化
- 提高开发和运维效率

## 适用范围

此任务模板适用于需要模板化支持的各种技术和场景，包括：
- 应用服务的配置和部署模板
- 基础设施的自动化部署模板
- 监控和告警系统的配置模板
- CI/CD流水线的标准化模板
- 微服务架构的标准化模板
