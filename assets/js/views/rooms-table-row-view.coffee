App.RoomsTableRowView = Ember.View.extend
  tagName: 'tr'
  classNameBindings: 'oddOrEven'

  newName: ''

  group: Ember.computed.alias('content')
  room: Ember.computed.alias('content')

  oddOrEven: (->
    if @get('contentIndex') % 2 == 0
      'odd'
    else
      'even'
  ).property('contentIndex')

  actions:

    renameRoom: (group) ->
      if ! group.get('isCurrentUserAdmin')
        alert "You must be an admin to rename a room."
        return

      @set('isRenaming', true)
      @set('newName', group.get('name'))
      Ember.run.schedule 'afterRender', @, ->
        $name = @$('.new-name')
        $name.textrange('set') # Select all.
        $name.focus()
      return undefined

    cancelRenamingRoom: ->
      @set('isRenaming', false)
      return undefined

    saveRoomName: (group) ->
      @set('isRenaming', false)
      newName = @get('newName')?.trim()
      oldName = group.get('name')
      return if Ember.isEmpty(newName)

      api = App.get('api')
      url = api.buildURL("/groups/#{group.get('id')}/update")
      group.withLockedPropertyTransaction url, 'POST', data: { name: newName }
      , 'name', =>
        group.set('name', newName)
      ,  =>
        group.set('name', oldName)
      return undefined
