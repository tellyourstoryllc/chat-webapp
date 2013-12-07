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

  body: (->
    escape = Ember.Handlebars.Utils.escapeExpression
    text = @get('userFacingText')

    escapedText = escape(text)

    # Emoticons.
    convoId = @get('conversationId')
    evaledText = App.Emoticon.replaceText escapedText, (str, emoticon) ->
      # Return the image HTML for the emoticon image.
      "<img class='emoticon' src='#{emoticon.get('imageUrl')}'" +
      " title='#{escape(emoticon.get('name'))}'" +
      " onload='App.onMessageContentLoad(&quot;#{escape(convoId)}&quot;, this, &quot;emoticon&quot;);'>"

    evaledText.htmlSafe()
  ).property('userFacingText')

  attachmentDisplayHtml: (options = {}) ->

  hasPlayableVideoAttachment: -> false

  hasPlayableAudioAttachment: -> false

  fetchAndLoadAssociations: ->
    # TODO: Ensure that the user is loaded, e.g. when a user joins a room.
    new Ember.RSVP.Promise (resolve, reject) -> resolve()

App.SystemMessage.reopenClass

  createFromConversation: (conversation, props) ->
    defProps = {}
    id = conversation.get('id')
    if conversation instanceof App.OneToOne
      defProps.oneToOneId = id
    else if conversation instanceof App.Group
      defProps.groupId = id

    @create(_.extend(defProps, props))
