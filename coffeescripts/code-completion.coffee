class Suggestions
  constructor: (completer) ->
    @element = $("#cm-suggestions")
    @create() unless @element.length

    @element.delegate "option", "click", (event) =>
      @element[0].selectedIndex = event.target.index
      completer.insert()

    $(document).unbind('click.completions').bind 'click.completions', (event, target) =>
      @hide()

  create: ->
    @element = $("<select id='cm-suggestions'></select>")
    $("body").append(@element)

  fill: (suggestions) ->
    options = for suggestion in suggestions
      label  = suggestion.label || suggestion.value || suggestion
      value  = suggestion.value || suggestion
      action = suggestion.action || ""
      "<option data-action='#{action}' value='#{value}'>#{label}</option>"
    element = @element.html(options.join(""))[0]
    element.selectedIndex = 0
    element.size = Math.min(Math.max(2, options.length), 10)

  selected: ->
    @element.val()

  action: ->
    index = @element[0].selectedIndex
    @element.find("option").slice(index, index + 1).data("action")

  selectPrevious: ->
    el = @element[0]
    el.selectedIndex = if el.selectedIndex < 1 then el.length - 1 else el.selectedIndex - 1

  selectNext: ->
    @element[0].selectedIndex = (@element[0].selectedIndex + 1) % @element[0].length

  showAt: (position) ->
    pos = {left: position.x, top: position.y}
          
    @element.css(pos)
    @visible = true
    @element.show()
    height = @element.outerHeight()
    if position.y + height > $(window).height()
      @element.css(top: position.y - @element.outerHeight() - 25)
    
  hide: ->
    @visible = false
    @element.hide()

  _select: (direction) ->
    
key = (e) ->
  CodeMirror.keyNames[e.keyCode]

class CodeCompletion
  
  constructor: (@editor, @mode) ->
    @widget = new Suggestions(this)

  suggest: ->
    return @widget.hide() if @editor.somethingSelected()
    return @widget.hide() unless @mode && @mode.hasHints(@editor)
    
    @hints = @getHints()

    if @hints
      @widget.fill(@hints.list)
      @widget.showAt(@editor.cursorCoords())
    else
      @widget.hide()

  getHints: ->
    hints = @mode && @mode.getHints(@editor)
    return null unless hints && hints.list && hints.list.length
    return null if hints.list.length == 1 && hints.to.ch - hints.from.ch == hints.list[0].length
    hints

  insert: ->
    return unless @widget.visible
    if action = @widget.action()
      @mode && @mode[action](@editor, @widget.selected())
    else
      @editor.replaceRange(@widget.selected(), @hints.from, @hints.to)
    @editor.focus()

  autoQuote: (event, ch, open, close) ->
    open  ||= ch
    close ||= open
    
    cursor = @editor.getCursor()
    
    if @editor.somethingSelected()
      event.stop()
      selection = @editor.getSelection()
      if selection.indexOf(open) == 0 && selection.match(new RegExp("\\#{close}$"))
        @editor.replaceSelection(selection.substr(1, selection.length - 2))
      else
        @editor.replaceSelection([open, @editor.getSelection(), close].join(""))
      return

    nextChar = @editor.getRange(cursor, {line: cursor.line, ch: cursor.ch + 1})

    if ch == close && nextChar == close
      event.stop()
      @editor.setCursor(cursor.line, cursor.ch + 1)

    return unless nextChar.match(/^\s?$/)
    
    token  = @editor.getTokenAt(cursor)    
    
    if token.string.match(new RegExp(".+\\#{close}$"))
      event.stop()
      @editor.setCursor(cursor.line, cursor.ch + 1)
    else if token.string.indexOf(close) == -1
      @editor.replaceRange(close, cursor)
      @editor.setCursor(cursor)

  ignoreBracketIfClosed: (event, ch) ->
    return if @editor.somethingSelected()
    
    cursor = @editor.getCursor()
    nextChar = @editor.getRange(cursor, {line: cursor.line, ch: cursor.ch + 1})

    if nextChar == ch
      event.stop()
      @editor.setCursor(cursor.line, cursor.ch + 1)
    

  keydown: (e) ->
    # Movements on the widget
    k = key(e)

    switch k
      when "Up"
        if @widget.visible
          @widget.selectPrevious()
          return true
      when "Down"
        if @widget.visible
          @widget.selectNext()
          return true
      when "Enter", "Tab"
        if @widget.visible
          @insert()
          @suggest()
          e.stop()
          return true
        else if k == "Enter"
          return @mode.newline(@editor, e)  if @mode && @mode.newline
      when "Esc"
        if @widget.visible
          @widget.hide()
          return true

  keypress: (e) ->
    switch e.charCode
      when 34 # "
        @autoQuote(e, '"')
      when 39 # '
        if @editor.somethingSelected()
          @autoQuote(e, "'")
        else
          @ignoreBracketIfClosed(e ,"'")
      when 8216 # ‘
        @autoQuote(e, "‘", "‘", "’")
      when 8217 # ’
        @ignoreBracketIfClosed(e, "’")
      when 8220 # “
        @autoQuote(e, "“", "“", "”")
      when 8221 # ”
        @ignoreBracketIfClosed(e, "”")
      when 40 # (
        @autoQuote(e, "(", "(", ")")
      when 41 # )
        @ignoreBracketIfClosed(e, ")")
      when 91 # [
        @autoQuote(e, "[", "[", "]")
      when 93 # ]
        @ignoreBracketIfClosed(e, "]")
      when 123 # {
        @autoQuote(e, "{", "{", "}")
      when 125
        @ignoreBracketIfClosed(e, "}")
      else
        return if @editor.somethingSelected()
        @mode.autoInsertions(@editor, e) if @mode && @mode.autoInsertions

  keyup: (e) ->
    k = key(e)

    return if k == "Enter"
    return @widget.hide() if k == "End" || k == "Home" && @widget.visible
    return @widget.hide() if (k == "Left" || k == "Right") 
    return if (k != "Space" && k != "Backspace" && e.keyCode < 48)
        
    @suggest(@editor)

  handleKeyEvent: (editor, e) ->
    @[e.type] && @[e.type](e)

window.CodeCompletion = CodeCompletion