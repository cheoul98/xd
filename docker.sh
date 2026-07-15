#!/bin/bash

set -e

echo "======================================="
echo " Docker + NVIDIA Container Toolkit 설치"
echo "======================================="

# Docker 설치
sudo apt update
sudo apt install -y docker.io curl ca-certificates gnupg

# Docker 서비스 시작
sudo systemctl enable --now docker

# NVIDIA Container Toolkit Repository 등록
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

# 패키지 설치
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Docker Runtime 설정
sudo nvidia-ctk runtime configure --runtime=docker

# Docker 재시작
sudo systemctl restart docker

# docker 그룹 추가 (root가 아닌 일반 사용자로 사용할 경우)
if [ "$SUDO_USER" ]; then
    sudo usermod -aG docker "$SUDO_USER"
fi

# Docker Compose Plugin 설치
sudo apt install -y docker-compose-v2

echo
echo "======================================="
echo " 설치 확인"
echo "======================================="

docker --version
docker compose version
nvidia-ctk --version

echo
echo "GPU 테스트"
echo "docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi"

echo
echo "설치 완료"
echo "로그아웃 후 다시 로그인하거나 재부팅하면 docker 그룹 권한이 적용됩니다."