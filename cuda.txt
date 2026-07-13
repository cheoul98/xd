#!/bin/bash

set -e

echo "======================================="
echo " NVIDIA CUDA 13.0 설치"
echo "======================================="

# Ubuntu 버전 확인
VERSION=$(lsb_release -rs)

case "$VERSION" in
    22.04)
        CUDA_REPO="ubuntu2204"
        ;;
    24.04)
        CUDA_REPO="ubuntu2404"
        ;;
    *)
        echo "지원하지 않는 Ubuntu 버전입니다. ($VERSION)"
        exit 1
        ;;
esac

echo "Ubuntu Version : $VERSION"
echo "CUDA Repo      : $CUDA_REPO"

# CUDA Repository 등록
wget -O cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO}/x86_64/cuda-keyring_1.1-1_all.deb

sudo dpkg -i cuda-keyring.deb
rm -f cuda-keyring.deb

sudo apt update

# CUDA Toolkit 13.0 설치
sudo apt install -y cuda-toolkit-13-0

# cuDNN 설치
sudo apt install -y cudnn

# PATH 등록 (중복 방지)
grep -qxF 'export PATH=/usr/local/cuda-13.0/bin:$PATH' ~/.bashrc || \
echo 'export PATH=/usr/local/cuda-13.0/bin:$PATH' >> ~/.bashrc

grep -qxF 'export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH' ~/.bashrc || \
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

# 환경 변수 적용
source ~/.bashrc

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

# burn.sh 이동 (존재하는 경우)
if [ -f "./burn.sh" ]; then
    mv ./burn.sh ~/
    echo "burn.sh를 홈 디렉터리로 이동했습니다."
fi

echo
echo "======================================="
echo " CUDA 13.0 설치 완료"
echo "======================================="
echo "재부팅을 권장합니다."
echo "sudo reboot"