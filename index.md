---
layout: page
title: "百度运维部官方博客"
---
{% include JB/setup %}


<div class="row">
  <div class="span12">
    <div class="row">
      <div class="span9">

        {% for post in site.posts limit:5 %}
        <div class="row">
          <div class="span8">
            <h2><a class="post-title" href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }} </a></h2>
            <h4 class="info">
              [ {{ post.date | date: "%Y-%m-%d" }}
               | 文: <a href="{{ post.author_blog }}">{{ post.author }}</a> ]
            </h4>
            <br />
            {{ post.abstract }}
            <br /><br /><a href="{{ BASE_PATH }}{{ post.url }}">阅读全文>></a>
            <hr>
            <br />
            <br />
          </div>
        </div>
        {% endfor %}

      </div>
      <div class="span3">
        {% include JB/sidebar %}
      </div>
    </div>
  </div>
  <div class="span7">
    <h3><a href="{{ BASE_PATH }}{{ site.JB.archive_path }}">更早的文章</a></h3>
  </div>
</div>
