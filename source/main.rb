require "redcarpet"
require "yaml"

require "active_support/inflector"

def api_host
  ENV["API_HOST"] || "localhost:5000"
end

def prefix
  "data/pages"
end

def gen(ss, anchors, &block)
  x = Weaver::Elements.new(ss, anchors)
  x.instance_eval &block
  x.generate
end

def make_page(pathname, filename)

  empty_page "#{pathname}", "Hibiol Wiki" do
    header do
      col 12 do
        h1 "Hibiol Wiki"

      end
    end

    row do
      col 12 do

        content = File.read("#{filename}")

        renderer = Redcarpet::Render::HTML.new(escape_html: true)
        markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)

        ibox do

          name = filename.sub(/\.md$/, "").sub(/^#{prefix}\//, "")

          name = "Preview the page" if filename == ".tmp_preview.md"

          title { 
            h2 {

              text "#{name.camelize}"
              span :class => "pull-right", style: "font-size: 0.7em; font-weight: normal" do

                a href: "/edit/page?slug=#{name}&name=#{name.camelize}", target: "_top", style: "color: blue;" do
                  icon :edit
                end if filename != ".tmp_preview.md"
              end
            }
          }

          rendered = markdown.render(content)

          rendered.gsub!(/<img src="(.+?)"/, '<img class="img-responsive" src="/images/\\1"')

          regex = /\[\[(?<page_name>[A-Z][a-zA-Z0-9]+)\]\]/
          rendered.gsub!(regex) do |word|
            w = regex.match(word)

            link_slug = w[:page_name].underscore
            link_file = "#{prefix}/#{link_slug}.md"
            link_title = "#{link_slug.camelize}"

            if File.exist?(link_file)
              gen(self, @anchors) do
                a link_title, href: "/#{link_slug}", target: "_top", style: "color: blue;"
              end

            else
              gen(self, @anchors) do
                a link_title, href: "/edit/page?slug=#{link_slug}&name=#{link_title}", target: "_top", style: "color: red;"
              end

            end

          end

          text rendered
        end

      end
    end
  end

end
