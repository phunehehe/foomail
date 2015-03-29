{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PolyKinds           #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}

import           Control.Monad.IO.Class        (liftIO)
import           Control.Monad.Trans.Either    (EitherT)
import           Data.Aeson                    (FromJSON, ToJSON)
import qualified Data.ByteString.Lazy          as LB
import           Data.List                     (sort)
import           Data.Maybe                    (fromMaybe)
import qualified Data.Text.Lazy                as LT
import           Data.Text.Lazy.Encoding       (encodeUtf8)
import           GHC.Generics                  (Generic)
import           Network.HaskellNet.Auth       (AuthType (PLAIN), Password,
                                                UserName)
import qualified Network.HaskellNet.IMAP       as I
import           Network.HaskellNet.IMAP.SSL   (connectIMAPSSL)
import           Network.HaskellNet.IMAP.Types (MailboxName)
import           Network.HaskellNet.SMTP       (Command (AUTH), sendCommand,
                                                sendMail)
import           Network.HaskellNet.SMTP.SSL   (connectSMTPSTARTTLS)
import           Network.Wai.Handler.Warp      (run)
import           Servant                       ((:<|>) (..), (:>), Get, Post,
                                                Proxy (..), ReqBody, Server,
                                                serve)

import qualified Helper                        as H


type MailApi = "api" :> "message" :> "list" :> ReqBody ListMessageRequest :> Get [H.Message]
          :<|> "api" :> "mailbox" :> "list" :> ReqBody ListMailboxRequest :> Get [MailboxName]
          :<|> "api" :> "message" :> "send" :> ReqBody SendMessageRequest :> Post ()


data ListMessageRequest = ListMessageRequest { lmrEmail    :: UserName
                                             , lmrPassword :: Password
                                             , lmrMailbox  :: LT.Text
                                             , lmrPage     :: Int
                                             } deriving (Show, Generic)
instance ToJSON ListMessageRequest
instance FromJSON ListMessageRequest

data ListMailboxRequest = ListMailboxRequest { lbrEmail    :: UserName
                                             , lbrPassword :: Password
                                             } deriving (Show, Generic)
instance ToJSON ListMailboxRequest
instance FromJSON ListMailboxRequest

data SendMessageRequest = SendMessageRequest { smrEmail    :: UserName
                                             , smrPassword :: Password
                                             , smrCc       :: [H.Contact]
                                             , smrBcc      :: [H.Contact]
                                             , smrDate     :: Maybe LT.Text
                                             , smrSender   :: Maybe H.Contact
                                             , smrSubject  :: Maybe LT.Text
                                             , smrTo       :: [H.Contact]
                                             , smrContents :: [LT.Text]
                                             } deriving (Show, Generic)
instance ToJSON SendMessageRequest
instance FromJSON SendMessageRequest

server :: Server MailApi
server = listMessages
    :<|> listMailboxes
    :<|> sendMessage

sendMessage :: SendMessageRequest -> EitherT (Int, String) IO ()
sendMessage _request@SendMessageRequest{..} = liftIO $ do
    -- TODO: put this in some config file
    connection <- liftIO $ connectSMTPSTARTTLS "localhost"
    -- TODO: handle authentication failure
    _result <- liftIO $ sendCommand connection $ AUTH PLAIN smrEmail smrPassword
    sendMail sender receivers mailContent connection
    where
        sender = case smrSender of
            Nothing -> ""
            Just contact -> show contact
        receivers = map show $ smrTo ++ smrCc ++ smrBcc
        mailContent = LB.toStrict $ encodeUtf8 $ LT.append subject body
        subject = fromMaybe LT.empty smrSubject
        -- TODO: support multi part
        body = head smrContents

listMailboxes :: ListMailboxRequest -> EitherT (Int, String) IO [MailboxName]
listMailboxes _request@ListMailboxRequest{..} = liftIO $ do
    connection <- connectIMAPSSL "localhost"
    I.login connection lbrEmail lbrPassword
    mailboxes <- I.list connection
    return $ sort $ map snd mailboxes

listMessages :: ListMessageRequest -> EitherT (Int, String) IO [H.Message]
listMessages _request@ListMessageRequest{..} = liftIO $ do
    connection <- connectIMAPSSL "localhost"
    I.login connection lmrEmail lmrPassword
    I.select connection $ LT.unpack lmrMailbox
    uids <- I.search connection [I.ALLs]
    -- TODO: maybe just fetch metadata and leave the body for later
    mapM (H.fetchMessage connection) $ H.getPage uids H.messagesPerPage lmrPage

mailApi :: Proxy MailApi
mailApi = Proxy

main :: IO ()
main = run 8080 (serve mailApi server)
