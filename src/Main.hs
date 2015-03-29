{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE DeriveGeneric   #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeOperators   #-}

import           Control.Monad.IO.Class        (liftIO)
import           Control.Monad.Trans.Either    (EitherT)
import           Data.Aeson                    (FromJSON, ToJSON)
import           Data.ByteString.Lazy          (toStrict)
import           Data.List                     (sort)
import           Data.Maybe                    (fromMaybe)
import qualified Data.Text.Lazy                as LT
import           Data.Text.Lazy.Encoding       (encodeUtf8)
import           GHC.Generics                  (Generic)
import           Network.HaskellNet.Auth       (AuthType (PLAIN))
import qualified Network.HaskellNet.IMAP       as I
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
          :<|> "api" :> "mailbox" :> "list" :> ReqBody H.Credentials :> Get [MailboxName]
          :<|> "api" :> "message" :> "send" :> ReqBody SendMessageRequest :> Post ()


data ListMessageRequest = ListMessageRequest { lmrCredentials :: H.Credentials
                                             , lmrMailbox     :: LT.Text
                                             , lmrPage        :: Int
                                             } deriving (Show, Generic)
instance ToJSON ListMessageRequest
instance FromJSON ListMessageRequest

data SendMessageRequest = SendMessageRequest { smrCredentials :: H.Credentials
                                             , smrCc          :: [H.Contact]
                                             , smrBcc         :: [H.Contact]
                                             , smrDate        :: Maybe LT.Text
                                             , smrSender      :: Maybe H.Contact
                                             , smrSubject     :: Maybe LT.Text
                                             , smrTo          :: [H.Contact]
                                             , smrContents    :: [LT.Text]
                                             } deriving (Show, Generic)
instance ToJSON SendMessageRequest
instance FromJSON SendMessageRequest


server :: Server MailApi
server = listMessages
    :<|> listMailboxes
    :<|> sendMessage

listMessages :: ListMessageRequest -> EitherT (Int, String) IO [H.Message]
listMessages _request@ListMessageRequest{..} = liftIO $ do
    connection <- H.imapConnect lmrCredentials
    I.select connection $ LT.unpack lmrMailbox
    uids <- I.search connection [I.ALLs]
    -- TODO: maybe just fetch metadata and leave the body for later
    mapM (H.fetchMessage connection) $ H.getPage uids lmrPage

listMailboxes :: H.Credentials -> EitherT (Int, String) IO [MailboxName]
listMailboxes credentials = liftIO $ do
    connection <- H.imapConnect credentials
    mailboxes <- I.list connection
    return $ sort $ map snd mailboxes

sendMessage :: SendMessageRequest -> EitherT (Int, String) IO ()
sendMessage _request@SendMessageRequest{..} = liftIO $ do
    -- TODO: handle authentication failure
    connection <- smtpConnect smrCredentials
    sendMail sender receivers mailContent connection
    where
        sender = maybe "" show smrSender
        receivers = map show $ smrTo ++ smrCc ++ smrBcc
        mailContent = toStrict $ encodeUtf8 $ LT.append subject body
        subject = fromMaybe LT.empty smrSubject
        -- TODO: support multi part
        body = head smrContents
        smtpConnect _credentials@H.Credentials{..} = do
            connection <- connectSMTPSTARTTLS cHost
            -- TODO: handle authentication failure
            _result <- sendCommand connection $ AUTH PLAIN cEmail cPassword
            return connection

mailApi :: Proxy MailApi
mailApi = Proxy

main :: IO ()
main = run 8080 (serve mailApi server)
