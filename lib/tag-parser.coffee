{Point} = require 'atom'

module.exports =
  class TagParser
    constructor: (tags, grammar) ->
      @tags = tags
      @grammar = grammar

      #splitSymbol = '::' for c/c++, and '.' for others.
      if @grammar == 'source.c++' or @grammar == 'source.c'
        @splitSymbol = '::'
      else
        @splitSymbol = '.'

    splitParentTag: (parentTag) ->
      index = parentTag.indexOf(':')

      type: parentTag.substr(0, index)
      parent: parentTag.substr(index+1)

    splitNameTag: (nameTag) ->
      index = nameTag.lastIndexOf(@splitSymbol)
      return nameTag.substr(index+@splitSymbol.length)

    buildMissedParent: (parents) ->
      parentTags = Object.keys(parents)
      parentTags.sort (a, b) =>
        {typeA, parent: nameA} = @splitParentTag(a)
        {typeB, parent: nameB} = @splitParentTag(b)
        return nameA > nameB

      for now, i in parentTags
        {type, parent: name} = @splitParentTag(now)
        if parents[now] is null
          parents[now] = {
            name: name,
            type: type,
            position: null,
            parent: null
          }
          @tags.push(parents[now])

        if i >= 1
          pre = parentTags[i-1]
          {type, name} = @splitParentTag(pre)
          if now.search(name) >= 0
            parents[now].parent = pre
            parents[now].name = @splitNameTag(parents[now].name)

    parse: ->
      roots = []
      parents = {}

      # sort tags by row number
      @tags.sort (a, b) =>
        return a.position.row - b.position.row

      # try to find out all tags with parent information
      for tag in @tags
        parents[tag.parent] = null if tag.parent

      # try to build up relationships between parent information an the real tag
      for tag in @tags
        if tag.parent
          {type, parent} = @splitParentTag(tag.parent)
          key = tag.type + ':' + parent + @splitSymbol + tag.name
        else
          key = tag.type + ':' + tag.name
        parents[key] = tag if key of parents

      # try to build up the missed parent
      @buildMissedParent(parents)

      for tag in @tags
        if tag.parent
          parent = parents[tag.parent]
          unless parent.position
            parent.position = new Point(tag.position.row-1)

      @tags.sort (a, b) =>
        return a.position.row - b.position.row

      for tag in @tags
        tag.label = tag.name
        tag.icon = "icon-#{tag.type}"
        if tag.parent
          parent = parents[tag.parent]
          parent.children ?= []
          parent.children.push(tag)
        else
          roots.push(tag)

      return {label: 'root', icon: null, children: roots}

    getNearestTag: (row) ->
      left = 0
      right = @tags.length-1
      while left <= right
        mid = (left + right) // 2
        midRow = @tags[mid].position.row

        if row < midRow
          right = mid - 1
        else
          left = mid + 1

      nearest = left - 1
      return @tags[nearest]