#!/bin/bash

set -e

echo "======================================="
echo " NVIDIA CUDA 13 설치"
echo "======================================="

# Ubuntu 버전 확인
VERSION=$(lsb_release -rs)

case "$VERSION" in
    22.04)
        CUDA_REPO="ubuntu2204"
        CUDA_PACKAGE="cuda-toolkit-13-0"
        CUDA_PATH="/usr/local/cuda-13.0"
        ;;
    24.04)
        CUDA_REPO="ubuntu2404"
        CUDA_PACKAGE="cuda-toolkit-13-0"
        CUDA_PATH="/usr/local/cuda-13.0"
        ;;
    26.04)
        CUDA_REPO="ubuntu2604"
        CUDA_PACKAGE="cuda-toolkit-13"
        CUDA_PATH="/usr/local/cuda"
        ;;
    *)
        echo "지원하지 않는 Ubuntu 버전입니다. ($VERSION)"
        exit 1
        ;;
esac

echo
echo "Ubuntu Version : $VERSION"
echo "CUDA Repo      : $CUDA_REPO"
echo "CUDA Package   : $CUDA_PACKAGE"
echo "CUDA Path      : $CUDA_PATH"

# =======================================
# CUDA Repository 등록
# =======================================

echo
echo "======================================="
echo " CUDA Repository 등록"
echo "======================================="

wget -O cuda-keyring.deb \
    "https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/cuda-keyring_1.1-1_all.deb"

sudo dpkg -i cuda-keyring.deb

rm -f cuda-keyring.deb

sudo apt update

# =======================================
# CUDA Toolkit 설치
# =======================================

echo
echo "======================================="
echo " CUDA Toolkit 설치"
echo "======================================="

# 설치 가능한 패키지인지 먼저 확인
if ! apt-cache show "$CUDA_PACKAGE" >/dev/null 2>&1; then
    echo
    echo "ERROR: CUDA 패키지를 찾을 수 없습니다."
    echo "Package: $CUDA_PACKAGE"
    echo
    echo "현재 설치 가능한 CUDA Toolkit:"
    apt-cache search '^cuda-toolkit-[0-9]' || true
    exit 1
fi

sudo apt install -y "$CUDA_PACKAGE"

# =======================================
# CUDA 경로 확인
# =======================================

echo
echo "======================================="
echo " CUDA 설치 경로 확인"
echo "======================================="

if [ ! -d "$CUDA_PATH" ]; then
    echo "지정된 CUDA 경로를 찾을 수 없습니다:"
    echo "$CUDA_PATH"
    echo
    echo "현재 /usr/local/cuda* 확인:"
    ls -ld /usr/local/cuda* 2>/dev/null || true
    exit 1
fi

# =======================================
# cuDNN 설치
# =======================================

echo
echo "======================================="
echo " cuDNN 설치"
echo "======================================="

if apt-cache show cudnn >/dev/null 2>&1; then
    sudo apt install -y cudnn
else
    echo "cudnn 패키지를 찾을 수 없습니다."
    echo "CUDA 설치는 완료되었지만 cuDNN 설치를 건너뜁니다."
fi

# =======================================
# 환경 변수 설정
# =======================================

echo
echo "======================================="
echo " 환경 변수 설정"
echo "======================================="

PATH_LINE="export PATH=${CUDA_PATH}/bin:\$PATH"
LD_LIBRARY_LINE="export LD_LIBRARY_PATH=${CUDA_PATH}/lib64:\$LD_LIBRARY_PATH"

grep -qxF "$PATH_LINE" ~/.bashrc || \
    echo "$PATH_LINE" >> ~/.bashrc

grep -qxF "$LD_LIBRARY_LINE" ~/.bashrc || \
    echo "$LD_LIBRARY_LINE" >> ~/.bashrc

# 현재 쉘에도 적용
export PATH="${CUDA_PATH}/bin:$PATH"
export LD_LIBRARY_PATH="${CUDA_PATH}/lib64:${LD_LIBRARY_PATH:-}"

# =======================================
# 설치 확인
# =======================================

echo
echo "======================================="
echo " 설치 확인"
echo "======================================="

echo
echo "Driver Version"
nvidia-smi || true

echo
echo "CUDA Compiler"
nvcc --version || true

echo
echo "CUDA 설치 경로"
ls -ld /usr/local/cuda* 2>/dev/null || true

# =======================================
# burn.sh 이동
# =======================================

if [ -f "./burn.sh" ]; then
    mv ./burn.sh ~/
    echo
    echo "burn.sh를 홈 디렉터리로 이동했습니다."
fi

# =======================================
# 완료
# =======================================

echo
echo "======================================="
echo " CUDA 설치 완료"
echo "======================================="

echo
echo "Ubuntu Version : $VERSION"
echo "CUDA Package   : $CUDA_PACKAGE"
echo "CUDA Path      : $CUDA_PATH"

echo
echo "환경 변수 적용:"
echo "source ~/.bashrc"

echo
echo "재부팅을 권장합니다:"
echo "sudo reboot"

echo
echo "======================================="
