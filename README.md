# SocioNoel

This repo contains a single-page website gathering all the Sociology(-ish)
books mentioned with the Twitter hashtag [#SocioNoel][hashtag].

[hashtag]: https://twitter.com/search?f=tweets&vertical=default&q=%23socionoel&src=typd

## Usage

Update `index.md` from `books.yml`:

```sh
./mklist.rb [--strict]
```

Use `--strict` to run more checks on the resulting list (e.g. find possibly
duplicated titles).
