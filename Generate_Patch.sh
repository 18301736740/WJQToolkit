#!/bin/bash

# 定义sdk目录
s_repo_root_path="/mnt/nfsroot/jianqun.wang/s-fransat-20230415-gtvs"
s_gretzky_root_path="/mnt/nfsroot/jianqun.wang/google_gretzky_zte"

# 定义patch目录
patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/ZTE-Soundbar-Patches"
s_gretzky_patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/ZTE-Gretzky-Patches"

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
  echo "Patch for $s_repo_root_path has been generated in $output_dir"

elif [[ $git_root_path == $s_gretzky_root_path* ]]; then
  # 获取当前 Git 仓库相对于 s_gretzky_root_path 根目录的相对路径
  relative_path=${git_root_path#$s_gretzky_root_path/}

  # 创建输出目录，包括相对路径
  output_dir="$s_gretzky_patch_path/$issue_path/$relative_path"
  mkdir -p "$output_dir"

  # 生成 patch 文件
  git format-patch -1 HEAD -o "$output_dir"
  echo "Patch for $s_gretzky_root_path has been generated in $output_dir"
else
  echo "当前 Git 仓库不位于指定的 repo 根目录下。"
fi
