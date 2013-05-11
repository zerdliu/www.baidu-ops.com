---
layout: post
title: "现代*NIX的进程与shell"
description: ""
category: 
tags: [shell]
author: 溢原
abstract:  现在*NIX系统的进程运行机制都比较类似，99.9%的系统都已经使用ELF格式作为可执行文件格式，a.out已经基本淘汰。此外parser的形式也被几乎所有系统支持，即文件头部写#!/some/parser的脚本。全文都以这两种情况展开，不考虑历史或者极特殊系统。
thumbnail: /assets/themes/twitter/bootstrap/img/2013-05-05-process-and-shell.md/thumbnail.jpg
---
{% include JB/setup %}
##1 什么是可执行文件

一个文件可以被执行的意思是这个文件不需要外界驱动，而可以直接作为**execve(2)**的第一参数。与之相反的就是不能被**execve(2)**直接作为第一参数，而必须在第二参数中作为参数传给第一参数指定的可执行文件。

对于ELF系统而言，只有ELF格式的文件是可执行的。一个ELF文件还需要在文件系统上具备执行权限，否则也无法作为第一参数。ELF文件是否可以被执行取决于ELF文件自身是否是可执行的，例如so或者detached debug symbols也是ELF，但是（99.9%）不能被执行。存在极少量特制的so可以被执行，例如libc.so，是因为特制的ELF结构。ELF格式不在本文的讨论当中。

大量非ELF格式的文件，例如脚本，是不能被操作系统载入并启动的。但是脚本文件可以作为**execve(2)**的第一参数，原因是parser体系。脚本解析器是解读脚本并且执行行动的ELF文件，例如常见的shell脚本，后缀名为 .sh的，他们可以通过sh script.sh来运行。这个道理很简单，sh是ELF文件，script.sh被作为数据传递给了sh进行解读。为了方便这一类情况（这个情况占了可执行文件的大多数），操作系统规定了自动调用parser的格式：

{% highlight bash %}
#!/some/elf/file -param1 –param2
script line 1
script line 2
…
{% endhighlight %}

第一行顶格写#!表示这个文件需要parser支持，**execve(2)**会去读取第一行的内容（为了防止溢出，通常第一行只会去读80个字节），然后把第一个字符串作为第一参数，重新传给**execve(2)**执行，第一行的其他参数会完整填充到argv[1]中，然后命令行上传来的argv被重新映射到新的位置。此时，由于argv数组的体积增加，有可能本来没有超过参数数组上限的命令现在超过了。这个过程不会递归，即如果parser字符串给出的不是ELF格式，那就不会再找下去了。

例如以下文件：
{% highlight bash %}
#!/usr/bin/awk –f
{ print $1 }
{% endhighlight %}

shell执行
{% highlight bash %}
./a.awk hello world
{% endhighlight %}
shell调用
{% highlight bash %}
execve("./a.awk", ["hello", "world", NULL], environ)
{% endhighlight %}
操作系统发现a.awk需要parser
操作系统调用
{% highlight bash %}
execve("/usr/bin/awk", ["-f", "./a.awk", "hello", "world", NULL], environ)
{% endhighlight %}
此时的实际效果就变成了
{% highlight bash %}
/usr/bin/awk -f ./a.awk hello world
{% endhighlight %}

所谓的完整填充：
{% highlight bash %}
#!/some/elf/file -param1 –-param2
{% endhighlight %}
执行./a.out xxx yyy会变成
{% highlight bash %}
execve("/some/elf/file", ["-param1 -–param2", "./a", "xxx", "yyy", NULL], environ)
{% endhighlight %}
即除了第一参数，后面所有的内容都是直接填进argv[1]的。

注意这个过程用户态可能可见（例如有些shell会手工完成这个过程而不是依靠操作系统），此外这个过程与扩展名无关，这与DOS/Windows不同（除非shell做了什么诡异的事），例如sh a.awk是完全合法的，如果a.awk内容其实是shell脚本。

当然，没有写parser头的文件也可以直接以ELF文件参数的形式启动，此时甚至不需要脚本文件自身有可执行权限，也不依赖${PATH}展开。 例如：
{% highlight bash %}
sh script.sh
{% endhighlight %}

##2 可执行文件的定位

\*NIX系统没有“内部命令”的概念，这与DOS/Windows不同。例如平时执行的ls，实际上是/bin/ls，或者其他部署在磁盘上的文件。存在所谓的内部命令，例如cd就在磁盘上找不到，但是这个内部命令并不是由操作系统执行的，而是shell自己内部处理的，因此可以认为\*NIX的内部命令就是shell的内建命令。

