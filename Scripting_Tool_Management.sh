#!/bin/bash


# 获取当前日期
current_date=$(date "+%Y-%m-%d")

#SDK 目录
tool_path="/mnt/nfsroot/jianqun.wang/Amlogic_tool"

#gretzky SDK
s_gretzky_sdk_path="/mnt/nfsroot/jianqun.wang/google_gretzky_zte"

# 定义日志文件路径
s_gretzky_push_log_file="$s_gretzky_sdk_path/push_out/$current_date"

# 确保目录存在
mkdir -p "$s_gretzky_push_log_file"

# 执行你的操作并将输出重定向到日志文件
./D_Server_Code_Push.sh >> $s_gretzky_push_log_file/$(date "+%Y-%m-%d")-push.log 2>&1
