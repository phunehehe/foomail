window.FM = window.FM || {}
var FM = window.FM


var getCredentials = function () {
    return {
        cHost: localStorage.getItem('host'),
        cEmail: localStorage.getItem('email'),
        cPassword: localStorage.getItem('password'),
    }
}

var getCurrentMailbox = function() {
  var hash = window.location.hash.substring(1).split('/')
  return hash[0]
}

var getCurrentMessage = function() {
  var hash = window.location.hash.substring(1).split('/')
  return hash[1]
}

var escapeMailbox = function (name) {
  var parts = name.split(/\W/)
  return parts.join('-')
}

var makeSelector = function(mailbox, messageID) {
    // http://stackoverflow.com/a/5154155/168034
    return mailbox + '\\/' + messageID
}

var createReact = function (arg) {
  return React.createFactory(React.createClass(arg))
}

var showContact = function (contact) {
  return contact.cName + ' <' + contact.cAddress + '>'
}


FM.postJSON = function (url, data, callback) {
  var ajax
  if (FM.ajaxMock) {
    ajax = FM.ajaxMock
  } else {
    ajax = $.ajax
  }
  return ajax({
    url: url,
    type: 'POST',
    data: JSON.stringify(data),
    contentType: 'application/json',
    success: callback,
  })
}

FM.MailboxList = createReact({
  displayName: 'MailboxList',
  getInitialState: function () {
    return { mailboxes: null }
  },
  render: function () {
    var mailboxNodes
    if (!this.state.mailboxes) {
      return React.DOM.div(null, 'Loading...')
    }
    mailboxNodes = this.state.mailboxes.map(function (mailbox) {
      return FM.Mailbox({
        id: mailbox,
        key: mailbox,
      })
    })
    return React.DOM.div({ className: 'panel-group' }, mailboxNodes)
  },
})

FM.Mailbox = createReact({
  displayName: 'Mailbox',
  getInitialState: function () {
    return {
      messageCount: null,
      currentPage: 1,
      messages: null,
    }
  },
  loadMessages: function () {
    return FM.postJSON('/api/message/list', {
      lmrCredentials: getCredentials(),
      lmrMailbox: this.props.id,
      lmrPage: this.state.currentPage,
    }, (function (_this) {
      return function (data) {
        return _this.setState({ messages: data })
      }
    })(this))
  },
  componentDidMount: function () {
    this.safeID = escapeMailbox(this.props.id)
    $(document).on('show.bs.collapse', '#' + this.safeID, this.loadMessages)
    return FM.postJSON('/api/message/count', {
      cmrCredentials: getCredentials(),
      cmrMailbox: this.props.id,
    }, (function (_this) {
      return function (data) {
        return _this.setState({ messageCount: data })
      }
    })(this))
  },
  componentDidUpdate: function () {
    if (getCurrentMailbox() == this.safeID) {
      $('#' + this.safeID).collapse('show')
    }
  },
  handleClick: function (page) {
    this.setState({ currentPage: page })
    return this.loadMessages()
  },
  render: function () {
    var badge, messageList, pager
    badge = this.state.messageCount
      ? React.DOM.span({ className: 'badge' }, this.state.messageCount)
      : ''
    pager = this.state.messageCount
      ? FM.Pager({
          currentPage: this.state.currentPage,
          handleClick: this.handleClick,
          totalItems: this.state.messageCount,
        })
      : 'Loading...'
    var safeID = this.safeID
    messageList = this.state.messages
      ? this.state.messages.map(function (message) {
        return FM.Message({
          mailboxID: safeID,
          key: message.mUid,
          uid: message.mUid,
          subject: message.mSubject,
          sender: message.mSender,
          date: message.mDate,
          contents: message.mContents,
        })})
      : React.DOM.div(null, 'Loading...')
    return React.DOM.div({ className: 'panel panel-default' },
      React.DOM.div({ className: 'panel-heading' },
        React.DOM.h4({ className: 'panel-title' }, React.DOM.a(
          {
            'data-toggle': 'collapse',
            href: '#' + safeID,
          },
          this.props.id, badge
        ))
      ),
      React.DOM.div(
        {
          id: safeID,
          className: 'panel-collapse collapse',
        },
        React.DOM.div({ className: 'panel-body' },
          messageList,
          React.DOM.div({ className: 'text-center' }, pager)
        )
      )
    )
  },
})


