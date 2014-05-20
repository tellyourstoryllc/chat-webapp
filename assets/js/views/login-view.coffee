App.LoginView = Ember.View.extend

  keyCount: 0

  isAllowedToLogIn: Ember.computed.alias('controller.isAllowedToLogIn')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyPress')

  didInsertElement: ->
    # Add class so that we keep the navbar full width.
    $('body').addClass 'login-page'
    $('body').on 'keypress', @onBodyKeyPress

  willDestroyElement: ->
    $('body').removeClass 'login-page'
    $('body').off 'keypress', @onBodyKeyPress

  onBodyKeyPress: (event) ->
    Ember.run @, ->
      # Control+Shift+L
      if event.which == 12 && event.ctrlKey && event.shiftKey
        @incrementProperty('keyCount')
      else
        @set('keyCount', 0)
      return undefined

  keyCountChanged: (->
    if @get('keyCount') >= 3
      @set('isAllowedToLogIn', true)
  ).observes('keyCount')

  isAllowedToLogInChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      # If we're showing the login form, set keyboard focus to the username
      # field.
      if @get('isAllowedToLogIn')
        @$('input:first').focus()
  ).observes('isAllowedToLogIn')

  actions:

    incrementKeyCount: ->
      @incrementProperty('keyCount')
      return undefined
