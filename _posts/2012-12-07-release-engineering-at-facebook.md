---
layout: post
title: "Release Engineering at Facebook"
description: ""
category: 
author: facebook
tags: ['release']
thumbnail: /assets/themes/twitter/bootstrap/img/2012-12-07-release-engineering-at-facebook.md/thumbnail.png
abstract: 让我们一起看看Facebook的软件发布是什么样子的？ 要知道这篇文章可是Facebook 11年5月的技术快照啊。
---
{% include JB/setup %}
[原文摘自](http://devops.com/2012/11/08/release-engineering-at-facebook/)

本文是来自Facebook的软件发布工程师 [Chuck Rossi](https://twitter.com/chuckr) 在[QConSF](http://qconsf.com/sf2012/) 2012上的一次演讲。

twitter： [@mattokeefe](https://twitter.com/chuckr)


Chuck其实不愿提及以“D”或“O”打头的那个词 “DevOps,  但自从John Allspaw（Etsy的OP高级副总裁,前Flickr工程师）在Velocity09年大会上做了 [“10+ Deploys Per Day: Dev and Ops Cooperation at Flickr“](http://www.youtube.com/watch?v=LdOe18KhtT4)的演讲后，他便从此被打动了。这也使得他在Facebook组建起一个关于开发和运维合作的训练营，因此他的演讲中尽是对新开发人员的培训内容。

## 面临的问题
开发人员想要尽可能快的产出代码成品，发布工程师也不希望有任何打断，因此便产生了一个流程需求。“我可以发布的更快么”，“不行，你走开”。这样当然不行啦，于是开发人员和发布工程师努力开始进行改变。
Facebook本身的迭代速度几近疯狂，而且规模（服务和基础设施）如此巨大，世界上几乎没有那家公司在这样大规模的情况下还向前发展（迭代）得这么快。

在Chuck的处理方式中有两件东西：工具和文化（译注：这也是DevOps的核心原则）。
他在听过Allspaw的演讲后认真理解了所谓的“文化”，他对开发人员宣灌的第一件事情就是：他们将把自己的对程序的改变呈献给全世界，如果他们写完代码就把其抛过墙去（译注：DevOps理念强调的Dev与Ops之间隔阂的那堵墙），这将直接影响Chuck的Mom系统（即Facebook的业务）。 因为你不得不进行一些基础的工作，并且把代码Check-in到主干，再到Facebook系统发布也是开发人员应尽的操作职责。要知道在Facebook并没有QA团队在程序发布前去帮你发现其中的Bug。

那么你该如何去做呢？你需要知道什么时候，什么样子表示你的提交完成了。Facebook的所有系统发布都遵循这样的路径，日复一日。


## FaceBook是如何做提交的？

Chuck并不关心你的源代码控制系统是什么？因为他讨厌所有的源代码控制系统。他们从主干进行发布（译注：通常会拉出Release Branch做发布），每周日下午6点，从主干拉出“最新”的分支，接下来的两天进行发布前的测试。不过那都是过去了， 现在他们在周二发布，周三至周五选择需要做的改进，每天差不多有50-300项改进被整合进去。

但是，Chuck觉得这样还不够，他在Facebook engineering blog上发表的[“Ship early and ship twice as often”](https://www.facebook.com/notes/facebook-engineering/ship-early-and-ship-twice-as-often/10150985860363920)一文表明了这一点。 2012年8月份的时候他们每天可以发布的变更是过去的两倍了。这种疯狂是一些人不能想象的，因为尽管现在每天的改进数量没变但改进本身比以前小得多了。

现在每周差不多有800个开发人员check in代码，并且随着雇员的增加还会增长。每个月差不多有10K次的代码提交，但是每天的发布占比还是很稳定的。 产品发布是有节奏的， 因此你应该把主要精力投入到每周级别的大发布中                                                                                                 
周三的时候 很多的代码修改涌入，要小心周五的发布,要知道在Google可有“逢周五不发布”的传统。不要把代码提交到主干后就溜掉了，要知道周日和周一可是Facebook的大日子，因为人们习惯这个时候上传和查看周末的照片。
如果你不记得该如何去发布，千万不要做任何事情。仅仅check in代码到主干，你不能避免日常发布中的操作负担
记住你不是今天唯一做发布的团队，把小的修改整合在一起，以至于你可以看到公司层面的发布计划，在Facebook他们建立其组群用做改进的整合。

## Dogfooding
“你应该时刻保持被测试”，虽然人们老是提起但并不是真正理解，但是Facebook却是很认真对待测试。  员工们从来不可能直接影响 facebook.com 主站， 因为他们所有改变将被重定向到 www.latest.facebook.com. 这个站是线上实际生产环境加上所有提交的改变，因此整个公司可以看到做了哪些改动。如果有任何的致命错误，你甚至可以直达bug报告页面。

当你能浮现Bug的时候把它归档，让内部人员在上报错误的时候更容易更顺畅。 Facebook内部页面将包含一些捕获会话状态的按钮，可以帮你把bug报告给合适的人。

当Chuck的发布，还要求开发人员的修改在需要发布前不要急于merge到主干，而是将少许的修改先发布在www.inyour.facebook.com。

Facebook.com主站也不能用作沙盒， 开发人员是不允许在生产环境随意测试的。如果你有10亿用户，就千万别事情在生产环境搞砸了。在Facebook有一套完全分离的并且具有较好鲁棒性的沙盒。

Facebook确保了整个系统中的每一块都有工程师负责，并且有一个快速找到On-call人员的工具。在Facebook On-call职责非常严肃认真，没有工程师可以逃离于On-call职责之外。


## Facebook的工具

### 自服务
在Facebook 你可以在IRC中做任何事情，IRC一个频道有上千人规模。简单的问题由机器人回答，比如查询任何一个待发布版本的状态的，同样也有浏览器截图       。
机器人是你的朋友，像一只宠物狗一样跟随你。也有机器人会问开发人员去确认是否想把改变发布。        

### 我们在哪儿？
Facebook 有一个显示每天发布状态的精美仪表盘，还有一个测试控制台。当Chuck进行最后merge的时候，会立即发起系统测试，他们大概有3500个单元测试用例并且在每台机器上运行。每次大的改变都会进行这些测试。

### Error tracking
Facebook有成千上万的web服务器，错误日志中饱含有用数据但他们不得不为大量级的日志专门编写了一个日志聚合器。在Facebook你可以通过仪表盘，点击一处日志错误然后查看对应的调用栈，点开一个函数就会展开代码对应的git blame信息，从而告诉你这段错误是谁引入的。Chuck他们还用一个名为Scuba的分析系统，这个系统可以展示其他事件的关系及对应趋势，比如用鼠标滑过某错误时，你就可以得到这个错误最近的出现趋势图。

### Gatekeeper
这是Facebook主要的战略优势之一，即打开环境的钥匙。这是一个由终端控制的feature flag（译注：类似于gflags，用标志开关控制feature）管理者，你可以有选择的打开新的feature，防止某些群组的用户察觉到刚做的变更。一次他们作为玩笑为Techcrunch打开了“传真你的招聘”的feature开关。

### Push karma
Chuck的工作就是管理风险。他观察仪表盘显示的这次变更的大小、diff工具中的讨论数量（通常只这次修改的冲突大小），如果发现这两个指标都很高，他就会更仔细查看。
他也可以看到每个变更请求者的发布karma高达5颗星，他有一个unlike按钮去降低你的karma。如果你的karma降到两星，Chuck就会停止发布的你的改进，你就不得不过来与他谈谈请求回到正规上。

### Perflab
这是一个用来做性能回归的强大工具，它可以比较主干和最新发布版本的性能。

### HipHop for PHP
这是一个由600个高度优化后的C++文件链接组成的单二进制工具，
但是有些时候他们也在开发环境中使用解释性的PHP。他们计划用准备开源的PHP虚拟机来解决这个问题。

### Bittorrent
这是他们分发大量二进制文件到成千上万台机器使用的peer-to-peer工具。bt的客户端向Open Tracker服务器请求节点，这样强大的分发能力可以保证数据15分钟内分发完成。

## 仅仅依靠工具是不能拯救你的
最主要的一点是，你不能依靠工具去改变你的状态。海外那些被洗过脑的人往往只吸收到了文化的部分，孰不知你需要的是一个公司的支持，从头到尾的支持。



## 引申阅读：
在Facebook程序的发布安排在哪天是有规定的。

karmar，梵文指业力；业力是指个人过去、现在或将来的行为所引发的结果的集合

