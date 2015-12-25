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
  <% if sources %>
    <% for s in sources %>
      <blockquote class="comment">
        <%= s["comment"] %><br/>
        <span class="comment-author">—&nbsp;&nbsp;<%= s["author"] %></span>
      </blockquote>
    <% end %>
  <% end %>
  <% if recommenders %>
    <p class="recommenders"><% if sources %>Également recommandé<% else %>Recommandé<% end %> par <%= recommenders %>.</p>
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

  def ref
    "#{title}, #{author}"
  end

  def sources
    @sources || @sources = sources_array.select { |s| s.has_key? "comment" }
  end

  def recommenders
    # A recommender is a source without a comment.
    @recommenders || @recommenders = sources_array.reject { |s| s.has_key? "comment" }
  end

  def validate!
    must "have a title" unless title
    must "have an author" unless author
    if has? "sources"
      sources = @attrs["sources"]
      must "have sources" if sources.nil? || sources.empty?
      must "use 'source' instead of 'sources' if there's only one" if sources.is_a? String
      sources.each_with_index do |s, i|
        must "have a 'source' attr for its source #{i}" unless s.has_key? "source"
        must "use 'source' instead of 'link' for its source #{i}" if s.has_key? "link"
      end
    elsif !has? "source"
      must "have a source"
    else
      source = @attrs["source"]
      must "use 'sources' instead of 'source'" if source.is_a? Array
      must "use Twitter for its source" if source !~ %r{^https?://twitter\.com/[^/]+/}
    end
  end

  def to_s
    "#{@attrs["title"]} (day #{@day}, ##{@idx})"
  end

  def to_html
    id = "#{@attrs["title"]} #{@attrs["author"]}".gsub(/[^A-Za-z0-9]+/, "-")
    @attrs["anchor"] = "#{day_anchor @day}-#{id}"
    @attrs["author_html"] = author_html
    @@renderer.result to_binding
  end

  private

  def to_binding
    attrs = @attrs.clone
    attrs["sources"] = html_sources
    attrs["recommenders"] = html_recommenders
    attrs["title"] = htmlize attrs["title"]
    # ERB wants bindings; not hashs. See https://bugs.ruby-lang.org/issues/8643
    OpenStruct.new(attrs).instance_eval { binding }
  end

  def sources_array
    if has? "source"
      s = {"source" => @attrs["source"]}
      s["comment"] = @attrs["comment"] if @attrs.has_key? "comment"
      [s]
    else
      @attrs["sources"]
    end
  end

  def has?(k)
    @attrs.has_key?(k) && !@attrs[k].nil?
  end

  def must(s)
    raise "Book '#{self}' must #{s}"
  end

  def author_html
    return " (collectif)" if @attrs["author"] == "collectif"
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

  def html_sources
    sources.empty? ? nil : sources.map do |s|
      s["comment"] = htmlize s["comment"].strip.gsub("\n", "<br/>")
      s["author"] = html_source_author s
      s
    end
  end

  def html_recommenders
    rs = recommenders.map { |r| html_source_author r }
    case rs.size
    when 0 then nil
    when 1 then rs.first
    when 2 then "#{rs.first} et #{rs.last}"
    else
      "#{rs[0..-2].join(", ")}, et #{rs[-1]}"
    end
  end

  def html_source_author(s)
    source = s["source"]
    author = source.split("/")[3]
    %(<a class="handle" href="#{source}">@#{author}</a>)
  end

  def htmlize(s)
    s.gsub(/« /, "«&nbsp;").gsub(/ »/, "&nbsp;»")
  end
end

class BooksList
  def initialize(source)
    @days = YAML.load_file(source)
    validate!
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

  def each_book
    @days.each do |day, books|
      books.each_with_index do |h, i|
        yield Book.new(h, day, i)
      end
    end
  end

  def write_compact_markdown(target)
    File.open(target, "w") do |f|
      each_book do |book|
        f.write "- *#{book.title}* (#{book.author})\n"
      end
    end
  end

  def validate!
    refs = Set.new
    each_book do |book|
      if refs.include? book.ref
        puts "#{book} might be duplicated"
      end
      refs << book.ref
    end
  end

  def stats
    books_count = 0
    mentions_count = 0
    authors = []
    authors_mentions = {}
    sources = Set.new
    days = []

    split_authors = /(?:,\s+(?:et\s+)?|\s+et\s+)/

    @days.each do |day, books|
      days << [day, books.size]
      books.each_with_index do |h, i|
        b = Book.new(h, day, i)
        books_count += 1

        book_sources = b.sources + b.recommenders
        book_sources.each do |source|
          mentions_count += 1

          source["source"] =~ %r{^https?://twitter\.com/([^/]+)/}
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
      :days => days,
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
