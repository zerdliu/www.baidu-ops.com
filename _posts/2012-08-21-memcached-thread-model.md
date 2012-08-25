---
layout: post
title: "memcached的线程模型"
description: ""
category: 
tags: ['memcached','open source']
author: 文晖
abstract: Memcached 是一个高性能的内存对象缓存系统，经典的场景是用于动态Web应用以减轻数据库负载。它通过在内存中缓存数据和对象来减少读取数据库的次数，从而提高动态、数据库驱动网站的速度。这里简要介绍一下memcached的线程模型。
thumbnail: http://www.linuxeden.com/upimg/allimg/100716/1I30359C-0.png
---
{% include JB/setup %}


## Memcached数据结构
memcached的多线程主要是通过实例化多个libevent实现的,分别是一个主线程和n个workers线程。每个线程都是一个单独的libevent实例,主线程eventloop负责处理监听fd，监听客户端的建立连接请求，以及accept连接，将已建立的连接round robin到各个worker。workers线程负责处理已经建立好的连接的读写等事件。”one event loop per thread”.


首先看下主要的数据结构

`thread.c`

CQ_ITEM是主线程accept后返回的已建立连接的fd的封装。

{% highlight c %}
/* An item in the connection queue. */
typedef struct conn_queue_item CQ_ITEM;
struct conn_queue_item {
    int     sfd;
    int     init_state;
    int     event_flags;
    int     read_buffer_size;
    int     is_udp;
    CQ_ITEM *next;
};
{% endhighlight %}


CQ是一个管理CQ_ITEM的单向链表
{% highlight c %}
/* A connection queue. */  
typedef struct conn_queue CQ;  
struct conn_queue {  
    CQ_ITEM *head;  
    CQ_ITEM *tail;  
    pthread_mutex_t lock;  
    pthread_cond_t  cond;  
};  
{% endhighlight %}


LIBEVENT_THREAD 是memcached里的线程结构的封装，可以看到每个线程都包含一个CQ队列，一条通知管道pipe和一个libevent的实例event_base。

{% highlight c %}
typedef struct {
    pthread_t thread_id;        /* unique ID of this thread */
    struct event_base *base;    /* libevent handle this thread uses */
    struct event notify_event;  /* listen event for notify pipe */
    int notify_receive_fd;      /* receiving end of notify pipe */
    int notify_send_fd;         /* sending end of notify pipe */
    CQ  new_conn_queue;         /* queue of new connections to handle */
} LIBEVENT_THREAD;
{% endhighlight %}

Memcached对每个网络连接的封装conn

{% highlight c %}
    typedef struct{  
      int sfd;  
      int state;  
      struct event event;  
      short which;  
      char *rbuf;  
      ... //这里省去了很多状态标志和读写buf信息等  
    }conn;  
{% endhighlight %}
memcached主要通过设置/转换连接的不同状态，来处理事件（核心函数是drive_machine，连接的状态机）。

## Memcached线程处理流程

`Memcached.c`
里main函数，先对主线程的libevent实例进行初始化, 然后初始化所有的workers线程，并启动。接着主线程调用server_socket（这里只分析tcp的情况）创建监听socket，绑定地址，设置非阻塞模式并注册监听socket的libevent 读事件等一系列操作。最后主线程调用event_base_loop接收外来连接请求。

{% highlight c %}
Main() {
/* initialize main thread libevent instance */  
     main_base = event_init();  
   
/* start up worker threads if MT mode */  
thread_init(settings.num_threads, main_base);   

server_socket(settings.port, 0);

/* enter the event loop */  
event_base_loop(main_base, 0);  
}
{% endhighlight %}

最后看看memcached网络事件处理的最核心部分- drive_machine
drive_machine是多线程环境执行的，主线程和workers都会执行drive_machine。

