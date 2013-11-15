class VmProductForm extends FormWorkflow

  createUpgradeForm: ->
    (KD.getSingleton 'paymentController').createUpgradeForm 'vm'

  checkUsageLimits: (pack, callback) ->
    { subscription } = @collector.data
    subscription.checkUsage pack, (err, usage) =>
      if err
        @clearData 'subscription'
        @setState 'upgrade'
      @collectData { pack }

  createPackChoiceForm: -> new PackChoiceForm
    title     : 'Choose your VM'
    itemClass : VmProductView

  setState: (state) ->
    @showForm state

  setCurrentSubscriptions: (subscriptions) ->
    @currentSubscriptions = subscriptions
    switch subscriptions.length
      when 0
        @setState 'upgrade'
      when 1
        [subscription] = subscriptions
        @collectData { subscription }
        # @emit 'PackOfferingRequested', subscription
      else
        @setState 'choice'

  setContents: (packs) ->
    @setState 'pack choice'
    (@getForm 'pack choice').setContents packs

  viewAppended: -> @prepareProductForm()

  createChoiceForm: -> new KDView partial: 'this is a plan choice form'

  prepareProductForm: ->

    @requireData [
      
      @any('subscription', 'plan')

      'pack'
    ]

    upgradeForm = @createUpgradeForm()
    upgradeForm.on 'PlanSelected', (plan) =>
      @collectData { plan }

    @addForm 'upgrade', upgradeForm

    packChoiceForm = @createPackChoiceForm()
    packChoiceForm.on 'PackSelected', (pack) =>
      @checkUsageLimits pack, (err, usage) ->
        debugger
      # @collectData { pack }

    @addForm 'pack choice', packChoiceForm

    choiceForm = @createChoiceForm()
    