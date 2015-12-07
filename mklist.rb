#! /usr/bin/env ruby
# -*- coding: UTF-8 -*-

require "erb"
require "ostruct"
require "yaml"

def day_title(day)
  "#{day == 1 ? "1er" : day} Décembre"
end

def day_anchor(day)
  "dec15-#{day}"
end

class Book
  TEMPLATE = <<-EOS
<article class="book">
  <h1<% if anchor %> id="<%= anchor %>"<% end %>><span class="title"><%= title %></span><%= author_html %><% if link %>&nbsp;(<a href="<%= link %>">lien</a>)<% end %></h1>
  <div class="sources">
  <% if source %>
    <blockquote class="comment">
      <%= comment.strip.gsub("\n", "<br/>") %><br/>
      <span class="comment-author">—&nbsp;&nbsp;<a class="handle" href="<%= source %>">@<%= source.split("/")[3] %></a></span>
    </blockquote>
  <% elsif sources %>
    <% for s in sources %>
      <blockquote class="comment">
        <%= s["comment"].strip.gsub("\n", "<br/>") %><br/>
        <span class="comment-author">—&nbsp;&nbsp;<a class="handle" href="<%= s["link"] %>">@<%= s["link"].split("/")[3] %></a></span>
      </blockquote>
    <% end %>
  <% end %>
  </div>
</article>
  EOS

  @@renderer = ERB.new(TEMPLATE, 3)

  def initialize(hash, day, idx)
    @attrs = hash
    @day = day
    @idx = idx

    validate!

    @attrs["title"].strip!
    @attrs["author"].strip!
  end

  def validate!
    must "have a title" unless has? "title"
    must "have an author" unless has? "author"
    if has? "sources"
      sources = @attrs["sources"]
      must "have sources" if sources.nil? || sources.empty?
      sources.each_with_index do |s, i|
        %w[link comment].each do |attr|
          must "have a #{attr} for its source #{i}" unless s.has_key? attr
        end
      end
    elsif !has? "source"
      must "have a source"
    else
      must "use 'sources' instead of 'source'" if @attrs["source"].is_a? Array
      must "have a comment" unless has? "comment"
    end
  end

  def to_s
    title = has?("title") ? @attrs["title"] : "<unknown title>"
    "#{title} (day #{@day}, ##{@idx})"
  end

  def to_html
    id = "#{@attrs["title"]} #{@attrs["author"]}".gsub(/[^A-Za-z0-9]+/, "-")
    @attrs["anchor"] = "#{day_anchor @day}-#{id}"
    @attrs["author_html"] = if @attrs["author"] == "collectif"
                              " (collectif)"
                            else
                              %(, par <span class="author">#{@attrs["author"]}</span>)
                            end

    @@renderer.result to_binding
  end

  private

  def to_binding
    # ERB wants bindings; not hashs. See https://bugs.ruby-lang.org/issues/8643
    OpenStruct.new(@attrs).instance_eval { binding }
  end

  def has?(k)
    @attrs.has_key?(k) && !@attrs[k].nil?
  end

  def must(s)
    raise "Book '#{self}' must #{s}"
  end
end

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

  days = YAML.load_file("books.yml")

  # we have to cheat here because GitHub doesn't seem to like <ol id="something">
  days.each_with_index do |p, i|
    day = p[0]
    f.write %{#{i + 1}. [#{day_title day}](##{day_anchor day})\n}
  end

  f.write "\n"

  days.each do |day, books|
    f.write %{<h2 id="#{day_anchor day}">#{day_title day}</h2>\n}

    if books.nil? or books.empty?
      f.write %(<p class="notice">Il n’y a pas encore de livres pour ce jour.</p>\n)
      next
    end

    books.each_with_index do |hash, i|
      book = Book.new(hash, day, i)
      f.write book.to_html
    end
  end
end
