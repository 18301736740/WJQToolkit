#!/bin/bash

# 定义路径变量
tool_path=$1
sdk_path=$2
# 定义xml文件路径
INPUT_FILE=$3


# 生成日期目录
date_dir=$(date "+%Y-%m-%d")
push_out_path="$sdk_path/push_out/$date_dir"
scan_out_path="$push_out_path/scanout"
OUTPUT_FILE=$(mktemp)
#OUTPUT_FILE="$push_out_path/paths_revisions.txt"

# 清空或创建输出文件
#> "$OUTPUT_FILE"

# 确保目录存在
mkdir -p "$push_out_path"
mkdir -p "$scan_out_path"

# 定义排除的目录列表
unshallow_dirs=("device/zte/YEV-kernel" "device/zte/YMA-kernel" "device/zte/HUI-kernel")

git_fetch() {
    for dir in "${unshallow_dirs[@]}"; do
        # 检查目录是否存在
        if [ -d "$dir" ]; then
            # 进入目录
            echo "Entering directory: $dir"
            cd "$dir"
            # 执行git fetch --unshallow
            echo "Fetching and unshallowing repository in $dir..."
            git fetch --unshallow
            # 返回到上一级目录
            cd -
        else
            echo "Directory $dir does not exist, skipping."
	    exit 1
        fi
    done
}


# 函数：执行repo操作
repo_sync() {
    cd "$sdk_path/.repo/manifests"
    git pull
    if [ $? -ne 0 ]; then
        echo "$(date "+%Y-%m-%d"): git pull 失败"
        exit 1
    fi
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
    git_fetch
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

# 函数：解析push xml信息
parse_xml() {
grep -Eo '<project remote="[^"]+" revision="[^"]+"[^>]*path="[^"]+"' "$INPUT_FILE" | \
    grep -Eo 'revision="[^"]+"[^>]*path="[^"]+"' | \
    sed -E 's/revision="([^"]+)"[^>]*path="([^"]+)"/\1 \2/' > "$OUTPUT_FILE"

grep -Eo 'path="[^"]+"[^>]*revision="[^"]+"' "$INPUT_FILE" | \
    sed -E 's/path="([^"]+)"[^>]*revision="([^"]+)"/\2 \1/' >> "$OUTPUT_FILE"

grep -E 'revision="[^"]+"[^>]*name="[^"]+"' "$INPUT_FILE" | \
    grep -v 'path=' | \
    grep -Eo 'revision="[^"]+"[^>]*name="[^"]+"' | \
    sed -E 's/revision="([^"]+)"[^>]*name="([^"]+)"/\1 \2/' >> "$OUTPUT_FILE"
}

# 读取临时文件中的信息,执行git push 操作
git_push() {
    echo "------------------------PUSH start-----------------------------"
    cd "$sdk_path"
    while IFS=' ' read -r revision path; do
        echo "Processing path: $path with revision: $revision"
        # 进入对应的路径
        if [ -d "$path" ]; then
            echo "执行 git push 的目录：$path"
	    cd "$path"
	    # 获取本地HEAD的commit hash
            local_head=$(git rev-parse HEAD)

            # 拉取远程分支的最新状态
            git fetch gerrit

            # 获取远程分支HEAD的commit hash
            remote_head=$(git rev-parse gerrit/$revision)

            # 比较本地HEAD和远程HEAD的commit hash
            if [ "$local_head" = "$remote_head" ]; then
                echo "-------------------本地和远程HEAD一致 skip-------------------"
            else
                echo "-------------------本地和远程HEAD不一致 push-----------------"
                git push gerrit HEAD:refs/heads/$revision
                echo "$path" >> $push_out_path/push_projects.txt # 将路径写入文件
            fi

            echo "push $project_path to gerrit/$revision"
	    #git push gerrit HEAD:refs/heads/$revision
	    #if [ $? -ne 0 ]; then
            #    echo "Git push successful for directory: $path"
            #else
            #    echo "Git push failed for directory: $path"
            #    exit 1
            #fi
            cd -
        else
            echo "Path $path does not exist. Skipping..."
        fi
    done < "$OUTPUT_FILE"
    echo "------------------------PUSH END-----------------------------"
}

# 函数：执行校验操作
push_verify() {
    echo "------------------------VERIFY START-----------------------------"
    while IFS=' ' read -r revision path; do
        echo "Processing path: $path with revision: $revision"
        # 进入对应的路径
        if [ -d "$path" ]; then
            echo "执行 git verify 的目录：$path"
            cd "$path"
            # 获取本地HEAD的commit hash
            local_head=$(git rev-parse HEAD)

            # 拉取远程分支的最新状态
            git fetch gerrit

            # 获取远程分支HEAD的commit hash
            remote_head=$(git rev-parse gerrit/$revision)

            # 比较本地HEAD和远程HEAD的commit hash
            if [ "$local_head" = "$remote_head" ]; then
                echo "----------git verify 成功，本地和远程HEAD一致---------------"
            else
                echo "----------git verify 警告，本地和远程HEAD不一致-------------"
                echo "$path" >> $push_out_path/warning_projects.txt # 将路径写入文件
            fi

            echo "verify $project_path to gerrit/$revision"
            #git push gerrit HEAD:refs/heads/$revision
            #if [ $? -ne 0 ]; then
            #    echo "Git push successful for directory: $path"
            #else
            #    echo "Git push failed for directory: $path"
            #    exit 1
            #fi
            cd -
        else
            echo "Path $path does not exist. Skipping..."
        fi
    done < "$OUTPUT_FILE"
    echo "------------------------VERIFY END-----------------------------"
}

# 函数：结果打印
result_print() {
    echo "-----------------------push 路径统计-------------------------"
    if [ -f "$push_out_path/push_projects.txt" ]; then
      cat $push_out_path/push_projects.txt
      rm $push_out_path/push_projects.txt
    else
      echo "-----------------------No was pushed------------------------"
    fi

    echo "-------------verify 本地和远程HEAD不一致统计----------------------"
    if [ -f "$push_out_path/warning_projects.txt" ]; then
      echo "-----------------------VERIFY FAIL------------------------"
      cat $push_out_path/warning_projects.txt
      rm $push_out_path/warning_projects.txt
    else
      echo "-----------------------VERIFY PASS------------------------"
    fi
}

# 主程序流程
main() {
    repo_sync
    compare_xml
    run_scan
    parse_xml
    git_push
    push_verify
    result_print
}

# 执行主程序
main
