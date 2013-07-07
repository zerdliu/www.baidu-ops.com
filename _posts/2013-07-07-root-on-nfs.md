---
layout: post
title: "Root on NFS"
description: ""
category:
author: baidu-ops 
tags: [NFS]
thumbnail: /assets/themes/twitter/bootstrap/img/2013-07-07-root-on-nfs.md/thumbnail.jpg
abstract: 有这样一台linux服务器，因为某开源软件的bug，因为绝对里路径多了一个空格，把/usr/sbin 给删了…你执行过 rm –rf / foo吗？
---
{% include JB/setup %}

##系统简介

设想这样一台linux服务器：
根分区是只读的，非常安全，即使root账户也无可奈何，因为根分区是只读的。这个只读的根分区（或者称为定制的一个操作系统），实际上是独立的客户端服务器通过网络从一个中控节点挂载的一份操作系统镜像，这样可以集中控制操作系统，并且任何修改都是实时生效的，当然也允许客户端服务器有特性的文件存在，例如etc下的某些配置文件，这个系统是用我们耳熟的bootp，tftp，nfs，dhcp这些服务搭建起来的。

##核心单点

中控节点是一个单点，保存了一个或者多个定制的操作系统，提供如上所述的各种服务，如果有单点故障，会导致整个集群都瘫痪。所以需要有备机实时同步数据，并且使用虚IP来提供服务，这里采用了开源的linux-ha下的heartbeat和drbd服务来避免单点故障，主备机自动切换启动服务，实现秒级的自动迁移，数据是DRBD实时同步的。

##特性优点

1. 集中，只维护一个操作系统

2. 实时，任何修改都是实时生效的

3. 安全，root账户都无可奈何啦

4. 例外，允许特性文件存在

##适用场景

1. MMORPG类似的服务

	服务器端只提供计算和数据库服务

2. 安全等级很高

	root用户登录机器也不能干坏事了，非常安全。

3. 其他场合

	这么一个古灵精怪的系统总有其他用武之地吧！

##搭建步骤

![infrastructure](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/infrastructure.jpg)

1. drbd和heartbeat的部署

2. 重新编译内核

3. 定做操作系统

4. tftp服务

5. dhcp服务

6. nfs服务

7. pxe网卡

step by step…

详细步骤省略，这几种服务的官网可以查到相关的详情。

【重点提示】

I.编译内核：

module参数编译的只能在内核启动之后才会工作,所以我们需要选择y.

把nfs编译到内核里，支持Root file system on NFS等

如何让 var tmp正常，不然很多系统自带的服务启动失败。

Ramdisk: 把var tmp目录放到内存里

II.启动系统：

1. 带上mac地址出发吧！

	开机，网卡引导； 自动寻找DHCP服务； 

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/1.png) 

2. 下载我们编译的内核文件。

	通过dhcp和tftp来下载定制的内核文件。

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/2.png)

3. 定位自己的IP，启动操作系统。

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/3.png)

4. 把var，tmp放到内存里。

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/4.png)

5. 登录操作系统

	顺利启动完毕，可以登录进去了！

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/5.png)

6. 看看Root on NFS是怎么个挂载法。

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/6.png)

7. 试试rm –rf / 吧！

	![img1](/assets/themes/twitter/bootstrap/img/2013-07/root-on-nfs/7.png)

