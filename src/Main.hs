{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PolyKinds           #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}

import           Codec.MIME.Parse                   (parseMIMEMessage)
import qualified Codec.MIME.Type                    as CT
import qualified Data.ByteString.Lazy               as LB
import           Data.List                          (find, sort)
import           Data.Maybe                         (mapMaybe)
import qualified Data.Text.Lazy                     as LT
import           Data.Text.Lazy.Encoding            (decodeUtf8, encodeUtf8)
import           Network.HaskellNet.Auth            (Password, UserName)
import           Network.HaskellNet.Auth            (AuthType (PLAIN))
import qualified Network.HaskellNet.IMAP            as I
import           Network.HaskellNet.IMAP.Connection (IMAPConnection)
import           Network.HaskellNet.IMAP.SSL        (connectIMAPSSL)
import           Network.HaskellNet.IMAP.Types      (MailboxName, UID)
import           Network.HaskellNet.SMTP            (Command (AUTH),
                                                     sendCommand)
import           Network.HaskellNet.SMTP            (SMTPConnection, sendMail)
import           Network.HaskellNet.SMTP.SSL        (connectSMTPSTARTTLS)
import           Text.Printf                        (printf)

import           Control.Applicative
import           Control.Monad.IO.Class
import           Control.Monad.Trans.Either
import           Data.Aeson
import           Data.Proxy
import           GHC.Generics
import           Network.Wai.Handler.Warp           (run)
import           Servant

import           Helper


type MailApi = "api" :> "message" :> "list" :> ReqBody ListMessageRequest :> Get [Message]
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
                                             , smrCc       :: [Contact]
                                             , smrBcc      :: [Contact]
                                             , smrDate     :: Maybe LT.Text
                                             , smrSender   :: Maybe Contact
                                             , smrSubject  :: Maybe LT.Text
                                             , smrTo       :: [Contact]
                                             , smrContents :: [LT.Text]
                                             } deriving (Show, Generic)
instance ToJSON SendMessageRequest
instance FromJSON SendMessageRequest

server :: Server MailApi
server = listMessages
    :<|> listMailboxes
    :<|> sendMessage

sendMessage :: SendMessageRequest -> EitherT (Int, String) IO ()
sendMessage request@SendMessageRequest{..} = liftIO $ do
    -- TODO: put this in some config file
    connection <- liftIO $ connectSMTPSTARTTLS "localhost"
    liftIO $ sendCommand connection $ AUTH PLAIN smrEmail smrPassword
    sendMail sender receivers mailContent connection
    where
        sender = case smrSender of
            Nothing -> ""
            Just contact -> show contact
        receivers = map show $ smrTo ++ smrCc ++ smrBcc
        mailContent = LB.toStrict $ encodeUtf8 $ LT.append subject body
        subject = case smrSubject of
            Nothing -> LT.empty
            Just text -> text
        -- TODO: support multi part
        body = head $ smrContents

listMailboxes :: ListMailboxRequest -> EitherT (Int, String) IO [MailboxName]
listMailboxes request@ListMailboxRequest{..} = liftIO $ do
    connection <- connectIMAPSSL "localhost"
    I.login connection lbrEmail lbrPassword
    mailboxes <- I.list connection
    return $ sort $ map snd mailboxes

listMessages :: ListMessageRequest -> EitherT (Int, String) IO [Message]
listMessages request@ListMessageRequest{..} = liftIO $ do
    connection <- connectIMAPSSL "localhost"
    I.login connection lmrEmail lmrPassword
    I.select connection $ LT.unpack lmrMailbox
    uids <- I.search connection [I.ALLs]
    -- TODO: maybe just fetch metadata and leave the body for later
    messages <- mapM (fetchMessage connection) $ getPage uids messagesPerPage lmrPage
    return messages

mailApi :: Proxy MailApi
mailApi = Proxy

main :: IO ()
main = do
    run 8080 (serve mailApi $ server)
