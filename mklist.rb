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
  <h1><span class="title"><%= title.strip %></span>, par <span class="author"><%= author.strip %></span><% if link %>&nbsp;(<a href="<%= link %>">lien</a>)<% end %></h1>
  <div class="sources">
  <% if source %>
    <blockquote class="comment">
      <%= comment.strip.sub('\n', "<br/>") %><br/>
      <span class="comment-author">—&nbsp;&nbsp;<a class="handle" href="<%= source %>">@<%= source.split("/")[3] %></a></span>
    </blockquote>
  <% elsif sources %>
    <% for s in sources %>
      <blockquote class="comment">
        <%= s["comment"].strip.sub('\n', "<br/>") %><br/>
        <span class="comment-author">—&nbsp;&nbsp;<a class="handle" href="<%= s["link"] %>">@<%= s["link"].split("/")[3] %></a></span>
      </blockquote>
    <% end %>
  <% end %>
  </div>
</article>
EOS

renderer = ERB.new(book_template, 3)

File.open("index.md", "w") do |f|
  f.write <<-EOS
---
layout: default
---

<img src="./assets/banner.png" id="banner" alt="Un ouvrage de socio par jour du 1er au 24 décembre" />

<b>#SocioNoel</b> est une idée originale de [@CobbleAndFrame](https://twitter.com/CobbleAndFrame/status/671360041136558081), qui a également créé l’image ci-dessus (utilisée sans aucune permission).
La liste ci-dessous est compilée à la main à partir des tweets qui ont ce hashtag ([voir sur Twitter](https://twitter.com/search?f=tweets&vertical=default&q=socionoel)).
Certaines personnes apparaissent plusieurs fois parce qu’elles ont mentionné 
plusieurs livres le même jour (bouuuuh !).
Il n’y a pas d’ordre particulier.

  EOS


  days.each do |day, books|
    f.write "## #{day} Décembre\n"

    books.each do |book|
      f.write renderer.result(book.to_binding)
    end
  end
end
