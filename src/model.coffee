
module = angular.module 'angular-orm',
module.factory 'Model', [ 'RelationalIndex', ( RelationalIndex ) ->

  class Model
    @CREATED: 'created'
    @UPDATED: 'updated'

    constructor: ( @staticSelf, data, @eventStream ) ->
      @update data, true

      if @eventStream
        @associatedModelStream = @eventStream.filter @filterModelStream
        @associatedModelStream.onValue @storeAssociatedModel
        @pushEvent Model.CREATED unless @staticSelf.relationalIndex.isEmpty()

    filterModelStream: ( data ) =>
      return false unless relation = @staticSelf.relationalIndex.get data.model
      if relation.keyInSelf
        return data.object.id == @[relation.key]
      else
        return data.object[ relation.key ] == @id

    storeAssociatedModel: ( data ) =>
      return unless relation = @staticSelf.relationalIndex.get data.model
      @staticSelf.setAssociatedModel this, relation.property, data.object, relation.type

      return unless inverse = data.object.staticSelf.relationalIndex.find model: @staticSelf.name, key: relation.key, keyInSelf: !relation.keyInSelf
      @staticSelf.setAssociatedModel data.object, inverse.property, this, inverse.type

    update: ( data, silent=false ) =>
      changed = @hasRelationalChanges data
      angular.extend this, data
      if !silent && changed
        @pushEvent Model.UPDATED

    hasRelationalChanges: ( data ) =>
      for property, value of data
        changed = @[property] != value
        continue unless changed
        hasRelation = @staticSelf.relationalIndex.find( key: property, keyInSelf: true )?
        return true if hasRelation
      return false

    pushEvent: ( type ) =>
      @eventStream?.push event: type, model: @staticSelf.name, id: @id, object: this

    @initialize: ( name=@name ) ->
      @name = name
      @defaultKey = @generateKeyFromModelName @name
      if @relationalIndex
        @relationalIndex = @relationalIndex.clone()
      else
        @relationalIndex = new RelationalIndex

    @generateKeyFromModelName: ( modelName ) ->
      "#{ modelName.charAt(0).toLowerCase() }#{ modelName.slice(1) }ID"

    @hasMany: ( property, modelName, options={} ) ->
      throw new Error "Cannot add relations to uninitialized class, call initialize() first." unless @relationalIndex
      key = options.key || @generateKeyFromModelName @name
      @relationalIndex.add property, modelName, RelationalIndex.MANY, key, false

    @hasOne: ( property, modelName, options={} ) ->
      throw new Error "Cannot add relations to uninitialized class, call initialize() first." unless @relationalIndex
      keyInSelf = options.keyInSelf != false
      nameForKey = if keyInSelf then modelName else @name
      key = options.key || @generateKeyFromModelName nameForKey
      @relationalIndex.add property, modelName, RelationalIndex.ONE, key, keyInSelf

    @belongsTo: ( property, modelName, options={} ) ->
      options = Object.clone options
      options.keyInSelf = true unless options.keyInSelf == false
      @hasOne property, modelName, options

    @setAssociatedModel: ( object, property, value, type ) =>
      switch type
        when RelationalIndex.ONE
          object[property] = value
        when RelationalIndex.MANY
          object[property] ||= {}
          object[property][value.id] = value
        else
          throw "Uknown relation-type"

]