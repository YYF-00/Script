#!/bin/bash

# 定义 jq 路径
jq_cmd="/opt/bin/jq"
[ ! -x "$jq_cmd" ] && jq_cmd="jq"

# 获取脚本所在绝对目录
DIR="$(cd "$(dirname "$0")" && pwd)"

# 获取域名配置
DDNS_HOSTNAME="$(nvram get ddns_hostname_x)"
export DOMAIN=$(echo "$DDNS_HOSTNAME" | cut -d'.' -f2-)
export SUB_DOMAIN=$(echo "$DDNS_HOSTNAME" | cut -d'.' -f1)

# 获取本地 WAN IP (修正语法)
export WAN_IP=${1:-$(nvram get wan0_ipaddr)}

# DNSPod 密钥 (!!! 请务必更换已暴露的密钥 !!!)
export DDNS_SECRET_ID="你的新ID"
export DDNS_SECRET_KEY="你的新KEY"

SUCCESS=0

# 查询记录 - 使用绝对路径
response=$(bash "$DIR/dnspod_api.sh")

if [[ -z "$response" ]]; then
    echo "DDNS_CUSTOM: API 返回为空，请检查网络"
    exit 1
fi

if echo "$response" | grep -q "Error"; then
    if echo "$response" | grep -q "ResourceNotFound.NoDataOfRecord"; then
        echo "DDNS_CUSTOM: 不存在记录，开始创建"
        bash "$DIR/dnspod_api.sh" "create_record" && SUCCESS=1
    else
        echo "DDNS_CUSTOM: API 错误: $response"
    fi
else
    # 使用正确的变量名执行 jq
    record_id=$(echo "$response" | $jq_cmd -r '.RecordList[0].RecordId // empty')
    record_ip=$(echo "$response" | $jq_cmd -r '.RecordList[0].Value // empty')

    if [[ -n "$record_id" ]]; then
        if [[ "$record_ip" != "$WAN_IP" ]]; then
            echo "DDNS_CUSTOM: IP 变化 ($record_ip -> $WAN_IP)，开始修改"
            bash "$DIR/dnspod_api.sh" "modify_record" "$record_id" && SUCCESS=1
        else
            echo "DDNS_CUSTOM: IP 未改变，状态正常"
            SUCCESS=1
        fi
    else
        echo "DDNS_CUSTOM: 无法解析 RecordId"
    fi
fi

# 返回执行结果
/sbin/ddns_custom_updated $SUCCESS