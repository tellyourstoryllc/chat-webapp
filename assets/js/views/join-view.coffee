App.JoinView = Ember.View.extend

  authState: Ember.computed.alias('controller.authState')

  didInsertElement: ->
    # Add class so that we keep the navbar full width.
    $('body').addClass 'join-page'

  willDestroyElement: ->
    $('body').removeClass 'join-page'

  isAuthStateSignup: Ember.computed.equal('authState', 'signup')

  isAuthStateLogin: Ember.computed.equal('authState', 'login')

  actions:

    signUp: ->
      @set('authState', 'signup')
      return undefined

    logIn: ->
      @set('authState', 'login')
      return undefined

    cancelAuthentication: ->
      @set('authState', null)
      return undefined
