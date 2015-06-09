{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Helper where

import qualified Codec.MIME.Type                    as M
import qualified Data.ByteString.Lazy               as B
import qualified Data.Map                           as Map
import qualified Data.Text.Lazy                     as T
import qualified Network.HaskellNet.IMAP            as I

import           Codec.MIME.Parse                   (parseMIMEMessage)
import           Data.Aeson                         (FromJSON, ToJSON)
import           Data.IORef                         (IORef, readIORef,
                                                     writeIORef)
import           Data.List                          (find)
import           Data.Maybe                         (mapMaybe)
import           Data.Pool                          (Pool, createPool,
                                                     withResource)
import           Data.Text.Lazy.Encoding            (decodeUtf8)
import           GHC.Generics                       (Generic)
import           Network.HaskellNet.Auth            (Password, UserName)
import           Network.HaskellNet.IMAP.Connection (IMAPConnection)
import           Network.HaskellNet.IMAP.SSL        (connectIMAPSSL)
import           Network.HaskellNet.IMAP.Types      (UID)
import           Network.HaskellNet.IMAP.Types      (MailboxName)
import           Text.Printf                        (printf)
import           Text.Read                          (readMaybe)


data Contact = Contact { cName    :: Maybe T.Text
                       , cAddress :: T.Text
                       } deriving (Generic)
instance ToJSON Contact
instance FromJSON Contact
instance Show Contact where
    show (Contact Nothing address) = T.unpack address
    show (Contact (Just name) address) =
        printf "%s <%s>" (T.unpack name) $ T.unpack address
instance Read Contact where
    -- TODO: maybe add some more validation
    readsPrec _ string = case break (== '<') string of
        (_, []) -> [(Contact Nothing $ T.pack string, "")]
        (name, address) -> case break (== '>') address of
            (address', ">") -> [(Contact (Just $ T.pack name) $ T.pack address', "")]
            _ -> []

data Message = Message { mUid      :: Maybe UID
                       , mCc       :: [Contact]
                       , mBcc      :: [Contact]
                       , mDate     :: Maybe T.Text
                       , mSender   :: Maybe Contact
                       , mSubject  :: Maybe T.Text
                       , mTo       :: [Contact]
                       , mContents :: [T.Text]
                       } deriving (Show, Generic)
instance ToJSON Message
instance FromJSON Message

data Credentials = Credentials { cHost     :: String
                               , cEmail    :: UserName
                               , cPassword :: Password
                               } deriving (Show, Generic)
instance ToJSON Credentials
instance FromJSON Credentials


getConnection :: IORef (Map.Map String (Pool IMAPConnection)) -> Credentials -> IO (Pool IMAPConnection)
getConnection poolsRef credentials = do
    pools <- readIORef poolsRef
    maybe (makePool pools) return $ Map.lookup key pools
    where
        makePool pools = do
            pool <- createPool (imapLogin credentials) I.logout 1 1000 10
            writeIORef poolsRef $ Map.insert key pool pools
            return pool
        key = "imap" ++ show credentials

doImap :: IORef (Map.Map String (Pool IMAPConnection)) -> Credentials -> (IMAPConnection -> IO a) -> IO a
doImap poolsRef credentials f = do
    pool <- getConnection poolsRef credentials
    withResource pool f

imapLogin :: Credentials -> IO IMAPConnection
imapLogin _c@Credentials{..} = do
    connection <- connectIMAPSSL cHost
    I.login connection cEmail cPassword
    -- TODO: handle authentication failure
    return connection

getPage :: [a] -> Int -> [a]
getPage items pageNumber = take messagesPerPage $ drop before items
    where before = messagesPerPage * (pageNumber - 1)

mimeContents :: M.MIMEValue -> [T.Text]
mimeContents message =
    case M.mime_val_content message of
        M.Single content -> [T.fromStrict content]
        M.Multi subValues -> concatMap mimeContents subValues

parseContacts :: Maybe T.Text -> [Contact]
parseContacts = maybe [] (mapMaybe (parseContact . Just) . T.splitOn ",")

headerValue :: [M.MIMEParam] -> T.Text -> Maybe T.Text
headerValue headers headerName = fmap (T.fromStrict . M.paramValue) header
    where header = find (\h -> M.paramName h == T.toStrict headerName) headers

parseContact :: Maybe T.Text -> Maybe Contact
parseContact = maybe Nothing $ readMaybe . T.unpack

parseMessage :: UID -> T.Text -> Message
parseMessage uid message = Message { mUid = Just uid
                                   , mCc = parseContacts $ headerValue headers "cc"
                                   , mBcc = parseContacts $ headerValue headers "bcc"
                                   , mDate = headerValue headers "date"
                                   , mSender = parseContact $ headerValue headers "from"
                                   , mSubject = headerValue headers "subject"
                                   , mTo = parseContacts $ headerValue headers "to"
                                   , mContents = mimeContents mimeValue
                                   }
    where
        mimeValue = parseMIMEMessage $ T.toStrict message
        headers = M.mime_val_headers mimeValue

fetchMessage :: IMAPConnection -> UID -> IO Message
fetchMessage connection uid = do
    message <- I.fetch connection uid
    return $ parseMessage uid $ decodeUtf8 $ B.fromStrict message

messagesPerPage :: Int
messagesPerPage = 10

filterMailboxes :: [([I.Attribute], MailboxName)] -> [MailboxName]
filterMailboxes = map snd . filter (notElem I.Noselect . fst)
