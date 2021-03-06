{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TypeOperators     #-}

import qualified Data.Map                           as M
import qualified Data.Text.Lazy                     as T
import qualified Network.HaskellNet.IMAP            as I
import qualified Network.HaskellNet.SMTP            as SMTP
import qualified Servant                            as S

import qualified Helper                             as H

import           Control.Monad.IO.Class             (liftIO)
import           Data.Aeson                         (FromJSON, ToJSON)
import           Data.ByteString.Lazy               (toStrict)
import           Data.IORef                         (IORef, newIORef)
import           Data.Maybe                         (fromMaybe)
import           Data.Pool                          (Pool)
import           Data.Text.Lazy.Encoding            (encodeUtf8)
import           GHC.Generics                       (Generic)
import           Network.HaskellNet.Auth            (AuthType (PLAIN))
import           Network.HaskellNet.IMAP.Connection (IMAPConnection)
import           Network.HaskellNet.IMAP.Types      (MailboxName)
import           Network.HaskellNet.SMTP.SSL        (connectSMTPSTARTTLS)
import           Network.Wai.Handler.Warp           (run)
import           Servant                            ((:<|>) (..), (:>), Handler,
                                                     JSON, Post, ReqBody)


data CountMessageRequest = CountMessageRequest { cmrCredentials :: H.Credentials
                                               , cmrMailbox     :: T.Text
                                               } deriving (Show, Generic)
instance ToJSON CountMessageRequest
instance FromJSON CountMessageRequest

data ListMessageRequest = ListMessageRequest { lmrCredentials :: H.Credentials
                                             , lmrMailbox     :: T.Text
                                             , lmrPage        :: Int
                                             } deriving (Show, Generic)
instance ToJSON ListMessageRequest
instance FromJSON ListMessageRequest

data SendMessageRequest = SendMessageRequest
  { smrCredentials :: H.Credentials
  , smrCc          :: [H.Contact]
  , smrBcc         :: [H.Contact]
  , smrDate        :: Maybe T.Text
  , smrSender      :: Maybe H.Contact
  , smrSubject     :: Maybe T.Text
  , smrTo          :: [H.Contact]
  , smrContents    :: [T.Text]
  } deriving (Show, Generic)
instance ToJSON SendMessageRequest
instance FromJSON SendMessageRequest

type MailApi =
      "api" :> "mailbox" :> "list"  :> ReqBody '[JSON] H.Credentials :> Post '[JSON] [MailboxName]
 :<|> "api" :> "message" :> "count" :> ReqBody '[JSON] CountMessageRequest :> Post '[JSON] Int
 :<|> "api" :> "message" :> "list"  :> ReqBody '[JSON] ListMessageRequest :> Post '[JSON] [H.Message]
 :<|> "api" :> "message" :> "send"  :> ReqBody '[JSON] SendMessageRequest :> Post '[JSON] ()
 :<|> S.Raw


server :: IORef (M.Map String (Pool IMAPConnection)) -> S.Server MailApi
server poolsRef =
      listMailboxes poolsRef
 :<|> countMessages poolsRef
 :<|> listMessages poolsRef
 :<|> sendMessage
 :<|> S.serveDirectory "./static"

listMailboxes :: IORef (M.Map String (Pool IMAPConnection)) -> H.Credentials -> Handler [MailboxName]
--listMailboxes _ _ = liftIO $ return ["First Mailbox", "Second Mailbox", "Third Mailbox"]
listMailboxes poolsRef credentials = liftIO $ H.doImap poolsRef credentials getMailboxes
    where
        getMailboxes connection = do
            mailboxes <- I.list connection
            return $ H.filterMailboxes mailboxes

countMessages :: IORef (M.Map String (Pool IMAPConnection)) -> CountMessageRequest -> Handler Int
--countMessages _ _ = liftIO $ return 42
countMessages poolsRef _r@CountMessageRequest{..} = liftIO $ H.doImap poolsRef cmrCredentials getCount
    where
        getCount connection = do
            I.select connection $ T.unpack cmrMailbox
            uids <- I.search connection [I.ALLs]
            return $ length uids

listMessages :: IORef (M.Map String (Pool IMAPConnection)) -> ListMessageRequest -> Handler [H.Message]
--listMessages _ _ = liftIO $ return
--    [ H.Message
--        { H.mUid = Nothing
--        , H.mCc = []
--        , H.mBcc = []
--        , H.mDate = Just "some date"
--        , H.mSender = Just H.Contact
--            { H.cName = Nothing
--            , H.cAddress = "some address"
--            }
--        , H.mSubject = Just "some subject"
--        , H.mTo = []
--        , H.mContents = ["some content"]
--        }
--    ]
listMessages poolsRef _r@ListMessageRequest{..} = liftIO $ H.doImap poolsRef lmrCredentials getMessages
    where
        getMessages connection = do
            I.select connection $ T.unpack lmrMailbox
            uids <- I.search connection [I.ALLs]
            -- TODO: maybe just fetch metadata and leave the body for later
            mapM (H.fetchMessage connection) $ H.getPage (reverse uids) lmrPage

sendMessage :: SendMessageRequest -> Handler ()
sendMessage _r@SendMessageRequest{..} = liftIO $ do
    connection <- smtpConnect smrCredentials
    SMTP.sendMail sender receivers mailContent connection
    where
        sender = maybe "" show smrSender
        receivers = show <$> smrTo ++ smrCc ++ smrBcc
        mailContent = toStrict $ encodeUtf8 $ T.append subject body
        subject = fromMaybe T.empty smrSubject
        -- TODO: support multi part
        body = head smrContents
        smtpConnect _c@H.Credentials{..} = do
            connection <- connectSMTPSTARTTLS cHost
            -- TODO: handle authentication failure
            _r <- SMTP.sendCommand connection $ SMTP.AUTH PLAIN cEmail cPassword
            return connection

mailApi :: S.Proxy MailApi
mailApi = S.Proxy

main :: IO ()
main = do
    poolsRef <- newIORef M.empty
    run 8080 (S.serve mailApi $ server poolsRef)
