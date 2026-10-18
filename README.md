# linux_lite

MT7621（HiLink HLK-7621A EVB）上的极简 Linux 构建工程：只包含静态 BusyBox 用户空间与内嵌 initramfs，继续使用板子上现有的 U-Boot 启动。

第一阶段方案与背景见 [doc/linux_lite_phase1_plan.md](doc/linux_lite_phase1_plan.md)。

## 启动链

```text
现有 U-Boot（不修改二进制）
    -> legacy uImage（lzma-loader + appended DTB）
    -> Linux Kernel
    -> 内嵌 initramfs
    -> /init
    -> 静态 BusyBox sh
```

## 目录结构

```text
linux_lite/
├── Makefile                  顶层构建入口
├── config/
│   ├── board.dts             板级 DTS
│   └── kernel.config         内核配置
├── doc/                      方案文档
├── rootfs-overlay/           /init 与额外 rootfs 文件
├── scripts/                  预留脚本目录
├── third_party/lzma-loader/  uImage 引导用解压器源码
├── dl/                       源码包缓存（不纳入版本库）
├── src/                      解包后的源码（不纳入版本库）
├── build/                    中间产物（不纳入版本库）
└── out/                      最终产物（不纳入版本库）
```

## 依赖

- 交叉工具链：`mipsel-openwrt-linux-musl-gcc`（GCC 13.3.0，musl，软浮点）
- 主机工具：`mkimage`、`lzma`
- 内核与 BusyBox 源码包放在 `dl/`，由 `make prepare` 解包到 `src/`

工具链与主机工具路径可用变量覆盖：

```sh
make TOOLCHAIN=/path/to/toolchain CROSS=/path/to/prefix- \
     MKIMAGE=/path/to/mkimage LZMA=/path/to/lzma
```

## 构建

```sh
make prepare     # 解包 dl/ 中的内核与 BusyBox 源码到 src/
make busybox     # 静态编译 BusyBox -> out/busybox
make rootfs      # 生成 out/rootfs.list 与 out/rootfs.cpio
make kernel      # 编译内核与板级 DTB
make uimage      # 打包 legacy uImage -> out/uImage
```

`make` 默认输出帮助，`make all` 等价于 `make uimage`。

构建前需要：

- `rootfs-overlay/init`（第一阶段的启动脚本，内容见方案文档 6.2 节）
- `config/kernel.config` 与 `config/board.dts` 按实际硬件裁剪

## 启动验证

U-Boot 中通过 TFTP 加载，不写 Flash：

```text
tftpboot 0x82000000 uImage
bootm 0x82000000
```

验收标志：

```text
MT7621 Linux Lite started
/ #
```

## 镜像约定

| 项目 | 取值 |
|---|---|
| 架构 | MIPS32 little-endian，mips32r2，软浮点 |
| 镜像格式 | legacy uImage（`-C none`） |
| 加载 / 入口地址 | 0x80001000 |
| lzma-loader 运行地址 | 0x81800000 |
| 用户空间 | 静态 BusyBox，无动态链接器 |
| 根文件系统 | 内嵌 initramfs（cpio，`nod` 描述设备节点） |

## 未纳入版本库的内容

`dl/`、`src/`、`build/`、`out/` 均为本地生成或体积较大的内容，不提交。
