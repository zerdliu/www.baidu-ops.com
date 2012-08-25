---
layout: post
title: "MFS master的核心数据结构及内存分配简析"
description: ""
category: 
tags: ["open source","mooseFS","system design"]
author: "一仕"
abstract: "MFS是广泛应用的分布式文件系统，为各个产品线提供业务数据共享，容灾备份等服务。MFS的实现思路全盘按照google的GFS这篇论文实现的，因此也被认为是GFS的一个开源C实现。对于这样一个分布式文件系统，它的master掌握了几乎系统的所有信息，而本文就是对这些元数据信息的设计和存储进行解析。并借此来加深对分布式文件系统的设计与实现的理解。"
thumbnail: http://www.moosefs.org/tl_files/mfs_folder/write862.png
---
{% include JB/setup %}


## fsnode
我们都知道在linux文件系统中有inode这个概念，inode是文件的索引节点，其中包含了：inode编号，文件的链接数目，属主的UID，属主的组ID
(GID)，文件的大小，文件所使用的磁盘块的实际数目，最近一次修改的时间(ctime)，最近一次访问的时间(atime)，最近一次更改的时间(mtime)等等。虚拟文件系统通过inode来访问磁盘中的实际数据块。并返回给应用层。

MFS系统维护着一个树状文件系统，这个文件系统里面的每个文件是由fsnode来唯一标示的。以下是fsnode的struct构成：

{% highlight c %}
typedef struct _fsnode {
    uint32_t id;
    uint32_t ctime,mtime,atime;
    uint8_t type;
    uint8_t goal;
    uint16_t mode;
    uint32_t uid;
    uint32_t gid;
    uint32_t trashtime;
    union _data {
        struct _ddata {
            fsedge *children;
            uint32_t nlink;
            uint32_t elements;
            statsrecord *quota;
        } ddata;
        struct _sdata {
            uint32_t pleng;
            uint8_t *path;
        } sdata;
        uint32_t rdev;
        struct _fdata {
            uint64_t length;
            uint64_t *chunktab;
            uint32_t chunks;
            sessionidrec *sessionids;
        } fdata;
    } data;
    fsedge *parents;
    struct _fsnode *next;
} fsnode;

{% endhighlight %}

其中的id代表fsnode的id号,ctime,atime,mtime代表文件的修改访问时间,goal代表了该文件的拷贝数(默认是3)等等,其中值得重点讲述的是data,我们可以看到这个结构是个union,它是ddata,sdata,fdata三者其中的一个,而这三个不同的struct分别代表这目录,链接,和文件三种不同的属性.某个具体的文件只能对应其中的一种属性.

`ddata`

	fsedge（留待后文）
	nlink：被链接的次数
	elements：该目录下的文件数
	tatsrecord：统计操作次数

`sdata`

	pleng：路径名长度
	path：路径名

`fdata`

	length：文件名长度
	chunktab：文件所存储的文件块索引
	chunks：文件所包含的文件块数量

其中我们最关心的当然就是chunktab了，因为它存储了某个文件对应的chunkid，在上图中我们可以看到，chunktab是一个整形数组指针，他存储了具体的chunkid，而这个chunkid是MFS中每一个chunk的唯一标识。

## chunk
{% highlight c %}
typedef struct chunk {
    uint64_t chunkid;
    uint32_t version;
    uint8_t goal;
    uint8_t allvalidcopies;
    uint8_t regularvalidcopies;
    uint8_t needverincrease:1;
    uint8_t interrupted:1;
    uint8_t operation:4;
    uint32_t lockedto;
    slist *slisthead;
    flist *flisthead;
    struct chunk *next;
} chunk;
{% endhighlight %}

以上代码是chunk的具体结构，其中chunkid是一个长整形，version是chunk的版本，goal是chunk的拷贝数，allvalidcopies是chunk的所有可用拷贝数目，lockto是此chunk在被写入或修改的时候会被锁住一定的时间。

需要重点提及的是里面的两个数据结构，slisthead和flisthead，我们知道，MFS同GFS一样，会把每个文件会分成64MB大小的块（某个块的实际存储不够64MB的时候会存储其他文件，直到达到64MB为止），并根据用户设定的拷贝数存储在各个chunkserver上面。所以一个chunk最重要的信息有两个，一个是这个chunk包含了哪一些文件？另一个是哪些chunkserver上有这个chunk?
    
{% highlight c %}
typedef struct _flist {
    uint32_t inode;
    uint16_t indx;
    uint8_t goal;
    struct _flist *next;
} flist;
{% endhighlight %}

flist是这个chunk拥有的文件列表。它通过文件inode号，和索引位置indx来唯一标识，并且通过一个链表来管理所有的flist。

{% highlight c %}
typedef struct _slist {
    void *ptr;
    uint8_t valid;
    uint32_t version;
    struct _slist *next;
} slist;
{% endhighlight %}

slist就是这个chunk分布在的chunkserver服务器的列表，ptr这个空指针包含了chunkserver的信息，包括ip，port等等，当需要的时候master通过函数matocsserv_getlocation（）来获取这些信息。

我们看到了客户端通过inode号来获取fsnode的信息，并且在需要发生实际数据IO的时候通过fsnode中对应的chunk列表来获取文件的物理存储位置，并读取文件数据。那么在master服务器中，这些信息是怎么存储的呢？

答案是：哈希链表。

哈希链表是linux内核中常常使用的一种数据结构，具体实现是一个哈希表，而这个表中的每个元素都是一个链表的表头。

每次添加新的fsnode的时候，系统首先会计算出一个hash表中的位置，然后把这个新添的fsnode添加在表头。同样的结构也应用在chunk以及fsedge上面。

## fsedge
   fsedge的实现如下所示

{% highlight c %}
typedef struct _fsedge {
    struct _fsnode *child, *parent;
    struct _fsedge *nextchild, *nextparent;
    struct _fsedge **prevchild,**prevparent;
    struct _fsedge *next,**prev;
    uint16_t nleng;
    uint8_t *name;
} fsedge;
{% endhighlight %}
 
我们上文提到，mfs维护了一个树状文件系统，而我们也看到fsnode本身并没有实现这种关联关系。fsedge的作用就是对整个文件系统中的fsnode建立树状逻辑关系。
 
fsnode之间并不是直接连接的，而是通过fsedge来建立逻辑关系。当我们需要用到这些目录信息，比如列出某个目录底下全部文件，计算某个目录下的文件大小等等的时候fsedge就能派上用场了。

至此，关于MFS的一些核心数据结构的设计，实现以及他们在内存中的分布我们的介绍就全部结束了。

