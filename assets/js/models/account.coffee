#= require base-model

App.Account = App.BaseModel.extend App.LockableApiModelMixin


App.Account.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    # Note: we're using the userId as the ID so we don't need to store multiple
    # map caches.
    id: @coerceId(json.user_id)
    email: json.email
    oneToOneWallpaperUrl: json.one_to_one_wallpaper_url
