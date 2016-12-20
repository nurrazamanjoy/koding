kd = require 'kd'
bowser = require 'bowser'
Encoder = require 'htmlencode'

FlexSplit = require './flexsplit'
FlexSplitStorage = require './flexsplit/storage'
AppStorageAdapter = require './appstorageadapter'

Toolbar = require './toolbar'
Editor = require './editorview'


module.exports = class StackEditor extends kd.View


  constructor: (options = {}, data = {}) ->

    super options, data

    # Storage
    @layoutStorage = new FlexSplitStorage
      adapter: AppStorageAdapter

    # Toolbar
    @toolbar = new Toolbar

    # Status bar
    @statusbar = new kd.View
      cssClass: 'statusbar'

    # Editor views
    @editor = new Editor
      cssClass: 'editor'

    @logs = new Editor
      cssClass: 'logs'
      title: 'Logs'

    @variables = new Editor
      cssClass: 'variables'
      title: 'Custom Variables'

    @readme = new Editor
      cssClass: 'readme'
      title: 'Readme'

    @emit 'ready'


  setTemplateData: (data) ->

    if data
      @setData data
      @toolbar.setData data

    { description, template } = @getData()
    return  unless description or template

    @editor.setContent Encoder.htmlDecode template.rawContent
    @readme.setContent description

    @logs.setContent 'Stack template loaded'



  viewAppended: ->

    # Layout
    @addSubView new FlexSplit
      cssClass            : 'mainview'
      resizable           : no
      views               : [
        @toolbar          # Toolbar on top, fixed height
        new FlexSplit
          resizable       : no
          views           : [
            contentView   = new FlexSplit
              name        : 'contentView'
              cssClass    : 'content'
              views       : [
                new FlexSplit
                  name    : 'leftColumn'
                  views   : [@editor, @logs]
                  sizes   : [90, 10]
                  storage : @layoutStorage
                new FlexSplit
                  name    : 'rightColumn'
                  sizes   : [50, 50]
                  views   : [@variables, @readme]
                  storage : @layoutStorage
              ]
              sizes       : [55, 45]
              type        : FlexSplit.VERTICAL
              storage     : @layoutStorage
            @statusbar    # Statusbar on bottom, fixed height
          ]
      ]

    contentView.setClass 'safari-flex-fix'  if bowser.safari
