---
layout: post
title: "一名运维工程师的读书列表"
description: ""
category: 
tags: [books]
author: zerdliu
abstract: 运维工程师成长的过程中离不开知识，书籍是获取知识的手段。技术，技术文化，提升思维深度一样都不能少。
thumbnail: http://woiba.com/wp-content/uploads/2012/02/tech-books.jpg
---
{% include JB/setup %}

![bookself](/assets/themes/twitter/bootstrap/img/bookself.jpg)

做应用运维这一行，读了一些书,从好书里面学到了不少知识。希望这个书单不断变长。

[stackoverflow](http://www.stackoverflow.com)上面列出了一名程序员都应该学习的[书单](http://stackoverflow.com/questions/1711/what-is-the-single-most-influential-book-every-programmer-should-read?tab=votes#tab-top),这是[中文版](http://book.douban.com/doulist/1244005/)

我把书分为3类：技术， 技术文化， 外延

## 技术文化读本：

* [程序员修炼之道](http://book.douban.com/subject/1152111/)里面的思想不仅适合开发，也适合运维。印象最深的是“正交设计”和“K.I.S.S.原则”

* [软件随想录](http://book.douban.com/subject/4163938/)joel带给你不同的思路，从不同的角度看软件和软件文化另外一本他之前出版的文集[joel谈优秀软件开发方法](http://book.douban.com/subject/2193777/)

* [黑客与画家](http://book.douban.com/subject/6021440/)关于互联网公司和软件的特点；设计；编程语言。java < python < perl < ruby < lisp 给我印象很深，坚定了我学习ruby和了解lisp的信心。

* [unix编程艺术](http://book.douban.com/subject/1467587/)在unix平台上工作，但对unix的开发和设计哲学不了解，转而采用windows的方式，做了很多额外的工作而没抓住本质。此书必读。另外近期出版了一本[linux/unix设计思想](http://www.amazon.cn/gp/product/B007PYVKLC/ref=oh_details_o01_s00_i00)也可以读一读。

* [软件开发沉思录](http://book.douban.com/subject/4031959/)能学到很多新奇的想法：关于“软件开发最后一英里”，ruby，多语言开发，配置文件重构，一键发布，性能测试的探讨一针见血。

* [rework](http://www.amazon.cn/gp/product/B0048EKQS0/ref=oh_details_o03_s00_i00)极简的思想，并应用于产品开发和工程实现。非常棒。很多工程师都把简单的问题搞复杂。此书必须要读一读。

* [你的灯亮着吗？](http://book.douban.com/subject/1135754/)关于问题的一本书。当中一句话受益匪浅“问题只能转化而不能被解决”。值得反复读。

* [杰拉尔德•温伯格(Gerald M.Weinberg)](http://book.douban.com/subject_search?search_text=%E6%B8%A9%E4%BC%AF%E6%A0%BC&cat=1003) 的书思想都很深邃，有兴趣可以读一读。

## 技术上的书籍：

* [unix超级工具(上/下册)](http://book.douban.com/subject/1333125/)非常棒。都是老一批骨灰级用户多年经验的结晶。每一个专题都需要反复阅读，并亲身实践。对于刚接触linux的人必须反复研读。才能了解unix设计的要点。读得多了就觉得unix是一个非常优雅的设计。还有一本开源的讲bash的书：[abs](http://tldp.org/LDP/abs/html/),bash学习必备的书，讲得很透彻，了解shell，通过shell熟悉linux的运行机制。

* [持续集成](http://book.douban.com/subject/2580604/)敏捷开发的最重要实践之一。软件工程的重要思想。

* [持续交付](http://book.douban.com/subject/6862062/)和上一本书思想一致，更切实与op的实际。一定要从产品研发周期看问题，不能仅看运维。开发和运维剁得越开，运维越是不好做。

* [unix和linux自动化管理](http://book.douban.com/subject/1238125/)老牌系统管理员的经验总结。书读得比较早了，印象最深的就是对数据推和拉的分析。还有一点印象比较深，如何设计shell脚本的配置文件。注意体会作者的思路，对问题的权衡。书中也有很多代码片段。

* [精通正则表达式](http://book.douban.com/subject/2154713/)经典。正则是非常美的DSL，perl是所有语言中正则和语言本体结合最紧密，最好用的语言。虽然后来喜欢ruby，但这一点仍然是perl的特色。

* [perl最佳实践](http://book.douban.com/subject/3063982/)如果在用perl，则在写真实的程序之前，一定要读perl的设计很灵活，遵循一定的约束，写出来的代码才能读。

* [sed和awk](http://book.douban.com/subject/1236944/)系统管理员必备工具。对awk把对文本一行一行的读取，这样一个大循环内置于工具所体现出来的表述上的简洁，非常震撼。

* [C专家编程](http://book.douban.com/subject/1232029/)非常有趣的一本书。给读者展现了C设计的一些优缺点，如何更好的使用C。对系统底层的理解也能加深。

* [重构](http://product.china-pub.com/196374)这本书我读过一点，书上的实例亲手操作了一下，非常cool。把code写好，写棒，不容易。

* [松本行弘的程序世界](http://www.amazon.cn/mn/detailApp?uid=479-6704744-9217618&ref=YS_TR_6&asin=B005KGBTQ8)了解ruby的设计折中，为何要采取此种class和module的继承机制，block的设计都做了哪些考虑和折中。体会他的思想。

* [ruby元编程](http://www.amazon.cn/Ruby%E5%85%83%E7%BC%96%E7%A8%8B-Paolo-Perrotta/dp/B0073APSCK/ref=pd_sim_b_2)信息量比较大。ruby的得体的设计，使它真的非常适合程序员使用。看完元编程后我就深深喜欢ruby了。真的简单，优雅。

## 其他读本
有益于提升自己能力。在另一个领域的知识能够很好的补充正在从事的专业领域的知识。比如：设计，中医给我的触动比较深。他们背后和unix所体现出来的，差不多。

* [演说之禅](http://book.douban.com/subject/3313363/)读完这本书，我很少再使用ppt的自带动画。都采用翻页的形式。ppt仅展现更简单的信息。简单就是美。所有讲ppt设计的书，这本最好。

 
* [走近中医](http://product.china-pub.com/676957)中医也是一个系统，可以类比unix。每个部分之间的关系紧凑，严谨，并且是辩证的。有利于形成系统思考的方法。
