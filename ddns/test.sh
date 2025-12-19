export DOMAIN="yyfvps.cn"
export SUB_DOMAIN="ali"
export WAN_IP="2.2.2.2"
export DDNS_SECRET_ID="AKIDKixELl1GZigRzJRM3XqzxhIix1ta50jH"
export DDNS_SECRET_KEY="RrHZYUIwPfhXDgwymOq6BbqrgHemiQ2T"

response=$(bash "./dnspod_api.sh")

if [[ -z "$response" ]]; then
    echo "DDNS_CUSTOM: API 返回为空，请检查网络"
    exit 1
fi

if echo "$response" | grep -q "Error"; then
    if echo "$response" | grep -q "ResourceNotFound.NoDataOfRecord"; then
        echo "DDNS_CUSTOM: 不存在记录，开始创建"
        bash ./dnspod_api.sh "create_record" && SUCCESS=1
    else
        echo "DDNS_CUSTOM: API 错误: $response"
    fi
else
    # 使用正确的变量名执行 jq
    echo "$response"
    record_id=$(echo "$response" | jq -r '.Response.RecordList[0].RecordId // empty')
    record_ip=$(echo "$response" | jq -r '.Response.RecordList[0].Value // empty')

    if [[ -n "$record_id" ]]; then
        if [[ "$record_ip" != "$WAN_IP" ]]; then
            echo "DDNS_CUSTOM: IP 变化 ($record_ip -> $WAN_IP)，开始修改"
            bash ./dnspod_api.sh "modify_record" "$record_id" && SUCCESS=1
        else
            echo "DDNS_CUSTOM: IP 未改变，状态正常"
            SUCCESS=1
        fi
    else
        echo "DDNS_CUSTOM: 无法解析 RecordId"
    fi
fi