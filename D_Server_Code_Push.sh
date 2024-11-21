#!/bin/bash

# 定义路径变量
tool_path="/mnt/nfsroot/jianqun.wang/Amlogic_tool"
sdk_path="/mnt/nfsroot/jianqun.wang/google_gretzky_zte"

# 生成日期目录
date_dir=$(date "+%Y-%m-%d")
push_out_path="$sdk_path/push_out/$date_dir"
scan_out_path="$push_out_path/scanout"

# 确保目录存在
mkdir -p "$push_out_path"
mkdir -p "$scan_out_path"

# 定义排除的目录列表
exclude_dirs=("device/zte/YEV" "device/zte/YEV-kernel" "vendor/zte/yev" "device/zte/YMA" "device/zte/YMA-kernel" "vendor/zte/yma" "vendor/zte/common")

# 函数：执行repo操作
repo_sync() {
    cd "$sdk_path"
    repo manifest -r -o $push_out_path/Before-update-$(date "+%Y-%m-%d").xml
    if [ $? -ne 0 ]; then
        echo "$(date "+%Y-%m-%d"): repo manifest 失败"
        exit 1
    fi

    repo sync
    if [ $? -ne 0 ]; then
        echo "$(date "+%Y-%m-%d") repo sync 失败"
        exit 1
    fi
    repo manifest -r -o $push_out_path/Updated-$(date "+%Y-%m-%d").xml
}

# 函数：对比base.xml和update.xml
compare_xml() {
	echo "Comparing manifests..."
	diffbase="$push_out_path/Before-update-$(date "+%Y-%m-%d").xml"
	diffupdate="$push_out_path/Updated-$(date "+%Y-%m-%d").xml"
	tmpfile=$(mktemp)
	grep 'revision' "$diffbase" > "$tmpfile"
	grep 'revision' "$diffupdate" | diff -u - "$tmpfile" | grep -E '^\+[^+]' | while read -r line; do
    name=$(echo "$line" | grep -oP 'name="\K[^"]+')
    path=$(echo "$line" | grep -oP 'path="\K[^"]+')
    	if [ -n "$path" ]; then
        	echo "$path" >> "$push_out_path/modified_repos.txt"
    	elif [ -n "$name" ]; then
        	echo "$name" >> "$push_out_path/modified_repos.txt"
    	fi
	done
	rm "$tmpfile"

	if [ ! -s "$push_out_path/modified_repos.txt" ]; then
        echo "$(date "+%Y-%m-%d"): No modified repositories found."
    	exit 1
	fi
}

# 函数：执行扫描操作
run_scan() {
    cd $tool_path/licensescan/
# 读取 modified_repos.txt 文件中的每个目录
    while IFS= read -r dir; do
        # 执行 scan_run.sh 脚本并捕获其输出
        scan_result=$(./scan_run.sh -c "$sdk_path/$dir" -r "$scan_out_path" -s local -a all -f true 2>&1)
        echo "$scan_result"
        # 检查输出中是否包含 PASS 或 FAILED
        if echo "$scan_result" | grep -q "Scan Double Confirm FAILED"; then
            echo "$(date "+%Y-%m-%d"): scan 失败"
            exit 1
        fi
    done < "$push_out_path/modified_repos.txt"
    cd -
}

# 函数：检查目录是否在排除列表中
is_excluded_dir() {
    local dir="$1"
    for excluded_dir in "${exclude_dirs[@]}"; do
        if [ "$dir" == "$sdk_path/$excluded_dir" ]; then
            return 0 # 目录在排除列表中
        fi
    done
    return 1 # 目录不在排除列表中
}

# 函数：执行git push操作
git_push() {
    repo forall -c 'dir=$(git rev-parse --show-toplevel); echo $dir;'| while read -r dir; do
        # 检查目录是否应该被排除
        if is_excluded_dir "$dir"; then
            echo "跳过push排除目录：$dir"
        else
            echo "执行 git push 的目录：$dir"
            # 在非排除目录中执行 git push
            cd "$dir"
            if git push gerrit HEAD:refs/heads/google_gretzky_zte; then
                echo "Git push successful for directory: $dir"
            else
                echo "Git push failed for directory: $dir"
                exit 1
            fi
            cd -
        fi
    done
    if [ $? -ne 0 ]; then
        echo "$(date "+%Y-%m-%d"): git push 失败"
        exit 1
    fi
}

# 函数：执行校验操作
push_verify() {
    # 读取 modified_repos.txt 文件中的每个目录
	while IFS= read -r dir; do
        # 检查目录是否在排除列表中
        local skip=false
        for excluded_dir in "${exclude_dirs[@]}"; do
            if [ "$dir" == "$excluded_dir" ]; then
                skip=true
                break
            fi
        done

        # 如果目录不在排除列表中，执行操作
        if [ "$skip" = false ]; then
            echo "正在处理目录：$dir"
            cd "$dir" || exit  # 如果目录不存在或无法切换，退出脚本
            local local_head
            local remote_head

            # 获取本地HEAD的commit hash
            local_head=$(git rev-parse HEAD)

            # 拉取远程分支的最新状态
            git fetch gerrit

            # 获取远程分支HEAD的commit hash
            remote_head=$(git rev-parse gerrit/google_gretzky_zte)

            # 比较本地HEAD和远程HEAD的commit hash
            if [ "$local_head" = "$remote_head" ]; then
                echo "$(date "+%Y-%m-%d"): git push 成功，本地和远程HEAD一致"
            else
                echo "$(date "+%Y-%m-%d"): git push 警告，本地和远程HEAD不一致"
            fi
            cd -  # 返回到原始目录
        else
            echo "跳过排除目录：$dir"
        fi
    done < "$push_out_path/modified_repos.txt"
}

# 主程序流程
main() {
    repo_sync
    compare_xml
    run_scan
    git_push
    push_verify
    echo "所有操作成功完成"
}

# 执行主程序
main
