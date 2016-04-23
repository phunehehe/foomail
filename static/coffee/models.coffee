window.FM = window.FM || {}
FM = window.FM


createReact = (arg) -> React.createFactory(React.createClass(arg))
showContact = (contact) -> "#{contact.cName} <#{contact.cAddress}>"


FM.MailboxList = createReact

    displayName: 'MailboxList'

    getInitialState: -> {
        mailboxes: null
    }

    componentDidMount: -> FM.postJSON('/api/mailbox/list', {
        cHost: FM.host
        cEmail: FM.email
        cPassword: FM.password
    }, (data) => @setState({
        mailboxes: data
    }))

    render: ->

        if !@state.mailboxes
            return React.DOM.div(null, 'Loading...')

        mailboxNodes = @state.mailboxes.map((mailbox) -> FM.Mailbox({
            id: mailbox
            key: mailbox
        }))

        return React.DOM.div({className: 'panel-group'}, mailboxNodes)


FM.Mailbox = createReact

    displayName: 'Mailbox'

    getInitialState: -> {
        messageCount: null
        currentPage: 1
        messages: null
    }

    loadMessages: -> FM.postJSON('/api/message/list', {
        lmrCredentials: {
            cHost: FM.host
            cEmail: FM.email
            cPassword: FM.password
        }
        lmrMailbox: @props.id
        lmrPage: @state.currentPage
    }, (data) => @setState({
        messages: data
    }))

    componentDidMount: ->

        @safeID = FM.makeId(@props.id)

        $(document).on('show.bs.collapse', "##{@safeID}", @loadMessages)

        FM.postJSON('/api/message/count', {
            cmrCredentials: {
                cHost: FM.host
                cEmail: FM.email
                cPassword: FM.password
            }
            cmrMailbox: @props.id
        }, (data) => @setState({
                messageCount: data
        }))

    handleClick: (page) ->
        @setState({
            currentPage: page
        })
        @loadMessages()


    # This contains more than 1 element. It doesn't fit into a ReactJS class.
    renderMessage: (uid, subject, sender, date, contents) ->
        url = FM.makeId(@safeID, uid)
        return [
            React.DOM.tr(null
                React.DOM.td(null, React.DOM.a({
                    'data-toggle': 'collapse'
                    href: "##{url}"
                }, subject))
                React.DOM.td(null, showContact sender)
                React.DOM.td(null, date)
            )
            React.DOM.tr(null
                React.DOM.td(
                    {
                        id: url
                        className: 'collapse'
                        colSpan: 3
                    }
                    React.DOM.dl({className: 'dl-horizontal'}
                        React.DOM.dt(null, 'Subject')
                        React.DOM.dd(null, subject)
                        React.DOM.dt(null, 'From')
                        React.DOM.dd(null, showContact sender)
                        React.DOM.dt(null, 'Date')
                        React.DOM.dd(null, date)
                    )
                    React.DOM.pre(null, contents[0])
                )
            )
        ]

    render: ->

        badge = if @state.messageCount
            React.DOM.span({className: 'badge'}, @state.messageCount)
        else
            ''

        pager = if @state.messageCount
            FM.Pager({
                currentPage: @state.currentPage
                handleClick: @handleClick
                totalItems: @state.messageCount
            })
        else
            'Loading...'

        messageList = if @state.messages
            messageNodes = @state.messages.map((message) => @renderMessage(
                message.mUid
                message.mSubject
                message.mSender
                message.mDate
                message.mContents
            ))
            React.DOM.table({className: 'message-list table table-striped table-hover'}
                React.DOM.thead(null
                    React.DOM.tr(null
                        React.DOM.th(null, 'Subject')
                        React.DOM.th(null, 'From')
                        React.DOM.th(null, 'Date')
                    )
                )
                React.DOM.tbody(null, messageNodes)
            )
        else React.DOM.div(null, 'Loading...')

        return React.DOM.div({className: 'panel panel-default'}
            React.DOM.div({className: 'panel-heading'}
                React.DOM.h4({className: 'panel-title'}
                    React.DOM.a({
                        'data-toggle': 'collapse'
                        href: "##{@safeID}"
                    }, @props.id, badge)))
            React.DOM.div(
                {
                    id: @safeID
                    className: 'panel-collapse collapse'
                }
                React.DOM.div({className: 'panel-body'}, messageList)
                React.DOM.div({className: 'text-center'}, pager)
            )
        )


FM.PagerItem = createReact

    displayName: 'PagerItem'

    handleClick: ->
        @props.handleClick(@props.target)

    render: ->
        # TODO: loading
        if @props.currentPage == @props.target
            React.DOM.li({className: 'active'}, React.DOM.span(null, @props.text))
        else if 0 < @props.target <= @props.total
            React.DOM.li({onClick: @handleClick}, React.DOM.span(null, @props.text))
        else
            React.DOM.li({className: 'disabled'}, React.DOM.span(null, @props.text))


FM.Pager = createReact

    displayName: 'Pager'

    render: ->
        totalPages = Math.ceil(@props.totalItems / 10)
        makePagerItem = (target, text=target) => FM.PagerItem({
            key: target
            currentPage: @props.currentPage
            target: target
            total: totalPages
            handleClick: @props.handleClick
            text: text
        })
        previous = makePagerItem(@props.currentPage - 1, '«')
        next = makePagerItem(@props.currentPage + 1, '»')
        # TODO: handle a large number of pages
        items = (makePagerItem(i) for i in [1..totalPages])
        return React.DOM.ul({className: 'pagination'}, previous, items, next)


FM.Alert = createReact
    displayName: 'Alert'
    render: ->
        if @props.code && @props.message
            return React.DOM.div({
                className: 'alert alert-danger'
                role: 'alert'
            }, React.DOM.strong(null, @props.code), ': ', @props.message)
