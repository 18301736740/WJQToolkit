#!/bin/bash

# 定义路径
PATCH_DIR="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1/common/common14-5.15/common/common_drivers/auto_patch/common14-5.15/common"
GIT_REPO_DIR="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1/common/common14-5.15/common"

# 检查目录是否存在
if [[ ! -d "$PATCH_DIR" ]]; then
    echo "Error: Patch directory $PATCH_DIR does not exist!"
    exit 1
fi

if [[ ! -d "$GIT_REPO_DIR" ]]; then
    echo "Error: Git repository directory $GIT_REPO_DIR does not exist!"
    exit 1
fi

# 获取所有.patch文件的Change-Id
echo "Collecting Change-Ids from patch files..."
declare -A patch_change_ids
declare -A patch_file_counts
change_id_count=0  # 初始化计数器
patch_count=0 # 初始化计数器

while IFS= read -r patch_file; do
    # 提取文件中的所有 Change-Id
    change_ids=$(grep 'Change-Id:' "$patch_file" | awk '{print $2}')
    
    # 检查是否提取到 Change-Id
    if [[ -n "$change_ids" ]]; then
        ((patch_count++))  # 增加计数器
        count=0
        # 遍历所有提取到的 Change-Id
        for change_id in $change_ids; do
            # 只保留以 "I" 开头的 Change-Id
            if [[ "$change_id" =~ ^I[0-9a-f]{40}$ ]]; then
                patch_change_ids["$change_id"]=1
                ((change_id_count++))  # 增加计数器
                ((count++))  # 增加当前文件的 Change-Id 计数器
                echo "Found Change-Id: $change_id in $patch_file"
            fi
        done
        # 如果当前文件的 Change-Id 数量大于或等于2，则记录文件名
        if [[ $count -ge 2 ]]; then
            patch_file_counts["$patch_file"]=1
        fi
    fi
done < <(find "$PATCH_DIR" -type f -name "*.patch")

# 打印Change-Ids
echo "#######patch_change_ids######"
for change_id in "${!patch_change_ids[@]}"; do
    echo "$change_id"
done

#打印包含2个或更多 Change-Id 的文件
echo "#######patch_files_with_multiple_change_ids######"
for patch_file in "${!patch_file_counts[@]}"; do
    echo "$patch_file"
done

# 打印总数
echo "Total number of unique Patch: $patch_count"
echo "Total number of unique Change-Ids: $change_id_count"

# 检查Change-Id是否已经合入
echo
echo "Checking if patches are already merged into the Git repository..."
cd "$GIT_REPO_DIR" || exit 1
#merged_change_ids=$(git log -E --grep='Change-Id:' | awk '{print $2}' | sort -u)
merged_change_ids=$(git log --pretty=format:"%B" | grep -E 'Change-Id:' | awk '{print $2}')

for change_id in "${!patch_change_ids[@]}"; do
    if [[ "$merged_change_ids" =~ "$change_id" ]]; then
        echo "Change-Id: $change_id is already merged."
    else
        echo "Change-Id: $change_id is NOT merged."
    fi
done

echo
echo "Check complete."

patch_merge_count=0  # 初始化计数器

# 获取所有提交的哈希和完整提交信息
while IFS=$'\n' read -r commit_hash; do
    echo "commit_hash: $commit_hash"
    
    # 检查 commit_hash 是否为空
    if [[ -z "$commit_hash" ]]; then
        echo "Error: commit_hash is empty. Skipping this entry."
        continue
    fi

    # 使用 git log 获取完整的提交信息
    commit_message=$(git log -1 --pretty=format:"%B" "$commit_hash" | grep -E 'Change-Id:' | awk '{print $2}')
    
    # 检查 commit_message 是否为空
    if [[ -z "$commit_message" ]]; then
        echo "Error: commit_message is empty for commit_hash $commit_hash. Skipping this entry."
        continue
    fi

    echo "Change-Id: $commit_message"
    
    found=false
    for change_id in "${!patch_change_ids[@]}"; do
        if echo "$commit_message" | grep -q "$change_id"; then
            found=true
            break
        fi
    done

    if [[ "$found" = false ]]; then
        echo "Latest commit without any of the commit_hash: $commit_hash"
        echo "Change-Id: $commit_message"
        # 打印merge patch总数
        echo "Total number of unique Patch merge: $patch_merge_count"
        break
    fi
    ((patch_merge_count++))  # 增加计数器
done < <(git log --pretty=format:"%H")
