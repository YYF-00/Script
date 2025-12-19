#!/bin/bash

# ========== 配置部分 ==========
# 基本配置
DOMAIN="yyfvps.cn"
SUB_DOMAIN="home"

RECORD_TYPE="A"
WAN_IP='1.1.1.1'

# API密钥（生产环境建议使用环境变量）
secret_id="AKIDKixELl1GZigRzJRM3XqzxhIix1ta50jH"
secret_key="RrHZYUIwPfhXDgwymOq6BbqrgHemiQ2T"

# API参数
service="dnspod"
host="dnspod.tencentcloudapi.com"
version="2021-03-23"
algorithm="TC3-HMAC-SHA256"

# ========== 初始化变量 ==========
timestamp=$(date +%s)
date=$(date -u -d @$timestamp +"%Y-%m-%d")

# 公共变量
credential_scope="$date/$service/tc3_request"
signed_headers="content-type;host;x-tc-action"

# ========== 函数定义 ==========
# 步骤 1：拼接规范请求串
build_canonical_request() {
  local payload="$1"
  local action="$2"

  http_request_method="POST"
  canonical_uri="/"
  canonical_querystring=""
  canonical_headers="content-type:application/json; charset=utf-8\nhost:$host\nx-tc-action:$(echo $action | awk '{print tolower($0)}')\n"
  hashed_request_payload=$(echo -n "$payload" | openssl sha256 -hex | awk '{print $2}')
  canonical_request="$http_request_method\n$canonical_uri\n$canonical_querystring\n$canonical_headers\n$signed_headers\n$hashed_request_payload"
}

# 步骤 2：拼接待签名字符串
build_string_to_sign() {
  hashed_canonical_request=$(printf "$canonical_request" | openssl sha256 -hex | awk '{print $2}')
  string_to_sign="$algorithm\n$timestamp\n$credential_scope\n$hashed_canonical_request"
}

# 步骤 3：计算签名
calculate_signature() {
  secret_date=$(printf "$date" | openssl sha256 -hmac "TC3$secret_key" | awk '{print $2}')
  secret_service=$(printf $service | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_date" | awk '{print $2}')
  secret_signing=$(printf "tc3_request" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_service" | awk '{print $2}')
  signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_signing" | awk '{print $2}')
}

# 步骤 4：拼接 Authorization
build_authorization() {
  authorization="$algorithm Credential=$secret_id/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature"
}

prepare_request() {
  local payload="$1"
  local action="$2"

  # 构建各个组件
  build_canonical_request "$payload" "$action"
  build_string_to_sign
  calculate_signature
  build_authorization
}

# 获取解析列表api
describe_record_list() {
  # 构建请求体
  local payload="{\"Domain\":\"${DOMAIN}\",\"Subdomain\":\"${SUB_DOMAIN}\"}"
  local action="DescribeRecordList"
  # 准备请求
  prepare_request "$payload" "$action"

  # 发起请求
  curl -s -XPOST "https://$host" \
    -d "$payload" \
    -H "Authorization: $authorization" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Host: $host" \
    -H "X-TC-Action: $action" \
    -H "X-TC-Timestamp: $timestamp" \
    -H "X-TC-Version: $version"
}

# 新增记录api
create_record() {
  # 构建请求体
  local payload="{\"Domain\":\"${DOMAIN}\",\"RecordType\":\"${RECORD_TYPE}\",\"RecordLine\":\"默认\",\"Value\":\"${WAN_IP}\",\"SubDomain\":\"${SUB_DOMAIN}\"}"
  local action="CreateRecord"
  # 准备请求
  prepare_request "$payload" "$action"

  # 发起请求
  curl -XPOST "https://$host" \
    -d "$payload" \
    -H "Authorization: $authorization" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Host: $host" \
    -H "X-TC-Action: $action" \
    -H "X-TC-Timestamp: $timestamp" \
    -H "X-TC-Version: $version"
}

# ========== 主流程 ==========
main() {
  local api_type=${1:-"describe_record_list"} #默认执行查询

  DOMAIN="${2:-$DOMAIN}"
  SUB_DOMAIN="${3:-$SUB_DOMAIN}"
  WAN_IP="${4:-$WAN_IP}"

  case $api_type in
    "describe_record_list")
      describe_record_list
      ;;
    "create_record")
      create_record
      ;;
    *)
      echo "Invalid API type: $api_type"
      exit 1
      ;;
  esac
}

# 执行主流程
main