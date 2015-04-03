window.FM = window.FM || {}

FM.makeUrl = (parts...) -> '#' + (encodeURIComponent(p) for p in parts).join('/')

FM.getJSON = (url, data, callback) ->
    $.post(url, JSON.stringify(data), callback, 'json')
