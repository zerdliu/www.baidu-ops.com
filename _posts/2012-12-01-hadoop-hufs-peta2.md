---
layout: post
title: "Hadoop hdfs peta2 高可用架构介绍"
description: ""
category: 
tags: 
author: 中辉
abstract: 大家对hadoop应该都不陌生，但谁知道在这高可用分布式系统背后经历过多次少的升级、优化，最终的高可用服务又是如何实现的。本文就为大家揭示这冰山一角中的maste消除单点问题。
thumbnail: /assets/themes/twitter/bootstrap/img/2012-12-01-hadoop-hufs-peta2.md/thumbnail.png
---
{% include JB/setup %}
## 背景介绍
### 1. hadoop peta的产生
目前公司的hadoop hdfs系统为了解决集群规模造成的master瓶颈(由于数据量增大，导致元数据的数据量带来的压力已经不能被一个单点master-namenode所能承担的)，开发了区别于社区版的peta 系统(这里不对社区版的进行介绍)。
### 2. peta1简介
Peta设计的主要思路就是把已经namenode的职责分解成了2部分(hadoop namenode的主要职责是:存储元数据，元数据包含文件对应的块信息，而块分布在哪些datanode上的信息是由datanode通过心跳周期性的汇报给namenode)，有2个较色代替，一个是namespace，一个是fms，部署的时候，namespace负责存储的元数据只是是记录的是一个文件所在的”pool”（每个pool有个pool id, pool均匀的分布在每个fms上，具体每个fms上分布哪些pool都是写在配置文件中的），通俗的说，就是namespace仅仅记录一个文件可以通过哪台fms上找到。这样namespace所承担的元数据压力就非常的少，所以namespace就由一台机器来承担。  
而fms负责的就是以前namenode的主要工作，它所存储的元数据记录着每个文件对应的块信息，同时它像以前的namenode一样接受所有datanode向它汇报的块信息。和以前不同的是，fms一般被部署2台以上的数量(目前我们的集群少的有3-5台，多的有10台)，来承当海量数据的元数据对节点带来的压力。
### 3. peta1的隐患及peta2的产生
Peta1的产生马上就解决了之前提到的单点压力问题，但是新的问题也随之而来：新的peta集群的hdfs master节点少则4-5台，多则上10台，大家知道，如果每台机器出问题的几率是P, 那么n台机器中有一台出问题的几率就是nP，而peta的架构中并没有考虑容错，一旦一个fms或者ns挂掉，随之而来的是整个hdfs系统的瘫痪，自从peta1上线的半年来，由于一个fms或者ns出问题导致整个hdfs瘫痪的次数不少于3次。  
在这种情况下，peta的容错机制就显得势在必行了，于是peta2的架构产生了，它与peta1的区别仅仅在添加了容错的机制，目标就是没有单点，无论peta中的master哪个挂掉了，都可以由它的备机自动切换顶替上来，避免服务的中断。
## peta2高可用原理架构简介
### 1. 主备节点方式实现高可用需要解决的问题
一旦涉及用主备节点的方式来实现高可用就有2个问题需要解决：  

1. 主备节点要对用户透明：我们拿着一个域名或者ip去访问服务，不能因为主机挂掉，备机变成主的后我们自己改访问服务的域名或ip吧，所以需要有一个封装，使得整个系统对用户透明。  

2. 数据的同步：既然备机是在每分每秒准备主机挂掉后马上顶替上去，那么它必须在任何时间内都具有和主机相同的数据才能保证，这样就需要有一套良好的数据同步机制，我们这里指的就是元数据的同步机制。  
下面，我们就为围绕这2个问题，来讲述peta2高可用架构。
### 2. peta2架构图
![hadoop_peta2_01](/assets/themes/twitter/bootstrap/img/2012-12/hadoop_peta2/hadoop_peta2_01.png)

