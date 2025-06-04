#!/bin/bash


# 获取当前日期
current_date=$(date "+%Y-%m-%d")

#SDK 目录
tool_path=$(pwd)

#gretzky SDK
sdk_path="/mnt/fileroot2/jianqun.wang/U_Android14/RefPlus_Wave2_ZTE"

#xml path
xml_path="/mnt/fileroot2/jianqun.wang/U_Android14/Push_RefPlus_Wave2_ZTE/.repo/manifests/gretzky/odms/zte/refplus_ott_zte_wave2_odm_dserver.xml"

# 定义日志文件路径
push_log_file="$sdk_path/push_out/$current_date"

# 定义文件路径
Google_SOURCE_XML="/mnt/fileroot2/jianqun.wang/U_Android14/RefPlus_Wave2_ZTE/.repo/manifests/gretzky/base/default_u-tv-keystone-ref-release_google.xml"
Google_TARGET_XML="/mnt/fileroot2/jianqun.wang/U_Android14/Push_RefPlus_Wave2_ZTE/.repo/manifests/gretzky/base/default_u-tv-keystone-ref-release_google.xml"
TARGET_DIR="/mnt/fileroot2/jianqun.wang/U_Android14/Push_RefPlus_Wave2_ZTE/.repo/manifests"

# 确保目录存在
mkdir -p "$push_log_file"

# 执行你的操作并将输出重定向到日志文件
./D_Server_Code_Push_v1.sh $tool_path $sdk_path $xml_path $Google_SOURCE_XML $Google_TARGET_XML $TARGET_DIR  >> $push_log_file/$(date "+%Y-%m-%d")-push.log 2>&1
