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

def separate_blocks(content)
  marked_blocks = []
  document_lines = []

  lines = content.split("\n")

  start_mark_regex = /^```(?<type>[a-z][a-z0-9_]+)/

  current_block_line_idx = 0
  current_block_lines = []
  current_block_type = ""
  marking = false
  lines.each_with_index do |line, idx|

    if marking
      if line.start_with?("```")
        marking = false
        marked_blocks << {
          line: current_block_line_idx,
          block: current_block_lines,
          type: current_block_type
        }
      else
        current_block_lines << line
      end

    else
      m = start_mark_regex.match line
      if m
        marking = true
        current_block_lines = []
        current_block_type = m[:type]
        current_block_line_idx = document_lines.length
        document_lines << ""
      else
        document_lines << line
      end
    end

  end

  {
    blocks: marked_blocks,
    lines: document_lines
  }
end


class Hanayo

  def initialize(options={}, &block)
    @start = nil
    @objects = {}
    @connections = {}
    @decisions = {}

    if block
      instance_eval(&block)
    end

    if options[:file]
      instance_eval(File.read(options[:file]), options[:file])
    end
  end

  def Start(with:)
    @start = with
  end

  def Define(a, as:)
    self.class.dd(a)
    @objects[:"#{a}"] = { desc: as, code: "A#{@objects.length}" }
  end

  def If(thing)
    @decisions[thing[:objname]] = [] if !@decisions.has_key?(thing[:objname])

    dec = thing[:passed_options].to_a.first

    @decisions[thing[:objname]] << {
      label: dec[0],
      destination: dec[1]
    }
  end

  class << self
    def dd(a)
      define_method(:"#{a}") do |options={}|
        if options[:then]
          @connections[:"#{a}"] = options[:then][:objname]
        end
        {
          objname: :"#{a}",
          passed_options: options
        }
      end
    end
  end

  def generate_dot

    defs = []
    conns = []

    @objects.each_with_index do |elem,idx|
      k,v = elem
      shape = "box"
      if "#{k}".end_with?("?")
        shape = "diamond"
      end
      defs << "#{v[:code]}[shape=#{shape}, label=\"\\n#{v[:desc]}\\n \"];"
    end

    conns << "Start -> #{@objects[:"#{@start[:objname]}"][:code]};" if @start

    @connections.each_with_index do |elem,idx|
      k,v = elem
      conns << "#{@objects[:"#{k}"][:code]} -> #{@objects[:"#{v}"][:code]};"
    end

    @decisions.each_with_index do |elem, idx|
      k,v = elem
      v.each do |other|
        #p other
        conns << "#{@objects[:"#{k}"][:code]} -> #{@objects[other[:destination][:objname]][:code]} [label=#{other[:label].to_s.inspect}];"
      end
    end

    <<-DOT   
digraph finite_state_machine {
  #{defs.join("\n  ")}
  #{conns.join("\n  ")}
}
    DOT
  end
end