这是一张peta2系统的示意架构图，其中，active和standby代表所有ns和fms的主节点和备节点，由于ns和fms分工上虽然不一样，但是他们的高可用性的原理和结构都相同，所以仅用一台server示意替代。
### 3. 主备节点对用户透明的实现方式
#### 1. zookeeper
Peta2高可用中，为了使得主备机器对用户透明，引入了zookeeper和adapter, zookeeper中主要存储的信息，就是主备节点的信息，它标示了每一对ns和fms的主备身份，由于ns是唯一的一对，不需要标示，而fms有n个，需要通过一个key来标示，通常使用字母：a,b,c…标示。下面就是peta2 zk中的信息示例，ip被我做了处理：
{% highlight bash %}   {"/FMS_a/ACTIVE":{"current":"xxx.xxx.109.32:55310","lastNotNull":"xxx.xxx.109.32:55310"},"/FMS_a/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_a/STANDBY":{"current":"xxx.xxx.108.31:55310","lastNotNull":"xxx.xxx.108.31:55310"},"/FMS_b/ACTIVE":{"current":"xxx.xxx.110.32:55310","lastNotNull":"xxx.xxx.110.32:55310"},"/FMS_b/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_b/STANDBY":{"current":"xxx.xxx.109.31:55310","lastNotNull":"xxx.xxx.109.31:55310"},"/FMS_c/ACTIVE":{"current":"xxx.xxx.111.32:55310","lastNotNull":"xxx.xxx.111.32:55310"},"/FMS_c/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_c/STANDBY":{"current":"xxx.xxx.110.31:55310","lastNotNull":"xxx.xxx.110.31:55310"},"/FMS_d/ACTIVE":{"current":"xxx.xxx.112.32:55310","lastNotNull":"xxx.xxx.112.32:55310"},"/FMS_d/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_d/STANDBY":{"current":"xxx.xxx.111.31:55310","lastNotNull":"xxx.xxx.111.31:55310"},"/FMS_e/ACTIVE":{"current":"xxx.xxx.113.32:55310","lastNotNull":"xxx.xxx.113.32:55310"},"/FMS_e/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_e/STANDBY":{"current":"xxx.xxx.112.31:55310","lastNotNull":"xxx.xxx.112.31:55310"},"/FMS_f/ACTIVE":{"current":"xxx.xxx.116.32:55310","lastNotNull":"xxx.xxx.116.32:55310"},"/FMS_f/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_f/STANDBY":{"current":"xxx.xxx.113.31:55310","lastNotNull":"xxx.xxx.113.31:55310"},"/FMS_g/ACTIVE":{"current":"xxx.xxx.148.32:55310","lastNotNull":"xxx.xxx.148.32:55310"},"/FMS_g/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_g/STANDBY":{"current":"xxx.xxx.116.31:55310","lastNotNull":"xxx.xxx.116.31:55310"},"/FMS_h/ACTIVE":{"current":"xxx.xxx.118.32:55310","lastNotNull":"xxx.xxx.118.32:55310"},"/FMS_h/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_h/STANDBY":{"current":"xxx.xxx.156.31:55310","lastNotNull":"xxx.xxx.156.31:55310"},"/FMS_i/ACTIVE":{"current":"xxx.xxx.119.32:55310","lastNotNull":"xxx.xxx.119.32:55310"},"/FMS_i/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_i/STANDBY":{"current":"xxx.xxx.118.31:55310","lastNotNull":"xxx.xxx.118.31:55310"},"/FMS_j/ACTIVE":{"current":"xxx.xxx.155.32:55310","lastNotNull":"xxx.xxx.155.32:55310"},"/FMS_j/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/FMS_j/STANDBY":{"current":"xxx.xxx.119.31:55310","lastNotNull":"xxx.xxx.119.31:55310"},"/NS/ACTIVE":{"current":"xxx.xxx.108.32:55310","lastNotNull":"xxx.xxx.108.32:55310"},"/NS/NNMONITOR":{"current":null,"lastNotNull":"NN_MONITOR_NODE"},"/NS/STANDBY":{"current":"xxx.xxx.75.55:55310","lastNotNull":"xxx.xxx.75.55:55310"}}
{% endhighlight %}
大家可以看到每对fms是通过”FMS_字母”的方式标示的，而关于其他信息，在后边会进一步解释。讲到这里大家就可以明白，我们只要通过这个zk就可以知道任何时候的主机是谁，请求服务前只要去zk查询主机，这样主备无论怎样切换，对用户来说都是透明的了。
#### 2. adapter
为了配合zookeeper更好的工作，peta2高可用架构引入了adapter这个角色，adpter其实相当于一个代理，对于用户来说，它是提供服务的接口，客户端提出的服务其请求都是通过adapter, adapter通过zk的信息，把用户的请求定向到active(主机)上, 使用adpter的好处在于:
+ zooKeeper的HTTP封装解决ZooKeeper频繁建立连接的性能问题
+ 对zookeeper不可用增加了容错机制：adapter会对zk的信息做一个缓存，这样如果zk挂掉，adapter中还缓存有zk的数据。
+ Adapter的工作过程：
+ init 连接zk
+ 2\.syncDate 同步zk数据，获得最近一个非空值（ns/fms 的 active和standby信息）(每秒一次调用syncDate方法去zk同步信息)。
+ startRpc 监听 54310
+ startHttpServer  开放一个web方式用来提供缓存的zk信息，同时将请求（dfslogin 、status等这些ns/fms的web功能接口重新定向(redirect)到active的ns和fms上）

