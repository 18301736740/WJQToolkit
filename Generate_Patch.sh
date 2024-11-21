#!/bin/bash

# 定义变量
s_repo_root_path="/mnt/nfsroot/jianqun.wang/s-fransat-20230415-gtvs"

patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/soundbar_zte"

git_root_path=$(git rev-parse --show-toplevel)

issue_path="$1"

# 检查当前目录是否在 repo 根目录下
if [[ $git_root_path == $s_repo_root_path* ]]; then
  # 获取当前 Git 仓库相对于 repo 根目录的相对路径
  relative_path=${git_root_path#$s_repo_root_path/}

  # 创建输出目录，包括相对路径
  output_dir="$patch_path/$issue_path/$relative_path"
  mkdir -p "$output_dir"

  # 生成 patch 文件
  git format-patch -1 HEAD -o $output_dir
else
  echo "当前 Git 仓库不位于指定的 repo 根目录下。"
fi
