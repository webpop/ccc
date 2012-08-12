selfClosers = {}
selfClosers[key] = true for key in "br,img,hr,link,input,meta,col,frame,base,area".split(",")

htmlTags =
  head:
    _tags:
      title: {}
      link:
        rel: ["stylesheet", "alternate", "icon"]
        href: -> file.path for file in design.bundles["public"].files_as_array when file.isStyleSheet()
      script:
        src: -> file.path for file in design.bundles["public"].files_as_array when file.isJavaScript()
          
      style: {}
      meta:
        name: ["description", "authors"]
        content: []
        charset: ["UTF-8"]
  body: {}
  a: {href: [], target: ["_blank", "_top"]}
  p: {}
  ul: {}
  ol: {}
  li: {}
  dl: {}
  dt: {}
  dd: {}
  img: {src: [], alt: [], width: [], height: []}
  div: {}
  span: {}
  blockquote: {}
  pre: {}
  code: {}
  strong: {}
  small: {}
  form:
    method: ["post","get"]
    action: []
    _tags:
      label: {for: []}
      input:
        type: ["text","email","url","password","hidden","checkbox","radio","submit","button","reset","image","file"]
        name: []
        value: []
        maxlength: []
        placeholder: []
        autofocus: ["autofocus"]
        readonly: ["readonly"]
        required: ["required"]
        disabled: ["disabled"]
        checked: ["checked"]
      textarea:
        name: []
        placeholder: []
        autofocus: ["autofocus"]
        readonly: ["readonly"]
        required: ["required"]
        disabled: ["disabled"]
      select:
        name: []
        size: []
        multiple: ["multiple"]
        disabled: ["disabled"]
        readonly: ["readonly"]
        _tags:
          option: {value: [], selected: ["selected"]}
          optgroup: {label: []}
      button: {}
      legend: {}
      fieldset: {}
  table:
    summary: {}
    border: [1]
  caption: {}
  thead: {}
  tbody: {}
  tfoot: {}
      
lookup = (obj, prefix, callback) ->
  for key of obj when key.indexOf("_") != 0 && (prefix == "" || key.indexOf(prefix) == 0)
    if callback then callback(key) else key