### 4. 数据同步
![hadoop_peta2_02](/assets/themes/twitter/bootstrap/img/2012-12/hadoop_peta2/hadoop_peta2_02.png)

数据同步这里分为两部分：一部分是元数据(记录文件和块的对应关系)的同步，一部分是块信息(使得fms知道每个块在哪个datanode上)的汇报。  
先说说元数据如何同步的：  
如图2所示，fms的standby还是要通过http协议去active拖取edit进行checkpoint的，但是与以前的namenode不同，这个edit是要被replay到内存的，这就避免了一旦主机挂掉备机需要启动的时候还要花费大量时间把元数据加载到内存。  
而这个checkpoint和replay的具体过程如下:
+ 主机方面：active 每分钟会主动roll一个新的edit并以编号的形式向上累加递增：edit.1 edit.2 edit.3 … edit.n+1
+ 备机方面：standby 每秒去问active询问有没有新的edit生成，如果有会把新edit拖过来，然后replay这个edit到内存。

同时，standby 1个小时做一次checkpoint (edit中的操作合并到fsimage产生新的fsimage ), 这个checkpoint和以前的namenode和peta不同, fsimage会生成一个fsimage.n+1的新fsimage，这个过程是由：fsimage.{n}+edits.{n+1}=fsimage.{n+1} 这样完成的。产生了新的fsimage后，还是通过http协议put 推送给active服务器(active 的策略是保留7天的edit和image)。
### 5. 元数据同步使用的http服务
在peta2中，为了实现这种元数据的同步，rd单独写了一个imagesever的服务，它是一个servelet的http server，在active上启动，可以通过这个接口获得edit和image的版本信息，并拖取edit，推送fsiamge。
### 6. 未来的数据同步模式
在未来可能考虑使用nas设备来完成数据的同步。
### 7. 块信息同步
Peta2 的datanode会同时向active和standby fms汇报块信息，来保证块信息的同步。由于standby的元数据会相对落后于active,所以当无法找到元数据的块汇报会被FMS保存到DeferedQueue，待到元数据同步跟上后再回放。
### 8. failover
#### 1. master节点的failover  
说到failover不得不说一个前提，就是：目前peta2只支持手动停止active机器，standby自动切换，听起来比较让人沮丧，但是这个只是一个过渡阶段，后续会让这种机制愈发强健。  
好了，回到正题，failover 的触发过程既然是手工触发，那么我们需要首先在active上启动一个nnmonitor进程(关于其作用稍后便说)。接着我们手工停止active的namenode进程，这个时候active会主动去zk注销自己的active信息, 这样的好处是，可以使得整个高可用系统在第一时间发现active已经挂掉，从而进入failover模式(而如果active是以意外方式挂掉，比如：断电，那么zk就需要过一个超时时间，才能发现active挂掉)。  
如图1所示，在这个高可用系统中，standby是在一直（秒级频率监听）监听zk的，standby通过zk的信息发现active机器挂掉，同时standby和nnmonitor这2个角色都存在（因为nnmonitor会代替死去的active的namenode做最后一次roll edit），那么它开始进入failover模式。  
Nnmonitor在本地会监视着namenode的进程，发现active挂掉后，会代替active的namenode进程去roll最后一次edit让目前的edit变成edit.{nowmax + 1} , 以便standby可以拖取获得最新的元数据。接下来的事情就顺理成章了：  
Standby 等待元数据同步完成,等待丢块数少于阈值（这个而是只有FMS涉及的，namespace不存在这个问题，它不care块在那些datanode上, 而standby需要这些信息，它需要命令所有的datanode做一次report）上面那些做完后，退出安全模式。Standby向ZK注册为Active模式
#### 2. datanode节点的重试
+ 发现NN不可用  或 收到ZK通知NN不可用。
+ 向ZK获取最新的Active和Standby信息。

#### 3. 客户端重试
+ 解析AdapterNode的域名乱序尝试访问一个AdapterNode，询问NS或者FMS地址。
+ 请求NS或FMS失败，重试向AdapterNode重新索取NS或者FMS地址直到成功或者超时。

##Peta2 元数据的备份与监控
###1. 备份
active standby 相同 ：通过rsync在本地备份，edit全量备份(考虑到只要有edit就相当于具有所有的元数据)，fsiamge(仅仅是为丢了数据后，不用play太多的edit而已)一天一个，后续存到hdfs上。
###2. 监控
~/hadoop-data/dfs/name中最新的edit和image之间版本号不能相差超过100，超过100说明checkpoint整个过程中有异常则发出报警，通过shell + crontab 实现。
