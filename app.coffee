console.log 'app.coffee'

{ Tags, Button, StringInput, Spinner } = Doodad
{ Collection, Model } = Backbone


oldSync = Backbone.sync
Backbone.sync = (method, model, options={}) ->
    console.log method, model, options
    options.headers ?= {}
    options.headers = _.extend {},
        'Authorization': "Token #{ params.CONTENT_API_TOKEN }"
        'X-Content-Query-Limit': 100
    , options.headers

    return oldSync(method, model, options)


class Card extends Model
    url: -> if @get('url') then @get('url') else @collection.url()

class CardCollection extends Collection
    model: Card
    url: -> params.CONTENT_API_ROOT
    addCard: (callback) =>
        { x, y } = canvas.getScreenCenter()
        @create {
                type: 'text'
                position:
                    left: x
                    top: y
            },
                wait: true
                success: (model) ->
                    callback(model)


makeStringFieldForProperty = ({ model, property, options }) ->
    options ?= {}
    options.value = model.get(property) or ''
    options.on = blur: (self) ->
        if self.value isnt model.get(property)
            model.save(property, self.value)
    field = new StringInput(options)
    return field


global_is_dragging = false
global_dragging_obj = null

class CardView extends Tags.DIV
    className: 'CardView'
    events: -> {
        'mousedown': '_startDrag'
        'mousedown > *': '_stopPropagation'
        'click > *': '_stopPropagation'
    }

    _stopPropagation: (e) ->
        e.stopPropagation()

    _startDrag: (e) ->
        global_dragging_obj = this

    setPosition: (@x, @y) ->
        @$el.css
            position: 'absolute'
            left: @x
            top: @y
        return

    updatePosition: (d_x, d_y, save=false) ->
        new_x = @x + d_x
        new_y = @y + d_y
        @$el.css
            position: 'absolute'
            left: new_x
            top: new_y
        if save
            @x = new_x
            @y = new_y
            @model.save 'position',
                left: @x
                top: @y
        return

    render: ->
        super(arguments...)
        @$el.empty()
        @$el.attr('id', @model.get('id'))
        @addContent(@model.get('id'))
        @addContent new Button
            type: 'icon'
            label: 'Toggle'
            class: 'action'
            extra_classes: ['CardView_toggle']
            action: =>
                console.log @$el.attr('data-expanded')
                if @$el.attr('data-expanded')
                    @$el.removeAttr('data-expanded')
                else
                    @$el.attr('data-expanded', true)
        @addContent new Button
            type: 'icon'
            label: 'Delete'
            class: 'dangerous'
            extra_classes: ['CardView_delete']
            action: =>
                @model.destroy()
                @$el.remove()
        @addContent makeStringFieldForProperty
            model: @model
            property: 'title'
            options:
                placeholder: 'Title'
        @addContent makeStringFieldForProperty
            model: @model
            property: 'content'
            options:
                multiline: true
                label: 'Description'
                extra_classes: ['description']
        @addContent makeStringFieldForProperty
            model: @model
            property: 'questions'
            options:
                multiline: true
                label: 'Questions'
                extra_classes: ['description']
        @addContent makeStringFieldForProperty
            model: @model
            property: 'requires'
            options:
                tokenize: true
                label: 'Requires'

        @x = @model.get('position').left
        @y = @model.get('position').top
        @$el.css
            position: 'absolute'
            left: @x
            top: @y
        # @$el.draggable
        #     containment: 'parent'
        #     stop: _.debounce (e, ui) =>
        #         @model.save(position: ui.position)
        #     , 1000

        return @el


card_collection = new CardCollection()
console.log card_collection.url()




class CardCanvas extends Tags.DIV
    className: 'CardCanvas'

    events: -> {
        'mousedown': '_startDrag'
        'mousemove': '_doDrag'
        'mouseup': '_stopDrag'
    }

    _zoom: (e) ->
        console.log e

    render: =>
        super()
        @x = 0
        @y = 0
        @$el.css
            left: 0
            top: 0
        return @el

    _startDrag: (e) =>
        global_is_dragging = true
        global_dragging_obj ?= this
        @_drag_x = e.screenX
        @_drag_y = e.screenY

    _doDrag: (e) =>
        e.preventDefault()
        e.stopPropagation()
        if global_is_dragging and global_dragging_obj
            global_dragging_obj.updatePosition(e.screenX - @_drag_x, e.screenY - @_drag_y)

    _stopDrag: (e) =>
        e.stopPropagation()
        global_is_dragging = false
        if global_dragging_obj?
            global_dragging_obj.updatePosition(e.screenX - @_drag_x, e.screenY - @_drag_y, true)
            @_drag_x = null
            @_drag_y = null
            global_dragging_obj = null

    updatePosition: (d_x, d_y, save=false) ->
        new_x = @x + d_x
        new_y = @y + d_y
        @$el.css
            position: 'absolute'
            left: new_x
            top: new_y
        if save
            @x = new_x
            @y = new_y
        return

    getScreenCenter: ->
        $w = $(window)
        w_x = $w.width() / 2 - @x
        w_y = $w.height() / 2 - @y
        return {
            x: w_x
            y: w_y
        }




$app = $('#app')
canvas = new CardCanvas
    id: 'canvas'
controls = new Tags.DIV
    id: 'controls'
    content: [
        new Button
            label: 'Add Card'
            spinner: true
            action: (self) ->
                console.log self, card_collection.url()
                card_collection.addCard (card) ->
                    self.enable()
                    console.log card
    ]



card_collection.on 'sync', ->
    # console.log card_collection.models
card_collection.on 'add', (card) ->
    canvas.addContent new CardView
        model: card









card_collection.fetch()
$app.append(canvas.el, controls.el)
_.defer(canvas.render)
