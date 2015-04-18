window.FM = window.FM || {}

FM.makeUrl = (parts...) -> '#' + (encodeURIComponent(p) for p in parts).join('/')

FM.postJSON = (url, data, callback) ->
    $.post(url, JSON.stringify(data), callback, 'json')

FM.getJSON = (url, data, callback) ->
    $.get(url, data, callback, 'json')


FM.makePagerItem = (currentPage, targetPage, totalPages, urlParts, text=targetPage) ->

    url = FM.makeUrl(urlParts + targetPage)

    if currentPage == targetPage
        React.DOM.li({className: "disabled"}, React.DOM.a({href: url}, text))
    else if 0 < targetPage <= totalPages
        React.DOM.li({}, React.DOM.a({href: url}, text))
    else
        React.DOM.li({className: "disabled"}, React.DOM.span({}, text))
