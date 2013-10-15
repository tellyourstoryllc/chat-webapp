window.App = App = Ember.Application.create
  LOG_TRANSITIONS: true

  token: null

  currentUser: null

  ready: ->
    # API implementation.
    @set('api', App.RemoteApi.create())

  isLoggedIn: -> @get('currentUser')?


if Modernizr.history
  # Browser supports pushState.
  App.Router.reopen
    location: 'history'


App.Router.map ->

  @route 'login', path: '/login'
