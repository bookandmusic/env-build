#!/bin/bash
set -eo pipefail

# 环境变量默认值
IMAGE_VARIANT="${IMAGE_VARIANT:-ubuntu-dev}"
DOCKER_MODE="${DOCKER_MODE:-cli-only}"
INSTALL_CODE_SERVER="${INSTALL_CODE_SERVER:-false}"
CONFIG_USER="${CONFIG_USER:-true}"
WSL_CONFIG="${WSL_CONFIG:-false}"

# 向后兼容：INSTALL_DOCKER 映射到 DOCKER_MODE
if [ -n "${INSTALL_DOCKER:-}" ]; then
    if [ "${INSTALL_DOCKER}" = "true" ]; then
        DOCKER_MODE="full"
    else
        DOCKER_MODE="none"
    fi
fi

# 环境变量验证函数
validate_environment_variables() {
    local errors=()
    
    if [[ ! "${IMAGE_VARIANT}" =~ ^(code-server|ubuntu-dev|ubuntu-wsl)$ ]]; then
        errors+=("IMAGE_VARIANT must be 'code-server', 'ubuntu-dev', or 'ubuntu-wsl', got '${IMAGE_VARIANT}'")
    fi
    
    if [[ ! "${DOCKER_MODE}" =~ ^(none|cli-only|full)$ ]]; then
        errors+=("DOCKER_MODE must be 'none', 'cli-only', or 'full', got '${DOCKER_MODE}'")
    fi
    
    if [[ ! "${INSTALL_CODE_SERVER}" =~ ^(true|false)$ ]]; then
        errors+=("INSTALL_CODE_SERVER must be 'true' or 'false', got '${INSTALL_CODE_SERVER}'")
    fi
    
    if [[ ! "${CONFIG_USER}" =~ ^(true|false)$ ]]; then
        errors+=("CONFIG_USER must be 'true' or 'false', got '${CONFIG_USER}'")
    fi
    
    if [[ ! "${WSL_CONFIG}" =~ ^(true|false)$ ]]; then
        errors+=("WSL_CONFIG must be 'true' or 'false', got '${WSL_CONFIG}'")
    fi
    
    if [ ${#errors[@]} -gt 0 ]; then
        error "Environment variable validation failed: ${errors[*]}"
    fi
    
    log "Environment variables validated successfully"
    log "IMAGE_VARIANT=${IMAGE_VARIANT}, DOCKER_MODE=${DOCKER_MODE}"
}

check_disk_space() {
    local required_space_gb=5
    local available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [ "$available_space" -lt "$required_space_gb" ]; then
        error "Insufficient disk space. Required: ${required_space_gb}GB, Available: ${available_space}GB"
    fi
}

run_preflight_checks() {
    log "Running pre-flight checks..."
    check_disk_space
    validate_environment_variables
    log "Pre-flight checks passed"
}