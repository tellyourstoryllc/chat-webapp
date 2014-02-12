###############################################################################
# Sometimes doing feature detection is just too hard or not worth it.  For
# example, IE9 supports the oninput event, but it doesn't trigger when pressing
# backspace.

###########################################################
# Mobile
#
# https://gist.github.com/danott/855078

Modernizr.addTest "ipad", ->
  !! navigator.userAgent.match(/iPad/i)

Modernizr.addTest "iphone", ->
  !! navigator.userAgent.match(/iPhone/i)

Modernizr.addTest "ipod", ->
  !! navigator.userAgent.match(/iPod/i)

Modernizr.addTest "appleios", ->
  Modernizr.ipad || Modernizr.ipod || Modernizr.iphone

Modernizr.addTest "android", ->
  !! navigator.userAgent.match(/Android/i)

###########################################################
# IE

Modernizr.addTest "msie", ->
  !! navigator.userAgent.match(/MSIE/)

Modernizr.addTest "msie9", ->
  !! navigator.userAgent.match(/MSIE 9\./)
