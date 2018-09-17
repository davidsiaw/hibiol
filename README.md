# Hibiol

Hibiol is a static wiki generator made with Weaver and Sumomo's API feature.

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
