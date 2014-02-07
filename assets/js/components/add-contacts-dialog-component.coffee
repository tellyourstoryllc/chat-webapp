# Actions: hideDialog, didAddUserContacts
App.AddContactsDialogComponent = Ember.Component.extend

  # Text entered.
  newContactsText: ''

  isAdding: false

  errorMessage: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onOverlayClick')

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    @$().closest('.page-overlay').on 'click', @onOverlayClick

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$().closest('.page-overlay').off 'click', @onOverlayClick

  onBodyKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        if event.which == 27      # Escape
          @closeModal()

  onOverlayClick: (event) ->
    Ember.run @, ->
      # Hide the dialog if user clicked the overlay.
      if $(event.target).hasClass('page-overlay')
        @closeModal()
      return undefined

  closeModal: ->
    @sendAction('hideDialog')

  resetNewRoom: ->
    @setProperties
      newContactsText: ''
      errorMessage: null

  actions:

    hideAddContactsDialog: ->
      @closeModal()
      return undefined

    add: ->
      emails = @get('newContactsText') ? ''
      emails = emails.trim()
      # Replace new lines with commas.
      emails = emails.replace(/\s*\r?\n\s*/g, ',')
      return if Ember.isEmpty(emails) || @get('isAdding')

      @setProperties(isAdding: true, errorMessage: null)
      data =
        emails: emails
      App.get('api').addEmailContacts(data)
      .always =>
        @set('isAdding', false)
      .then (json) =>
        if ! json? || json.error?
          throw json

        # Users added successfully.  Load as contacts.
        instances = App.loadAll(json)
        users = instances.filter (o) -> o instanceof App.User
        @sendAction('didAddUserContacts', users)

        # Hide the dialog.
        @closeModal()

      , (xhrOrError) =>
        # Show error message.
        @set('errorMessage', App.userMessageFromError(xhrOrError))
      .fail App.rejectionHandler

      return undefined
