---
layout: post
title: "mysql timeout调研与实测"
description: ""
category: 
tags: ['mysql']
author: 张良
abstract: "mysql的timeout有多少种，之间的区别时什么？本文从实测和代码分析的角度验证了不同的超时参数的作用。"
thumbnail: http://media.tumblr.com/tumblr_lnyugw8OtD1qkyu55.jpg
---
{% include JB/setup %}

接触网络编程我们不得不提的就是超时，TCP建立连接的超时，数据报文发送/接收超时等等，mysql在超时上也做足了功夫。

Variable_name |  Default Value     
--------- | ---------
connect_timeout | 5 
interactive_timeout | 28800 
net_read_timeout | 30 
net_write_timeout | 60 
wait_timeout | 28800 


上面这5个超时是本次调研的重点，当然MySQL绝对不指这5种超时的配置，由于经历和时间有限，本次只谈这5种。
## Connect_Timeout 

这个比较好理解，字面上看意思是连接超时。"The number of seconds that the mysqld server waits for a connect packet before responding with Bad  handshake"。

MySQL连接一次连接需求经过6次“握手”方可成功，任意一次“握手”失败都有可能导致连接失败，如下图所示。

![mysql_handshake](/assets/themes/twitter/bootstrap/img/mysql-timeout/mysql_handshake.png)

前三次握手可以简单理解为TCP建立连接所必须的三次握手，MySQL无法控制，更多的受制于不TCP协议的不同实现，后面的三次握手过程超时与connect_timeout有关。简单的测试方法： 

{% highlight bash %}
$time telnet mysql_ip_addr port
$ time telnet 127.0.0.1 5051
Trying 127.0.0.1...
Connected to 127.0.0.1.
Escape character is '^]'.
?
Connection closed by foreign
host.
real    0m5.005s #这里的5秒即mysql默认的连接超时
user    0m0.000s
sys 0m0.000s
{% endhighlight %}

Telnet未退出前通过show processlist查看各线程状态可见，当前该连接处于授权认证阶段，此时的用户为“unauthenticated user”。细心的你懂得，千万不要干坏事。

{% highlight bash %}
+--+--------------------+---------------+----+-------+----+----------------+----------------+
|Id|User                |Host           |db  |Command|Time|State           |Info            |
+--+--------------------+---------------+----+-------+----+----------------+----------------+
| 6|root                |localhost      |NULL|Query  |   0|NULL            |show processlist|
| 7|unauthenticated user|localhost:58598|NULL|Connect|NULL|Reading from net|NULL            |
+--+--------------------+---------------+----+-------+----+----------------+----------------+
{% endhighlight %}

## wait_timeout
等待超时，那mysql等什么呢？确切的说是mysql在等用户的请求(query)，如果发现一个线程已经sleep的时间超过wait_timeout了那么这个线程将被清理掉，无论是交换模式或者是非交换模式都以此值为准。 

注意：wait_timeout是session级别的变量哦，至于session和global变量的区别是什么我不说您也知道。手册上不是明明说wait_timeout为not interactive模式下的超时么？为什么你说无论是交换模式或者非交换模式都以此值为准呢？简单的测试例子如下：

{% highlight bash %}
mysql> show variables like "%timeout%";
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| connect_timeout            | 5     | 
| delayed_insert_timeout     | 300   | 
| innodb_lock_wait_timeout   | 50    | 
| innodb_rollback_on_timeout | OFF   | 
| interactive_timeout        | 28800 | 
| net_read_timeout           | 30    | 
| net_write_timeout          | 60    | 
| slave_net_timeout          | 3600  | 
| table_lock_wait_timeout    | 50    | 
| wait_timeout               | 28800 | 
+----------------------------+-------+
10 rows in set (0.00 sec)

Date : 2012-2-24 Fri 22:41:24
#可见我把interactive_timeout改为1秒后经过了4秒的时间没有任何请求，连接却没有被断开。

mysql> set interactive_timeout=28800;
#为了验证wait_timeout我再把interactive_timeout改回来
Query OK, 0 rows affected (0.00 sec)

Date : 2012-2-24 Fri 22:43:43

mysql> show variables like "%timeout%";
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| connect_timeout            | 5     | 
| delayed_insert_timeout     | 300   | 
| innodb_lock_wait_timeout   | 50    | 
| innodb_rollback_on_timeout | OFF   | 
| interactive_timeout        | 28800 | 
| net_read_timeout           | 30    | 
| net_write_timeout          | 60    | 
| slave_net_timeout          | 3600  | 
| table_lock_wait_timeout    | 50    | 
| wait_timeout               | 28800 | 
+----------------------------+-------+
10 rows in set (0.00 sec)
Date : 2012-2-24 Fri 22:43:46

mysql> set wait_timeout=1;
Query OK, 0 rows affected (0.00 sec)

Date : 2012-2-24 Fri 22:43:52

