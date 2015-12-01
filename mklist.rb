#! /usr/bin/env ruby
# -*- coding: UTF-8 -*-

require "erb"
require "ostruct"
require "yaml"

class Hash
  def to_binding
    # https://bugs.ruby-lang.org/issues/8643
    OpenStruct.new(self).instance_eval { binding }
  end
end

days = YAML.load_file("books.yml")

book_template = <<-EOS
<article class="book">
  <h1><span class="title"><%= title.strip %></span>, par <span class="author"><%= author.strip %></span></h1>
  <div class="sources">
  <% if source %>
    <p class="from">Recommandé par <a class="handle" href="<%= source %>">@<%= source.split("/")[3] %></a>&nbsp;:</p>
    <blockquote class="comment"><%= comment.strip.sub('\n', "<br/>") %></blockquote>
  <% elsif sources %>
    <% for s in sources %>
    <p class="from">Recommandé par <a class="handle" href="<%= s["link"] %>">@<%= s["link"].split("/")[3] %></a>&nbsp;:</p>
    <blockquote class="comment"><%= s["comment"].strip.sub('\n', "<br/>") %></blockquote>
    <% end %>
  <% end %>
  </div>
  <% if link %>
    <p>&rarr;&nbsp;<a href="<%= link %>">Lien</a></p>
  <% end %>
</article>
EOS

renderer = ERB.new(book_template, 3)

File.open("index.md", "w") do |f|
  f.write <<-EOS
---
layout: default
---

<img src="./assets/banner.png" id="banner" alt="Un ouvrage de socio par jour du 1er au 24 décembre" />
  EOS


  days.each do |day, books|
    f.write "## #{day} Décembre\n"

    books.each do |book|
      f.write renderer.result(book.to_binding)
    end
  end
end
