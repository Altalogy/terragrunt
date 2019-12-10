require "nokogiri"

class CollectionNavGenerator < Jekyll::Generator
  def generate(site)
    @toc = ''
    site.data['collections_nav'] = {}
    parser = Jekyll::AsciiDoc::Converter.new(site.config)

    site.collections.each do |collection|
      @toc = ''
      if collection[1].label != 'posts'
        docs_grouped = collection[1].docs.group_by { |d| d.data['categories'] }
        @toc = @toc + "<ul>"
        docs_grouped.each do |doc_grouped|
          cat = doc_grouped[0][0].to_s
          @toc = @toc + "<li class='toc-level-category'> \
            <span class='category-head collapsed' data-toggle='collapse' data-target='#cat-nav-id-#{ slugify(cat) }' \
              role='button' aria-expanded='false' aria-controls='#{ slugify(cat) }'> \
              <span class='arrow-icon glyphicon glyphicon-triangle-bottom'></span> \
            </span><a href='/#{collection[1].label}##{cat.downcase}'>#{cat.capitalize.gsub('-', ' ')}</a>" unless cat.empty?
          @toc = @toc + "<ul id='cat-nav-id-#{ slugify(cat) }' class='collapse'>" unless cat.empty?
          doc_grouped[1].each do |doc|
            doc.data['subnav'] = []
            if doc['ext'] == ".adoc"
              @toc = @toc + "<li class='toc-level-doc'> \
                <span class='collapsed' data-toggle='collapse' data-target='#doc-nav-id-#{ slugify(doc.data['title']) }' role='button' aria-expanded='false' aria-controls='toc'> \
                  <span class='arrow-icon glyphicon glyphicon-triangle-bottom'></span> \
                </span> \
                <a href='#{doc.url}'>#{doc.data['title']}</a>"

              content = Nokogiri::HTML(parser.convert(doc.content))
              toc_content = parse_content(content, doc.url)
              @toc = @toc + "<ul id='doc-nav-id-#{ slugify(doc.data['title']) }' class='collapse'>"
              @toc = @toc + build_toc_list(toc_content)
              @toc = @toc + "</ul>"
              @toc = @toc + "</li>"
            end
          end
          @toc = @toc + "</ul>"
          @toc = @toc + "</li>" unless cat.empty?
        end
        @toc = @toc + "</ul>"
      end

      site.data['collections_nav'][collection[1].label] = @toc
    end
  end

  def parse_content(doc, doc_url)
    headers = Hash.new(0)

    (doc.css("h1,h2,h3,h4,h5"))
      .inject([]) do |entries, node|
      text = node.text
      id = node.attribute('id') || text
           .downcase
           .gsub(PUNCTUATION_REGEXP, '') # remove punctuation
           .tr(' ', '-') # replace spaces with dash

      suffix_num = headers[id]
      headers[id] += 1

      entries << {
        id: suffix_num.zero? ? id : "#{id}-#{suffix_num}",
        text: CGI.escapeHTML(text),
        node_name: node.name,
        header_content: node.children.first,
        h_num: node.name.delete('h').to_i,
        doc_url: doc_url
      }
    end
  end

  def build_toc_list(entries)
    i = 0
    toc_list = +''
    min_h_num = entries.map { |e| e[:h_num] }.min

    while i < entries.count
      entry = entries[i]
      if entry[:h_num] == min_h_num
        # If the current entry should not be indented in the list, add the entry to the list
        toc_list << %(<li class="toc-level-#{entry[:node_name]}"><a href="#{entry[:doc_url]}##{entry[:id]}">#{entry[:text]}</a>)
        # If the next entry should be indented in the list, generate a sublist
        next_i = i + 1
        if next_i < entries.count && entries[next_i][:h_num] > min_h_num
          nest_entries = get_nest_entries(entries[next_i, entries.count], min_h_num)
          toc_list << %(\n<ul>\n#{build_toc_list(nest_entries)}</ul>\n)
          i += nest_entries.count
        end
        # Add the closing tag for the current entry in the list
        toc_list << %(</li>\n)
      elsif entry[:h_num] > min_h_num
        # If the current entry should be indented in the list, generate a sublist
        nest_entries = get_nest_entries(entries[i, entries.count], min_h_num)
        toc_list << build_toc_list(nest_entries)
        i += nest_entries.count - 1
      end
      i += 1
    end
    return toc_list
  end

  def get_nest_entries(entries, min_h_num)
    entries.inject([]) do |nest_entries, entry|
      break nest_entries if entry[:h_num] == min_h_num
      nest_entries << entry
    end
  end

  def slugify(text)
    text.downcase.gsub(' ', '-')
  end
end