class window.HtmlCompletion
  constructor: ->
    @cssCompletion ||= new CssCompletion({local: true})

  hasHints: (editor) -> 
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)

    return true if token.state.mode == "css"
    return false unless token.state.htmlState && token.state.htmlState.inTag && token.state.htmlState.tagName
    return false if token.state.htmlState.type == "openTag" && token.string.length < 3 && token.string.indexOf("<") == 0
    true
    
  getRootTags: (string) ->
    htmlTags

  getContextualTags: (token, outerTags, closest = -1) ->
    cur   = token.state.htmlState.context
    index = 0
    while cur
      tag  = outerTags[cur.tagName]
      tag  = tag() if tag && tag.call
      tags = tag && tag._tags
      tags = tags(token) if tags && tags.call
      if tags && (closest < 0  || index < closest)
        return @getContextualTags(token, tags, index)
      cur = cur.prev
      index++
    return outerTags

  getTagCompletions: (token) ->
    type = token.state.htmlState.type
    skip = if type == "openTag" then 1 else 2
    @state.getString = (token) -> token.string.substr(skip, token.string.length)
    
    if type == "closeTag"
      openTag = token.state.htmlState.context.tagName
      return [{value: "</" + openTag + ">", label: openTag}]

    string = @state.getString(token)    
    tags = @getContextualTags(token, @getRootTags(string))

    results = lookup tags, string, (result) ->
      {value: "<" + result, label: result}

  getAttributeCompletions: (token) ->
    tagName = token.state.htmlState.tagName
    tag = @getContextualTags(token, @getRootTags(tagName))[tagName]
    return [] unless tag
    tag = tag() if tag.call

    currentAttrs = token.state.htmlState.attrs || {}
    attrs = lookup tag, token.string, (result) ->
      {value: result, action: 'insertAttribute'}

    unless tagName.indexOf("po") == 0
      attrs.push {value: "class", action: 'insertAttribute'}
      attrs.push {value: "id", action: 'insertAttribute'}

    attr for attr in attrs when not currentAttrs[attr.value]
  
  insertAttribute: (editor, selected) ->
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)

    # handle empty strings
    if /^\s+$/.test(token.string)
      token = $.extend({}, token, {start: cursor.ch, end: cursor.ch, string: ""})    
    
    from   = {line: cursor.line, ch: token.start}
    to     = {line: cursor.line, ch: token.end}    

    editor.replaceRange("#{selected}=\"\"", from, to)
    cursor = editor.getCursor()
    editor.setCursor(cursor.line, cursor.ch - 1)

  insertRule: (editor, selected) ->
    @cssCompletion.insertRule(editor, selected)
  
  getAttributeValueCompletions: (token, editor, cursor) ->
    tagName = token.state.htmlState.tagName

    tag = @getContextualTags(token, @getRootTags(tagName))[tagName]
    return [] unless tag
    tag = tag() if tag.call

    attrToken = editor.getTokenAt({line: cursor.line, ch: token.start - 1})
    list = tag[attrToken.string] || []
    list = list(token) if list.call
    
    @state.getString = (token) -> token.string.replace(/(^["']|["']$)/g, '')
    
    string = @state.getString(token)
    
    for attr in list when string == "" || attr.indexOf(string) == 0
      {value: "\"#{attr}\"", label: attr}
  
  getCompletions: (token, editor, cursor) ->
    if token.className && token.string.indexOf("<") == 0
      @getTagCompletions(token)
    else if token.state.htmlState && token.state.htmlState.tagName && token.state.htmlState.type != "closeTag"    
      if (token.className == null || token.className.match(/attribute/))
        @getAttributeCompletions(token)
      else if (token.className && token.className.indexOf("string") > -1)
        @getAttributeValueCompletions(token, editor, cursor)

  getHints: (editor) ->
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)

    unless @state && @state.line == cursor.line && @state.start == token.start && @state.end == token.end - 1
      @state =
        line: cursor.line
        start: token.start

    @state.end = token.end

    switch token.state.mode
      when "html"

        # handle empty strings
        if /^\s+$/.test(token.string)
          token = $.extend({}, token, {start: cursor.ch, end: cursor.ch, string: ""})
        
        if @state.suggestions
          string = if @state.getString then @state.getString(token) else token.string
          @state.suggestions = (suggestion for suggestion in @state.suggestions when suggestion.label.indexOf(string) == 0)
        else
          @state.suggestions = @getCompletions(token, editor, cursor)
        
        return null if @state.suggestions && @state.suggestions.length == 1 && @state.suggestions[0].value == token.string
        
        {
          list: @state.suggestions
          from: {line: cursor.line, ch: token.start}
          to:   {line: cursor.line, ch: token.end}
        }
      when "css"
        @cssCompletion.getHints(editor)
  
  autoAttribute: (editor, event) ->
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)
    if token.className && token.className.indexOf("attribute") > -1
      event.stop()
      editor.replaceRange('=""', cursor)
      editor.setCursor(cursor.line, cursor.ch + 2)
      
  autoCloseTag: (editor, event, ch) ->
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)
    
    # Make sure we're not inside an attribute
    return if token.className && token.className.indexOf("string") > -1 && cursor.ch != token.end
    return if token.className && token.className.indexOf("attribute") > -1
    
    nextChar = editor.getRange(cursor, {line: cursor.line, ch: cursor.ch + 1})
    if nextChar == ">"
      event.stop()
      editor.setCursor(cursor.line, cursor.ch + 1)
    return unless nextChar.match(/^\s?$/)
    
    tagName = token.state.htmlState && token.state.htmlState.tagName    
    
    if selfClosers[tagName]
      event.stop()
      editor.replaceRange("/>", cursor)
      editor.setCursor(cursor.line, cursor.ch + 2)
    
    else if tagName && token.string.match(/[^>\/]$/)
      event.stop()
      nextToken = editor.getTokenAt({line: cursor.line, ch: cursor.ch + 1})
      if nextToken.state.htmlState && nextToken.state.htmlState.tagName && nextToken.string.match(/^\/?>$/)
        end = {line: cursor.line, ch: nextToken.end}
      else
        end = cursor
      
      if end.ch == cursor.ch && token.state.htmlState.type != "closeTag"
        editor.replaceRange("></" + tagName + ">", cursor, end)
      else
        editor.replaceRange(">", cursor, end)
      editor.setCursor(cursor.line, cursor.ch + 1)

  autoInsertions: (editor, event) ->
    switch event.charCode
      when 61 # =
        @autoAttribute(editor, event)
      when 62 # >
        @autoCloseTag(editor, event, '>')

  newline: (editor, event) ->
    cursor = editor.getCursor()
    token  = editor.getTokenAt(cursor)
    
    if token.className && token.className.indexOf("tag") > -1 && token.string == ">"
      nextToken = editor.getTokenAt({line: cursor.line, ch: cursor.ch + 1})
      if nextToken.className && nextToken.className.indexOf("tag") > -1
        if nextToken.state.htmlState.tagName == token.state.htmlState.tagName
          if token.state.htmlState.type == "endTag" && nextToken.state.htmlState.type == "closeTag"
            event.stop()
            editor.operation ->
              editor.replaceRange("\n\n", cursor)
              editor.setCursor(cursor.line + 1, cursor.ch + 2)
              for i in [cursor.line..cursor.line+2]
                editor.indentLine(i)
            return true
    false