FM.Message = createReact({
  displayName: 'Message',

  componentDidMount: function () {
    if (getCurrentMailbox() == this.props.mailboxID
        && getCurrentMessage() == this.props.uid) {
      $('#' + makeSelector(this.props.mailboxID, this.props.uid)).collapse('show')
    }
  },

  render: function () {
    this.url = this.props.mailboxID + '/' + this.props.uid
    return React.DOM.div({ className: 'panel panel-default' },
      React.DOM.div({ className: 'panel-heading' },
        React.DOM.div({ className: 'row' },
          React.DOM.h4({ className: 'col-md-4 panel-title' }, React.DOM.a(
            {
              'data-toggle': 'collapse',
              href: '#' + this.url,
              'data-target': '#' + makeSelector(this.props.mailboxID, this.props.uid),
            },
            this.props.subject
          )),
          React.DOM.div({ className: 'col-md-4' }, showContact(this.props.sender)),
          React.DOM.div({ className: 'col-md-4' }, this.props.date)
        )
      ),
      React.DOM.div(
        {
          id: this.url,
          className: 'panel-collapse collapse',
        },
        React.DOM.pre({ className: 'panel-body' }, this.props.contents[0])
      )
    )
  },
})


FM.PagerItem = createReact({
  displayName: 'PagerItem',
  handleClick: function () {
    return this.props.handleClick(this.props.target)
  },
  render: function () {
    var ref
    if (this.props.currentPage === this.props.target) {
      return React.DOM.li({ className: 'active' },
        React.DOM.span(null, this.props.text)
      )
    } else if ((0 < (ref = this.props.target) && ref <= this.props.total)) {
      return React.DOM.li({ onClick: this.handleClick },
        React.DOM.span(null, this.props.text)
      )
    } else {
      return React.DOM.li({ className: 'disabled' },
        React.DOM.span(null, this.props.text)
      )
    }
  },
})

FM.Pager = createReact({
  displayName: 'Pager',
  render: function () {
    var i, items, makePagerItem, next, previous, totalPages
    totalPages = Math.ceil(this.props.totalItems / 10)
    makePagerItem = (function (_this) {
      return function (target, text) {
        if (text == null) {
          text = target
        }
        return FM.PagerItem({
          key: target,
          currentPage: _this.props.currentPage,
          target: target,
          total: totalPages,
          handleClick: _this.props.handleClick,
          text: text,
        })
      }
    })(this)
    previous = makePagerItem(this.props.currentPage - 1, '«')
    next = makePagerItem(this.props.currentPage + 1, '»')
    items = (function () {
      var j, ref, results
      results = []
      for (i = j = 1, ref = totalPages; 1 <= ref ? j <= ref : j >= ref; i = 1 <= ref ? ++j : --j) {
        results.push(makePagerItem(i))
      }
      return results
    })()
    return React.DOM.ul({ className: 'pagination' }, previous, items, next)
  },
})

FM.Alert = createReact({
  displayName: 'Alert',
  render: function () {
    if (this.props.code && this.props.message) {
      return React.DOM.div({
        className: 'alert alert-danger',
        role: 'alert',
      }, React.DOM.strong(null, this.props.code), ': ', this.props.message)
    }
  },
})


// var relogin = function (data) {
//   ReactDOM.render(FM.Alert({
//     code: data.code,
//     message: data.message
//   }), document.getElementById('login-alert'))
//   return $('#login-modal').modal()
// }

var fetchMailboxes = function () {
  return FM.postJSON('/api/mailbox/list', getCredentials(), function (data) {
    FM.mailboxList.setState({ mailboxes: data })
  })
}

// var fetchMessages = function (mailbox, page, callback) {
//   return FM.postJSON('/api/message/list', {
//     lmrCredentials: {
//       cHost: FM.host,
//       cEmail: FM.email,
//       cPassword: FM.password
//     },
//     lmrMailbox: mailbox,
//     lmrPage: page
//   }, callback)
// }

var fetch = function () {
  fetchMailboxes()
}

$(window).on('hashchange', function () {
  return fetch()
})

$('#refresh-button').click(function () {
  return fetch()
})

$('#login-modal').on('shown.bs.modal', function () {
  return $('#login-host').focus()
})

$('#compose-button').click(function () {
  return $('#compose-modal').modal()
})

$('#compose-modal').on('shown.bs.modal', function () {
  return $('#compose-recipients').focus()
})

$('#login-modal').on('hide.bs.modal', function () {
  localStorage.setItem('host', $('#login-host').val())
  localStorage.setItem('email', $('#login-email').val())
  localStorage.setItem('password', $('#login-password').val())
  fetch()
})

$('#compose-submit').click(function () {
  var recipients = $('#compose-recipients').val()
  var subject = $('#compose-subject').val()
  var message = $('#compose-message').val()
  return FM.postJSON('/api/message/send', {
    smrBcc        : [],
    smrCc         : [],
    smrContents   : [message],
    smrCredentials: getCredentials(),
    smrSubject    : subject,
    smrTo         : [{ cAddress: recipients }],
  }, (function (data) {
  }))
})

FM.mailboxList = ReactDOM.render(FM.MailboxList(), document.getElementById('mailbox-list'))

if (
    localStorage.getItem('host')
 && localStorage.getItem('email')
 && localStorage.getItem('password')
) {
  fetch()
} else {
  $('#login-modal').modal()
}
