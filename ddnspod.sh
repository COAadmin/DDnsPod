#!/bin/sh

#################################################
# AnripDdns v5.08
# Dynamic DNS using DNSPod API
# Original by anrip<mail@anrip.com>, http://www.anrip.com/ddnspod
# Edited by ProfFan
#################################################
#获取系统日期及时间
  time=$(date)
  echo $time
# 操作系统检测
case $(uname) in
  'Linux')
    echo "操作系统: Linux"
    arIpAddress() {
        local extip
        extip=$(curl -s http://members.3322.org/dyndns/getip)
        echo $extip
    }
    ;;
  'FreeBSD')
    echo '操作系统: FreeBSD'
    exit 100
    ;;
  'WindowsNT')
    echo "操作系统: Windows"
    exit 100
    ;;
  'Darwin')
    echo "操作系统: Mac"
    arIpAddress() {
        ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
    }
    ;;
  'SunOS')
    echo '操作系统: Solaris'
    exit 100
    ;;
  'AIX')
    echo '操作系统: AIX'
    exit 100
    ;;
  *) ;;
esac

# 获取脚本目录
# See: http://stackoverflow.com/a/29835459/4449544
rreadlink() ( # Execute the function in a *subshell* to localize variables and the effect of `cd`.

  target=$1 fname= targetDir= CDPATH=

  # Try to make the execution environment as predictable as possible:
  # All commands below are invoked via `command`, so we must make sure that `command`
  # itself is not redefined as an alias or shell function.
  # (Note that command is too inconsistent across shells, so we don't use it.)
  # `command` is a *builtin* in bash, dash, ksh, zsh, and some platforms do not even have
  # an external utility version of it (e.g, Ubuntu).
  # `command` bypasses aliases and shell functions and also finds builtins 
  # in bash, dash, and ksh. In zsh, option POSIX_BUILTINS must be turned on for that
  # to happen.
  { \unalias command; \unset -f command; } >/dev/null 2>&1
  [ -n "$ZSH_VERSION" ] && options[POSIX_BUILTINS]=on # make zsh find *builtins* with `command` too.

  while :; do # Resolve potential symlinks until the ultimate target is found.
      [ -L "$target" ] || [ -e "$target" ] || { command printf '%s\n' "ERROR: '$target' does not exist." >&2; return 1; }
      command cd "$(command dirname -- "$target")" # Change to target dir; necessary for correct resolution of target path.
      fname=$(command basename -- "$target") # Extract filename.
      [ "$fname" = '/' ] && fname='' # !! curiously, `basename /` returns '/'
      if [ -L "$fname" ]; then
        # Extract [next] target path, which may be defined
        # *relative* to the symlink's own directory.
        # Note: We parse `ls -l` output to find the symlink target
        #       which is the only POSIX-compliant, albeit somewhat fragile, way.
        target=$(command ls -l "$fname")
        target=${target#* -> }
        continue # Resolve [next] symlink target.
      fi
      break # Ultimate target reached.
  done
  targetDir=$(command pwd -P) # Get canonical dir. path
  # Output the ultimate target's canonical path.
  # Note that we manually resolve paths ending in /. and /.. to make sure we have a normalized path.
  if [ "$fname" = '.' ]; then
    command printf '%s\n' "${targetDir%/}"
  elif  [ "$fname" = '..' ]; then
    # Caveat: something like /var/.. will resolve to /private (assuming /var@ -> /private/var), i.e. the '..' is applied
    # AFTER canonicalization.
    command printf '%s\n' "$(command dirname -- "${targetDir}")"
  else
    command printf '%s\n' "${targetDir%/}/$fname"
  fi
)

DIR=$(dirname -- "$(rreadlink "$0")")

# Global Variables:

# Token-based Authentication
arToken=""
# Account-based Authentication
arMail=""
arPass=""

# Load config

#. $DIR/dns.conf

# 获取域名IP
# arg: domain
arDdnsInfo() {
    local domainID recordID recordIP
    # 获取域名 ID
    domainID=$(arApiPost "Domain.Info" "domain=${1}")
    domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')
    
    # 获取记录 ID
    recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=${2}")
    recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')
    
    # Last IP
    recordIP=$(arApiPost "Record.Info" "domain_id=${domainID}&record_id=${recordID}")
    recordIP=$(echo $recordIP | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/')

    # 输出 IP
    case "$recordIP" in 
      [1-9][0-9]*)
        echo $recordIP
        return 0
        ;;
      *)
        echo "获取记录信息失败!"
        return 1
        ;;
    esac
}

# 获取数据
# arg: type data
arApiPost() {
    local agent="AnripDdns/5.07(mail@anrip.com)"
    local inter="https://dnsapi.cn/${1:?'Info.Version'}"
    if [ "x${arToken}" = "x" ]; then # undefine token
        local param="login_email=${arMail}&login_password=${arPass}&format=json&${2}"
    else
        local param="login_token=${arToken}&format=json&${2}"
    fi
    wget --quiet --no-check-certificate --output-document=- --user-agent=$agent --post-data $param $inter
}

# 更新数据
# arg: main domain  sub domain
arDdnsUpdate() {
    local domainID recordID recordRS recordCD recordIP myIP
    # 获取域名 ID
    domainID=$(arApiPost "Domain.Info" "domain=${1}")
    domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')
    
    # 获取记录 ID
    recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=${2}")
    recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')
    
    # 更新 IP
    myIP=$(arIpAddress)
    recordRS=$(arApiPost "Record.Ddns" "domain_id=${domainID}&record_id=${recordID}&sub_domain=${2}&record_type=A&value=${myIP}&record_line=默认")
    recordCD=$(echo $recordRS | sed 's/.*{"code":"\([0-9]*\)".*/\1/')
    recordIP=$(echo $recordRS | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/')

    # 输出 IP
    if [ "$recordIP" = "$myIP" ]; then
        if [ "$recordCD" = "1" ]; then
            echo $recordIP
            return 0
        fi
        # 输出错误信息
        echo $recordRS | sed 's/.*,"message":"\([^"]*\)".*/\1/'
        return 1
    else
        echo "Update Failed! Please check your network."
        return 1
    fi
}

# DDNS Check
# Arg: Main Sub
arDdnsCheck() {
    local postRS
    local lastIP
    local hostIP=$(arIpAddress)
    echo "更新域名: ${2}.${1}"
    echo "主机IP: ${hostIP}"
    lastIP=$(arDdnsInfo $1 $2)
    if [ $? -eq 0 ]; then
        echo "域名IP: ${lastIP}"
        if [ "$lastIP" != "$hostIP" ]; then
            postRS=$(arDdnsUpdate $1 $2)
            if [ $? -eq 0 ]; then
                echo "postRS: ${postRS}"
                return 0
            else
                echo ${postRS}
                return 1
            fi
        fi
        echo "本机IP和域名IP相同！"
        echo ""
        echo "本次服务已结束！"
        echo "------- Server  End -------"
        echo ""
        return 1
    fi
    return 1
}
Server() {
  echo "Test "
  return 1
  }
# DDNS
#echo ${#domains[@]}
#for index in ${!domains[@]}; do
#    echo "${domains[index]} ${subdomains[index]}"
#    arDdnsCheck "${domains[index]}" "${subdomains[index]}"
#done

. $DIR/dns.conf
