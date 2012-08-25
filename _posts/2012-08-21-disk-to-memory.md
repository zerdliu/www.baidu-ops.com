---
layout: post
title: "系统优化--磁盘缓存放入内存"
description: ""
category: 
tags: ["performance"]
author: 王伟
abstract: "机器富余的内存可以如何使用？做虚拟机？混部？其实还有一种方法--当磁盘用"
thumbnail: "http://img.tfd.com/cde/CACHDISK.GIF"
---
{% include JB/setup %}

## 背景
News浏览架构升级到lamp后开启了apache的磁盘缓存，使用了eacc加速器，并使用eacc对数据进行了缓存。这些缓存数据并不是放在内存中，而是放在了磁盘上，缓存的频繁读写使得磁盘IO开销很大，cpu-wa达到10~15。另一方面，线上服务器硬件配置越来越高，前端机器的内存高达48甚至64G，只部署webserver的前端机器为cpu和网络消耗型，内存使用率低于50%。因此，希望将前端机器的磁盘缓存放入闲置的内存中，一可以提升内存的利用率，二则可以提升机器的极限处理性能。
调整部署方案是一个办法，修改apache或者php的相关配置，将缓存放入内存也是一种可能的解决办法，但，恰好OP在了解内存文件系统的东西，因此如果能将磁盘缓存目录放入内存文件系统中，会是简单易行的。

## 名词解释
内存文件系统：使用内存作为存储介质，并充分发挥内存特性的一类文件系统