对于一个磁盘上的可执行文件，操作系统需要给出其绝对路径，或者相对路径，但是不能没有路径。例如以下情况都是合法的：
{% highlight bash %}
execve("/bin/ls", ["ls", NULL], environ)
{% endhighlight %}
{% highlight bash %}
execve("../ls", ["ls", NULL], environ]
{% endhighlight %}
但是以下是非法的：
{% highlight bash %}
execve("ls", ["ls", NULL], environ)
{% endhighlight %}
不带路径的可执行文件需要由shell进行解析，解析结果会变成带路径的形式，操作系统才会接受，其依据一般为${PATH}环境变量。如果这个环境变量没有设置（不是为空），则shell通常会内部使用固定的值。这个值通常会包含/bin或者/usr/bin等常用FHS路径。对于大部分shell来说，这个值不一定在环境变量上得到体现，例如这样启动一个bash：
{% highlight bash %}
env –i /bin/bash –-norc
{% endhighlight %}
此时可以通过env工具看出环境变量中没有${PATH}，但是set内建命令会给出实际生效的值。和DOS/Windows不同的是，DOS/Windows没有内部变量，一切都是环境变量，并且不管%PATH%取值如何，当前路径（即.）一定是在生效路径的首位。

为了方便这类情况（也是占了大多数），libc提供了若干**exec(3)**家族函数，用于**execve(2)**的封装。例如**execlp(3)**或者**execvp(3)**。

##3 动态库的定位

这一节的内容，有兴趣的同学可以看一看关于/lib/ld-linux.so.2或者/lib64/ld-linux-x86-64.so.2的相关知识，以及其配置文件/etc/ld.so.conf外加环境变量LD_LIBRARY_PATH以及LD_PRELOAD等。熟练使用**ldd(1)**、**readelf(1)**以及ld-linux.so.2会给你很多深入的理解。

##4 shell与作业调度

###4.1 多任务概念

正是因为操作系统对启动程序的诸多要求，shell应运而生。shell的作用就是帮助用户能够用尽可能简单的操作完成以上这些繁琐的事情。\*NIX早期并没有多用户、多任务的概念（当然，那是好几十年前的事情），后面逐步出现了多任务、多用户的体系。因此shell的发展也经历了若干个时期，但是到了BSD4.4时代，就已经完全是现在的样子了，即使是POSIX.1-2008也没有对BSD的进程管理作出根本性的改变。（遗憾的是Linux的出现在BSD4.4之前，因此到今天BSD规范还是和Linux规范有细微的差异，而双方都与POSIX不完全相同。）

现代shell基本上都是按照BSD规范编写的，即基于进程组（process group）的作业调度系统（job control）。一个作业是指一组\*NIX进程联合完成某种事务的过程，这个过程中可能有多次进程的诞生和消亡、进程之间的关系更替、终端的状态切换等。常见的例子就是coding的时候从vim里make一下，或者是把一个命令置入后台运行，都是作业调度在发挥作用。

每一个进程（包括不少平台上的线程）有自己的进程标识PID，父进程标识PPID，进程组标识PGID和会话标识SID。可以通过以下命令查看进程状态（各个平台输出不同）：
{% highlight bash %}
# ps -fj
UID    PID  PPID  PGID   SID  C STIME TTY        TIME CMD
0    10973 10972 10973 10973  0 Jan21 pts/9  00:00:00 –bash
0    15680 10973 15680 10973  0 17:05 pts/9  00:00:00 ps -fj
{% endhighlight %}

从大到小的关系如下：

会话：用户从登录到登出的整个过程为一个会话

进程组：用户执行的一个多进程协作的任务所具有的组织单元

进程：进程组当中的一个元素

每一个进程必定属于且仅属于一个进程组，一个进程组一定属于且仅属于一个会话。

对比以下例子：
{% highlight bash %}
# ps -fj | tail
UID    PID  PPID  PGID   SID  C STIME TTY        TIME CMD
0    10973 10972 10973 10973  0 Jan21 pts/9  00:00:00 -bash
0    14343 10973 14343 10973  0 17:03 pts/9  00:00:00 ps -fj
0    14344 10973 14343 10973  0 17:03 pts/9  00:00:00 tail
{% endhighlight %}
和前一个例子相比，可以看出两组命令的会话ID相同，说明这是同一个用户一次登录过程输入的两个命令。第二次运行时，ps进程和tail进程的PGID相同，说明ps和tail运行在同一个进程组，是一个多进程联合动作。在这两次过程中，bash作为shell，是ps和tail进程的父进程。可以看出有一些进程的PGID和PID是相同的，即表示这个进程是进程组长。而PID与SID相同的进程（bash），则是会话组长。会话组长在作业调度有重要的作用。

