#!/bin/bash

# ========== 配置部分 ==========
# 基本配置
Domain="yyfvps.cn"
Subdomain="home"

# API密钥（生产环境建议使用环境变量）
secret_id="AKIDKixELl1GZigRzJRM3XqzxhIix1ta50jH"
secret_key="RrHZYUIwPfhXDgwymOq6BbqrgHemiQ2T"

# API参数
service="dnspod"
host="dnspod.tencentcloudapi.com"
action="DescribeRecordList"
version="2021-03-23"
algorithm="TC3-HMAC-SHA256"

# ========== 初始化变量 ==========
timestamp=$(date +%s)
date=$(date -u -d @$timestamp +"%Y-%m-%d")
echo "Date: $date"
payload="{\"Domain\":\"${Domain}\",\"Subdomain\":\"${Subdomain}\"}"

# 公共变量
credential_scope="$date/$service/tc3_request"
signed_headers="content-type;host;x-tc-action"

# ========== 函数定义 ==========
# 步骤 1：拼接规范请求串
build_canonical_request() {
    http_request_method="POST"
    canonical_uri="/"
    canonical_querystring=""
    canonical_headers="content-type:application/json; charset=utf-8\nhost:$host\nx-tc-action:$(echo $action | awk '{print tolower($0)}')\n"
    hashed_request_payload=$(echo -n "$payload" | openssl sha256 -hex | awk '{print $2}')
    canonical_request="$http_request_method\n$canonical_uri\n$canonical_querystring\n$canonical_headers\n$signed_headers\n$hashed_request_payload"
    echo "$canonical_request"
}

# 步骤 2：拼接待签名字符串
build_string_to_sign() {
    hashed_canonical_request=$(printf "$canonical_request" | openssl sha256 -hex | awk '{print $2}')
    string_to_sign="$algorithm\n$timestamp\n$credential_scope\n$hashed_canonical_request"
    echo "$string_to_sign"
}

# 步骤 3：计算签名
calculate_signature() {
    secret_date=$(printf "$date" | openssl sha256 -hmac "TC3$secret_key" | awk '{print $2}')
    secret_service=$(printf $service | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_date" | awk '{print $2}')
    secret_signing=$(printf "tc3_request" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_service" | awk '{print $2}')
    signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_signing" | awk '{print $2}')
    echo "$signature"
}

# 步骤 4：拼接 Authorization
build_authorization() {
    authorization="$algorithm Credential=$secret_id/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature"
    echo $authorization
}

# ========== 主流程 ==========
main() {
    echo "=== 构建请求 ==="
    canonical_request=$(build_canonical_request)
    echo "Canonical Request: $canonical_request"

    echo "=== 构建签名字符串 ==="
    string_to_sign=$(build_string_to_sign)
    echo "String to Sign: $string_to_sign"

    echo "=== 计算签名 ==="
    signature=$(calculate_signature)
    echo "Signature: $signature"

    echo "=== 构建授权头 ==="
    authorization=$(build_authorization)
    echo "Authorization: $authorization"

    echo "=== 发起请求 ==="
    curl -XPOST "https://$host" \
        -d "$payload" \
        -H "Authorization: $authorization" \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "Host: $host" \
        -H "X-TC-Action: $action" \
        -H "X-TC-Timestamp: $timestamp" \
        -H "X-TC-Version: $version"
}

# 执行主流程
main