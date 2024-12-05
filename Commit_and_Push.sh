#!/bin/bash

# 定义补丁目录
# Enter the corresponding working directory based on the host name and user name
HOSTNAME=`hostname`
USERNAME=`whoami`
if [ "$HOSTNAME" == "droid16-sz" ] && [ "$USERNAME" == "jianqun.wang" ]; then
    patch_dir="/mnt/fileroot2/jianqun.wang/zte-project-patch"
elif [ "$HOSTNAME" == "droid13-sz" ] && [ "$USERNAME" == "jianqun.wang" ]; then
    patch_dir="/mnt/nfsroot/jianqun.wang/zte-project-patch"
else
    echo "no push work dir of jianqun.wang"
fi

# 检查参数数量
if [ $# -eq 0 ]; then
    echo "No arguments provided. Exiting."
    exit 1
fi

# 进入补丁目录
cd "$patch_dir"

# 检查目录是否是一个Git仓库
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: $patch_dir is not a git repository."
    exit 1
fi

# 获取git status的输出
status_output=$(git status --porcelain)

# 检查是否有未跟踪的文件或修改过的文件
if [ -n "$status_output" ]; then
    # 如果有更新，则执行 git add
    git add -A

    # 执行 git commit，$1 是脚本的第一个参数，即补丁的描述
    git commit -m "Add $1 Patches"

    # 执行 git push 到远程分支，这里假设远程分支名为 origin
    # 并且假设您想要推送到的分支名为 master
    git push origin HEAD:refs/for/master
else
    echo "No changes detected in $patch_dir."
fi