进程可以在进程组之间移动，如果当前进程组与目标进程组属于相同的会话。

###4.2 控制终端

如果我们有一些任务希望在后台运行，暂时不与终端交互（例如make的时候vim就在后台待命），可以在命令后面加上&符号，告诉shell将这个任务组放入后台。

在上面的例子，ps和tail进程组的输出被打印到了终端上。此时只有一个任务组在向终端输入输出，因此终端没有冲突问题。试想如果一个vim正在前台coding，用户的终端输入都会被vim作为文本保存起来，这个时候突然有个后台进程从终端上读了一个字符，vim就丢了一个字符。反过来，make正在输出编译日志到终端上，突然一个 echo进程打出来密密麻麻的垃圾文字，终端就被搞得一团糟了。由于一个会话只有一个和用户相连的终端，即用户的登录点，因此这个点需要进行互斥保护。这个点称为控制终端（controlling terminal/TTY）。

控制终端只能由会话组长进程（session leader process）打开，即PID与SID相同的进程，然后会话组长根据需要选择它的子进程组临时接管控制终端。如果会话还没有控制终端（比如刚刚**setsid(2)**完成），则不同的平台使用不同的策略来使会话获得控制终端。System V和BSD都有不同的策略，而Linux的策略则空前复杂。简单地讲，对于Linux而言，会话组长只要打开任何一个空闲的合法的TTY设备就会使之成为控制终端（除非**open(2)**指定O_NOCTTY选项），“空闲”与“合法”的定义随着内核与发行版不同而差异很大。不管什么情况下非会话组长即使打开TTY也不能使之成为控制终端。失去会话组长的进程组，即使TTY的句柄还开着，也会失去控制终端，此时TTY句柄降级成孤儿TTY，**ps(1)**将看到进程组没有TTY（或者FreeBSD是显示有TTY但是不可用状态）。APUE中关于守护进程的操作明确要求两次**fork(2)**，使得进程树变成孤儿进程组（见后文），防止会话组长意外打开控制终端。

获得控制终端使用权的进程组称为前台进程组，任何时候最多只有一个。其他进程组就是后台进程组。后台进程组如果试图读取终端，会立刻收到一个SIGTTIN信号而STOP；如果试图写入终端，则会收到SIGTTOU信号而STOP。如果整个前台进程组所有进程都STOP了，shell就获得控制权（这货其实一直都在后台监视着所有的子进程组，都不能说是丢失了控制权，毕竟它是会话组长），重新搭载到控制终端上，输出一句提示：
{% highlight bash %}
[1]+  Stopped                 ./a.out
{% endhighlight %}
此时即表示出现了作业调度组1号被放置到后台并且已经STOP。可以通过**fg(1)**和**bg(1)**来激活这个或者其他作业，也可以通过**jobs(1)**来查看所有后台作业。

多数shell都允许用户手工将前台进程组立刻放入后台，例如CTRL-Z快捷键，这个快捷键是终端驱动产生的，因此即使shell此时没有TTY控制权也会自动产生，此时一个SIGTSTP信号会发往整个前台进程组。

进程也可以自行选择忽略SIGTTIN和SIGTTOU信号，此时进程虽然不会STOP，但是**read(2)**或者**write(2)**会相应返回EIO。但是因为相对于输入，输出通常都是可接受而且被预期的，因此现代shell都会主动帮助后台进程组关闭SIGTTOU信号（不仅仅是忽略信号，而是通知终端驱动允许后台进程输出到控制终端）。而如果SIGTSTP被忽略，那么终端驱动就无法将前台进程组放进后台了。

###4.3 孤儿进程组

由于用户登录所使用的TTY是控制终端，当用户登出的时候，TTY也就空闲了（用户离开控制台了），此时另外一个会话就可以从这个TTY展开。为了防止上一个用户会话和下一个用户会话发生冲突（同一个用户也不行），上一个会话的进程不能继续使用此TTY。用户登出的时候伴随着会话组长的消亡（不然怎么叫登出了呢）。这是孤儿进程组出现的最初原因，即执行终端和作业树隔离。

