App.SettingsDialogComponent = Ember.Component.extend App.BaseControllerMixin,
  classNames: ['modal', 'settings-dialog']

  isSendingAvatar: false

  preferences: (->
    App.get('preferences')
  ).property('App.preferences')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'fileChange')

  didInsertElement: ->
    @$('.avatar-file-input').on 'change', @fileChange

  willDestroyElement: ->
    @$('.avatar-file-input').off 'change', @fileChange

  isHiddenChanged: (->
    if @get('isHidden')
      @$().removeClass('expand-in')
    else
      @$().addClass('expand-in')
  ).observes('isHidden')

  fileChange: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      return unless file?

      @updateAvatar(file)

  updateAvatar: (file) ->
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('avatar_image_file', file)
    @set('isSendingAvatar', true)
    api.ajax(api.buildURL('/users/update'), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingAvatar', false)

  clientWebPreferencesDidChange: (->
    data =
      client_web: JSON.stringify(@get('preferences.clientWeb'))
    App.get('api').updatePreferences(data)
  ).observes('preferences.clientWeb.playSoundOnMessageReceive',
             'preferences.clientWeb.showNotificationOnMessageReceive',
             'preferences.clientWeb.playSoundOnMention',
             'preferences.clientWeb.showNotificationOnMention')

  actions:

    chooseAvatarFile: ->
      @$('.avatar-file-input').trigger('click')
      return undefined

    hideDialog: ->
      @get('targetObject').send('hide')
      return undefined
