App.RoomsRoomView = Ember.View.extend

  group: Ember.computed.alias('controller.model')

  activeRoomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @activateRoomLinks()
  ).observes('controller.roomsLoaded', 'controller.model.id')

  activateRoomLinks: ->
    groupId = @get('controller.model.id')
    return unless groupId?

    regexp = new RegExp("/#{groupId}$")
    $('.room-list-item a[href]').each ->
      $link = $(@)
      if regexp.test($link.prop('href') ? '')
        $link.addClass 'active'
      else
        $link.removeClass 'active'