POSIX定义的孤儿进程组为：一个进程组中的所有进程的父进程要么是该进程组的一个进程，要么不是该进程组所在的会话中的进程。 一个进程组不是孤儿进程组的条件是，该组中有一个进程其父进程在属于同一个会话的另一个组中。除了会话组长消亡外，满足条件的进程组也会成为孤儿进程组，例如一个子进程树的树根进程消亡，即使这个进程不是会话组长，这棵子树也成为孤儿。孤儿进程组不会再次触发操作系统发出的会话级SIGHUP，也不再接受任何作业调度控制，即使原会话组长也不能再操作。孤儿进程组的整棵进程树树根通常会过继给init进程，即PID=1的进程。这种机制保证了登录同一TTY的不同用户，甚至是登录同一TTY的同一用户（考虑一下密码被泄露的情况），都不再能够对原来存活的进程作出危险操作（这里不是指kill一个信号，而是说夺取/伪造TTY输入输出、监听进程活动或者是执行子进程调试等），原来的进程如果没有被SIGHUP杀死，那就会永远安全地跑下去。

如果终端对端关闭，并且CLOCAL没有置位，并且会话当前有控制终端，那么会话组长就会收到一个SIGHUP。如果会话组长退出（未必是终端挂断，也许是被kill -9了），那么SIGHUP就发往会话的前台进程组。CLOCAL是一种特殊终端标记，比如串行口，对端关闭不代表会话终结，这是串行口的本质特性。现代的仿真终端基本上都不适用CLOCAL。如果会话组长没有打开控制终端，那么就和普通的进程消亡造成孤儿进程组的情况相同。这里的一个特殊点就在于会话组长，其所在的进程组一定是孤儿进程组，因为其父进程不在会话中，因此会话组长自己退出不会导致SIGHUP发给自己所在的进程组。

如果因为某种原因，包括某个进程组的父进程退出，或者父进程移动到了进程组内部且祖父进程不在会话中，或者其他任何奇怪的原因，导致一个本来不是孤儿进程组的进程组变成了孤儿进程组，那么进程组中所有处于STOP状态的进程都会收到一个SIGHUP，紧接着一个SIGCONT。当然，如果这之后这个进程又因为SIGTTIN而STOP了，就没有人救它了。这样做的理由是会话组长通常也是作业调度器，失去了作业调度，STOP的进程就没有办法唤醒了，因此操作系统统一全给叫醒。这里需要注意的是，如果进程没有处于STOP状态，则什么信号都不会收，连SIGHUP也不收。

如果进程忽略了SIGHUP，则可以继续运行，但是任何试图访问TTY的行为都会被阻止，也就是说所有的进程组都自动变为后台进程组，并且无法被再次激活到前台。

shell除了解析命令并执行外，最重要的工作就是为每一组用户击入的指令创建对应的进程组（一条命令可能会产生不止一个进程组），为组内的进程建立好关联关系（例如ps和tail之间就存在输入输出管道），并且监视各个进程组的状态以便实现作业调度。

###4.4 ssh无法干净退出

受OpenSSH版本的影响，存在这种情况：ssh登出的时候hang住了，没有任何方法退出来，除非ssh client执行local disconnect。这种情况是因为ssh使用了伪终端（pesudo terminal/PTY），这种终端对外表现和终端相同，但是特定版本的OpenSSH并不会使后台进程组读写到EIO或者是连接断开，而是直接读hang死。终端此时无法正确关闭，就是说有某个孤儿进程组没有因为SIGHUP消亡，而继续持有终端。sshd此时因为不能关闭终端，就卡住了。这种情况出现的最常见原因就是./a.out &，而这个a.out没有主动把自己的stdio也就是终端句柄关闭掉，而且又是在后台，不会自动SIGHUP。如果这个进程此时试图**read(2)**终端，不但不会读到连接关闭，还会把自己也一起hang死。APUE明确要求守护进程nullify stdio的原因就在于此。

杀死sshd会导致终端关闭，从而会话组长shell退出，接下来所有子shell也会因为终端关闭退出，前台进程组收到SIGHUP，从而杀死整个会话。保留sshd而杀死会话组长shell，SIGHUP发往前台进程组，但是此时因为终端还在，因此交互式子shell此时如果变成前台进程组则读hang死；忽略SIGHUP的其他持有PTY的进程会继续运行。但是这个时候sshd能够发现这种情况，因为会话组长没了，PTY还在，此时出现了选择：要不要主动关闭PTY呢？

这个问题的测试程序如下：
{% highlight bash %}
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

