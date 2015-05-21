window.FM = window.FM || {}


FM.MailboxList = React.createClass({

    displayName: 'MailboxList'

    getInitialState: -> {
        mailboxes: null
    }

    componentDidMount: ->
        FM.postJSON('/api/mailbox/list', {
            cHost: window.host
            cEmail: window.email
            cPassword: window.password
        }, (data) => @setState({
            mailboxes: data
        }))

    render: ->

        if !@state.mailboxes
            return React.DOM.div(null, 'Loading...')

        mailboxNodes = @state.mailboxes.map((mailbox) => FM.Mailbox({
            key: mailbox
        }))

        return React.DOM.div({
            className: 'panel-group'
        }, mailboxNodes)
})


FM.Mailbox = React.createClass({

    displayName: 'Mailbox'

    getInitialState: -> {
        messageCount: null
        currentPage: 1
        messages: null
    }

    loadMessages: ->
        FM.postJSON('/api/message/list', {
            lmrCredentials: {
                cHost: window.host
                cEmail: window.email
                cPassword: window.password
            }
            lmrMailbox: @props.key
            lmrPage: @state.currentPage
        }, (data) => @setState({
            messages: data
        }))

    componentDidMount: ->

        # FIXME: may result in ambiguous IDs
        @safeID = @props.key.replace(/\W/g, '')

        $(document).on('show.bs.collapse', "##{@safeID}", @loadMessages)

        FM.postJSON('/api/message/count', {
            cmrCredentials: {
                cHost: window.host
                cEmail: window.email
                cPassword: window.password
            }
            cmrMailbox: @props.key
        }, (data) => @setState({
                messageCount: data
        }))

    handleClick: (page) ->
        @setState({
            currentPage: page
        })
        @loadMessages()


    # This contains more than 1 element. It doesn't fit into a ReactJS class.
    renderMessage: (uid, subject, sender, date, contents) -> [
        React.DOM.tr(
            null
            React.DOM.td(null, React.DOM.a({
                href: FM.makeUrl(@safeID, uid)
            }, subject))
            React.DOM.td(null, sender)
            React.DOM.td(null, date)
        )
        React.DOM.tr(
            null
            React.DOM.td(
                {colSpan: 3}
                React.DOM.dl({className: 'dl-horizontal'}
                    React.DOM.dt(null, 'Subject')
                    React.DOM.dd(null, subject)
                    React.DOM.dt(null, 'From')
                    React.DOM.dd(null, sender)
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

        pager = FM.Pager({
            currentPage: @state.currentPage
            handleClick: @handleClick
            totalItems: @state.messageCount
        })

        messageList = if @state.messages
            messageNodes = @state.messages.map((message) => @renderMessage(
                message.mUid
                message.mSubject
                message.mSender
                message.mDate
                message.mContents
            ))
            React.DOM.div(null
                React.DOM.table({className: 'table table-striped table-hover'}
                    React.DOM.thead(null
                        React.DOM.tr(null
                            React.DOM.th(null, 'Subject')
                            React.DOM.th(null, 'From')
                            React.DOM.th(null, 'Date')
                        )
                    )
                    React.DOM.tbody(null, messageNodes)
                )
            )
        else React.DOM.div({}, 'Loading...')

        return React.DOM.div({className: 'panel panel-default'}
            React.DOM.div({className: 'panel-heading'}
                React.DOM.h4({className: 'panel-title'}
                    React.DOM.a({
                        'data-toggle': 'collapse'
                        href: "##{@safeID}"
                    }, @props.key, badge)))
            React.DOM.div(
                {
                    id: @safeID
                    className: 'panel-collapse collapse'
                }
                React.DOM.div({className: 'panel-body'}, messageList)
                React.DOM.div({className: 'text-center'}, pager)
            )
        )
})


FM.PagerItem = React.createClass({

    displayName: 'PagerItem'

    handleClick: ->
        @props.handleClick(@props.target)

    render: ->
        # TODO: loading
        if @props.currentPage == @props.target
            React.DOM.li({className: 'active'}, React.DOM.span({}, @props.text))
        else if 0 < @props.target <= @props.total
            React.DOM.li({onClick: @handleClick}, React.DOM.span({}, @props.text))
        else
            React.DOM.li({className: 'disabled'}, React.DOM.span({}, @props.text))
})


FM.Pager = React.createClass({

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
})


FM.Alert = React.createClass({
    displayName: 'Alert'
    render: ->
        if @props.code && @props.message
            return React.DOM.div({className: 'alert alert-danger', role: 'alert'}
                React.DOM.strong(null, @props.code), ': ', @props.message
            );
})
