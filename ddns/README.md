# ASUSWRT-Merlin DDNS 更新脚本

这是一个为华硕路由器 ASUSWRT-Merlin 固件设计的 DDNS (动态域名解析) Custom（自定义）更新脚本，支持使用腾讯云 DNSPod API 自动更新域名解析记录。

## 文件结构

- [ddns-start](./ddns-start): 主启动脚本
- [dnspod_api](./dnspod_api): DNSPod API 接口实现脚本
- [asuswrt-merlin-ddns](./asuswrt-merlin-ddns): DDNS 主逻辑处理脚本

## 脚本详解
### ddns-start
这是路由器调用的入口脚本，主要功能包括：
- 关闭华硕路由器硬件加速 (`fc disable`)
- 调用 `asuswrt-merlin-ddns` 执行 DDNS 更新逻辑
- 更新完成后重新开启硬件加速 (`fc enable`)

### dnspod_api
DNSPod API 接口封装脚本，实现了与腾讯云 DNSPod 服务的交互：

#### 主要功能
- 支持 DescribeRecordList (查询记录)
- 支持 CreateRecord (创建记录)
- 支持 ModifyRecord (修改记录)

#### 认证机制
采用腾讯云标准的 TC3-HMAC-SHA256 签名算法：
1. 构建规范请求串 (`build_canonical_request`)
2. 拼接待签名字符串 (`build_string_to_sign`)
3. 计算签名 (`calculate_signature`)
4. 拼接授权头 (`build_authorization`)

#### 配置参数
下面为脚本默认参数，可自行修改，
若无必要无需修改
   ```bash
   DOMAIN="${DOMAIN:-example.com}"           # 域名
   SUB_DOMAIN="${SUB_DOMAIN:-test}"          # 子域名
   WAN_IP="${WAN_IP:-8.8.8.8}"              # WAN IP 地址
   secret_id="${DDNS_SECRET_ID:-id}"         # 腾讯云 Secret ID
   secret_key="${DDNS_SECRET_KEY:-key}"      # 腾讯云 Secret Key
   ```


### asuswrt-merlin-ddns
DDNS 主逻辑处理脚本：

#### 执行流程
1. 从 NVRAM 获取域名配置信息
2. 提取域名和子域名部分
3. 获取当前 WAN IP 地址
4. 调用 [dnspod_api](file://D:\workSpace\demo\Script\ddns\dnspod_api) 查询现有记录
5. 根据查询结果决定创建新记录或修改现有记录
6. 使用 `/sbin/ddns_custom_updated` 返回执行结果

#### 日志记录
使用 `logger` 命令记录操作日志，可在系统日志中查看：
   ```bash
   logread | grep DDNS_CUSTOM
   ```


## 使用方法

1. 修改 [asuswrt-merlin-ddns](./asuswrt-merlin-ddns) 中的认证信息：
   ```bash
   export DDNS_SECRET_ID="你的腾讯云Secret ID"
   export DDNS_SECRET_KEY="你的腾讯云Secret Key"
   ```


2. 将脚本部署到路由器适当位置（通常为 `/opt/config/`）
3. 将[ddns-start](./ddns-start) 移动到 `/jffs/scripts/`
4. 修改 `/jffs/scripts/ddns-start` 文件中调用 `asuswrt-merlin-ddns` 脚本的调用路径
   ```bash
   bash /opt/config/asuswrt-merlin-ddns
    ```
5. 在路由器管理界面开启并配置自定义 DDNS 服务

## 注意事项

- 确保路由器已安装 `jq` 工具用于 JSON 解析
- 腾讯云 API 需要正确的时间同步
- 建议使用环境变量存储敏感信息而不是硬编码在脚本中
- 脚本会自动处理记录创建和更新，避免重复记录
- 使用 `RecordLineId` 而不是 `RecordLine` 来规避签名问题