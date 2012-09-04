---
layout: post
title: "本站供稿须知"
description: ""
category: 
tags: ['notification']
author: zerdliu
abstract: 如何为站点贡献文章。内部稿件投递方式。
thumbnail: http://liuxue.nhscnu.edu.cn/Article/UploadFiles/200808/2008081710260794.jpg
---
{% include JB/setup %}

## 基本说明

本站点是使用[jekyll](http://jekyllrb.com)搭建。
文章的格式是[Markdown](http://www.markdown.tw)

这是其中一篇文章的[源码](https://raw.github.com/zerdliu/www.baidu-ops.com/master/_posts/2012-08-21-disk-to-memory.md),转换后的页面样式在[这里](http://www.baidu-ops.com/2012/08/21/disk-to-memory/)

每篇post的开头都有如下一部分代码,说明如下
{% highlight xml %}
---
layout: post ## 必备，默认不需要改动。
title: "how to write post for this site" ##必备，文章题目
description: ""
category: 
tags: ['notification']  ## 必备，标明文章分类。需要使用英文
author: zerdliu  ## 必备,文章作者名字。真名（两个字）或者英文名字，笔名都可以
author_blog: zerdliu.github.com
abstract: 如何为站点贡献文章。内部稿件投递方式。 ## 必备，文章的摘要
thumbnail: http://liuxue.nhscnu.edu.cn/Article/UploadFiles/200808/2008081710260794.jpg ## 必备，提供一个能反映文章内容的图片，小图片即可，会显示在主页上。
---
{% endhighlight %}

文章中如果涉及图片,将图片按照含义命名（英文）好，然后放在一个目录里面。

如果不了解git及分布开发，至少需要提供一个xxx.md的文档，以减轻主编人肉编辑压力。

## 深入

本站点托管在github上。可以fork到本地进行编辑。

{% highlight bash %}
git clone git@github.com:/zerdliu/www.baidu-ops.com  ## 将仓库clone到本地
jekyll post title="how-to-write-a-post-for-this-site" ## 写一篇文章
vim _post/xxxxxxxx-how-to-write-a-post-for-this-site
jekyll   ## 生成站点
rake preview     # 本地review ， http://127.0.0.1:4000 
{% endhighlight %}
