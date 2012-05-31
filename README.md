Contextual CodeMirror Completions
-----------------------------------------------------

This is the contextual code completion code behind [Webpop's](http://www.webpop.com) CodeMirror2 based editor (minus the pop-tag specific completions).

To get started:

1. git clone git://github.com/webpop/ccc.git
2. git submodule update --init # fetches the codemirror dependency
3. open demo/index.html

See demo/index.html for how to use with CodeMirror2.

Internals
---------

code-completion.coffee Is the generic code completion handler. It manages the suggestion box and provides auto-closing quotes and brackets.

The CodeCompletion instance delegates the actual contextual lookups to a mode that must implement:

  hasHints(editor) // Should tell whether any hints should be shown for the current location
  getHints(editor) //must return a hints object:
    {
      list: [...], // An array of suggestions. Can either be strings or objects of the form {label: "Label", value: "value", action: fn}
      from: {...}, // A CodeMirror cursor position to start the replacement from
      to: {...}, // A CodeMirror cursor position to end the replacement
    }
  newline(editor, keyDownEvent) // Optional - if the mode wants to autoclose tags or the like, it can respond to newline
  autoInsertions(editor, keyPressEvent) // Optional - if the mode does autoinsertions this method can handle them

The HtmlCompletion depends on our pophtmlmixed mode. It's a modified version of CodeMirror 2's included htmlmixed mode, keeping a bit more state around that the code completion mode can use for context.

The CssCompletion mode works with the default CodeMirror 2 CSS parser.