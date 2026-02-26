#!/bin/bash

# ==============================================================================
#  Orion/Scorpio 环境强制重置脚本
#  在使用前，请确保您位于 orion-runner 目录下
# ==============================================================================

set -ex # 如果命令失败，则停止执行

SCORPIO_TOML="scorpio.toml"

read_scorpio_path() {
    local key="$1"
    local file="$2"
    if [ -f "$file" ]; then
        awk -F'"' -v k="$key" '$1 ~ "^"k"[[:space:]]*=" {print $2; exit}' "$file"
    fi
}

echo "==> [1/5] 检查当前目录..."
if [ ! -f "orion" ] || [ ! -f "scorpio" ]; then
    echo "错误：未找到 orion 或 scorpio 程序。"
    echo "请确保您在 orion-runner 目录下执行此脚本。"
    exit 1
fi
echo "当前目录正确。"

echo "==> [2/5] 停止所有相关进程..."
# 使用 buck2 killall (如果存在)
if command -v buck2 &> /dev/null; then
    echo "  - 正在执行 'buck2 killall'..."
    buck2 killall || echo "  - 'buck2 killall' 执行完毕或没有进程可杀。"
else
    echo "  - 'buck2' 命令未找到，跳过。"
fi
# 额外使用 pkill 确保 orion 和 scorpio 被终止
pkill -f "./orion" || echo "  - 没有找到 orion 进程。"
pkill -f "./scorpio" || echo "  - 没有找到 scorpio 进程。"
echo "所有相关进程已停止。"

echo "==> [3/5] 强制卸载 FUSE 挂载点..."
MOUNT_DIR="$(read_scorpio_path "workspace" "${SCORPIO_TOML}")"
MOUNT_DIR="${MOUNT_DIR:-/tmp/megadir/mount}"
    echo "  - 正在卸载 ${MOUNT_DIR}..."
    # 优先使用 fusermount，它是处理 FUSE 的最佳工具
    fusermount -u "${MOUNT_DIR}" || umount -l "${MOUNT_DIR}" || umount -f "${MOUNT_DIR}" ||echo "  - 卸载可能未完全成功，将继续执行清理。"
# 若已卸载，则删除并重建目录，解决 "Transport endpoint" 问题
echo "  - 正在清理并重建挂载目录..."
if mountpoint -q "${MOUNT_DIR}"; then
    echo "  - ${MOUNT_DIR} 仍是挂载点，跳过删除目录。"
else
    rm -rf "${MOUNT_DIR}" || true
    mkdir -p "${MOUNT_DIR}"
fi
echo "挂载点已清理。"

echo "==> [4/5] 清理 store 目录并重置 config.toml..."
CONFIG_FILE="config.toml"
STORE_DIR="$(read_scorpio_path "store_path" "${SCORPIO_TOML}")"
STORE_DIR="${STORE_DIR:-/tmp/megadir/store}"

# 从 config.toml 读取需要删除的 hash 目录
if [ -f "${CONFIG_FILE}" ]; then
    hashes=$(grep 'hash =' "${CONFIG_FILE}" | awk -F'"' '{print $2}')
    if [ -n "${hashes}" ]; then
        for hash in $hashes; do
            dir_to_delete="${STORE_DIR}/${hash}"
            if [ -d "${dir_to_delete}" ]; then
                echo "  - 删除 work 目录: ${dir_to_delete}"
                rm -rf "${dir_to_delete}"
            fi
        done
    else
        echo "  - config.toml 中没有找到 work 记录。"
    fi
else
    echo "  - 未找到 ${CONFIG_FILE}，跳过 work 目录清理。"
fi

# 重置 config.toml
echo "  - 正在重置 ${CONFIG_FILE}..."
echo "works = []" > "${CONFIG_FILE}"
echo "配置已重置。"


echo "==> [5/5] 清理完成！"
echo "环境已重置为干净状态。"
chmod +x ./orion ./scorpio

LOG_DIR=/home/orion/orion-runner/log
ORION_LOG="${LOG_DIR}/orion.log"
SCORPIO_LOG="${LOG_DIR}/scorpio.log"

mkdir -p "${LOG_DIR}"
touch "${ORION_LOG}" "${SCORPIO_LOG}"

SCORPIO_PID=""
cleanup() {
    set +e
    if [ -n "${SCORPIO_PID}" ] && kill -0 "${SCORPIO_PID}" 2>/dev/null; then
        kill "${SCORPIO_PID}" 2>/dev/null
        wait "${SCORPIO_PID}" 2>/dev/null
    fi
}
trap cleanup INT TERM EXIT

echo "==> 启动 scorpio（日志: ${SCORPIO_LOG}）..."
./scorpio >>"${SCORPIO_LOG}" 2>&1 &
SCORPIO_PID=$!

echo "==> 启动 orion（日志: ${ORION_LOG}）..."
./orion >>"${ORION_LOG}" 2>&1
