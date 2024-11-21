#!/bin/bash

# 源目录和目标目录
src_dir="/mnt/fileroot2/xiaoming.liu/atv14/ab_clean_version"
dest_dir="/mnt/fileroot2/xiaoming.liu/atv14/jianqun1"

# 确保目标目录存在
mkdir -p "$dest_dir"

#进入到相关目录
cd $src_dir

# 查找所有子目录并存储到数组中
directories=( $(find . -maxdepth 1 -type d ! -name "." -exec basename {} \;) )

#拷贝所有的文件和软连接
tar -czvf $dest_dir/on_directories.tar.gz -C . $(find . -maxdepth 1 ! -type d)

# 循环遍历数组中的每个目录
for dir in "${directories[@]}"; do
    # 跳过空目录名
    if [[ -z "$dir" ]]; then
        continue
    fi
    # 打包每个目录
    echo "Creating zip for directory: $dir"
    zip -r -y "${dest_dir}/${dir}.zip" "$dir"
done

echo "All directories have been zipped."
