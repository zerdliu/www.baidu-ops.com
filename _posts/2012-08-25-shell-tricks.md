---
layout: post
title: "bash的常用功能和技巧"
description: ""
category: 
tags: ['shell','practice']
author: zerdliu
abstract: "本文分享了在shell学习和使用中经常用到的一些功能和技巧。"
thumbnail: http://hp.dewen.org/wp-content/uploads/2012/07/bash-shell.jpg
---
{% include JB/setup %}

## 编码规范

1 对命令的返回值进行判断
2 临时文件采用脚本名加PID标识并清理   
3 function内的局部变量使用local限定符   
4 显式函数返回return脚本退出exit   
5 变量名用`${}`括起来   
6 命令替换使用`$()`而不是反引号   
7 将变量写在脚本头或者独立成配置   

## 参数处理
* 直接使用$0,$1……，$@，$#
* 通过eval赋值

{% highlight bash %}
function_test key1=value1 key2=value2
在function_test内部使用
eval “$@” 
解析参数输入,后面就可以通过$key1,$key2使用了
{% endhighlight %}

* 通过set改变环境变量

{% highlight bash %}
string=“var1 var2 var3” 
set -- $string
{% endhighlight %}

则可以通过$1的值为var1，$#的值为3。这种方法改变了环境变量，慎重。或者在subshell中使用

* getopts

## 理解subshell/子进程
子进程可以继承父进程的环境变量
{% highlight bash %}
num=0
cat file | while read line ; do
  $num++
done
echo $num
{% endhighlight %}

和

{% highlight bash %}
num=0
While read line ; do
  let "num ++"
Done < file
{% endhighlight %}

“|”创建了一个子进程，无法将变量传给父shell

## 文本使用here文档

{% highlight bash %}
/usr/sbin/sendmail -t <<-End_mail
    Subject:$mail_subject
    From:$mail_from
    To:$mail_to
    Return-Path:$mail_return_path
    Reply-to:$mail_reply_to
    `cat -`
End_mail
{% endhighlight %}

利用End_mail前面的”-”可以使用tab进行缩进，保持脚本可读

## 避免常见陷阱

1. 避免shell参数个数限制

{% highlight bash %}
xargs
{% endhighlight %}

2. 避免test测试错误

{% highlight bash %}
[ "X$var" = Xsomething ]
{% endhighlight %}

3. 避免变量未初始化错误

{% highlight bash %}
${var:-0}
{% endhighlight %}

4. 避免cd引起路径错误

{% highlight bash %}
() #或者
&& #屏蔽
{% endhighlight %}

5. 更加安全的使用$@

{% highlight bash %}
${1+”$@”}
{% endhighlight %}

6. 避免进程异常退出

{% highlight bash %}
trap 'rm tempfle' EXIT
{% endhighlight %}

7. crontab中的元字符

{% highlight bash %}
%
{% endhighlight %}

8. 规避xargs的默认分割行为

{% highlight bash %}
find . Type f -mtime +7 -print 0 | xargs -0 rm
{% endhighlight %}

9. 避免拷贝错误：

{% highlight bash %}
cp file dir/ ## 一定记住最后的“/”
{% endhighlight %}

## 理解文件描述符


{% highlight bash %}
>file 2>&1 #和
2>&1 >file ##的区别为: shell从左到右读取参数

>file 2>&1 ##将标准输出和标准错误重定向到file
2>&1 >file ##将标准输出重定向到file，标准错误仍然为屏幕

-------------------
&>/dev/null ##等价于 
>/dev/null 2>&1 ##使用前者。
{% endhighlight %}

## 命令分组

{% highlight bash %}
(command1;command2) >log ## 子shell中运行命令组
{command1 ; command2 ;} >/dev/null ## 当前shell中运行命令组
((command1;command2)& ##多个命令后台运行
{% endhighlight %}

## 字串替换
说明： #前%后，控制字串截取方式
实例：当前目录下有如下文件

`host.new offline.new online.new rd.new wugui64.new xferlog.new`

需要将后缀.new去掉

{% highlight bash %}
for x in `ls *new`; do
  old_name=${x%.new} 
  mv $x $old_name
done
{% endhighlight %}

## 进程替换

`<()`
将进程的输出替换为文本做标准输入

{% highlight bash %}
vimdiff <() <()
{% endhighlight %}

同时从文件和标准输入获取：
{% highlight bash %}
cat file | diff - file2 ## -代表标准输入
{% endhighlight %}

另外一种方式

{% highlight bash %}
diff <(cat file) file2
{% endhighlight %}

实例：diff两台服务器的同一个配置文件
{% highlight bash %}
Vimdiff <(ssh server1 cat conf) <(ssh server2 cat conf)
{% endhighlight %}

## wget使用

1. 不要随便修改-t -T选项的设置
2. 限制使用`*`，失败后返回值仍为0
3. 注意加-c和不加-c的程序行为
4. 从线上下载数据要加--limit-rate=10M

## ssh的使用
非交互使用ssh，最好加-n参数

file文件的内容为：

{% highlight bash %}
server1
server2
{% endhighlight %}

{% highlight bash %}
while read server ; do
   ssh -n $server ‘uname -r’
done < file
{% endhighlight %}

远程使用vim，加-t参数，分配tty
超时，重试参数
{% highlight bash %}
-o ConnectTimeout=20 -o ConnectionAttempts=4
{% endhighlight %}
使用rsync前，加--dry-run参数
scp加-p参数，保持文件时间戳一致，利用浏览器缓存

## find的使用


1. 排除目录
{% highlight bash %}
find abs -path "abs/zllib" -prune -o -name "*.sh" –print
{% endhighlight %}
2. 精确判断时间
{% highlight bash %}
touch –t time time_file
find –newer time_file
{% endhighlight %}
3. 运行命令
{% highlight bash %}
-exec command {} \; # {}代表find找到的，作为command的参数
{% endhighlight %}

## 分离会话

1 nohup 

{% highlight bash %}
nohup command & ## 需要注意的一点是如果command中包含多个命令，不要使用&&连接，需要使用;
{% endhighlight %}

2 disown：命令敲下去发现忘记nohup了怎么办？使用disown补救
3 screen：在wiki中搜一下

## 创建安全和可维护的脚本

1 供其他进程使用的文件生成时 采用更名再mv的方式 如
{% highlight bash %}
file </dev/null
:>file
{% endhighlight %}

2 将函数和配置独立成单独的脚本

3 将不同服务器需要差异对待的变量提取成单独的配置文件

4 日志打印必须包含脚本名`basename`和时间

5 每步骤必须校验返回值

6 脚本中避免使用`*`

7 保持缩进4个空格

8 过长的命令按照`|`折行

9 创建目录使用`mkdir –p`

10 如果采用后台运行一定要wait： `( command1 ; command2 ) & wait`

11 对于需要获取命令输出的命令需要将`stderr`屏蔽到`/dev/null`

12 抽离公共逻辑作为函数或者代码片段（导入变量）

13 保证互斥和脚本实例唯一性

## 参考资料
1. [Abs](http://tldp.org/LDP/abs/html/) -- advanced bash scripting guide
2. [unix power tools](http://docstore.mik.ua/orelly/unix/upt/index.htm) -- unix超级工具上、下
