---
layout: post
title: "shadow-mfs系统架构介绍"
description: ""
category: 
tags: ["system design"]
author: 一仕 东阳
abstract: "分布式文件系统的架构进化和性能调优重构"
thumbnail: https://raw.github.com/yaojingguo/data-mining/master/images/google-file-system.png
---
{% include JB/setup %}
## 背景简介
shadow-mfs百度运维部基于开源分布式文件系统项目[moosefs](http://www.moosefs.org/)深度二次开发的系统。我们在开源项目的基础上进行了系统架构的升级开发和单节点的性能优化。在系统可用性，可靠性和可扩展性方面有显著的提升。shadow-mfs在github上进行了开源，[shadow-mfs的github项目点这里](https://github.com/ops-baidu/shadow-mfs)





## 系统架构

![1](/assets/themes/twitter/bootstrap/img/shadow-mfs/1.jpg)


目前，shadow-mfs架构包括如上组件：

1，应用客户端（client）：业务服务访问mfs系统的节点

2，数据服务器（chunk server）：mfs系统存储数据的节点

3，元数据主服务器（master）：管理元数据节点，客户端所有的修改元数据操作和读写窗内的读取元数据操作均访问该节点

4，元数据备服务器（slave）：备份元数据，当master发生宕机后接管master服务

5，影子元数据服务器（shadow master）：只读元数据服务器，分担master的读/查询请求

其中，slave服务器和shadow master服务器是为增加mfs的扩展性和健壮性新开发的组件。

## 功能介绍


####1，shadow master

![2](/assets/themes/twitter/bootstrap/img/shadow-mfs/2.jpg)


为了解决MFS的扩展性，shadow master通过类似mysql主从同步的数据同步传输机制来传输重放master的基准元数据（metadata）和增量修改日志（changelog）来保持master和shadow mater的元数据最终一致性（Eventually Consistency）。
通过在client端的读写分离路由策略，来路由读写请求，最终达到master负载降低，扩大shadow-mfs集群规模，为shadow-mfs的master高可用做铺垫基础


####2，master的HA自动切换方案

![3](/assets/themes/twitter/bootstrap/img/shadow-mfs/3.jpg)


为了解决master的单点故障，引入主备机制来实现ha

1）基于keepalive来管理虚拟ip，client和chunk server只访问虚拟ip节点，master宕机后，slave进行接管，提供元数据服务器的可用性

2）基于session文件进行客户端会话保持，实现客户端切换master服务

3）基于replication流程和learning流程实现主从的强一致，保证元数据的高可靠

4）基于主从快速切换，实现master的优雅升级


####3，master异步多线程模型

![4](/assets/themes/twitter/bootstrap/img/shadow-mfs/4.jpg)


为了充分利用多cpu和多核的性能和解决chunk server掉线的问题，mfs将master进行线程化，分为如下线程：

1）网络线程：收发网络包，构造心跳包

2）元数据写线程：处理元数据修改请求

3）元数据读线程：处理元数据读请求

4）slave同步线程：收发slave网络包，读取元数据文件，处理replication流程和learning流程

5）shadow master同步线程：收发shadow master网络包，读取元数据文件


####4，机架感知

基于网络拓扑结构，尽量减少跨机架的读，提升读性能；通过保证数据多副本分布在多个机架，保证数据的高可靠性。

![5](/assets/themes/twitter/bootstrap/img/shadow-mfs/5.jpg)


基于百度内网极其规整的网络结构，得到网络拓扑结构如图5，由上到下层次分别为超级核心、IDC、机架和机器。他们网络拓扑距离为同一个IDC > 同一个机架 > 同一个机器。

1)	在client请求mfsmaster获取chunk位置信息列表的时候，mfsmaster根据client和chunk每个副本所在的chunkserver网络拓扑距离从小到大，对返回的列表进行排序，client在读取数据的时候就优先读取网络距离更近的副本数据，从而提高读取性能。

2)	对于mfs，整个集群会影响chunk副本分布的地方有两个，一个是chunk新建，另一个是chunk调度。

对于chunk新建，将chunk副本分布的跨机架属性放到第一优先级，chunkserver磁盘均衡性为次优先级策略，同时对磁盘剩余空间，做一个硬限制条件，根据如上策略进行chunk server选择。

对于chunk调度，当需要删除副本时，需保证chunk的跨机架属性不被破坏，同时考虑磁盘负载；当为缺失副本选取新副本时，根据跨机架属性和磁盘容量进行选择。


####5，其他功能

· chunk管理结构重构

原有的chunk server掉线流程，需要扫描chunk的hash表，当chunk数目很大的时刻（千万级别），这个时间将会很长（数十秒），当网络抖动时，几百个chunk server掉线，整个处理流程将会达到数十分钟，导致服务不可用。通过为每个chunk server构造 hash表管理相关的chunk，使得chunk server掉线的处理流程时间极大缩短（千万级chunk时，几百个chunk server掉线处理为几十秒）。

· 日志库

原有的syslog的日志记录严重影响系统的性能（某些机器数百条日志的耗时可以达到1s），通过实现mfs的日志库，实现了日志级别控制 ，日志切割等相关问题，有效提高了日志的有效性。

## 应用范围和规模

shadow-mfs系统广泛应用于百度商业产品体系，LBS产品体系，数据库文件热备等在线业务，并支撑大量关键服务。规模方面只能给一些比较粗略的数据：总集群规模超过万台服务器以上，单集群规模超过千台服务器以上。