def convert_blocks!(separated, name)

  separated[:blocks].each_with_index do |block,idx|

    image_name = "#{name}/#{idx}"

    if block[:type] == "math"
      elem = Weaver::Elements.new(@page, @anchors)
      elem.instance_eval do
        math block[:block].join("\n")
      end
      block[:block] = [elem.generate]

    elsif block[:type] == "graphviz_dot"

      File.write("a.dot", block[:block].join("\n"))
      `mkdir -p images/#{name}`
      `dot a.dot -Tpng -oimages/#{image_name}.png`
      block[:block] = ["![graphviz_dot](#{image_name}.png)"]

    elsif block[:type] == "flowchart"

      File.write(".tmp.rb", block[:block].join("\n"))

      begin
        pana = Hanayo.new(file: ".tmp.rb").generate_dot
        File.write("a.dot", pana)
        `mkdir -p images/#{name}`
        `dot a.dot -Tpng -oimages/#{image_name}.png`
        block[:block] = ["![graphviz_dot](#{image_name}.png)"]

      rescue Exception => e
        elem = Weaver::Elements.new(@page, @anchors)
        elem.instance_eval do
          text ["`#{e.message.gsub('`',"'")}`", "", e.backtrace.map{|x| "- `#{x.gsub('`',"'")}`"}.join("\n")].join("\n")
        end
        block[:block] = [elem.generate]
      end
    end

  end
end

def recombine_blocks(separated)

  marked_blocks = separated[:blocks]
  document_lines = separated[:lines]

  block_hash = {}
  marked_blocks.each do |block|
    block_hash[block[:line]] = block
  end

  result_lines = []
  document_lines.each_with_index do |line, idx|
    if block_hash.has_key?(idx)
      block_hash[idx][:block].each do |bline|
        result_lines << bline
      end
    else
      result_lines << document_lines[idx]
    end
  end

  result_lines.join("\n")
end

def render_file(filename, header_func: :title, show_title: true, preview: false)
  render(File.read("#{filename}"), filename, header_func: header_func, show_title: show_title, preview: preview)
end

def split_meta(content)
  result = {
    meta: {},
    content: content
  }

  if content.start_with?("---")
    sections = content.split("---\n", 3)
    begin
      result[:meta] = YAML.load(sections[1])
      result[:content] = sections[2]
    rescue
    end
  end

  result
end

def render(content, filename, header_func: :title, show_title: true, preview: false)
  preview = true unless ENV["PREVIEW"] == "true"
  renderer = Redcarpet::Render::HTML.new(escape_html: true)
  markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)

  name = filename.sub(/\.md$/, "").sub(/^#{prefix}\//, "")

  name = "_preview_page" if filename == ".tmp_preview.md"

  self.send(header_func) do
    h2 do
      text "#{name.camelize}" if show_title
      span :class => "pull-right", style: "font-size: 0.7em; font-weight: normal" do

        a href: "/edit/page?slug=#{name}&name=#{name.camelize}", target: "_top", style: "color: blue;" do
          icon :edit
          #text "(edit #{name})" if !show_title
        end
      end if !preview
    end
  end

  s = split_meta(content)
  content = s[:content]
  metadata = s[:meta]

  footer do
    references = metadata["references"]
    tags = metadata["tags"]

    if references

      h6 do
        h5 "References"
        ul do
          references.each do |num, val|
            li id: "reference_#{num}_background" do
              a "[#{num}]", id:"#reference_#{num}"
              text " - "
              text "#{val}".sub(/\(https?\:.+?\)/){ |x| gen(self, @anchors) { hyperlink x.gsub(/^\(|\)$/, ""), x }}
            end
          end
        end
      end

    end

    if tags

      h5 do
        text "Tags: "
        tags.each do |tag|
          a "#{tag} ", href:"/tags/#{tag}"
        end
      end

    end
  end if metadata.keys.length != 0

  # process blocks
  separated_blocks = separate_blocks(content)

  convert_blocks!(separated_blocks, name)

  rendered = markdown.render( recombine_blocks(separated_blocks) )

  rendered.gsub!(/<img src="(.+?)"/, '<img class="img-responsive" src="/images/\\1"')

  wikilink_match = /\[\[(?<page_name>[A-Z][a-zA-Z0-9]+)\]\]/
  rendered.gsub!(wikilink_match) do |word|
    w = wikilink_match.match(word)

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

  citation_match = /\{\{(?<refnum>[0-9]+)\}\}/
  rendered.gsub!(citation_match) do |word|
    w = citation_match.match(word)

    num = w[:refnum]
    gen(self, @anchors) do
      sup do
        a "[#{num}]", href: "#reference_#{num}", target: "_top"
      end
    end
  end

  icon_match = /:(?<icon>[a-zA-Z0-9-_]+):/
  rendered.gsub!(icon_match) do |word|
    iconsym = icon_match.match(word)[:icon]

    gen(self, @anchors) { icon :"#{iconsym}" }
  end

  rendered.gsub!("<table>", '<table class="table table-bordered table-striped table-hover">')

  rendered
end

def render_subsection(name, preview: false)
  filename = "data/pages/_#{name}.md"
  if File.exist?(filename)
    render_file(filename, header_func: :h1, show_title: false, preview: preview)
  else
    render("", filename, header_func: :h1, show_title: false, preview: preview)
  end
end

def make_standard_page(pathname, &block)

  topnav_page "#{pathname}", "Hibiol Wiki" do

    menu do
      nav "Home", :home, "/"
      nav "All pages", :list, "/meta/all_pages"
    end

    row do
      col 12 do
        text render_subsection(:header, preview: preview)
      end
    end

    instance_eval(&block)

    row do
      col 12 do
        text render_subsection(:footer, preview: preview)
      end
    end
  end

end

def make_page(pathname, filename)

  name = filename.sub(/\.md$/, "").sub(/^#{prefix}\//, "")
  preview = filename == ".tmp_preview.md"

  make_standard_page(pathname) do

    row do
      content_width = 12      
      sidebar_exists = File.exist?("data/pages/_sidebar.md")
      page_sidebar_exists = File.exist?("data/pages/_sidebar_#{name}.md")
      if sidebar_exists || page_sidebar_exists
        content_width = 9
      end
      sidebar_width = 12-content_width

      col content_width, sm: 12, xs: 12 do
        ibox do
          text render_file(filename, preview: preview)
        end
        if !preview
          text render_subsection(:sidebar, preview: preview) if !sidebar_exists
          br if !sidebar_exists && !page_sidebar_exists
          text render_subsection(:"sidebar_#{name}", preview: preview) if !page_sidebar_exists
        end
      end

      col sidebar_width, sm: 12, xs: 12 do
        text render_subsection(:sidebar, preview: preview) if sidebar_exists
        br if sidebar_exists && page_sidebar_exists
        text render_subsection(:"sidebar_#{name}", preview: preview) if page_sidebar_exists
      end
    end

  end

end
