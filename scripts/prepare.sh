#!/bin/sh
# ---------------------------------------------------------------------------
# prepare.sh：把 dl/ 里的源码包解包到 src/
#
# 实际动作：在项目根执行 make prepare
#   - dl/ 里已有源码包就直接用，没有才联网下载
#   - 解包出 src/linux-6.6.144 与 src/busybox-1.36.1
#   - 检查交叉工具链、mkimage、lzma 以及 config/ 下的 DTS 和内核配置是否存在
#
# 用法：
#   scripts/prepare.sh              正常执行
#   scripts/prepare.sh JOBS=8       临时覆盖 Makefile 变量
# ---------------------------------------------------------------------------

set -eu
# -e：任何一条命令返回非 0 就立刻退出
# -u：引用未定义的变量时报错退出

TOPDIR=$(cd "$(dirname "$0")/.." && pwd)
# $0        当前脚本路径，例如 scripts/prepare.sh
# dirname   只取目录部分，得到 scripts
# ..        再上一层，就是项目根目录 linux_lite
# pwd       输出绝对路径
# 结果：TOPDIR=/home/.../hlk_7621_all_kit_new/linux_lite

exec make -C "$TOPDIR" "$@" prepare
# -C "$TOPDIR"  让 make 先切换到项目根目录
# "$@"          把调用脚本时附加的参数原样传给 make，例如 JOBS=8
# prepare       Makefile 里的目标名
# exec          用 make 进程替换当前 shell，脚本退出码即 make 的退出码
