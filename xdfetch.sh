#!/usr/bin/env python3

import argparse
import os
import platform
import shutil
import socket
import subprocess
import time


VERSION = "0.1.0"


# ---------------------------------------------------------
# Utility
# ---------------------------------------------------------

def run_cmd(cmd, timeout=3):
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False
        )

        if result.returncode == 0:
            return result.stdout.strip()

    except Exception:
        pass

    return None


def human_bytes(value):
    units = ["B", "KB", "MB", "GB", "TB", "PB"]

    value = float(value)

    for unit in units:
        if value < 1024:
            return f"{value:.1f} {unit}"
        value /= 1024

    return f"{value:.1f} PB"


def human_gb(value_mb):
    return f"{value_mb / 1024:.1f} GB"


def section(title):
    print()
    print(f" {title}")
    print(" " + "─" * 61)


def status(ok):
    return "[ OK ]" if ok else "[FAIL]"


# ---------------------------------------------------------
# SYSTEM
# ---------------------------------------------------------

def get_system():

    hostname = socket.gethostname()

    try:
        os_info = platform.freedesktop_os_release()
        os_name = os_info.get("PRETTY_NAME", "Unknown")
    except Exception:
        os_name = "Unknown"

    kernel = platform.release()
    arch = platform.machine()

    try:
        with open("/proc/uptime") as f:
            uptime = float(f.read().split()[0])

        days = int(uptime // 86400)
        hours = int((uptime % 86400) // 3600)
        minutes = int((uptime % 3600) // 60)

        if days:
            uptime_text = f"{days} days, {hours} hours"
        elif hours:
            uptime_text = f"{hours} hours, {minutes} min"
        else:
            uptime_text = f"{minutes} min"

    except Exception:
        uptime_text = "Unknown"

    return {
        "hostname": hostname,
        "os": os_name,
        "kernel": kernel,
        "arch": arch,
        "uptime": uptime_text,
    }


# ---------------------------------------------------------
# CPU
# ---------------------------------------------------------

def get_cpu():

    model = "Unknown"
    physical = 0
    logical = os.cpu_count() or 0

    try:
        with open("/proc/cpuinfo") as f:

            for line in f:

                if line.startswith("model name"):
                    model = line.split(":", 1)[1].strip()
                    break

    except Exception:
        pass

    try:
        physical_output = run_cmd(
            ["lscpu", "-p=CPU,CORE,SOCKET"]
        )

        if physical_output:

            cores = set()

            for line in physical_output.splitlines():

                if line.startswith("#"):
                    continue

                parts = line.split(",")

                if len(parts) >= 3:
                    cores.add((parts[1], parts[2]))

            physical = len(cores)

    except Exception:
        physical = logical

    return {
        "model": model,
        "physical": physical,
        "logical": logical,
    }


# ---------------------------------------------------------
# MEMORY
# ---------------------------------------------------------

def get_memory():

    mem_total = 0
    mem_available = 0

    try:

        with open("/proc/meminfo") as f:

            for line in f:

                if line.startswith("MemTotal:"):
                    mem_total = int(line.split()[1]) * 1024

                elif line.startswith("MemAvailable:"):
                    mem_available = int(line.split()[1]) * 1024

    except Exception:
        pass

    used = mem_total - mem_available

    usage = 0

    if mem_total:
        usage = used / mem_total * 100

    return {
        "total": mem_total,
        "used": used,
        "available": mem_available,
        "usage": usage,
    }


# ---------------------------------------------------------
# GPU
# ---------------------------------------------------------

def get_gpu():

    command = [
        "nvidia-smi",
        "--query-gpu=name,memory.total,memory.used,"
        "utilization.gpu,temperature.gpu,power.draw,power.limit,"
        "driver_version",
        "--format=csv,noheader,nounits"
    ]

    output = run_cmd(command)

    if not output:
        return []

    gpus = []

    for line in output.splitlines():

        parts = [x.strip() for x in line.split(",")]

        if len(parts) < 8:
            continue

        gpu = {
            "name": parts[0],
            "memory_total": parts[1],
            "memory_used": parts[2],
            "utilization": parts[3],
            "temperature": parts[4],
            "power": parts[5],
            "power_limit": parts[6],
            "driver": parts[7],
        }

        gpus.append(gpu)

    return gpus


def get_cuda():

    output = run_cmd(["nvcc", "--version"])

    if not output:
        return None

    for line in output.splitlines():

        if "release" in line:

            try:
                return line.split("release", 1)[1].split(",", 1)[0].strip()
            except Exception:
                pass

    return None


# ---------------------------------------------------------
# STORAGE
# ---------------------------------------------------------

def get_storage():

    filesystems = []

    mounts = [
        "/",
        "/boot",
        "/home",
        "/data",
        "/data1",
        "/data2",
    ]

    for mount in mounts:

        if not os.path.exists(mount):
            continue

        try:

            total, used, free = shutil.disk_usage(mount)

            filesystems.append({
                "mount": mount,
                "total": total,
                "used": used,
                "free": free,
                "usage": used / total * 100
            })

        except Exception:
            pass

    return filesystems


# ---------------------------------------------------------
# NETWORK
# ---------------------------------------------------------

def get_network():

    interfaces = []

    try:

        for interface in os.listdir("/sys/class/net"):

            if interface == "lo":
                continue

            ip_output = run_cmd(
                ["ip", "-4", "addr", "show", interface]
            )

            ip_address = "-"

            if ip_output:

                for line in ip_output.splitlines():

                    line = line.strip()

                    if line.startswith("inet "):

                        ip_address = line.split()[1].split("/")[0]
                        break

            speed = "-"

            speed_path = f"/sys/class/net/{interface}/speed"

            try:

                with open(speed_path) as f:
                    speed = f.read().strip()

            except Exception:
                pass

            interfaces.append({
                "name": interface,
                "ip": ip_address,
                "speed": speed,
            })

    except Exception:
        pass

    return interfaces


# ---------------------------------------------------------
# DOCKER
# ---------------------------------------------------------

def get_docker():

    version = run_cmd(["docker", "--version"])

    if not version:
        return {
            "installed": False,
            "running": False,
            "containers": 0,
        }

    running = run_cmd(["docker", "info"]) is not None

    containers = 0

    if running:

        output = run_cmd(
            ["docker", "ps", "-q"]
        )

        if output:
            containers = len(output.splitlines())

    return {
        "installed": True,
        "running": running,
        "containers": containers,
    }


# ---------------------------------------------------------
# PRINT
# ---------------------------------------------------------

def print_header():

    print()
    print("╭──────────────────────────────────────────────────────────────╮")
    print("│                         XDFETCH v0.1                       ")
    print("╰──────────────────────────────────────────────────────────────╯")


def print_system(data):

    section("SYSTEM")

    print(f" Hostname     : {data['hostname']}")
    print(f" OS           : {data['os']}")
    print(f" Kernel       : {data['kernel']}")
    print(f" Architecture : {data['arch']}")
    print(f" Uptime       : {data['uptime']}")


def print_cpu(data):

    section("CPU")

    print(f" Model        : {data['model']}")
    print(f" Physical     : {data['physical']}")
    print(f" Logical      : {data['logical']}")


def print_memory(data):

    section("MEMORY")

    print(f" Total        : {human_bytes(data['total'])}")
    print(f" Used         : {human_bytes(data['used'])}")
    print(f" Available    : {human_bytes(data['available'])}")
    print(f" Usage        : {data['usage']:.1f}%")


def print_gpu(gpus):

    section("GPU")

    if not gpus:

        print(" NVIDIA GPU   : Not detected")

        return

    for index, gpu in enumerate(gpus):

        print(f" GPU {index:<7} : {gpu['name']}")
        print(
            f" VRAM         : "
            f"{gpu['memory_used']} MB / {gpu['memory_total']} MB"
        )

        print(f" Utilization  : {gpu['utilization']} %")
        print(f" Temperature  : {gpu['temperature']} C")
        print(
            f" Power        : "
            f"{gpu['power']} W / {gpu['power_limit']} W"
        )

        print(f" Driver       : {gpu['driver']}")

        if index != len(gpus) - 1:
            print()


def print_nvidia(gpus):

    section("NVIDIA")

    if not gpus:

        print(" Driver       : Not detected")
        print(" CUDA         : Not detected")

        return

    print(f" Driver       : {gpus[0]['driver']}")

    cuda = get_cuda()

    if cuda:
        print(f" CUDA         : {cuda}")
    else:
        print(" CUDA         : nvcc not found")


def print_storage(storage):

    section("STORAGE")

    if not storage:

        print(" No filesystem information")

        return

    for disk in storage:

        print(
            f" {disk['mount']:<12} : "
            f"{human_bytes(disk['used'])} / "
            f"{human_bytes(disk['total'])} "
            f"({disk['usage']:.1f}%)"
        )


def print_network(network):

    section("NETWORK")

    if not network:

        print(" No network interface")

        return

    for interface in network:

        speed = interface["speed"]

        if speed.isdigit():
            speed = f"{speed} Mbps"

        print(
            f" {interface['name']:<12} : "
            f"{interface['ip']:<16} "
            f"{speed}"
        )


def print_docker(docker):

    section("DOCKER")

    if not docker["installed"]:

        print(" Docker       : Not installed")

        return

    state = "Running" if docker["running"] else "Stopped"

    print(f" Docker       : {state}")
    print(f" Containers   : {docker['containers']}")


def print_status(gpus, docker, storage, network):

    section("STATUS")

    gpu_ok = len(gpus) > 0
    docker_ok = not docker["installed"] or docker["running"]
    network_ok = len(network) > 0
    storage_ok = len(storage) > 0

    print(f" {status(True)} System")
    print(f" {status(gpu_ok)} NVIDIA GPU")
    print(f" {status(gpu_ok)} NVIDIA Driver")
    print(f" {status(docker_ok)} Docker")
    print(f" {status(network_ok)} Network")
    print(f" {status(storage_ok)} Storage")


# ---------------------------------------------------------
# MAIN
# ---------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description="Linux Server Information Tool"
    )

    parser.add_argument(
        "--version",
        action="store_true",
        help="show version"
    )

    parser.add_argument(
        "--no-gpu",
        action="store_true",
        help="skip GPU information"
    )

    args = parser.parse_args()

    if args.version:

        print(f"serverfetch {VERSION}")

        return

    system = get_system()
    cpu = get_cpu()
    memory = get_memory()

    if args.no_gpu:
        gpus = []
    else:
        gpus = get_gpu()

    storage = get_storage()
    network = get_network()
    docker = get_docker()

    print_header()

    print_system(system)
    print_cpu(cpu)
    print_memory(memory)
    print_gpu(gpus)
    print_nvidia(gpus)
    print_storage(storage)
    print_network(network)
    print_docker(docker)
    print_status(gpus, docker, storage, network)

    print()


if __name__ == "__main__":
    main()