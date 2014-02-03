#= require signup-form-component

# Actions: signUpWithFacebook, logInWithRoom
App.RoomJoinGroupSignupFormComponent = App.SignupFormComponent.extend App.AutoFillSignupMixin,
  classNames: ['room-join-group-signup-form-component']
  classNameBindings: ['isInline:inline']

  room: null

  showRelatedLinks: false
  shouldRequirePassword: false

  authStep: 'email'

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onResize')

  didInsertElement: ->
    @_super(arguments...)
    $(window).on 'resize', @onResize
    Ember.run.schedule 'afterRender', @, 'updateSize'

  isAuthStepEmail: Ember.computed.equal('authStep', 'email')

  isAuthStepPassword: Ember.computed.equal('authStep', 'password')

  onResize: _.throttle (event) ->
    Ember.run @, ->
      @updateSize()
      return undefined
  , 100, leading: false

  roomChanged: (->
    Ember.run.schedule 'afterRender', @, 'updateSize'
  ).observes('room', 'room._membersAssociationLoaded')

  updateSize: ->
    return unless @currentState == Ember.View.states.inDOM
    $e = @$()
    width = $e.outerWidth()
    height = $e.outerHeight()
    $window = $(window)
    windowWidth = $window.width()
    windowHeight = $window.height()
    bannerHeight = if Modernizr.appleios || Modernizr.android then 50 else 0
    visibleHeight = windowHeight - bannerHeight

    $e.css
      left: Math.round((windowWidth - width) / 2)
      top: Math.round((visibleHeight - height) / 2) + bannerHeight

  userErrorMessageDidChange: (->
    Ember.run.schedule 'afterRender', @, ->
      # Run later so that it's actually inserted into the DOM and the CSS can
      # transition.
      Ember.run.later @, ->
        # Transition the error message in.
        if Ember.isEmpty(@get('errorMessage'))
          @$('.alert').removeClass('visible')
        else
          @$('.alert').addClass('visible')
      , 50
  ).observes('errorMessage')

  # Called when the user submits a duplicate email address.
  userDidEnterDuplicateEmail: (xhr) ->
    # Use the same email address, but prompt the user for password.
    @set('authStep', 'password')

  authStepChanged: (->
    # Set focus to the right input.
    Ember.run.schedule 'afterRender', @, ->
      if @get('authStep') == 'email'
        $control = @$('.email-input')
      else
        $control = @$('.password-input')
      $control.focus()
  ).observes('authStep').on('didInsertElement')

  hostedByName: (->
    room = @get('room')
    return null if room instanceof App.OneToOne
    room.get('admins.firstObject.name')
  ).property('room', 'room.admins.firstObject.name')

  actions:

    attemptSignup: ->
      if @get('isAuthStepPassword')
        @send('attemptLogin')
      else
        @_super(arguments...)
      return undefined

    logInWithRoom: ->
      @sendAction('logInWithRoom')
      return undefined
