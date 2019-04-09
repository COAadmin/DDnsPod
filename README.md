#DDnsPod
基于DNSPod用户API实现的纯Shell动态域名客户端。

原项目:[https://github.com/anrip/ArDNSPod](https://github.com/anrip/ArDNSPod "https://github.com/anrip/ArDNSPod")

PS:此项目基于ArDNSPod修改，稍微修改了下，解决了在某些环境下获取到的是局域网IP的问题。</p>

# Usage

修改`dns.conf`后直接运行`ddnspod.sh`即可，支持cron任务。

配置文件格式：
```
# 安全起见，不推荐使用密码认证
# arMail="test@gmail.com"
# arPass="123"

# 推荐使用Token认证
# 按`TokenID,Token`格式填写
arToken="12345,7676f344eaeaea9074c123451234512d"

# 每行一个域名
arDdnsCheck "test.org" "subdomain"
```
# Credit

Original: anrip

Redit: [COAadmin](http://www.coaadmin.cn "COAadmin")
