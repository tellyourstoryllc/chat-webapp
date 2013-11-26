# A message displayed in the thread but that comes from the system, not a
# particular user, and is not persisted.  For example, room join and leave
# messages are system messages.
App.SystemMessage = Ember.Object.extend

  # Set this to the text to be displayed when instantiating this locally.
  localText: null

  createdAt: null

  init: ->
    @_super(arguments...)
    @setProperties
      createdAt: new Date()

  isSystemMessage: true

  userFacingText: Ember.computed.alias('localText')

  body: Ember.computed.alias('userFacingText')

  attachmentDisplayHtml: (options = {}) ->

  fetchAndLoadAssociations: ->
    # TODO: Ensure that the user is loaded, e.g. when a user joins a room.
    new Ember.RSVP.Promise (resolve, reject) -> resolve()
