App.Util = Ember.Object.extend()

App.Util.reopenClass

  # Given an array of pairs, returns query string.
  arrayToQueryString: (arr, encode = true) ->
    return '' if Ember.isEmpty(arr)
    '?' + (arr.map (pair) ->
      val = pair[1]
      # Use empty string for undefined.
      val = '' if val == undefined

      if encode
        encodeURIComponent('' + pair[0]) + '=' + encodeURIComponent('' + val)
      else
        '' + pair[0] + '=' + val
    ).join('&')

  escapeRegexp: (str) ->
    (str + '').replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1")

  # Returns the file name from a URL or last non-empty part.  Returns undefined
  # if can't be found.
  fileNameFromUrl: (url) ->
    urlToMatch = url
    # Remove query params.
    queryParamsIndex = urlToMatch.indexOf('?')
    if queryParamsIndex >= 0
      urlToMatch = urlToMatch[0 ... queryParamsIndex]
    # Remove trailing slash.
    if urlToMatch[urlToMatch.length - 1] == '/'
      urlToMatch = urlToMatch[0 ... urlToMatch.length - 1]
    # Try to extract the file name at the end.
    matches = /\/([^\/?]+)[^\/]*$/.exec(urlToMatch)

    matches?[1]

  # Generates a GUID as securely as possible.
  #
  # http://stackoverflow.com/a/8472700/12887
  generateGuid: if typeof (window.crypto) != 'undefined' && typeof (window.crypto.getRandomValues) != 'undefined'
    ->
      # If we have a cryptographically secure PRNG, use that
      # http://stackoverflow.com/questions/6906916/collisions-when-generating-uuids-in-javascript
      buf = new Uint16Array(8)
      window.crypto.getRandomValues(buf)
      S4 = (num) ->
        ret = num.toString(16)
        while ret.length < 4
          ret = '0' + ret
        ret

      S4(buf[0]) + S4(buf[1]) + '-' + S4(buf[2]) + '-' + S4(buf[3]) + '-' + S4(buf[4]) + '-' + S4(buf[5]) + S4(buf[6]) + S4(buf[7])
   else
     ->
      # Otherwise, just use Math.random
      # http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript/2117523#2117523
      "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace /[xy]/g, (c) ->
        r = Math.random() * 16 | 0
        v = (if c == 'x' then r else (r & 0x3 | 0x8))
        v.toString(16)

  # Returns true if the file attachment is an audio file supported by the
  # browser.
  isPlayableAudioFile: (mimetype, file) ->
    return false unless Modernizr.audio
    types = []
    # Use Modernizr to detect if the file can actually be played.
    if Modernizr.audio.ogg
      types.push('audio/ogg')
    if Modernizr.audio.mp3
      types.push('audio/mpeg')
      types.push('audio/mp3')
    if Modernizr.audio.wav
      types.push('audio/wav')
      types.push('audio/x-wav')
    if Modernizr.audio.m4a
      types.push('audio/x-m4a')
      types.push('audio/aac')
    # If the current user sent it, we have the actual file and can try to use
    # its mime type.
    mimetype in types || file?.type in types

  # Returns true if the file attachment is a video file supported by the
  # browser.
  isPlayableVideoFile: (mimetype, file) ->
    return false unless Modernizr.video
    types = []
    # Use Modernizr to detect if the file can actually be played.
    if Modernizr.video.ogg
      types.push('video/ogg')
    if Modernizr.video.h264
      types.push('video/mp4')
    if Modernizr.video.webm
      types.push('video/webm')
    # If the current user sent it, we have the actual file and can try to use
    # its mime type.
    mimetype in types || file?.type in types

  serializeDate: (date) ->
    month = "#{date.getMonth() + 1}"
    month = '0' + month if month.length < 2
    day = "#{date.getDate()}"
    day = '0' + day if day.length < 2

    "#{date.getFullYear()}-#{month}-#{day}"

  deserializeDate: (str) ->
    parts = str.split('-')
    return null unless parts.length == 3
    new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))

  isUsingModifierKey: (event) ->
    event.ctrlKey || event.altKey || event.shiftKey || event.metaKey

  notUsingModifierKey: (event) ->
    ! @isUsingModifierKey(event)

  arrayWithoutArray: (arr1, arr2) ->
    arr = []
    arr1.forEach (obj) ->
      arr.pushObject(obj) if ! arr2.contains(obj)

    arr
