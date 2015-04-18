{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE DeriveGeneric   #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeOperators   #-}

import qualified Data.Map                           as M
import qualified Data.Text.Lazy                     as T
import qualified Network.HaskellNet.IMAP            as I
import qualified Network.HaskellNet.SMTP            as SMTP
import qualified Servant                            as S

import qualified Helper                             as H

import           Control.Monad.IO.Class             (liftIO)
import           Control.Monad.Trans.Either         (EitherT)
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
import           Servant                            ((:<|>) (..), (:>))


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

data SendMessageRequest = SendMessageRequest { smrCredentials :: H.Credentials
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
      "api" :> "mailbox" :> "list"  :> S.ReqBody H.Credentials :> S.Post [MailboxName]
 :<|> "api" :> "message" :> "count" :> S.ReqBody CountMessageRequest :> S.Post Int
 :<|> "api" :> "message" :> "list"  :> S.ReqBody ListMessageRequest :> S.Post [H.Message]
 :<|> "api" :> "message" :> "send"  :> S.ReqBody SendMessageRequest :> S.Post ()
 :<|> S.Raw


server :: IORef (M.Map String (Pool IMAPConnection)) -> S.Server MailApi
server poolsRef =
      listMailboxes poolsRef
 :<|> countMessages poolsRef
 :<|> listMessages poolsRef
 :<|> sendMessage
 :<|> S.serveDirectory "./static"

listMailboxes :: IORef (M.Map String (Pool IMAPConnection)) -> H.Credentials -> EitherT (Int, String) IO [MailboxName]
listMailboxes poolsRef credentials = liftIO $ H.doImap poolsRef credentials getMailboxes
    where
        getMailboxes connection = do
            mailboxes <- I.list connection
            return $ map snd mailboxes

countMessages :: IORef (M.Map String (Pool IMAPConnection)) -> CountMessageRequest -> EitherT (Int, String) IO Int
countMessages poolsRef _request@CountMessageRequest{..} = liftIO $ H.doImap poolsRef cmrCredentials getCount
    where
        getCount connection = do
            I.select connection $ T.unpack cmrMailbox
            uids <- I.search connection [I.ALLs]
            return $ length uids

listMessages :: IORef (M.Map String (Pool IMAPConnection)) -> ListMessageRequest -> EitherT (Int, String) IO [H.Message]
listMessages poolsRef _request@ListMessageRequest{..} = liftIO $ H.doImap poolsRef lmrCredentials getMessages
    where
        getMessages connection = do
            I.select connection $ T.unpack lmrMailbox
            uids <- I.search connection [I.ALLs]
            -- TODO: maybe just fetch metadata and leave the body for later
            mapM (H.fetchMessage connection) $ H.getPage uids lmrPage

sendMessage :: SendMessageRequest -> EitherT (Int, String) IO ()
sendMessage _request@SendMessageRequest{..} = liftIO $ do
    -- TODO: handle authentication failure
    connection <- smtpConnect smrCredentials
    SMTP.sendMail sender receivers mailContent connection
    where
        sender = maybe "" show smrSender
        receivers = map show $ smrTo ++ smrCc ++ smrBcc
        mailContent = toStrict $ encodeUtf8 $ T.append subject body
        subject = fromMaybe T.empty smrSubject
        -- TODO: support multi part
        body = head smrContents
        smtpConnect _credentials@H.Credentials{..} = do
            connection <- connectSMTPSTARTTLS cHost
            -- TODO: handle authentication failure
            _result <- SMTP.sendCommand connection $ SMTP.AUTH PLAIN cEmail cPassword
            return connection

mailApi :: S.Proxy MailApi
mailApi = S.Proxy

main :: IO ()
main = do
    poolsRef <- newIORef M.empty
    run 8080 (S.serve mailApi $ server poolsRef)
