#!/bin/bash

# 加载配置文件
source ~/config.sh

# Redmine 服务器地址
REDMINE_URL="http://61.144.235.50:10320"

# API 密钥
API_KEY=$WJQ_REDMINE_API_KEY

# 目录名称
DIR_NAME=$1

# Issue ID
ISSUE_ID=$(echo "$DIR_NAME" | grep -oE '[0-9]{4}$')

# 调用 gettop 函数并存储其输出
TOP_DIR=$(git rev-parse --show-toplevel)
PWD=$(pwd)
RELATIVE_PATH=$(echo "$PWD" | sed "s|$TOP_DIR/||")

# 评论内容
COMMENT="Patches 获取
http://61.144.235.50:10320/boards/1/topics/630

目录:
$(echo "$RELATIVE_PATH/$DIR_NAME")

$(tree $DIR_NAME)"

# 打包目录为 ZIP 文件
zip -r -y "$DIR_NAME.zip" "$DIR_NAME"

echo "ISSUE_ID=$ISSUE_ID"
echo "COMMENT=$COMMENT"


# 提交评论并上传文件
curl -X PUT "$REDMINE_URL/issues/$ISSUE_ID.json" \
     -H "X-Redmine-API-Key: $API_KEY" \
     -F "issue[notes]=$COMMENT" \

#上传文件并获取 token
UPLOAD_RESPONSE=$(curl -s -X POST "$REDMINE_URL/uploads.json" \
  -H "X-Redmine-API-Key: $API_KEY" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$DIR_NAME.zip")


# 解析 token
TOKEN=$(echo $UPLOAD_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# 检查是否获取到 token
if [[ -z "$TOKEN" ]]; then
  echo "文件上传失败！请检查 Redmine 配置。"
  exit 1
fi

# 2. 关联文件到 Issue
curl -X PUT "$REDMINE_URL/issues/$ISSUE_ID.json" \
  -H "Content-Type: application/json" \
  -H "X-Redmine-API-Key: $API_KEY" \
  -d "{
        \"issue\": {
          \"uploads\": [
            {
              \"token\": \"$TOKEN\",
              \"filename\": \"$(basename $DIR_NAME.zip)\",
              \"description\": \"issue release patch\"
            }
          ]
        }
      }"

# 删除临时生成的 ZIP 文件
rm "$DIR_NAME.zip"

echo "patch release success"
