#!/bin/bash

# 定义Master-AV1-Patches目录
s_repo_root_path="/mnt/nfsroot/jianqun.wang/s-fransat-20230415-gtvs"
patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/ZTE-Master-AV1-Patches"
#patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/ZTE-Soundbar-Patches"

# 定义Gretzky-Patches目录
s_gretzky_root_path="/mnt/nfsroot/jianqun.wang/google_gretzky_zte"
s_gretzky_patch_path="/mnt/nfsroot/jianqun.wang/zte-project-patch/S/ZTE-Gretzky-Patches"

# 定义X4_Y4_Android14_ab2目录
u_ab2_root_path="/mnt/fileroot2/jianqun.wang/U_Android14/X4_Y4_Android14_ab2"
u_ab2_patch_path="/mnt/fileroot2/jianqun.wang/zte-project-patch/U/X4_Y4_Android14_ab2"

# 定义Y5_X5_Android14_ab1目录
u_ab1_root_path="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1"
u_ab1_patch_path="/mnt/fileroot2/jianqun.wang/zte-project-patch/U/Y5_X5_Android14_ab1"

git_root_path=$(git rev-parse --show-toplevel)

#脚本传递的参数
param_count=$#
issue_path="$1"
commit_range="$2"
hash_value="$3"

# 根据账号定义对应的zte-project-patch 目录
HOSTNAME=`hostname`
USERNAME=`whoami`
if [ "$HOSTNAME" == "droid16-sz" ] && [ "$USERNAME" == "jianqun.wang" ]; then
    zte_project_patch="/mnt/fileroot2/jianqun.wang/zte-project-patch"
elif [ "$HOSTNAME" == "droid13-sz" ] && [ "$USERNAME" == "jianqun.wang" ]; then
    zte_project_patch="/mnt/nfsroot/jianqun.wang/zte-project-patch"
else
    echo "no zte-project-patch work dir of jianqun.wang"
fi

# 定义函数来生成patch
generate_patch() {
    local root_path=$1
    local patch_dir=$2
    local issue_path=$3
    local relative_path=${git_root_path#$root_path/}
    local output_dir="$patch_dir/$issue_path/$relative_path"

    mkdir -p "$output_dir"
    # 检查 patch-list.txt 中是否已经有 $issue_path 内容
    if ! grep -q "$issue_path" "$patch_dir/patch-list.txt"; then
        echo "$issue_path" >> "$patch_dir/patch-list.txt"
    else
        echo "Issue path $issue_path already exists in $patch_dir/patch-list.txt"
    fi

    if [ "$param_count" -eq 3 ]; then
        git format-patch "$commit_range" "$hash_value" -o "$output_dir"
    else
        git format-patch -1 HEAD -o "$output_dir"
    fi
    echo "Patch for $root_path has been generated in $output_dir"
}

# 检查参数数量
if [ "$param_count" -eq 0 ]; then
    echo "No arguments provided. Exiting."
    exit 1
fi

# 更新响应的zte-project-patch 目录
cd $zte_project_patch
git pull
cd - 

# 生成patch
if [[ $git_root_path == $s_repo_root_path* ]]; then
    generate_patch "$s_repo_root_path" "$patch_path" "$issue_path"
elif [[ $git_root_path == $s_gretzky_root_path* ]]; then
    generate_patch "$s_gretzky_root_path" "$s_gretzky_patch_path" "$issue_path"
elif [[ $git_root_path == $u_ab2_root_path* ]]; then
    generate_patch "$u_ab2_root_path" "$u_ab2_patch_path" "$issue_path"
elif [[ $git_root_path == $u_ab1_root_path* ]]; then
    generate_patch "$u_ab1_root_path" "$u_ab1_patch_path" "$issue_path"
else
    echo "当前 Git 仓库不位于指定的 repo 根目录下。"
fi
