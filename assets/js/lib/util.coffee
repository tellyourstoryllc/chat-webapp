App.Util = Ember.Object.extend()

App.Util.reopenClass

  escapeRegexp: (str) ->
    (str + '').replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1")

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
