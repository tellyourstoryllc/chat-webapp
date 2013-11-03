#= require base-model

App.Message = App.BaseModel.extend

  # Error message to diplay to the user.
  errorMessage: null

  group: (->
    App.Group.lookup(@get('groupId'))
  ).property('groupId')

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId', 'group._membersAssociationLoaded')

  mentionedUsers: (->
    @get('mentionedUserIds').map (id) -> App.User.lookup(id)
  ).property('mentionedUserIds')

  doesMentionUser: (user) ->
    mentionedUserIds = @get('mentionedUserIds')
    return true if mentionedUserIds.any (id) -> id == App.Message.mentionAllId
    userId = user.get('id')
    return false unless userId?
    mentionedUserIds.any (id) -> id == userId

  title: (->
    userName = @get('user.name') ? "User #{@get('userId')}"
    roomName = @get('group.name') ? "Room #{@get('groupId')}"
    "#{userName} | #{roomName}"
  ).property('user.name', 'group.name')

  # This is the html text with emoticons and mentions.
  body: (->
    # For some reason, this is getting triggered on rooms that haven't been
    # loaded yet.  Since this is a fairly expensive computation, just exit
    # without doing anything since the result will be bogus anyway.
    return null if ! @get('group.usersLoaded')

    text = @get('text')

    escapedText = Ember.Handlebars.Utils.escapeExpression(text)

    # Link to URLs.  I know this looks overly complicated, but there's a reason.
    # See http://www.codinghorror.com/blog/2008/10/the-problem-with-urls.html We
    # whitelist characters to prevent XSS injection.  We match both full URLs
    # and bare domains at the same time since one would expand into matches of
    # the other.
    urlRegexp = ///
      \(?\b                              # Optional open-paren at the beginning.
        (
          (https?|ftp)://                  # Protocol.
          [-A-Za-z0-9+&@\#/%?=~_()|!:,.;]* # Whitelist URL characters.
          [-A-Za-z0-9+&@\#/%=~_()|]        # Don't include punctuation at the end.
        | ( (?:[A-Za-z0-9][-A-Za-z0-9]{0,61}[a-zA-Z0-9]\.)+ # Domain characters.
            [a-zA-Z0-9]{2,6}               # Only top-level domains at the end.
          )
          ([^a-zA-Z0-9]|$)       # Make sure it's followed by non-domain char.
        )
    ///g
    evaledText = escapedText.replace urlRegexp, (fullMatch, urlOrDomain, protocol, bareDomain, trailingChar) ->
      prefix = ''
      suffix = ''
      if protocol
        display = urlOrDomain
        url = urlOrDomain
        useTruncation = true
      else
        url = "http://#{bareDomain}/"
        display = bareDomain
        # Make sure to carry over trailing character.
        suffix = trailingChar ? ''
      if fullMatch[0] == '('
        prefix = '('
        if url.slice(-1) == ')'
          # The whole URL is inside parentheses.
          url = url[0 ... -1]
          display = display[0 ... -1]
          suffix = ')'
      if useTruncation && display.length > 100
        attrs = " title='#{display}'"
        display = "#{display[0...100]}..."
      "#{prefix}<a href='#{url}'#{attrs} target='_blank'>#{display}</a>#{suffix}"

    # Mentions.
    currentUser = App.get('currentUser')
    group = @get('group')
    groupMembers = group.get('members')
    evaledText = evaledText.replace /@(\w+)/g, (fullMatch, name) ->
      user = App.User.userMentionedInGroup(name, groupMembers)
      isAll = /^all$/i.test(name)
      if user? || isAll
        classNames = ['mention']
        classNames.push('you') if user == currentUser || isAll
        "<span class='#{classNames.join(' ')}'>#{fullMatch}</span>"
      else
        fullMatch

    # Emoticons.
    groupId = @get('groupId')
    escape = Ember.Handlebars.Utils.escapeExpression
    evaledText = App.Emoticon.all().reduce (str, emoticon) ->
      regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
      imageHtml = "<img class='emoticon' src='#{emoticon.get('imageUrl')}'" +
                  " title='#{escape(emoticon.get('name'))}'" +
                  " onload='App.onMessageImageLoad(&quot;#{escape(groupId)}&quot;, this, true);'>"
      str.replace regexp, imageHtml
    , evaledText

    evaledText.htmlSafe()
  # Note: We omit group members' names from dependent keys since we don't care
  # about updating mentions when a user changes his/her name or a new user joins
  # or leaves the room.
  ).property('App.emoticonsVersion', 'text', 'group.usersLoaded')

  isSentByCurrentUser: (->
    userId = @get('userId')
    userId? && userId == App.get('currentUser.id')
  ).property('userId', 'App.currentUser.id')

  fetchAndLoadAssociations: ->
    @get('group').fetchAndLoadAssociations()

  toNotification: ->
    # TODO: icon field.
    tag: @get('groupId')
    title: @get('title')
    body: @get('text')
    icon: {}


App.Message.reopenClass

  # ID representing @all mention.  Yes, a string to match the type of other IDs.
  mentionAllId: '-1'

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')
    mentionedUserIds = if Ember.isArray(json.mentioned_user_ids)
      json.mentioned_user_ids
    else
      (json.mentioned_user_ids ? '').split(/,/)

    id: App.BaseModel.coerceId(json.id)
    groupId: App.BaseModel.coerceId(json.group_id)
    userId: App.BaseModel.coerceId(json.user_id)
    mentionedUserIds: mentionedUserIds.map (id) -> App.BaseModel.coerceId(id)
    text: json.text
    imageUrl: json.image_url
    imageThumbUrl: json.image_thumb_url
    createdAt: api.deserializeUnixTimestamp(json.created_at)

  # Given a Message instance, persists it to the server.  Returns a Promise.
  sendNewMessage: (message) ->
    groupId = message.get('groupId')
    data = {}
    for key in ['text', 'imageFile']
      val = message.get(key)
      if val?
        data[key.underscore()] = val

    mentionedUserIds = message.get('mentionedUserIds')
    if ! Ember.isEmpty(mentionedUserIds)
      data.mentioned_user_ids = mentionedUserIds.join(',')

    # Update instance state.
    message.set('isSaving', true)

    # Only send message via POST if there's an image.
    if message.get('imageFile')?
      api = App.get('api')
      formData = new FormData()
      formData.append(k, v) for k,v of api.defaultParams()
      formData.append(k, v) for k,v of data
      api.ajax(api.buildURL("/groups/#{groupId}/messages/create"), 'POST',
        data: formData
        processData: false
        contentType: false
      )
      .then (json) =>
        Ember.Logger.log "message create response", json
        message.set('isSaving', false)
        if ! json? || json.error?
          # Reject the promise.
          throw json
        else
          json = Ember.makeArray(json)
          msgAttrs = json.find (o) -> o.object_type == 'message'
          @didCreateRecord(message, msgAttrs)

          return message
      , (e) =>
        message.set('isSaving', false)
        throw e
    else
      # The instance is used by the faye extension.
      data.messageInstance = message
      # Wrap Faye's promise in an RSVP.Promise.
      return new Ember.RSVP.Promise (resolve, reject) =>
        # Publish the message via the socket.
        App.get('fayeClient').publish("/groups/#{groupId}/messages", data)
        .then (result) =>
          Ember.run @, ->
            message.set('isSaving', false)
            resolve(result)
        , (result) =>
          Ember.run @, ->
            message.set('isSaving', false)
            reject(result)

  didCreateRecord: (message, attrs) ->
    hadId = message.get('id')?
    # Update the Message instance.
    props = @propertiesFromRawAttrs(attrs)
    # Update state.
    props.isLoaded = true
    props.isSaving = false
    message.setProperties(props)

    if ! hadId && message.get('id')?
      # Save to our identity map.
      @_all.pushObject(message)
      @_allById[message.get('id')] = message

  # Parses text and returns users from the given set who were mentioned.  This
  # is helpful when creating new messages.
  mentionedIdsInText: (text, users) ->
    return [] unless text?

    if /@all\b/i.test(text)
      # Everyone was mentioned.
      return [@mentionAllId]

    lowerCasedText = text.toLowerCase()
    users.filter (user) ->
      mentionName = user.get('mentionName')
      regexp = new RegExp("@#{App.Util.escapeRegexp(mentionName)}\\b", 'i')
      regexp.test(text)
    .mapProperty('id')
