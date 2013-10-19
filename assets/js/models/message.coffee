#= require base-model

App.Message = App.BaseModel.extend

  group: (->
    App.Group.lookup(@get('groupId'))
  ).property('groupId')

  user: (->
    App.User.lookup(@get('userId'))
  ).property('userId')

  # This is the html text with emoticons and mentions.
  body: (->
    text = @get('text')

    escapedText = Ember.Handlebars.Utils.escapeExpression(text)

    # Link to URLs.
    urlRegexp = ///
      \b(https?|ftp)://[-A-Za-z0-9+&@\#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@\#/%=~_()|]
    ///g
    escapedText = escapedText.replace urlRegexp, (fullMatch) ->
      "<a href='#{fullMatch}' target='_blank'>#{fullMatch}</a>"

    # Mentions.
    currentUser = App.get('currentUser')
    group = @get('group')
    groupMembers = group.get('members')
    evaledText = escapedText.replace /@(\w+)/g, (fullMatch, name) ->
      user = App.User.userMentionedInGroup(name, groupMembers)
      isAll = /^all$/i.test(name)
      if user? || isAll
        classNames = ['mention']
        classNames.push('you') if user == currentUser || isAll
        "<span class='#{classNames.join(' ')}'>#{fullMatch}</span>"
      else
        fullMatch

    # Emoticons.
    evaledText = App.Emoticon.all().reduce (str, emoticon) ->
      regexp = new RegExp(App.Util.escapeRegexp(emoticon.get('name')), 'g')
      imageHtml = "<img class='emoticon' src='#{emoticon.get('imageUrl')}' title='#{emoticon.get('name')}'>"
      str.replace regexp, imageHtml
    , evaledText

    evaledText.htmlSafe()
  ).property('App.emoticonsVersion', 'text', 'group.members.@each.name')

  loadAssociations: ->
    new Ember.RSVP.Promise (resolve, reject) =>
      user = App.User.lookup(@get('userId'))
      group = App.Group.lookup(@get('groupId'))
      if user? && ! Ember.isEmpty(group?.get('messages'))
        resolve(false)
      else
        App.Group.fetchById(@get('groupId'))
        .then (json) =>
          if json? && ! json.error?
            # Load everything from the response.
            instances = App.loadAll(json)

            group = instances.find (o) -> o instanceof App.Group
            newlyLoadedMessages = false
            if Ember.isEmpty(group.get('messages'))
              group.set('messages', instances.filter (o) -> o instanceof App.Message)
              newlyLoadedMessages = true

            resolve(newlyLoadedMessages)
            return true
          else
            throw new Error(JSON.stringify(json))

  toNotification: ->
    userName = @get('user.name') ? "User #{@get('userId')}"
    roomName = @get('group.name') ? "Room #{@get('groupId')}"

    # TODO: icon field.
    tag: @get('id')
    title: "#{userName} | #{roomName}"
    body: @get('text')
    icon: {}


App.Message.reopenClass

  # Array of all instances.
  _all: []

  # Identity map of model instances by ID.
  _allById: {}

  all: -> @_all

  loadRaw: (json) ->
    props = @propertiesFromRawAttrs(json)

    prevInst = props.id? && @_allById[props.id]
    if prevInst?
      prevInst.setProperties(props)
      inst = prevInst
    else
      inst = @create(props)
      @_all.pushObject(inst)
      @_allById[props.id] = inst

    inst

  propertiesFromRawAttrs: (json) ->
    api = App.get('api')

    id: App.BaseModel.coerceId(json.id)
    groupId: App.BaseModel.coerceId(json.group_id)
    userId: App.BaseModel.coerceId(json.user_id)
    text: json.text
    imageUrl: json.image_url
    createdAt: api.deserializeUnixTimestamp(json.created_at)

  # Returns Promise.
  sendNewMessage: (message) ->
    groupId = message.get('groupId')
    data = {}
    for key in ['text', 'imageFile']
      val = message.get(key)
      if val?
        data[key.underscore()] = val

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
        if ! json? || json.error?
          # Reject the promise.
          throw json
        else
          json = Ember.makeArray(json)
          msgAttrs = json.find (o) -> o.object_type == 'message'
          @didCreateRecord(message, msgAttrs)

          return message
    else
      # The instance is used by the faye extension.
      data.messageInstance = message
      # Publish the message via the socket.
      App.get('fayeClient').publish("/groups/#{groupId}/messages", data)

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