## 内存文件系统调研
内存文件系统可以直接通过简单mount的方式把内存分配一块出来虚拟成文件系统直接使用，这就提供了一种不修改程序、配置的情况下，将普通文件系统里的数据直接放进内存的方法。如下为一些参考资料：
1. [文件系统剖析](http://www.ibm.com/developerworks/cn/linux/l-linux-filesystem/#N10208)
2. 现有的内存文件系统介绍[tmpfs、ramfs、ramdisk、proc](http://linux.net527.cn/Linuxwendang/xitongguanliyuan/1926.html)

#### TmpFS优缺点
1. 需要内核支持，2.4以上版本已经支持；
2. mount即可完成，构架在linux虚拟内存管理基础之上的，因此数据有可能在内存，也有可能在交换分区中。重启后文件系统不在存在，数据会丢失，需要重新mount，可以配置在fstab里，启动便加载；
3. [支持设定文件系统大小](http://jinbangli.blog.163.com/blog/static/115625352200932382517151/)

#### RamFS优缺点
1. mount即可完成
2. 重启后数据丢失。重启后文件系统不在存在，需要重新mount，可以配置在fstab里，启动便加载
3. 不支持设定文件系统大小，占用大小动态增长，有内存耗尽的风险

#### RamDisk
1. 需要格式化内存，格式化为ext2或其他
2. 然后mount

#### 结论
内存文件系统不需要读取硬盘，只读取内存，也就是使IO的等待时间、平均排队时间、对列大小等减低，提高吞吐率，节省出的IO时间，就是提升了服务时间。ramdisk需要格式化,ramfs占用空间大小不可控,因此选择tmpfs。

## 部署方法及测试

#### 部署方法
1. 建立一个目录`/mnt/tmpfs`，以tmpfs文件系统格式mount到`/mnt/tmpfs`,指定使用最大内存

{% highlight sh %}
mount -t tmpfs -o size=50M tmpfs /mnt/tmpfs/
{% endhighlight %}

2. 用df -h 来检查是否正确.如果mount成功后,该目录大小是10G
3. 使用free 来查看内存使用情况

#### 测试对比

通过对比普通的磁盘文件和tmpfs文件来比较其读写性能。/mnt/tmp为普通的文件目录，/mnt/tmpfs为tmpfs文件系统目录，/dev/shm也为tmpfs文件系统。

* 写普通文件到普通文件，速率：15.153 MB/秒

{% highlight sh %}
root@tc-news-spi00.tc:/mnt/tmpfs# time dd if=/home/work/tmp_rm/A/SrData0722/722_1mstrip11.0005 of=/mnt/tmp/zero bs=1M count=128
记录了 128+0 的读入
记录了 128+0 的写出
134217728 bytes (134 MB) copied，8.7819 秒，15.3 MB/秒
{% endhighlight %}

* 普通文件到tmpfs文件，速率：32.7 MB/秒

{% highlight sh %}
root@tc-news-spi00.tc:/mnt/tmpfs# time dd if=/home/work/tmp_rm/A/SrData0722/722_1mstrip11.0014 of=/mnt/tmpfs/zero bs=1M count=128
记录了 128+0 的读入
记录了 127+0 的写出
134082560 bytes (134 MB) copied，4.10379 秒，32.7 MB/秒
{% endhighlight %}

* 32写tmpfs文件到普通文件，速率：32.2 MB/秒

{% highlight sh %}
root@tc-news-spi00.tc:/mnt/tmpfs# time dd  if=/mnt/tmpfs/zero of=/mnt/tmp/zero bs=1M count=128
记录了 127+1 的读入
记录了 127+1 的写出
134082560 bytes (134 MB) copied，4.16382 秒，32.2 MB/秒
{% endhighlight %}

* 写tmpfs文件到tmpfs文件，速率：64.2 MB/秒

{% highlight bash %}
root@tc-news-spi00.tc:/mnt/tmpfs# time dd  if=/mnt/tmpfs/zero of=/dev/shm/zero bs=1M count=128
记录了 127+1 的读入
记录了 127+1 的写出
134082560 bytes (134 MB) copied，2.08752 秒，64.2 MB/秒
{% endhighlight %}

## 线上实际情况

#### 部署与性能测试
16台48G前端机器，各开辟了1个20G大小的tmpfs文件系统。测试数据在下一小节中详细阐述。

#### 性能表现
1. 每秒写磁盘次数对比：1100 -> 5 (次)
![write_performance_times](/assets/themes/twitter/bootstrap/img/disk-to-memory/write_performance_times.png)
2. 每秒写数据量对比 ：8100 ->  50 (KB) 
![write_performance_Bytes](/assets/themes/twitter/bootstrap/img/disk-to-memory/write_performance_Bytes.png)
3. 每秒写磁盘扇区数对比 :  11000 ->  200 (块)
![write_performance_block](/assets/themes/twitter/bootstrap/img/disk-to-memory/write_performance_block.png)
4. 每个IO的平均服务时间：0.85  -> 0.14 (ms)
![service_time](/assets/themes/twitter/bootstrap/img/disk-to-memory/service_time.png)
5. 每个IO任务等待时间  : 110 ->  1.5 (ms)
![io_wait](/assets/themes/twitter/bootstrap/img/disk-to-memory/io_wait.png)
6. cpu-wa  :  12% -> 0%
![cpu_wa](/assets/themes/twitter/bootstrap/img/disk-to-memory/cpu_wa.png)
7. cpu-Idle  : 83% -> 93% 
![cpu_idle](/assets/themes/twitter/bootstrap/img/disk-to-memory/cpu_idle.png)
8. php响应时间：  23  -> 21 ms

![response_time](/assets/themes/twitter/bootstrap/img/disk-to-memory/response_time.png)

## 风险控制

* tmpfs已经用于linuxnux内核的启动，因此成熟稳定可靠。
* tmpfs支持文件系统空间大小设置，从而排除缓存将内存耗尽引起机器死机的风险，另外，对文件系统添加监控，提前预防的方式也更一步保证了风险可控。
* tmpfs失效后，原ext2目录仍然存在，因此服务仍然可用，并不会因tmpfs失效而直接引发服务问题。
* 将tmpfs文件系统的mount等步骤放在rc.local中，以备机器重启后自动mount生效。

## 结论

在net527ws的前端机器用上后效果显著，完成了空间换时间的一次典型实践：
* 挖掘闲置内存，使内存使用率提升30%；
* 减少磁盘IO 98%以上，平均读写速度提升85%以上：
  1. 每秒写磁盘次数由1100次降为5次；
  2. 每秒写数据量由8100KB降为50KB；
  3. 每秒写磁盘扇区数由11000块降为200块；
  4. 每个IO的平均服务时间由850ns降为140ms；
  5. 每个IO任务等待时间由110ms降为了1.5 ms；
  6. 降低CPU-WA消耗：CPU-WA由15%降为了0%；
* 提升了机器性能，(单机极限压力提升5~8%：CPU-WA节省带来的CPU收益使得单机极限压力提升5~8%
* 降低磁盘文件系统异常的几率：使用内存文件系统后磁盘文件系统报警基本不再发生
