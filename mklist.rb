#! /usr/bin/env ruby
# -*- coding: UTF-8 -*-

require "erb"
require "ostruct"
require "yaml"

def day_title(day)
  "#{day == 1 ? "1er" : day} Décembre"
end

class Book
  TEMPLATE = <<-EOS
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

  def initialize(hash, day, idx)
    @attrs = hash
    @day = day
    @idx = idx
  end

  def to_binding
    # ERB wants bindings; not hashs. See https://bugs.ruby-lang.org/issues/8643
    OpenStruct.new(@attrs).instance_eval { binding }
  end

  def has?(k)
    @attrs.has_key?(k) && !@attrs[k].nil?
  end

  def [](k)
    @attrs[k]
  end

  def validate!
    must "have a title" unless has? "title"
    must "have an author" unless has? "author"
    if has? "sources"
      sources = self["sources"]
      must "have sources" if sources.nil? || sources.empty?
      sources.each_with_index do |s, i|
        %w[link comment].each do |attr|
          must "have a #{attr} for its source #{i}" unless s.has_key? attr
        end
      end
    elsif !has? "source"
      must "have a source"
    else
      must "use 'sources' instead of 'source'" if self["source"].is_a? Array
      must "have a comment" unless has? "comment"
    end
  end

  def to_s
    title = has?("title") ? self["title"] : "<unknown title>"
    "#{title} (day #{@day}, ##{@idx})"
  end

  private

  def must(s)
    raise "Book '#{self}' must #{s}"
  end
end

days = YAML.load_file("books.yml")

renderer = ERB.new(Book::TEMPLATE, 3)

File.open("index.md", "w") do |f|
  f.write <<-EOS
---
layout: default
---

<img src="./assets/banner.png" width="740" height="586" id="banner" alt="Un ouvrage de socio par jour du 1er au 24 décembre" />

<b>#SocioNoel</b> est une idée originale de [@CobbleAndFrame](https://twitter.com/CobbleAndFrame/status/671360041136558081), qui a également créé l’image ci-dessus (utilisée sans aucune permission).
La liste ci-dessous est compilée à la main à partir des tweets qui ont le hashtag [#SocioNoel](https://twitter.com/search?f=tweets&vertical=default&q=socionoel).
Certaines personnes apparaissent plusieurs fois parce qu’elles ont mentionné
plusieurs livres le même jour (bouuuuh !).
Il n’y a pas d’ordre particulier.

Le <a href="https://github.com/bfontaine/SocioNoel">code de cette page</a> est libre et la liste est dans le domaine public.
Contactez-moi sur Twitter (<a href="https://twitter.com/bfontn">@bfontn</a>) si vous la voulez dans un autre format (CSV/Excel, PDF, etc).

Accès direct à un jour :<br/>

  EOS

  # we have to cheat here because GitHub doesn't seem to like <ol id="something">
  idx = 0
  days.each do |day, _|
    idx += 1
    f.write %{#{idx}. [#{day_title day}](#dec15-#{day})\n}
  end

  f.write "\n"

  days.each do |day, books|
    f.write %{<h2 id="dec15-#{day}">#{day_title day}</h2>\n}

    if books.nil? or books.empty?
      f.write %(<p class="notice">Il n’y a pas encore de livres pour ce jour.</p>\n)
      next
    end

    books.each_with_index do |hash, i|
      book = Book.new(hash, day, i)
      book.validate!
      f.write renderer.result(book.to_binding)
    end
  end
end
