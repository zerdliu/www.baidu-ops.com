---
layout: post
title: PBUI开启超线程的性能调研
description: ""
category: 
tags: 
author: 姚珺
abstract: 超线程技术在产品上的应用实例
thumbnail: /assets/themes/twitter/bootstrap/img/2012-12-01-PBUI-open-Hyper-Threading.md/thumbnail.png
---
{% include JB/setup %}

## 超线程介绍
超线程（HT，Hyper Threading）是英特尔所研发的一种技术，于2002年发布。它利用特殊的硬件指令，把一个物理芯片模拟为两个逻辑内核，共享CPU的全部资源，使单个处理器完成线程级并行计算，减少了CPU闲置时间，在相同时间内完成了更多的任务，提高了CPU的运行效率。在处理过程中，处理器内部的每个逻辑处理器都可以单独对中断做出响应，并且为了避免CPU资源冲突，第二个逻辑处理器使用的是第一个逻辑处理器在处理第一个线程时暂时闲置的处理单元（如下图所示）。不同于多核处理器间的工作原理，超线程中2个逻辑处理器需要共用处理单元、cache和系统总线接口，如果两个线程同时需要同一资源时，其中一个逻辑处理器就要暂停等到资源闲置时才能继续运行，因此超线程带来的性能提升无法等同于两个相同时钟频率处理器带来的性能提升，Intel的官方数据是30%左右的性能提升。

![PBUI_HT_01](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_01.png)

##pbui开启超线程的性能调研
由于超线程的性能提升取决于程序对多线程的支持，只有当多线程充分发挥其作用的时候，超线程才能进一步提升CPU利用率，提高程序的吞吐量。对于前端ui这种多线程且为cpu消耗型的服务，超线程是否能有效提升其性能呢？

主机名		|初始套餐|厂商  |型号		|CPU(型号:数量)					|内存(型号:数量)			|硬盘(型号:数量)	|超线程
------------------------|--------|------|-----------|-------------------------------|---------------------------|-------------------|--------
cq01-forum-pbphp02.cq01|KW1 |IBM   | X3650M3	|INTEL Nehalem E5645 2.4GHZx2	|IBM PC3L-10600 8GB 2Rx8	|IBM SAS 300G 10Kx8	|关闭
cq01-forum-pbphp00.cq01|KW1 |IBM	|X3650M3	|INTEL Nehalem E5645 2.4GHZx2	|IBM PC3L-10600 8GB 2Rx8	|IBM SAS 300G 10Kx8	|关闭
cq01-forum-pbphp31.cq01|KW1 |IBM	|X3650M3	|INTEL Nehalem E5645 2.4GHZx2	|IBM PC3L-10600 8GB 2Rx8	|IBM SAS 300G 10Kx8	|开启
cq01-forum-pbphp30.cq01|KW1 |IBM	|X3650M3	|INTEL Nehalem E5645 2.4GHZx2	|IBM PC3L-10600 8GB 2Rx8	|IBM SAS 300G 10Kx8	|开启

### 1. 机器
如上表所示，关闭与开启超线程的机器各选取两台。四台机器具有相同的硬件配置均为12核。不同的只是由于开启了超线程，机器30、31在用户看来为24核，而00、02为12核。  
从接入层分流来看，ta中这四台机器配置了相同的权重weight=3。虽然当前pbui使用了基于baiduid的一致性哈希策略，正常情况下该权重不生效。但至少说明异常时一致性哈希策略退化为按照权重的轮询后，四台机器的qps也应基本相同。接下来就看一下两组机器的性能对比。
	
### 2. 性能参数
#### 1. qps基本相同  
+ 查询数量相同:<br />观察了12.03 20:10--12.04 20:10一整天的流量，四台机器的qps基本一致。
	![PBUI_HT_02](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_02.png)  
+ 网卡入口流量相近<br />![PBUI_HT_03](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_03.png)  
	观察12\.03 15:10--16:10一个小时的网卡入口流量，均在8,282,490~7,043,520bytes/s范围内波动。  
+ 网卡出口流量相近<br />![PBUI_HT_04](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_04.png)  
网卡出口流量稍有差异，00、02在15:10左右有流量瞬间突增，其它时间的流量基本上保持在四五M。

综上，从qps、网卡入出口流量来看，两组机器的压力基本上可以看作是相同的。
#### 2. 性能参数比
+ 平均耗时相同<br />从12.03 20:10--12.04 20:10一整天的请求耗时来看，两组机器的平均耗时基本保持一致，且并未由于高峰期流量上涨而有明显的处理时间加长。也就是说，超线程更加频繁的线程切换并未给30、31带来明显的处理时间加长，当然也没有缩短处理时间。

	![PBUI_HT_05](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_05.png)  
+ CPU_IDLE差距较大<br />![PBUI_HT_06](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_06.png)  
	12\.03 20:10--12.04 20:10一天的数据来看，两组机器的CPU_IDLE基本保持在7~20的差距。  
	开启超线程的机器的idle均值基本在85左右，而未开启的机器在67左右。  
	![PBUI_HT_07](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_07.png)  
	由上图可以更为直观的看到两组机器的CPU_IDLE与QPS的关系：未开启超线程的机器（00,01）在qps加重的过程中idle下降的更快。在qps为124时，未开启超线程的机器idle已降至54，而开启超线程的机器还在74。按照贴吧的扩容规范，核心ui的cpuidle在高峰期均值低于55就可以考虑扩容。可见开启超线程之后可以提高机器的极限压力，减少很多扩容（撒花撒花).  
+ CPU使用占比<br />	![PBUI_HT_08_01](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_08_01.png)
![PBUI_HT_08_02](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_08_02.png)  
由图中可见，CPU_IDLE的时间差异主要在于us和sys时间上，未开启超线程的机器的用户时间和系统时间都是两倍，基本符合预期。

#### 3. 小结
理论上讲，超线程由于能够更有效的利用CPU的空闲时间，提升系统的吞吐量；但是由于开启超线程会使得线程切换更加频繁，会拉长单一任务的处理时间。  
从pbui的线上数据来看，在相同吞吐的情况下超线程并没有使响应时间加长，当然也没有提升（见第2小节平均耗时对比）。但是超线程提升了机器（30,31）的处理能力，提升了系统的极限性能。这跟pbui服务特性有关：  
pbui作为前端ui，接受前端接入层（nginx_access）分流来的用户请求，并到相应后端，如member_perm、btx、post_comment取得数据（如下图所示）并拼装返回给用户。  
![PBUI_HT_09](/assets/themes/twitter/bootstrap/img/2012-12/PBUI_HT/PBUI_HT_09.png)  
可见pbui对一条请求的处理中存在大量的网络通信，必然会有很多IO等待，唯有充分利用这些等待时间才能提高CPU的利用效率。因此，对于开启了128个php-cgi进程的ui服务，超线程的应用使得这些进程的并行度进一步的提升，从而提升了服务的极限性能。
##结论
超线程并不总是能提升系统的性能，需要业务本身性能对多线程足够支持才行。  
pbui就是一个正面例子，相信对于贴吧很多前端ui来说，超线程都可以有类似的改善接下来会选择线上一些其它ui开启超线程做小流量调研。
