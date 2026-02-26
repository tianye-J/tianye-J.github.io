+++
title = 'Linux 常用命令速查笔记'
date = 2026-02-25
draft = false
tags = ['Linux', '工具', '笔记']
description = '整理日常开发中最常用的 Linux 命令，涵盖文件操作、进程管理、网络调试等场景。'
+++

## 文件操作

```bash
# 查找文件
find /path -name "*.py" -type f

# 文件内容搜索
grep -rn "pattern" /path/to/dir

# 磁盘使用
du -sh *         # 当前目录各项大小
df -h            # 磁盘分区使用情况
```

## 进程管理

```bash
# 查看进程
ps aux | grep process_name
htop             # 交互式进程监控

# 后台运行
nohup ./script.sh &
```

## 网络调试

```bash
# 端口占用
ss -tlnp | grep :8080
netstat -tlnp

# 网络连通性
ping -c 4 google.com
curl -I https://example.com
```

## SSH 相关

```bash
# 生成密钥
ssh-keygen -t ed25519 -C "your_email@example.com"

# 远程连接
ssh user@host -p 22

# 端口转发
ssh -L 8080:localhost:80 user@remote
```

## 实用技巧

- `Ctrl+R` — 反向搜索历史命令
- `!!` — 重复上一条命令（`sudo !!` 很常用）
- `&&` — 前一条成功才执行下一条
- `|` — 管道：将前一条输出作为下一条输入

> 持续更新中，遇到好用的命令会随时补充。
