#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. $DIR/../common/log.sh

function get_pwd()
{
    host=$1
    v=`$DIR/getconfig.sh root_passwd_$host`
    if [ -z "$v" ]; then
        $DIR/getconfig.sh root_passwd_def
    fi
}

function get_all_hostname()
{
    {
    $DIR/getconfig.sh admin.hostnames;
    $DIR/getconfig.sh zookeeper.hostnames;
    $DIR/getconfig.sh hadoop.namenode.hostnames;
    $DIR/getconfig.sh hadoop.datanode.hostnames;
    $DIR/getconfig.sh spark.master.hostnames;
    $DIR/getconfig.sh spark.slave.hostnames
    $DIR/getconfig.sh client.hostnames; 
    } | sed 's/[,;]/\n/g' | sort -u | grep -v '^$'
}

fab_options=""

function fab_command()
{
    cmd="$1"
    msg="$2"

    {
        echo "fab --fabfile=$DIR/../admin/fabfile.py $fab_options $cmd > tmp.fab.log 2>&1"
        fab --fabfile=$DIR/../admin/fabfile.py $fab_options $cmd > tmp.fab.log 2>&1
    } &
    pid=$!
    wait $pid
    if [ $? -ne 0 ]; then
        LOG ERROR "FAILED: $msg"
        exit 1
    fi
    LOG INFO "SUCCEED: $msg"
}

# 初始化所有的机器

for host in $(get_all_hostname); do

    LOG DEBUG "init host $host"

    pwd=$(get_pwd $host)
    port=$($DIR/getconfig.sh ssh_port)
    ip=$(./nametoip.sh $host)

    if [ -z "$ip" ] || [ -z "$port" ] || [ -z "$pwd" ]; then
        LOG ERROR "get ip,post,pwd of $host failed: ($ip:$post, $pwd)"
        exit 1
    fi

    fab_options="--hosts=$ip:$port --password=$pwd"

    fab_command "set_hostname:name=$host" "set $ip hostname to $host"

    user=$($DIR/getconfig.sh run.user)
    group=$($DIR/getconfig.sh run.group)
    fab_command "add_user_group:user=$user,group=$group"

    dir=$($DIR/getconfig.sh install.basedir)
    fab_command "init_base_dir:dir=$dir,user=$user,group=$group"

    jdk_pkg=$($DIR/getconfig.sh package.jdk)
    pkg_dir="$DIR/../packages"
    fab_command "install_jdk_tar:tarpath=$pkg_dir/$jdk_pkg,ver=1.7.0_65"

    # JDK

    # /etc/hosts

    break;

done

# ssh no pwd, master to slave

# TODO: for all hadoop datanode, init data dir


