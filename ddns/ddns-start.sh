#!/bin/bash

# 获取记录
response=$(bash ./dnspod_api.sh)

# 输出结果
echo "API Response: $response"