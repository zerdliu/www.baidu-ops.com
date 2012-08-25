---
layout: post
title: "ssh hang 问题追查"
description: ""
category: 
tags: ['ssh','practice','problem solved']
author: 治伟
abstract: "一些原因会让ssh hang住，本文即介绍了一种场景，并介绍了定位问题的过程。希望大家能学到问题分析和定位的思路。"
thumbnail: http://www.blyon.com/blogimg/openssh.png
---
{% include JB/setup %}

## 问题表现
Log平台短期内两次出现多个统计任务ssh hangg住的问题。具体症状就是：ssh执行机执行脚本时，比如：

{% highlight bash %}
ssh test@jx-nsop-test01.jx \
"test -e
/home/test/dw/runtime//201202130000/23111_5076668/output/hadoop_1_success_mark"
2>&1
{% endhighlight %}

这个命令理应很快返回结果，但问题是hang住了，直到50分钟后被系统检测到才被杀死重跑。严重影响任务的完成时间，对下游用户造成了影响，需要马上解决。相信这个问题大家在工作中都有遇到过吧？

## 问题分析
经过统计，我们发现，这个问题80%的概率是发生在跨地域交互，我们初步怀疑跟网络问题有关。

我们已经知道是ssh的服务出现问题，我们先查看了我们的机器的网卡情况，看看是不是由于我们网卡打满出现了瓶颈问题造成的，经过排查网卡在出现问题的时段没有问题。然后我们考虑可能是长距离网络传输问题造成了上述的问题，于是我们联系了网络组的人，沟通了一下在这个时段是不是有网络的变动，经过网络组的排查确实在这两次的服务出现的问题的时间段里都做了网络的调整，这样可以得出一个猜测，可能是由于网络的调整造成了网络抖动，部分数据包丢失，从而导致ssh-hang的发生，基于上面的猜测，我们通过wiki和网上搜索了相关文档发现，修改配置的以下几个参数：

`/etc/ssh/ssh_config`

{% highlight bash %}
ConnectTimeout 60
ServerAliveInterval 60
ClientAliveInterval 90
{% endhighlight %}

可以解决问题，于是我们做了相应的修改，结果很显著，ssh-hang的问题发生的概率减少了90%左右，可是还会出现ssh-hang的问题，问题还是没有彻底的解决。既然是网络丢包导致的问题，我们就对网络进行监控，追查到底是哪里出现的问题，首先我们建立一个专门监控ssh-hang的监控策略，并且开始抓包实时监控中控机的22号端口，这样一旦再次出现ssh-hang的问题我们就会第一时间捕捉问题现场，追查原因。

## 问题定位

在又一次的网络调整的时段，ssh hang 的问题如约而至，我们迅速定位了问题。凌晨的时候又发生了任务hang住的问题，通过抓包得到的数据，分析出任务hang在系统调用：

{% highlight c %}
select(7, [6], NULL, NULL, NULL
select(10, [6], [], NULL, NULL
read(6,
……
{% endhighlight %}

read的时候，在对应的/proc/PID/fd下，6对应的是一个socket

{% highlight bash %}
lrwx------  1 test test 64 Feb 18 01:12 6 -> socket:[2606004771]
{% endhighlight %}

也就是说由于socket:[2606004771]包的丢失，造成了这次的ssh-hang的问题，问题出现在read函数这，我们log组就追查了openssh的源码，了解到在4.9版本前存在一个bug： ssh命令执行时，如果在ssh_connect 之后，但在ssh_exchange_identification交换之前出现网络问题，则ssh client可能会hang住（因为socket在ssh_exchange_identification之后才设置为nonblocking状态），后来我们分析openssh3.9p1的源码得出：

{% highlight c %}
int main() {
    initialize_options(&options);
    /* Parse command-line arguments. */
    /* Open a connection to the remote host. */
    ssh_connect(host, &hostaddr, ...);
    /* Log into the remote system.  This never returns if the login
fails. */
    ssh_login(&sensitive_data, host, (struct sockaddr *)&hostaddr, pw);
    exist_status = ssh_session();//client_loop() called
    packet_close();
}
void ssh_login() {
    /* Exchange protocol version identification strings with the server.
*/
    ssh_exchange_identification();
    /* Put the connection into non-blocking mode. */
    packet_set_nonblocking();    //在这个阶段才将数据包设置问异步状态
    ssh_kex();//key exchange
    ssh_userauth();//authenticate user
}
/*
* Waits for the server identification string, and sends our own
* identification string.
*/
void ssh_exchange_identification() {
    /* Read other side\'s version identification. */
    while (true) {
        int len = read(connection_in, &buf[i],
1);//由于数据包的丢失，这里read不到数据，这时数据包还是同步状态，会hang在这个地方
        if ($buf[i] == '\n') {
            break;
        }
    } // Check that the versions match. 
}
void client_loop() {
    client_wait_until_can_do_something();
}
void client_wait_until_can_do_something() {
    //server_alive_count_max只在server_alive_check()中调用了
    if (options.server_alive_interval == 0 || !compat20)
            tvp = NULL; 
    else {
            tv.tv_sec = options.server_alive_interval;
            tv.tv_usec = 0;
            tvp = &tv;
    }
    $ret = select((*maxfdp)+1, *readsetp, *writesetp, NULL, tvp);
    if (ret < 0) {
    } else if ($ret ==0) {
//因为目前没有设定这个server_alive_interval配置，其实这句话不会被执行，server_alive_count_max
,只对timeout重试次数负责，默认是3
        server_alive_check();
    }
}

{% endhighlight %}
在3.9p1源码中，如果hang住发生在ssh_connect中（如远程机器禁用了客户端的ip），那么可以设置ConnectTimeout从而在ssh_connect阶段就能发现问题并解决。如果修改ServerAliveInterval，则在ssh_login的后续执行过程中，连接忽然失效的情况可以timeout；也就是我们之前设置的参数是针对解决这两个问题的，但本次hang住在read系统调用中，openssh的read调用不多，其中在ssh_login函数的ssh_exchange_identification有read函数读取socket，由于在此时未将socket设置为nonblock状态，因此就可能阻塞，而且在这个版本中，没有参数可以阻止这种情况导致的hang住的问题，在4.9以后的版本中这个bug得到了修正，现在看只能通过升级openssh的版本来解决这个问题了。

## 问题总结
在公司网络核心交互日益增多的情况下，网络抖动这类情况不可避免的会发生，ssh是大家每天必用的工具，而且很多任务的提交也用了ssh，这个问题的定位解决发出来希望对大家有一定参考意义.