{% highlight c %}
static void drive_machine(conn *c) {  
    bool stop = false;  
    int sfd, flags = 1;  
    socklen_t addrlen;  
    struct sockaddr_storage addr;  
    int res;  
  
    assert(c != NULL);  
  
    while (!stop) {  
  
        switch(c->state) {  
        case conn_listening:  
            addrlen = sizeof(addr);  
            if ((sfd = accept(c->sfd, (struct sockaddr *)&addr, &addrlen)) == -1) {  
                //省去n多错误情况处理  
                break;  
            }  
            if ((flags = fcntl(sfd, F_GETFL, 0)) < 0 ||  
                fcntl(sfd, F_SETFL, flags | O_NONBLOCK) < 0) {  
                perror("setting O_NONBLOCK");  
                close(sfd);  
                break;  
            }  
            dispatch_conn_new(sfd, conn_read, EV_READ | EV_PERSIST,  
                                     DATA_BUFFER_SIZE, false);  
            break;  
  
        case conn_read:  
            if (try_read_command(c) != 0) {  
                continue;  
            }  
        ....//省略  
     }       
 }  
{% endhighlight %}

drive_machine主要是通过当前连接的state来判断该进行何种处理，因为通过libevent注册了读写事件后回调的都是这个核心函数，所以实际上我们在注册libevent相应事件时，会同时把事件状态写到该conn结构体里，libevent进行回调时会把该conn结构作为参数传递过来，就是该方法的形参。
连接的状态枚举如下。

{% highlight c %}
    enum conn_states {  
        conn_listening,  /** the socket which listens for connections */  
        conn_read,       /** reading in a command line */  
        conn_write,      /** writing out a simple response */  
        conn_nread,      /** reading in a fixed number of bytes */  
        conn_swallow,    /** swallowing unnecessary bytes w/o storing */  
        conn_closing,    /** closing this connection */  
        conn_mwrite,     /** writing out many items sequentially */  
    };  
{% endhighlight %}

实际对于case conn_listening:这种情况是主线程自己处理的，workers线程永远不会执行此分支我们看到主线程进行了accept后调用了


{% highlight c %}
dispatch_conn_new(sfd, conn_read, EV_READ | EV_PERSIST,DATA_BUFFER_SIZE, false);
{% endhighlight %}

这个函数就是通知workers线程的地方，看看

{% highlight c %}

void dispatch_conn_new(int sfd, int init_state, int event_flags,  
                           int read_buffer_size, int is_udp) {  
        CQ_ITEM *item = cqi_new();  
        int thread = (last_thread + 1) % settings.num_threads;  
      
        last_thread = thread;  
      
        item->sfd = sfd;  
        item->init_state = init_state;  
        item->event_flags = event_flags;  
        item->read_buffer_size = read_buffer_size;  
        item->is_udp = is_udp;  
      
        cq_push(&threads[thread].new_conn_queue, item);  
      
        MEMCACHED_CONN_DISPATCH(sfd, threads[thread].thread_id);  
        if (write(threads[thread].notify_send_fd, "", 1) != 1) {  
            perror("Writing to thread notify pipe");  
        }  
} 
{% endhighlight %}
可以清楚的看到，主线程首先创建了一个新的CQ_ITEM，然后通过round robin策略选择了一个thread并通过cq_push将这个CQ_ITEM放入了该线程的CQ队列里，那么对应的workers线程是怎么知道的呢?
就是通过
{% highlight c %}
write(threads[thread].notify_send_fd, "", 1）
{% endhighlight %}

向该线程管道写了1字节数据，则该线程的libevent立即回调了thread_libevent_process方法（上面已经描述过）。
然后那个线程取出item,注册读时间，当该条连接上有数据时，最终也会回调drive_machine方法，也就是drive_machine方法的 case conn_read:等全部是workers处理的，主线程只处理conn_listening 建立连接这个。
memcached的这套多线程event机制很值得设计linux后端网络程序时参考。

## 参考文献
* [memcache源码分析--线程模型](http://www.iteye.com/topic/344172)
* [memcached结构分析——线程模型](http://blog.csdn.net/bokee/article/details/6670550)
* [Memcached的线程模型及状态机](http://basiccoder.com/thread-model-and-state-machine-of-memcached.html)


