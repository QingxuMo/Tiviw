#!/data/data/com.termux/files/usr/bin/bash

RED=$(printf	'\033[31m')
GREEN=$(printf	'\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf	'\033[34m')
LIGHT=$(printf	'\033[1;96m')
RESET=$(printf	'\033[0m')

red() {
	echo -e "${RED}$1${RESET}"
}

green() {
	echo -e "${GREEN}$1${RESET}"
}

yellow() {
	echo -e "${YELLOW}$1${RESET}"
}

blue() {
	echo -e "${BLUE}$1${RESET}"
}

light() {
	echo -e "${LIGHT}$1${RESET}"
}

ask() {
    # http://djm.me/ask
    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question
		printf '%s\n' "${LIGHT}"
        printf "[?] "
        read -r -p "$1 [$prompt] " REPLY

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

		printf '%s\n' "${RESET}"

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

blue "

_/_/_/_/_/  _/              _/
   _/          _/      _/      _/      _/      _/
  _/      _/  _/      _/  _/  _/      _/      _/
 _/      _/    _/  _/    _/    _/  _/  _/  _/
_/      _/      _/      _/      _/      _/

"

# Check
if [[ $EUID -eq 0 ]]; then
	yellow "
[!] 检测到您正在尝试使用 ROOT 权限运行安装脚本
[!] 这是不建议且不被允许的
[!] 安装全过程不需要 ROOT 权限,且以 ROOT 权限运行可能会带来一些无法预料的问题
[!] 为了您的设备安全，请避免在任何情况下以 ROOT 用户运行安装脚本
	"
	exit 1
fi
if [[ -d /system/app && -d /system/priv-app ]]; then
	systeminfo="Android $(getprop ro.build.version.release)"
	export systeminfo
else 
	red	"[!] This operating system is not supported."
	exit 1
fi

if [ -d "$PREFIX/etc/tiviw" ]; then 
	yellow "
[!] 您已安装 Tiviw ，无需重复安装
如果您需要移除 Tiviw，请输入 rm -rf $PREFIX/etc/tiviw
	"
	exit 1
fi

check_mirrors() {
	mirrors_status=$(grep "mirror" "$PREFIX/etc/apt/sources.list" | grep -v '#')
	if [ -z "$mirrors_status" ]; then 
		red "[!] Termux 镜像源未配置!"
		blue "对于国内用户，添加清华源作为镜像源可以有效增强 Termux 软件包下载速度" 
		if ask "是否添加清华源?" "Y"; then
			sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' "$PREFIX/etc/apt/sources.list"
			sed -i 's@^\(deb.*games stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/game-packages-24 games stable@' "$PREFIX/etc/apt/sources.list.d/game.list"
			sed -i 's@^\(deb.*science stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/science-packages-24 science stable@' "$PREFIX/etc/apt/sources.list.d/science.list"
			apt update && apt upgrade -y
		else
			blue "使用默认源进行安装"
		fi
	fi
}

check_mirrors

blue "[*] 检查依赖中…"
apt-get update -y &> /dev/null
for i in git wget; do
if [ -e "$PREFIX/bin/$i" ]; then
	echo "  $i 已安装！"
else
	echo  "Installing $i..."
	apt-get install -y $i || {
		red "
[!] 依赖安装失败!
[*] 退出中……
			"
			exit 1
		}
fi
done
apt-get upgrade -y

blue "\n[*] 正在创建工作目录…"
mkdir -p "$PREFIX/etc/tiviw"
mkdir -p "$PREFIX/etc/tiviw/logs" "$PREFIX/etc/tiviw/linux" "$PREFIX/etc/tiviw/etc"

blue "\n[*] 正在检测网络可用性…"
if ping -q -c 1 -W 1 google.com >/dev/null; then
	green "[✓] 网络可用！"
	blue "\n[*] 正在拉取远程仓库…"
	git clone https://github.com/RimuruW/Tiviw "$PREFIX/etc/tiviw/core"
	cd "$PREFIX/etc/tiviw/core" || { red "目录跳转失败！" >&2;  exit 1; }
	git checkout master
else
	red "[!] 网络连接受限，尝试启用代理！"
	blue "\n[*] 正在拉取远程仓库…"
	git clone https://gitee.com/RimuruW/tiviw "$PREFIX/etc/tiviw/core"
	blue "\n[*] 正在修改远程仓库地址…"
	cd "$PREFIX/etc/tiviw/core" || { red "目录跳转失败！" >&2;  exit 1; }
	git checkout master
	git remote set-url origin https://github.com/RimuruW/Tiviw
fi

blue "\n[*] 正在检查远程仓库地址…"
remote_status="$(git remote -v | grep "https://github.com/RimuruW/Tiviw")"
[[ -z "$remote_status" ]] && red "
[!] 远程仓库地址修改失败!
[!] 请提交错误内容至开发者!
"

blue "\n[*] 正在校验其他选项…"

cd "$HOME" || { red "[!] 目录跳转失败!" >&2;  exit 1; }

blue "\n[*] 正在修改文件权限…"
bash "$PREFIX/etc/tiviw/core/permission.sh"

blue "\n[*] 正在创建启动器…"
rm -f "$PREFIX/bin/tiviw"
cp "$PREFIX/etc/tiviw/core/tiviw" "$PREFIX/bin/tiviw"
chmod +x "$PREFIX/bin/tiviw"

if [ -f "$PREFIX/bin/tiviw" ]; then
	green "\n[√]  安装成功！请输入 tiviw 启动脚本！"
	exit 0
else
	red	"
[!] 安装失败！请提交错误内容至开发者！
[*] 错误：启动器安装失败
	"
	exit 1
fi