int main()
{
    int i;
    char c;
    int ret;
    FILE *f;
    signal(SIGHUP, SIG_IGN);
    signal(SIGTTIN, SIG_IGN);
    f = fopen("/tmp/aaa","w");
    for (i = 0; i < 60; ++i) {
        sleep(1);
        errno = 0;
        ret = read(0, &c, sizeof(c));
        fprintf(f,"%d %d\n", ret, errno);
        fflush(f);
    }
    fclose(f);

    return 0;
}
{% endhighlight %}
只要在命令行执行./a.out &，然后若干秒后按下CTRL-D或者通过**logout(1)**注销。

<table style="width: 398px; height: 90px;" cellspacing="0" cellpadding="0" border="0"> <col width="117" style="mso-width-source: userset; mso-width-alt: 3744; width: 88pt;"></col> <col width="72" style="width: 54pt;"></col> <col width="110" style="mso-width-source: userset; mso-width-alt: 3520; width: 83pt;"></col> <col width="100" style="mso-width-source: userset; mso-width-alt: 3200; width: 75pt;"></col> <tbody> <tr style="height: 16.5pt;" height="22"> <td style="border: 1px solid #000000;"> <strong>PTY环境</strong> </td> <td style="border: 1px solid #000000;"> <strong>结论</strong> </td> <td style="border: 1px solid #000000;"> <strong>注销前输出</strong> </td> <td style="border: 1px solid #000000;"> <strong>注销后输出</strong> </td> </tr> <tr style="height: 16.5pt;" height="22"> <td style="border: 1px solid #000000;">RHEL4 SSH</td> <td style="border: 1px solid #000000;">Hang</td> <td style="border: 1px solid #000000;">-1 5 EIO</td> <td style="border: 1px solid #000000;">Hang</td> </tr> <tr style="height: 16.5pt;" height="22"> <td style="border: 1px solid #000000;">Ubuntu 11.10</td> <td style="border: 1px solid #000000;">Clear</td> <td style="border: 1px solid #000000;">-1 5 EIO</td> <td style="border: 1px solid #000000;">0 0</td> </tr> <tr style="height: 16.5pt;" height="22"> <td style="border: 1px solid #000000;">FreeBSD 7.4</td> <td style="border: 1px solid #000000;">Clear</td> <td style="border: 1px solid #000000;">-1 5 EIO</td> <td style="border: 1px solid #000000;">-1 6 ENXIO</td> </tr> </tbody> </table>

原因很简单：注销会使shell退出，此时会话组长消亡，但是使用PTY的进程没有消亡。Uubntu 11.10和FreeBSD 7.4的**sshd(1)**在会话组长消亡的时候都会将PTY关闭，因此程序读到0（对端关闭）或者ENXIO（设备不存在）。但是RHEL4自带的OpenSSH 3.9却保持着PTY不释放，虽然新连接也的确不会复用没有释放的PTY，但是此时PTY却没有按照规范返回EIO，而是变成了普通的PTY（job controlling没了，而且恰好没有其他进程组了，于是被踢到前台了），然而PTY却不会有任何输入，于是交互式子shell或者其他进程组读hang死，**sshd(8)**死锁。即使子进程没有被hang死，**sshd(1)**也会一直等下去，直到使用PTY的进程都退出，或者关闭PTY，总之就是退不出。

但是注意一点，如果**ssh(1)**的时候没有打开PTY，情况是所有系统全部hang死。
原因同样很简单：不使用PTY的时候因为没有job control，shell的消亡无法给出SIGHUP信号，此时**sshd(8)**不去（应该说是不应当，因为无法可靠地SIGHUP孤儿进程组）关闭那些socket/pipe，而是耐心等待程序释放socket/pipe才能退出。

这个行为我的理解是：终端登录后面有人类，人类决定注销是应该尊重的，那些后台进程就作为孤儿继续运行也是可以接受的。非终端登录则（通常）应该是批处理模式，这个时候保障程序完整运行更为重要，因此不会主动关闭socket/pipe。

此节内容通过把Ubuntu的**sshd(8)**移植到RHEL4试验发现hang死问题消失，行为与Ubuntu一致，因此断定问题出在**sshd(8)**，而不是操作系统或者终端驱动。从OpenSSH代码来看，的确存在关闭PTY的动作。

解决方法只要要求shell帮助a.out关闭句柄即可（不需要nohup，后台进程本来就不会SIGHUP）：
{% highlight bash %}
./a.out </dev/null >/dev/null 2>&1 &
{% endhighlight %}

##5 **login(1)**的作用与仿真

