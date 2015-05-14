window.FM = window.FM || {}


FM.MailboxList = React.createClass({

    displayName: 'MailboxList'

    getInitialState: -> {
        mailboxes: []
    }

    componentDidMount: ->
        FM.postJSON('/api/mailbox/list', {
            cHost: window.host
            cEmail: window.email
            cPassword: window.password
        }, (data) => @setState({mailboxes: data}))

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
        messages: []
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
        }, (data) =>
            @setState({messages: data})
        )

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
        }, (data) =>
            @setState({
                messageCount: data
            })
        )

    handleClick: (page) ->
        @setState({
            currentPage: page
        })
        @loadMessages()

    render: ->

        badge = if @state.messageCount
            React.DOM.span({className: 'badge'}, @state.messageCount)
        else
            ''

        pager = FM.Pager({
            handleClick: @handleClick
            totalItems: @state.messageCount
        })

        messageNodes = @state.messages.map((message) => FM.Message({
            key: message.mUid
            subject: message.mSubject
            sender: message.mSender
            date: message.mDate
            mailbox: @safeID
        }))

        messageList = if @state.messages
            React.DOM.div(null,
                React.DOM.table({className: "table table-striped table-hover"},
                    React.DOM.thead(null,
                        React.DOM.tr(null,
                            React.DOM.th(null, "Subject"),
                            React.DOM.th(null, "From"),
                            React.DOM.th(null, "Date")
                        )
                    ),
                    React.DOM.tbody(null, messageNodes)
                )
            )
        else React.DOM.div({}, "Loading...")

        return React.DOM.div({className: 'panel panel-default'},
            React.DOM.div({className: 'panel-heading'},
                React.DOM.h4({className: 'panel-title'},
                    React.DOM.a(
                        {
                            'data-toggle': 'collapse'
                            href: "##{@safeID}"
                        },
                        @props.key,
                        badge)))
            React.DOM.div(
                {
                    id: @safeID
                    className: 'panel-collapse collapse'
                },
                React.DOM.div({className: 'panel-body'}, messageList)
                React.DOM.div({className: 'text-center'}, pager)
            )
        )
})


#FM.MessageList = React.createClass({
#
#    #renderSingle: ->
#    #    message = this.state.message
#    #    React.DOM.div(null,
#    #        React.DOM.dl({className: "dl-horizontal"},
#    #            React.DOM.dt(null, "Subject"),
#    #            React.DOM.dd(null, message.message_subject),
#    #            React.DOM.dt(null, "From"),
#    #            React.DOM.dd(null, message.message_sender),
#    #            React.DOM.dt(null, "Date"),
#    #            React.DOM.dd(null, message.date)
#    #        ),
#    #        React.DOM.pre(null,
#    #            this.state.message.contents[0]
#    #        )
#    #    )
#
#})


FM.Message = React.createClass({
    displayName: 'Message'
    render: ->
        React.DOM.tr(null,
            React.DOM.td(null, React.DOM.a(
                {
                    href: FM.makeUrl(@props.mailbox, @props.key)
                },
                @props.subject
            )),
            React.DOM.td(null, @props.sender),
            React.DOM.td(null, @props.date)
        )
});


FM.PagerItem = React.createClass({

    displayName: 'PagerItem'

    handleClick: ->
        @props.handleClick(@props.target)

    render: ->
        # TODO: loading
        if @props.current == @props.target
            React.DOM.li({className: "active"}, React.DOM.span({}, @props.text))
        else if 0 < @props.target <= @props.total
            React.DOM.li({onClick: @handleClick}, React.DOM.span({}, @props.text))
        else
            React.DOM.li({className: "disabled"}, React.DOM.span({}, @props.text))
})


FM.Pager = React.createClass({

    displayName: 'Pager'

    getInitialState: -> {
        current: 1
    }

    render: ->
        totalPages = Math.ceil(@props.totalItems / 10)
        makePagerItem = (target, text=target) => FM.PagerItem({
            key: target
            current: @state.current
            target: target
            total: totalPages
            handleClick: @props.handleClick
            text
        })
        previous = makePagerItem(@state.current - 1, "«")
        next = makePagerItem(@state.current + 1, "»")
        # TODO: handle a large number of pages
        items = (makePagerItem(i) for i in [1..totalPages])
        return React.DOM.ul({className: "pagination"}, previous, items, next)
})


FM.Alert = React.createClass({
    displayName: 'Alert'
    render: ->
        if @props.code && @props.message
            return React.DOM.div({className: "alert alert-danger", role: "alert"},
                React.DOM.strong(null, @props.code), ": ", @props.message
            );
})
