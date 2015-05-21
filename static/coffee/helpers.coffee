window.FM = window.FM || {}

FM.makeUrl = (parts...) -> '#' + (encodeURIComponent(p) for p in parts).join('/')

# FIXME: may result in ambiguous IDs
FM.makeId = (parts...) -> (p.toString().replace(/\W/g, '') for p in parts).join('-')

# Because jQuery... http://stackoverflow.com/q/2845459/168034
FM.postJSON = (url, data, callback) ->
    $.ajax({
        url: url
        type: 'POST'
        data: JSON.stringify(data)
        contentType: 'application/json'
        success: callback
    })

FM.getJSON = (url, data, callback) ->
    $.get(url, data, callback, 'json')