终端是\*NIX的操作入口。真正的终端就类似于很多很多串口线接在小型机后面一个蜂窝一样的终端面板上，然后在电传打字机的单色屏幕上把字母一个一个地列出来。因为终端有电平、时序、流量控制等很多差异，因此终端类型${TERM}就显得非常重要。不同的终端其能力是不同的，有的能显示彩色，有的能传输带外控制信号等。终端的大小也不尽相同，80列还是40列，50行或者25行。

时至今日“终端”已经可以是任何形式，保留的只是概念了。通常习惯上把实际物理上连接在主机上的入口叫做终端TTY（terminal），而其他通过网络等手段仿真的虚拟终端叫做PTY（pesudo terminal）。Linux的常用配置为：console通常还是RS-232，键盘和显示器则连接在TTY1-6，而没有console的主机其TTY1也复用为console终端。

**login(1)**是运行在TTY上的入口程序，负责进行登录校验，然后启动正确的shell。login的大部分用途在今天都已经不复存在，因为连接TTY的可能性很小，除了真的跑到主机跟前，或者使用**telnetd(1)**以外，现代终端仿真系统如**sshd(8)**等都不再使用**login(1)**。此时，终端仿真器充当了login的作用，其行为需要和**login(1)**保持一致。

网络连接、AAA、把网络流和stdio挂接这些和普通的**inetd(1)**程序没区别，不赘述。

连接一旦建立，首先就是确定终端类型，即使是在仿真的现代，终端类型也有很大的区别，\*NIX常见的有vt100、xterm、linux甚至screen。即使是考虑安全因素而禁止客户端覆盖环境变量，**login(1)**也一定会接受客户端传来的${TERM}。此外，一些情况下客户端传来的其他环境变量也会被保留。

一旦开始建立会话，**login(1)**首先需要清空自身的特权数据，例如环境变量等。然后需要设置的环境变量进行重新设置。接下来开始寻找正确的参数，这通常依靠**passwd(5)**或者是硬编码的部分设置（比如**cron(1)**就是写死${SHELL}为/bin/sh，但是可以被覆盖。毕竟cron job很多是机器账户，不允许登录，**passwd(5)**里写的就是/sbin/nologin）。特殊的环境变量在控制权移交给shell之前必须设置，包括但是不限于：

USER:用户名（通常设置为用户登录名）                               root

LOGIN:用户登录名（AIX专有）                                        root

LOGNAME:用户登录名                                                   root

PATH:寻找可执行文件的路径,可以不设置，此时由shell自行决定解析方法 /usr/local/bin:/bin:/usr/bin

SHELL:shell的绝对路径                                              /bin/sh

TERM:终端类型 可以不设置，如果是守护进程的话                      xterm

HOME:用户主目录                                                   /root

PWD:当前目录                                                     /root

对于**sshd(8)**来说，额外的环境变量SSH_TTY、SSH_CLIENT和SSH_CONNECTION也会被设置，用以记录用户的来源。

接下来根据需要执行jail或者chroot操作，以及其他特权限制操作。

然后根据用户身份执行权限变更，此时**login(1)**不再具有特权。

启动会话。

使用用户的身份切换当前目录。

使用用户的身份启动shell。

几乎所有的步骤都是顺理成章，但是启动shell之前需要决定是否使用PTY：

是：	PTY需要分配，并且使之成为控制终端。

否：	需要建立其他类型的管道。

只有会话组长可以打开控制终端，而这个动作必须有**login(1)**完成，才能使得PTY的另一端连接在网络流上。**login(1)**需要**fork(2)**，**setsid(2)**，然后**login_pty(3)**或者**ioctl(2)**来挂载控制终端，接下来将无关的句柄关闭（例如PTY的控制端、网络流等），再把PTY的slave端挂接到stdio上。

不使用PTY的情况下，可以选择任何流式管道作为stdio，常见的选择是**pipe(2)**和**socketpair(2)**。这里有一个很强的偏好就是使用**socketpair(2)**，因为此时stdio会连接在socket上，对于shell来说，这就和**telnetd(1)**或者**rshd(8)**的行为相同。对于**bash(1)**而言，这样的特殊意义在于bashrc的调用。

##6 shell的启动

GNU Bourne Again SHell（bash）可能是最常用的shell之一，但是除此以外还有很多与bash相似shell例如ash、csh、zsh……这些shell与传统的POSIX Shell（sh）有一个重大区别：启动文件（startup files），也叫做rc文件。本章将以bash作为标准，但是会注明与sh不同的地方。

shell有几个运行模式，对于所有shell有效，但是不是所有shell都区分这些模式：

交互式的：用户会连续敲击键盘，眼睛看着输出。

批处理的：用于执行脚本或者立即指令然后退出。

