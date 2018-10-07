# Hibiol

Hibiol is a static wiki generator made with Weaver and Sumomo's API feature.

# Getting started using docker

This is a lot easier because all you have is a current directory with your pages.

## Requires

- docker

## How to run

```
mkdir -p data/pages
docker run -v `pwd`/data:/app/data -v `pwd`/images:/app/images -p 4567:4567 -p 5000:5000 -ti davidsiaw/hibiol
```

## Where to use

https://localhost:4567

## How to deploy

```
docker run -v `pwd`/build:/app/release -v `pwd`/data:/app/data -ti davidsiaw/hibiol build
```

---

# Getting started normally

## Requires

- node js
- ruby

`bundle install`

## How to run

`foreman start`

## Where to use

https://localhost:4567

Click on the edit sign at the right to start!

### Editing

Uses markdown

To create new pages or to link to pages simply make a `[[WikiLink]]` (First letter must be capitalized, and numbers and letters are permitted following that. No symbols)

## How to deploy

`bundle exec weaver build`

Copy the build directory to your favorite static hosting site.

## Issues

Feel free to make them.
