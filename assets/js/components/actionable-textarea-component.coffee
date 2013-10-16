#= require textarea-component

# A textarea that triggers an action when the user presses enter.
#
# Caller should set the `action` property to the name of the action that should
# get triggered when user presses the enter key.
App.ActionableTextareaComponent = App.Textarea.extend

  # The name of the action that gets sent.
  action: null

  # The optional context (argument) of the action.
  actionContext: null

  # Must use keyDown (not keyUp) so we can prevent the insertion of new line.
  keyDown: (event) ->
    # Pressing enter.
    if event.keyCode == 13 && ! @isUsingModifierKey(event)
      event.preventDefault()
      actionName = @get('action')
      if actionName
        @triggerAction()
      else
        Ember.Logger.warn "Action name not set (action property) on ActionableTextareaComponent. Ignoring."

  isUsingModifierKey: (event) ->
    event.ctrlKey || event.altKey || event.shiftKey || event.metaKey
