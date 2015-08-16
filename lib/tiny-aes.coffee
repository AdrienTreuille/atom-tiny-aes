{PasswordDialogView} = require './tiny-aes-view'
{CompositeDisposable} = require 'atom'

####################
# Helper Functions #
####################

TinyAES =
  subscriptions: null
  encryptView: null
  decryptView: null

  activate: (state) ->
    @encryptView = new PasswordDialogView atom.workspace, 'encrypt'
    @decryptView = new PasswordDialogView atom.workspace, 'decrypt'

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'tiny-aes:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'tiny-aes:encrypt': => @encrypt()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'tiny-aes:decrypt': => @decrypt()

  deactivate: ->
    @subscriptions.dispose()
    @encryptView.destroy()
    @decryptView.destroy()

  serialize: ->

  toggle: ->
    console.log 'TinyAes was toggled!'

    if @decryptView.isVisible()
      @decryptView.hide()
    else
      @decryptView.show()
      # @tinyAesView.getElement().find('atom-text-editor').focus()
      # console.log 'THIS IS THE MODEL'
      # console.log  @tinyAesView.getElement().find('atom-text-editor')[0].getModel()

  encrypt: ->
    selection = @getSelectionOrEverything()
    passwords = []
    @passwordDialog 'Enter password:'
    .then (pw) =>
      passwords.push pw
      @passwordDialog 'Repeat encryption password:'
    .then (pw) =>
      passwords.push pw
      if passwords[0] != passwords[1]
        return Promise.reject Error "Passwords don't match."
      script = "openssl enc -e -aes128 -base64 -pass \"pass:#{pw}\""
      @exec script, input: selection.getText()
    .then (cyphertext) =>
      selection.insertText cyphertext, select:yes
    .catch (err) =>
      console.log err.stack
      console.log err
      atom.notifications.addWarning err.message

  decrypt: ->
    selection = @getSelectionOrEverything()
    @passwordDialog 'Enter decryption password:'
    .then (pw) =>
      script = "openssl enc -d -aes128 -base64 -pass \"pass:#{pw}\""
      @exec script, input: selection.getText()
      .catch (err) => Promise.reject Error 'Password incorrect.'
    .then (cleartext) =>
      selection.insertText cleartext, select:yes
    .catch (err) =>
      console.log err
      atom.notifications.addWarning err.message

  # Execute something on the command line, returning a promise.
  # cmd: (string) the cmd to execute
  # options: list of options
  #   input: (string) piped into stdin
  exec: (cmd, options) ->
    new Promise (resolve, reject) ->
      childProcess = require 'child_process'
      child = childProcess.exec cmd, (err, stdout, stderr) ->
        if err then reject err else resolve stdout
      child.stdin.write(options?.input ? '')
      child.stdin.end()

  # Creates a passowrd dialog, returning a promise.
  passwordDialog: (prompt) ->
    script = """osascript -e '
      display dialog "#{prompt}" \
        hidden answer true \
        default answer ""'"""
    @exec script
    .then ((result) ->
      resultRegex = /button\ returned\:OK\,\ text\ returned\:(.*)/
      if match = result.match resultRegex
        return match[1] # return the password
      else Promise.reject Error "Cannot parse: #{result}"
    ), (err) ->
      Promise.reject Error 'Cancelled.'

  # The current selection or selects everything.
  getSelectionOrEverything: ->
    editor = atom.workspace.getActiveTextEditor()
    selection = editor.getLastSelection()
    selection.selectAll() if selection.isEmpty()
    return selection

module.exports =
    activate: (state) -> TinyAES.activate state
    deactivate: -> TinyAES.deactivate
    serialize: -> TinyAES.serialize