登录的：这是一个**login(1)**启动的shell。

受限的：只有少量功能允许使用。（常用于敏感主机、跳板机等）

如果bash被以sh作为argv[0]启动，则会自动进入POSIX兼容模式，尽可能仿真POSIX Shell的行为。Bash可以通过查看$-变量获得当前运行模式。对于一个常见的交互式、登录、非限制的bash，其输出类似于：
{% highlight bash %}
# echo $-
himBH
{% endhighlight %}

###6.1 交互式的

这是最高等级的shell，货真价实的shell，要求对键盘输入有低延迟，只要可能就启用作业调度等等。交互式shell因为需要用户直接输入，启动过程不允许有批处理指令进入，例如-c或者-s参数。一般来说直接启动一个不带任何参数的shell就是交互式shell。交互式shell要求终端，因为终端是作业调度的核心，没有终端的话特殊按键例如CTRL-Z将会被真实终端捕获，或者直接就无法生效。

只要有终端，交互式shell会启动作业调度，即使不是会话组长。

交互式shell会给出提示符，例如$或者#，等待用户输入。每次命令执行完毕，shell不会退出，而是再次输出提示符等待输入。作业调度会启动，从而允许把前台进程组踢到后台，或者后台进程组被重新激活。交互式shell会忽略SIGTERM、SIGINT、SIGQUIT等会导致作业中断的信号，并且根据需要将信号转递到子进程组。子进程组因为信号而改变状态时，shell也会进行响应。

如果没有终端，shell会自动退化成批处理模式。

交互式bash的$-包含i字母。

###6.2 批处理的

非交互式shell统称批处理shell，即不通过用户输入而得到操作指示的情况。非交互式shell通常不会给出提示符（也有特殊的比如${PS4}）。

最常见的批处理shell就是sh script.sh，也包括./script.sh。此外，通过-c参数，shell可以从命令行上采集运行命令：
{% highlight bash %}
sh –c 'ls –l'
{% endhighlight %}
注意单引号。

bash额外引入了-s参数，可以通过stdin读取指令，运行后退出。与子shell相同（见后文），sh会**fork(2)**去执行任务，而bash的行为不同，是自己**execve(2)**。可以通过下面的命令看出区别。
{% highlight bash %}
sh –c ps
bash –c ps
{% endhighlight %}
通常情况下，如果不是交互式shell，那么所有startup/cleanup files都会被跳掉。可以通过打上登录开关强制激活bash_profile，或者-i参数强制交互式。对于bash有一个特例，就是在没有终端的情况下，会试图检查当前是否是**rshd(8)**等网络伺服在调用批处理shell，如果是则也会执行bashrc。判断方法为：检查stdin是否是socket。因此**sshd(8)**等网络伺服偏向于使用**socketpair(2)**来充当不使用终端时的stdio流。因此，以下命令会使得bashrc被调用：
{% highlight bash %}
ssh hostname /some/command
{% endhighlight %}
因为ssh remote execution默认是不使用PTY的。

以下命令不会调用bashrc：
{% highlight bash %}
ssh –t hostname /some/command
{% endhighlight %}
因为此时**sshd(8)**会使用PTY来挂载stdio，stdio不是socket了，而又不是交互式shell，因为给出了-c参数，所以残念……

一种特例是ssh(1)但是不使用终端，因为没有携带-c参数，还是会不断等待用户输入，bash也可以通过-s参数强迫进入这种状态（此时stdio需要外界挂载）。因为不能获得终端信息，所以输入的处理机制大部分会关闭，比如命令历史、tab补全等（tab本身就是一种特殊终端按键，home和end等也是）。作业调度不能启动，因此SIGTERM、SIGINT、SIGQUIT等信号会直接作用于shell本身。为了便于上级作业调度器（也许在远程，考虑ssh -T的情况）的操作，此时shell不会将任务放置于独立进程组，而是作为自身进程组的一部分，从而使得上级作业调度器可以连shell带命令当成一个作业来调度。此时虽然因为作业调度，没有前后台进程组之分，因此无法把进程组停止、踢到后台等，但是仍然可以运行./a.out &，此时a.out会在“后台”运行，输出照旧，而stdin被重定向到/dev/null，因此**read(2)**访问stdin会读到对端关闭。这个时候虽然shell行为比较像交互式的，但是实际上$-里不包含i字母，即实际上运行在批处理模式。这种特例情况下，bashrc会被调用。
{% highlight bash %}
# ssh -T hostname
# echo $-
hB
{% endhighlight %}

