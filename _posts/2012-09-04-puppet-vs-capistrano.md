---
layout: post
title: "[译文]puppet和capistrano 简要的对比"
description: ""
category: 
tags: [puppet,capistrano,deployment]
author: zerdliu
thumbnail: http://jedi.be/blog/wp-content/uploads/2010/05/puppetcamp-europe-2010.png 
abstract: "capistrano和puppet都能够做到部署的功能。那他们有什么区别呢？capistrano是在执行action，puppet是在维护state。本文将介绍两者之间的不同。并剖析其最初面对的问题和设计目标如何造成了这种不同。同学们，不能一刀切哦。"
---
{% include JB/setup %}

[原文地址](http://www.agileweboperations.com/puppet-vs-capistrano-short-comparison)

我们现在不仅使用[capistrano](https://github.com/capistrano/capistrano/wiki)部署Ruby on Rails的应用，也用来安装和管理我们的物理服务器和虚拟（基于Xen）服务器。我们编写capistrano的recipe用来添加用户，安装apache和mysql，配置Xen虚拟机等等。邂逅了[puppet](http://www.agileweboperations.com/configuration-management-introduction-to-puppet)，我开始惊讶他们之间本质的不同。puppet宣称能够让用户自动化管理服务器，扩展集群，这个目标我们已经通过实现定制的capistrano recipe实现了。那么，他们之间的不同是什么呢？

## 设计目标

首先，我尝试理解这两个工具的设计目标。capistrano开发出来是为了部署rails应用。当然，他非常易于扩展而像我们一样用来管理服务器，像[deprec](http://deprec.org)这样的recipe汇集网站已经为capistrano提供了这些功能，但是，capistrano最基本的功能仍是部署。

puppet不同于capistrano，他一开始作为生命周期管理工具问世。他提供了定义服务间依赖和服务预期状态的能力，例如，一个配置文件描述apache应处于运行中，其运行需要依赖一些包。然后puppet自动化的达到你所设定的这个状态。这个不同的设计目的，使我们使用两个工具的方式是如此的不同。


## 使用方法

capistrano的recipe使用命令式的方法描述如何做。capistrano的recipe展现了系统上“动态”的视图。你能看到配置是如何一步步变化的。capistrano的recipe解答了“我想做什么”的问题。

puppet用声明的方法描述系统预期的状态。puppet的manifest解答了“他看起来应该是怎样的”的问题。puppet从这份配置中生成步骤，并自动的应用系统上。

## 特性对比

我发现了他们之间一些有趣的特性，整理成一个列表，目前还不完整，希望起到一个概览的作用。

 特性                 |   puppet                              | capistrano  
----------------------|---------------------------------------|---------------
 配置语言             | "元"语言（自己写的DSL）               |   Ruby      
 dry-run模拟执行      |  有                                   | 有（2.5+）  
 幂等                 |   是                                  | 否          
 对事务的支持         |  支持                                 |   支持      
 回滚                 |   不支持                              | 支持        
 随机监控服务器       |  不支持                               |     支持    
 操作模式             | daemon进程拉取配置                    |  用户推     
 定义依赖             | service，packages，files复杂依赖      | dir,writablity,command,gem,regex的单向依赖 
 解决依赖             | 自动                                  |  手工       

## 结论 


puppet 和 capistrano 处于不同的层，puppet更多的处理依赖的管理而不是脚本任务。在通常场景下，puppet 负责保证特定的系统配置，capistrano负责动态的步骤，像部署应用的新版本或者随机监控服务器（ad-hoc server monitoring）。但从我的经验和deprec上展示的脚本，capistrano能对配置系统起到很大的帮助。