mysql> set wait_timeout=1;
ERROR 2006 (HY000): MySQL server has gone away  
No connection. Trying to reconnect...
Connection id:    8
Current database: *** NONE ***

Query OK, 0 rows affected (0.00 sec)

Date : 2012-2-24 Fri 22:43:55 #可见即使在交互模式下真正起作用的也是wait_timeout而不是interactive_timeout

{% endhighlight %}

那为什么手册上说在交互模式下使用的是interactive_timeout呢，原因如下： 

check_connection函数在建立连接初期，如果为交互模式则将interactive_timeout值赋给wait_timeout，骗您误以为交互模式下等待超时为interactive_timeout 
代码如下: 

{% highlight c %}
   if (thd->client_capabilities & CLIENT_INTERACTIVE)
     thd->variables.net_wait_timeout=thd->variables.net_interactive_timeout；
{% endhighlight %}

## interactive_timeout

上面说了那么多，这里就不再多做解释了。我理解mysql之所以多提供一个目的是提供给用户更灵活的设置空间。

## net_write_timeoutite_timeout

看到这儿如果您看累了，那下面您得提提神了，接下来的两个参数才是我们遇到的最大的难题。
"The number of seconds to wait for a block to be written to a connection before aborting the write." 等待将一个block发送给客户端的超时，一般在网络条件比较差的时，或者客户端处理每个block耗时比较长时，由于net_write_timeout导致的连接中断很容易发生。下面是一个模拟的例子： 

{% highlight c %}
mysql > set global max_allow_packet=1;
#目的是让结果集被分成多个包传输给客户端 
mysql > set global net_write_timeout=1; 
#include 
#include 
#include 
main() {
   MYSQL *conn;
   MYSQL_RES *res;
   MYSQL_ROW row;
   char *server = "localhost";
   char *user = "test"; 
   char *password = ""; /* set me first */
   char *database = "test";
   conn = mysql_init(NULL);
   /* Connect to database */
   if (!mysql_real_connect(conn, server, 
         user, password, database, 0, NULL, 0)) {
      fprintf(stderr, "%s\n", mysql_error(conn));
      exit(1);
   }
   /* send SQL query */
   if (mysql_query(conn, "SELECT * from big_table;")) {
      fprintf(stderr, "%s\n", mysql_error(conn));
      exit(1);
   }
   res = mysql_use_result(conn);
#mysql_use_result不会一次将全部结果给都丢给客户端内存
   /* output table name */
   printf("MySQL Tables in mysql database:\n");
   sleep(7); #模拟网络环境不稳定或客户端处理耗时
   while ((row = mysql_fetch_row(res)) != NULL){
      printf("%s \n", row[0]);
   }
   /* close connection */
   mysql_free_result(res);
   mysql_close(conn);
}
{% endhighlight %}

## net_read_timeout
“The number of seconds to wait fprintfor more data from a connection before aborting the read.”。Mysql读数据的时的等待超时，可能的原因可能为网络异常或客户端or服务器端忙无法及时发送或接收处理包。这里我用的是iptables来模拟网络异常，生成一个较大的数据以便于给我充足的时间在load data的过程中去配置iptables规则。

{% highlight bash %}
mysql > set global max_allowed_packet=1073741824;
mysql > set global net_read_timeout=1;
mysql > create table test.test(a char(10)) engine=myisam;

for((i=0;i<100000;i++));do echo "abcdefghij" >> data.txt;done

mysql -uroot -h 127.0.0.1 -P 3306 --local-enable=1
--max-allowed-packet=1073741824
mysql > load data local infile 'load.txt' into table test;

iptables -F
/sbin/iptables -A INPUT -p tcp --dport 3306 -j DROP
/sbin/iptables -A OUTPUT -p tcp --sport 3306 -j DROP
iptables -L
{% endhighlight %}

执行完iptables命令后show processlist可以看到load data的连接已经被中断掉了，但因为这里我选择了myisam表，所以

{% highlight sql %}
select count(*) from test；
{% endhighlight %}

可以看到数据还是被插入了一部分。

## net_retry_count
"超时"的孪生兄弟“重试”，时间原因这个我没有进行实际的测试，手册如是说，估且先信它一回。

If a read or write on a communication port is interrupted, retry this many times before giving up. This value should be set quite high on FreeBSD because internal interrupts are sent to all threads. 

On Linux, the "NO_ALARM" build flag (-DNO_ALARM) modifies how the binary treats both net_read_timeout and net_write_timeout. With this flag enabled, neither timer cancels the current statement until after the failing connection has been waited on an additional net_retry_count times. This means that the effective timeout value becomes" (timeout setting) × (net_retry_count+1)". 

FreeBSD中有效，Linux中只有在build的时候指定NO_ALARM参数时net_retry_count才会起作用。

说明：目前线上使用的版本都未指定NO_ALARM。

