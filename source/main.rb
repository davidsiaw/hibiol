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
        shape = "diamond, regular=true"
      end
      defs << "#{v[:code]}[shape=#{shape}, label=\"#{v[:desc]}\"];"
    end

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
  splines=false;
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
      pana = Hanayo.new(file: ".tmp.rb").generate_dot
      File.write("a.dot", pana)
      `mkdir -p images/#{name}`
      `dot a.dot -Tpng -oimages/#{image_name}.png`
      block[:block] = ["![graphviz_dot](#{image_name}.png)"]

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

          name = "_preview_page" if filename == ".tmp_preview.md"

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

          separated_blocks = separate_blocks(content)

          convert_blocks!(separated_blocks, name)

          rendered = markdown.render( recombine_blocks(separated_blocks) )

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
