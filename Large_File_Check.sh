#!/bin/bash

# 定义文件路径
FILE="/mnt/fileroot2/jianqun.wang/U_Android14/Y5_X5_Android14_ab1/.repo.zip"

# 定义块大小（例如：1MB）
BLOCK_SIZE=1M

# 计算文件总大小
TOTAL_SIZE=$(stat -c%s "$FILE")

# 计算需要计算的块数
# 这里我们只计算文件的前1MB和后1MB
BLOCK_COUNT=$((TOTAL_SIZE / BLOCK_SIZE))

# 检查文件大小是否小于块大小
if [ $TOTAL_SIZE -lt $BLOCK_SIZE ]; then
    BLOCK_COUNT=1
fi

# 计算 MD5
echo "Calculating MD5 for the first $BLOCK_SIZE of $FILE"
head -c $BLOCK_SIZE "$FILE" | md5sum | awk '{print $1}' > first_block.md5

echo "Calculating MD5 for the last $BLOCK_SIZE of $FILE"
tail -c $BLOCK_SIZE "$FILE" | md5sum | awk '{print $1}' > last_block.md5

echo "MD5 calculations complete."
