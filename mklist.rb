#! /usr/bin/env ruby
# -*- coding: UTF-8 -*-

require "erb"
require "ostruct"
require "yaml"
require "fileutils"
require "set"

def day_title(day)
  "#{day == 1 ? "1er" : day} Décembre"
end

def day_anchor(day)
  "dec15-#{day}"
end

class Book
  # Note that we also use this HTML to generate the LaTeX used for the PDF.
  # This is why we use <div class="ref"> instead of h{1..6} for the title.
  TEMPLATE = <<-EOS
<article class="book">
  <div class="ref" id="<%= anchor %>"><b class="title"><%= title %></b><%= author_html %><% if link %>&nbsp;(<a href="<%= link %>">lien</a>)<% end %></div>
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

  def title
    @attrs["title"]
  end

  def author
    @attrs["author"]
  end

  def sources
    if has? "source"
      [{"link" => @attrs["source"], "comment" => @attrs["comment"]}]
    else
      @attrs["sources"]
    end
  end

  def validate!
    must "have a title" unless title
    must "have an author" unless author
    if has? "sources"
      sources = @attrs["sources"]
      must "have sources" if sources.nil? || sources.empty?
      must "use 'source' instead of 'sources' if there's only one" if sources.is_a? String
      sources.each_with_index do |s, i|
        %w[link comment].each do |attr|
          must "have a #{attr} for its source #{i}" unless s.has_key? attr
        end
      end
    elsif !has? "source"
      must "have a source"
    else
      source = @attrs["source"]
      must "use 'sources' instead of 'source'" if source.is_a? Array
      must "have a comment" unless has? "comment"
      must "use Twitter for the source" if source !~ %r{^https?://twitter\.com/[^/]+/}
    end
  end

  def to_s
    "#{@attrs["title"]} (day #{@day}, ##{@idx})"
  end

  def to_html
    id = "#{@attrs["title"]} #{@attrs["author"]}".gsub(/[^A-Za-z0-9]+/, "-")
    @attrs["anchor"] = "#{day_anchor @day}-#{id}"
    @attrs["author_html"] = if @attrs["author"] == "collectif"
                              " (collectif)"
                            else
                              prefix = if @attrs["directed"]
                                         "dirigé par"
                                       elsif @attrs["coordinated"]
                                         "coordonné par"
                                       elsif @attrs["type"] == "movie"
                                         "réalisé par"
                                       else
                                         "par"
                                       end

                              %(, #{prefix} <span class="author">#{@attrs["author"]}</span>)
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

class BooksList
  def initialize(source)
    @days = YAML.load_file(source)
  end

  def write_jekyll(target)
    File.open(target, "w") do |f|
      write_jekyll_prelude f
      write_html_file f
    end
  end

  def write_html(target)
    File.open(target, "w") do |f|
      write_html_prelude f
      write_html_file f
      write_html_end f
    end
  end

  def write_compact_markdown(target)
    File.open(target, "w") do |f|
      @days.each do |day, books|
        books.each_with_index do |h, i|
          book = Book.new(h, day, i)
          f.write "- *#{book.title}* (#{book.author})\n"
        end
      end
    end
  end

  def stats
    books_count = 0
    mentions_count = 0
    authors = []
    authors_mentions = {}
    sources = Set.new

    split_authors = /(?:,\s+(?:et\s+)?|\s+et\s+)/

    @days.each do |day, books|
      books.each_with_index do |h, i|
        b = Book.new(h, day, i)
        books_count += 1

        book_sources = b.sources
        book_sources.each do |source|
          mentions_count += 1

          source["link"] =~ %r{^https?://twitter\.com/([^/]+)/}
          sources << $1
        end

        b.author.split(split_authors).each do |a|
          authors << a

          authors_mentions[a] ||= 0
          authors_mentions[a] += book_sources.size
        end
      end
    end

    authors = authors.sort.group_by { |a| a }.map { |a, x| [a, x.size]}.sort_by(&:last).reverse
    authors_mentions = authors_mentions.entries.sort_by(&:last).reverse

    {
      :books_count => books_count,
      :authors_count => authors.size,
      :mentions_count => mentions_count,
      :sources_count => sources.size,
      :most_common_authors => authors[0..2],
      :most_mentioned_authors => authors_mentions[0..2],
    }
  end

  private

  def write_html_file(file)
    @days.each do |day, books|
      file.write %{<h2 id="#{day_anchor day}">#{day_title day}</h2>\n}

      if books.nil? or books.empty?
        file.write %(<p class="notice">Il n’y a pas encore de livres pour ce jour.</p>\n)
        next
      end

      books.each_with_index do |hash, i|
        book = Book.new(hash, day, i)
        file.write book.to_html
      end
    end
  end

  def write_jekyll_prelude(file)
    file.write <<-EOS
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

    @days.each_with_index do |p, i|
      day = p[0]
      file.write %{#{i + 1}. [#{day_title day}](##{day_anchor day})\n}
    end

    file.write "\n"
  end

  def write_html_prelude(file)
    file.write <<-EOS
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width initial-scale=1" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <title>#SocioNoël</title>
</head>
<body>
    EOS
  end

  def write_html_end(file)
    file.write "</body></html>"
  end
end

def make_pdf(source, target)
  tmp = ".tex2pdf#{rand}"
  tex = "#{tmp}.tex"
  begin
    system "pandoc", "--latex-engine=xelatex", "--standalone", source, "-o", tex
    system "xelatex", tex
    FileUtils.mv "#{tmp}.pdf", target
  ensure
    Dir["#{tmp}.*"].each { |f| File.unlink f }
  end
end

ls = BooksList.new "books.yml"

if ARGV.include? "--pdf"
  html = "_books.html"
  begin
    ls.write_html html
    make_pdf html, "books.pdf"
  ensure
    File.unlink html
  end
elsif ARGV.include? "--html"
  ls.write_html "books.html"
elsif ARGV.include? "--compact-markdown"
  ls.write_compact_markdown "books.md"
elsif ARGV.include? "--stats"
  ls.stats.each do |label, value|
    puts "#{label}: #{value}"
  end
else
  ls.write_jekyll "index.md"
end
