Ember.Widgets.PopoverComponent =
Ember.Component.extend Ember.Widgets.StyleBindingsMixin,
Ember.Widgets.BodyEventListener,
  layoutName: 'popover'
  classNames: ['popover']
  classNameBindings: ['isShowing:in', 'fade', 'placement']
  styleBindings: ['left', 'top', 'display', 'visibility']

  # The target element to anchor the popover to
  targetElement: null
  contentViewClass: null
  placement:  'top'
  title:      ''
  left:       0
  top:        0
  display:    'block'
  visibility: 'hidden'
  fade: yes
  isShowing:  no
  inserted: no
  content: ""
  marginTop: 10
  marginLeft: 10

  _resizeHandler: null
  _scrollHandler: null

  _contentViewClass: Ember.computed ->
    return @get('contentViewClass') if @get('contentViewClass')
    Ember.View.extend
      content: Ember.computed.alias 'parentView.content'
      template: Ember.Handlebars.compile('{{view.parentView.content}}')
  .property 'contentViewClass'

  didInsertElement: ->
    @_super()
    # we want the view to render first and then we snap to position after
    # it is renered
    Ember.run.next this, ->
      @snapToPosition()
      @set 'visibility', 'visible'
      @set 'isShowing', yes

  bodyClick: -> @hide()

  hide: ->
    @set('isShowing', no)
    @$().one $.support.transition.end, =>
      # We need to wrap this in a run-loop otherwise ember-testing will complain
      # about auto run being disabled when we are in testing mode.
      Ember.run this, @destroy

  ###
  Calculate the offset of the given iframe relative to the top window.
  - Walks up the iframe chain, checking the offset of each one till it reaches top
  - Only works with friendly iframes.
  - Takes into account scrolling, but comes up with a result relative to
  top iframe, regardless of being visibile withing intervening frames.

  @param window win    the iframe we're interested in (e.g. window)
  @param object pos   an object containing the offset so far:
  { left: [x], top: [y] }
  (optional - initializes with 0,0 if undefined)
  @return pos object above

  via http://stackoverflow.com/a/9676655
  ###
  computeFrameOffset: (win, pos={top: 0, left: 0}) ->
    # find our <iframe> tag within our parent window
    frames = win.parent.document.getElementsByTagName("iframe")
    found = false

    for frame in frames
      if frame.contentWindow is win
        found = true
        break

    # add the offset & recur up the frame chain
    if found
      rect = frame.getBoundingClientRect()
      pos.left += rect.left
      pos.top += rect.top
      @computeFrameOffset win.parent, pos if win isnt top
    pos

  getOffset: ($target) ->
    pos = $target.offset()
    doc = $target[0].ownerDocument
    win = doc.defaultView
    @computeFrameOffset(win, pos)

  snapToPosition: ->
    $target      = $(@get('targetElement'))
    return if @get('state') isnt 'inDOM' or Ember.isEmpty($target)
    actualWidth  = @$()[0].offsetWidth
    actualHeight = @$()[0].offsetHeight
    pos = @getOffset($target)
    pos.width  = $target[0].offsetWidth
    pos.height = $target[0].offsetHeight

    switch @get('placement')
      when 'bottom'
        @set 'top',   pos.top + pos.height
        @set 'left',  pos.left + pos.width / 2 - actualWidth / 2
        break
      when 'top'
        @set 'top',   pos.top - actualHeight
        @set 'left',  pos.left + pos.width / 2 - actualWidth / 2
        break
      when 'top-right'
        @set 'top',   pos.top
        @set 'left',  pos.left + pos.width
        break
      when 'top-left'
        @set 'top',   pos.top
        @set 'left',  pos.left - actualWidth
        break
      when 'bottom-right'
        @set 'top', pos.top + pos.height
        @set 'left', pos.left + pos.width - actualWidth
        break
      when 'bottom-left'
        @set 'top',   pos.top + pos.height
        @set 'left',  pos.left
        break
      when 'left'
        @set 'top',   pos.top - @get('marginTop')
        @set 'left',  pos.left - actualWidth
        break
      when 'right'
        @set 'top',   pos.top - @get('marginTop')
        @set 'left',  pos.left + pos.width
        break
    @correctIfOffscreen()
    @positionArrow()

  positionArrow: ->
    $target = $(@get('targetElement'))
    pos = @getOffset($target)
    pos.width  = $target[0].offsetWidth
    pos.height = $target[0].offsetHeight
    switch @get('placement')
      when 'left', 'right'
        @set 'arrowStyle', "margin-top:#{pos.top - @get('top') + 11}px;"
      when 'top', 'bottom'
        @set 'arrowStyle', "margin-left:#{pos.left - @get('left') + 11}px;"

  correctIfOffscreen: ->
    bodyWidth = $('body').width()
    bodyHeight = $('body').height()
    actualWidth  = @$()[0].offsetWidth
    actualHeight  = @$()[0].offsetHeight

    if @get('left') + actualWidth > bodyWidth
      @set 'left', bodyWidth - actualWidth - @get('marginLeft')
    if @get('left') < 0
      @set 'left', @get('marginLeft')
    if @get('top') + actualHeight > bodyHeight
      @set 'top', bodyHeight - actualHeight - @get('marginTop')
    if @get('top') < 0
      @set 'top', @get('marginTop')

  # We need to put this in a computed because this is attached to the
  # resize and scroll events before snapToPosition is defined. We
  # throttle for 100 ms because that looks nice.
  debounceSnapToPosition: Ember.computed ->
    Ember.run.debounce(this, @snapToPosition, 100)

  _setupDocumentHandlers: ->
    @_super()
    unless @_hideHandler
      @_hideHandler = => @hide()
      $(document).on 'popover:hide', @_hideHandler
    unless @_resizeHandler
      @_resizeHandler = @get('debounceSnapToPosition')
      $(document).on 'resize', @_resizeHandler
    unless @_scrollHandler
      @_scrollHandler = @get('debounceSnapToPosition')
      $(document).on 'scroll', @_scrollHandler

  _removeDocumentHandlers: ->
    @_super()
    $(document).off 'popover:hide', @_hideHandler
    @_hideHandler = null
    $(document).off 'resize', @_resizeHandler
    @_resizeHandler = null
    $(document).off 'scroll', @_scrollHandler
    @_scrollHandler = null

Ember.Widgets.PopoverComponent.reopenClass
  rootElement: '.ember-application'
  hideAll: -> $(document).trigger('popover:hide')

  popup: (options) ->
    @hideAll()
    rootElement = options.rootElement or @rootElement
    popover = this.create options
    popover.set 'container', popover.get('targetObject.container')
    popover.appendTo rootElement
    popover

Ember.Handlebars.helper('popover-component', Ember.Widgets.PopoverComponent)
