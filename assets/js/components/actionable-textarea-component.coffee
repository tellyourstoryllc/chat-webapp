#= require textarea-component

# A textarea that triggers an action when the user presses enter.
#
# Caller should set the `enter-key-down` property to the name of the action that
# should get triggered when user presses the enter key.
App.ActionableTextareaComponent = App.TextareaComponent.extend

  # The optional context (argument) of the action.
  actionContext: null

  # Object to send actions to.
  target: null

  # Must use keyDown (not keyUp) so we can prevent the insertion of new line.
  keyDown: (event) ->
    # Pressing enter.
    if event.which == 13 && ! @isUsingModifierKey(event)
      actionName = @get('enter-key-down')
      if actionName
        event.preventDefault()
        @triggerAction(action: actionName, target: @get('target'))
      else
        Ember.Logger.warn "Action name not set (enter-key-down property) on ActionableTextareaComponent. Ignoring."

  isUsingModifierKey: (event) ->
    event.ctrlKey || event.altKey || event.shiftKey || event.metaKey
