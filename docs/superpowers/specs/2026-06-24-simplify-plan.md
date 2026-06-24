# env-build 简化重构实施计划

**日期**: 2026-06-24
**设计文档**: `docs/superpowers/specs/2026-06-24-simplify-design.md`
**目标**: 将 env-build 项目从 11+ 个脚本简化为 1 个 setup.sh

---

## 实施阶段

### 阶段一：创建新的 setup.sh（核心工作）

**目标**: 合并所有脚本逻辑到单一 setup.sh

**步骤**:
1. 创建 `setup.sh` 文件
2. 实现公共函数（log, error, install_apt_packages, safe_git_clone, add_to_zshrc, create_config_file）
3. 实现 Root 阶段函数（install_system_deps, create_user, install_docker, setup_wsl_config）
4. 实现 User 阶段函数（setup_oh_my_zsh, setup_toolchain, setup_vim）
5. 实现主逻辑（main 函数，通过 id -u 判断阶段）

**验证**:
- 语法检查: `bash -n setup.sh`
- 逻辑检查: 确保所有旧脚本的功能都被覆盖

### 阶段二：更新 Dockerfile

**目标**: 简化为两个构建目标

**步骤**:
1. 重写 Dockerfile，使用新的 setup.sh
2. 保留 ubuntu-dev 和 ubuntu-wsl 两个构建目标
3. 移除 code-server 构建目标
4. 确保 IMAGE_VARIANT 环境变量正确传递

**验证**:
- 构建测试: `docker build --target ubuntu-dev -t ubuntu-dev:latest .`
- 构建测试: `docker build --target ubuntu-wsl -t ubuntu-wsl:latest .`

### 阶段三：更新 CI/CD 工作流

**目标**: 合并为单一工作流

**步骤**:
1. 更新 `.github/workflows/docker-images.yaml`
2. 合并 WSL 导出功能到主工作流
3. 删除旧的工作流文件

**验证**:
- 工作流语法检查
- 测试触发工作流

### 阶段四：删除旧文件

**目标**: 清理不再需要的文件

**删除文件**:
- `scripts/orchestration/root-setup.sh`
- `scripts/orchestration/user-setup.sh`
- `scripts/installation/01-system-deps.sh`
- `scripts/installation/02-docker-cli-setup.sh`
- `scripts/installation/02-docker-engine-setup.sh`
- `scripts/installation/03-user-config.sh`
- `scripts/installation/04-oh-my-zsh-setup.sh`
- `scripts/installation/05-toolchain-setup.sh`
- `scripts/installation/06-vimrc.sh`
- `scripts/installation/07-code-server.sh`
- `scripts/configs/common.sh`
- `scripts/configs/variables.sh`
- `scripts/configs/start-services.sh`
- `scripts/configs/wsl.conf`
- `scripts/build-images.sh`
- `scripts/export-wsl.sh`
- `.github/workflows/wsl-export.yml`
- `.github/workflows/sync-docker-image-with-skopeo.yml`
- `.github/workflows/sync-docker-image-with-manifest.yml`

**验证**:
- 确认所有旧文件已删除
- 确认新文件正常工作

### 阶段五：更新文档

**目标**: 更新 README.md 和 CLAUDE.md

**步骤**:
1. 更新 README.md，简化使用说明
2. 更新 CLAUDE.md，更新架构说明
3. 提交所有更改

**验证**:
- 文档准确性检查
- Git 提交检查

---

## 关键检查点

### 检查点 1: setup.sh 完成
- [ ] 文件创建完成
- [ ] 所有函数实现完成
- [ ] 语法检查通过
- [ ] 逻辑覆盖所有旧脚本功能

### 检查点 2: Dockerfile 更新完成
- [ ] 两个构建目标实现
- [ ] 本地构建测试通过
- [ ] 镜像功能验证通过

### 检查点 3: CI/CD 更新完成
- [ ] 工作流合并完成
- [ ] 旧工作流删除
- [ ] 工作流语法检查通过

### 检查点 4: 文件清理完成
- [ ] 所有旧文件删除
- [ ] 新文件正常工作
- [ ] 无遗漏文件

### 检查点 5: 文档更新完成
- [ ] README.md 更新
- [ ] CLAUDE.md 更新
- [ ] Git 提交完成

---

## 风险缓解

### 风险 1: 功能遗漏
**缓解**: 逐个对比旧脚本和新 setup.sh 的功能

### 风险 2: 构建失败
**缓解**: 每个阶段完成后进行构建测试

### 风险 3: CI/CD 工作流失败
**缓解**: 工作流更新后进行语法检查和测试触发

---

## 预计时间

- 阶段一: 30-45 分钟
- 阶段二: 15-20 分钟
- 阶段三: 20-30 分钟
- 阶段四: 10-15 分钟
- 阶段五: 15-20 分钟

**总计**: 90-130 分钟

---

## 开始实施

准备就绪后，告诉我开始实施阶段一。
