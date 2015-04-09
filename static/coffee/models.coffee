window.FM = window.FM || {}


FM.MailboxList = React.createClass({

    displayName: 'MailboxList'

    getInitialState: -> {
        currentMailbox: null
        mailboxes: null
    }

    componentDidMount: ->
        FM.getJSON('/api/mailbox/list', {
            cHost: window.host
            cEmail: window.email
            cPassword: window.password
        }, (data) => @setState({mailboxes: data}))

    render: ->

        if !@state.mailboxes
            return React.DOM.div(null, 'Loading...')

        mailboxNodes = @state.mailboxes.map((mailbox) =>
            FM.Mailbox({
                currentMailbox: @state.currentMailbox
                name: mailbox
            })
        )

        return React.DOM.div({
            className: 'panel-group'
        }, mailboxNodes)
})


FM.Mailbox = React.createClass({

    displayName: 'Mailbox'

    getInitialState: -> {
        messageCount: 'Loading...'
        pagination: ''
    }

    componentDidMount: ->
        FM.getJSON('/api/message/count', {
            cmrCredentials: {
                cHost: window.host
                cEmail: window.email
                cPassword: window.password
            }
            cmrMailbox: @props.name
        }, (data) =>
            @setState({
                messageCount: data
                pagination: FM.Pagination({
                    total: Math.ceil(data / 10)
                })
            })
        )

    render: ->

        # FIXME: may result in ambiguous IDs
        safeID = @props.name.replace(/\W/g, '')

        messageList = FM.MessageList({
            mailbox: @props.name
            mailboxID: safeID
        })

        return React.DOM.div({className: 'panel panel-default'},
            React.DOM.div({className: 'panel-heading'},
                React.DOM.h4({className: 'panel-title'},
                    React.DOM.a(
                        {
                            'data-toggle': 'collapse'
                            href: "##{safeID}"
                        },
                        @props.name,
                        # TODO: ugly badge
                        React.DOM.span({className: 'badge'}, @state.messageCount))))
            React.DOM.div(
                {
                    id: safeID
                    className: 'panel-collapse collapse'
                },
                React.DOM.div({className: 'panel-body'}, messageList)
                React.DOM.div({className: 'text-center'}, @state.pagination)
            )
        )
})


FM.MessageList = React.createClass({

    displayName: 'MessageList'

    getInitialState: -> {
        currentPage: null
        loadingPage: null
        messages: null
        pages: 1
    }

    componentDidMount: ->

        onShow = =>
            FM.getJSON('/api/message/list', {
                lmrCredentials: {
                    cHost: window.host
                    cEmail: window.email
                    cPassword: window.password
                }
                lmrMailbox: @props.mailbox
                lmrPage: 1
            }, (data) =>
                @setState({messages: data})
            )

        $("##{@props.mailboxID}").on('show.bs.collapse', onShow)

    renderList: ->

        messageNodes = @state.messages.map((message) ->
            FM.Message({message: message})
        )

        return React.DOM.div(null,
            React.DOM.table({className: "table table-striped table-hover"},
                React.DOM.thead(null,
                    React.DOM.tr(null,
                        React.DOM.th(null, "Subject"),
                        React.DOM.th(null, "From"),
                        React.DOM.th(null, "Date")
                    )
                ),
                React.DOM.tbody(null,
                    messageNodes
                )
            )
        );

    #renderSingle: ->
    #    message = this.state.message
    #    React.DOM.div(null,
    #        React.DOM.dl({className: "dl-horizontal"},
    #            React.DOM.dt(null, "Subject"),
    #            React.DOM.dd(null, message.message_subject),
    #            React.DOM.dt(null, "From"),
    #            React.DOM.dd(null, message.message_sender),
    #            React.DOM.dt(null, "Date"),
    #            React.DOM.dd(null, message.date)
    #        ),
    #        React.DOM.pre(null,
    #            this.state.message.contents[0]
    #        )
    #    )

    render: ->
        if @state.messages
            return @renderList()
        else
            return React.DOM.div({}, "Loading...")
})


FM.Message = React.createClass({
    displayName: 'Message'
    render: ->
        React.DOM.tr(null,
            React.DOM.td(null, React.DOM.a(
                {href: FM.makeUrl('view', this.props.mailbox, this.props.message.mUid)},
                this.props.message.mSubject
            )),
            React.DOM.td(null, this.props.message.mSender),
            React.DOM.td(null, this.props.message.mDate)
        )
});


FM.Pagination = React.createClass({
    displayName: 'Pagination',
    render: ->

        if this.props.currentPage > 1
            previous = React.DOM.li(null, React.DOM.a({
                href: FM.makeUrl('list', this.props.mailbox, this.props.currentPage - 1)
            }, "«"))
        else
            previous = React.DOM.li({className: "disabled"}, React.DOM.span(null, "«"))

        if this.props.currentPage < this.props.total
            next = React.DOM.li(null, React.DOM.a({
                href: FM.makeUrl('list', this.props.makeUrl, this.props.currentPage + 1)
            }, "»"))
        else
            next = React.DOM.li({className: "disabled"}, React.DOM.span(null, "»"))

        items = [];
        # TODO: handle a large number of pages
        for i in [1..this.props.total]
            if i == this.props.loadingPage
                item = React.DOM.li({className: "disabled"}, React.DOM.span(null, i));
            else if i == this.props.currentPage
                item = React.DOM.li({className: "active"},
                    React.DOM.span(null, i, " ", React.DOM.span({className: "sr-only"}, "(current)"))
                );
            else
                item = React.DOM.li(null,
                    React.DOM.a({href: FM.makeUrl('list', this.props.mailbox, i)}, i)
                );
            items.push(item)

        return React.DOM.ul({className: "pagination"}, previous, items, next)
})


FM.Alert = React.createClass({
    displayName: 'Alert',
    render: ->
        if this.props.code && this.props.message
            return React.DOM.div({className: "alert alert-danger", role: "alert"},
                React.DOM.strong(null, this.props.code), ": ", this.props.message
            );
})
