#!/bin/bash

# 源目录（包含压缩文件的目录）
src_dir="/mnt/fileroot2/jianqun.wang/U_Android14/tmp"
# 目标目录（解压文件的目标目录）
dest_dir="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1"

# 确保目标目录存在
mkdir -p "$dest_dir"

cd $src_dir
# 查找源目录下的所有.zip和.tar.gz文件，并解压到目标目录
find . -maxdepth 1 -type f \( -name "*.zip" -o -name "*.tar.gz" \) | while read -r file; do
    filename=$(basename "$file")
    echo "Extracting $filename to $dest_dir"
    
    case "$filename" in
        *.zip)
            unzip -o "$file" -d "$dest_dir" && echo "Extraction of $filename completed."
            ;;
        *.tar.gz)
            tar -xzf "$file" -C "$dest_dir" && echo "Extraction of $filename completed."
            ;;
        *)
            echo "Skipping $filename, unsupported file type."
            ;;
    esac
done

echo "All supported files have been extracted to $dest_dir"