携带-c参数时bash的$-包含c字母。

携带-s参数时bash的$-包含s字母。

###6.3 登录的

登录shell是由**login(1)**产生的第一个shell，这个shell需要完整地执行会话初始化。对于默认配置的bash，会执行~/.bash_profile，如果没有找到，就执行/etc/profile。登录shell在退出的时候会执行~/.bash_logout。作业调度也是登录shell进行，因为是会话组长。登录shell会设置环境变量SHLVL=1，此后每一次嵌套启动子shell都会把这个变量+1。这也是子shell判定自己是否是登录shell的重要依据。

登录shell的标准启动方法是**execve(2)**的时候将argv[0]的第一个字母设置成减号。这是约定行为，不管argv[0]写了什么，只要第一字符是减号，就代表这是登录shell。ps(1)的时候看到-bash或者-/bin/bash甚至-ash都可以，不过比较标准的做法是减号跟着basename，即-bash。

bash --login可以强制一个子shell成为登录shell，此时bash不会去读取bashrc，而是读取bash_profile。但是因为会话实际上由会话组长维持，因此bash退出的时候也不会执行bash_logout。

POSIX Shell不会读取任何startup/cleanup files。对于登录bash来说，通过参数--noprofile可以迫使bash跳过bash_profile的读取。

###6.4 非登录的

子shell，通常用作执行一个复杂子语句，也可以用于执行不可逆破坏性操作，比如chroot或者ulimit而保持退路。非登录shell不执行登录的初始化和反初始化，但是执行普通初始化，此时读取~/.bashrc，或者没找到就是/etc/bash.bashrc。因为登录shell通常也会执行普通初始化，因此习惯上~/.bash_profile会source一下~/.bashrc。

POSIX Shell没有初始化文件，bash也可以通过--norc参数跳过初始化。

###6.5 受限的

当bash被以rbash启动，或者bash -r启动，此时大量功能会被屏蔽。通过适当配置其环境（特别是chroot之后）会收到很有趣的效果。受限shell将阻止切换目录、使用带路径的命令（相对绝对都不行）、输出流重定向等。只要将${PATH}所能访问的路径里的绝大部分程序删除，那么就可以使得用户除了特定程序以外都无法运行的效果。例如只希望用户通过跳板机访问防火墙之后的主机，而不是操作防火墙本身。

受限bash的$-中包含r字母。

##7 常见login的行为

本章以Ubuntu 11.10为基准，其他平台可能有差异。

标准环境变量如HOME、USER等这里没有写出。

{% highlight bash %}
login(1)
TERM=linux or something like cons25
SHELL=<passwd(5)>
PATH=/bin:/usr/bin
argv[0]: -<basename>
{% endhighlight %}
示例
{% highlight bash %}
TERM=cons25
SHELL=/bin/bash
PATH=/bin:/usr/bin
argv[0]: -bash
{% endhighlight %}

{% highlight bash %}
sshd(8)
TERM=<set by ssh(1), or unset if not using PTY>
SHELL=<passwd(5)>
argv[0]: -<basename>
SSH_CLIENT=from_ip from_port local_port
SSH_CONNECTION=from_ip from_port local_ip local_port
If has PTY:
SSH_TTY=<path to PTY slave side>

For root user:
PATH=/usr/bin:/bin:/usr/sbin:/sbin
For normal user:
PATH=/usr/local/bin:/bin:/usr/bin
{% endhighlight %}
示例
{% highlight bash %}
TERM=xterm
SHELL=/bin/csh
argv[0]: -csh
SSH_CLIENT=123.45.67.89 55555 22
SSH_CONNECTION=123.45.67.89 55555 45.67.89.123 22
SSH_TTY=/dev/pts/7
USER=nobody
PATH=/usr/local/bin:/bin:/usr/bin
{% endhighlight %}

ssh的远程执行模式下，启动shell的行为为：
{% highlight bash %}
argv[0]: <basename>
argv[1]: -c
argv[2]: <command>
其他环境变量与交互式登录相同。
{% endhighlight %}
示例
{% highlight bash %}
execve("/bin/bash", ["bash", "-c", "echo Hello World!", NULL], environ)
{% endhighlight %}

{% highlight bash %}
cron(8)
SHELL=<set by crontab(5), or hardcoded /bin/sh>
PATH=/usr/bin:/bin, can be override in crontab(5)
argv[0]: <full path>
{% endhighlight %}
示例
{%highlight bash %}
SHELL=/bin/sh
PATH=/usr/bin:/bin
argv[0]: /bin/sh
{% endhighlight %}

