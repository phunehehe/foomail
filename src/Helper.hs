{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Helper where

import           Codec.MIME.Parse                   (parseMIMEMessage)
import qualified Codec.MIME.Type                    as CT
import           Data.Aeson                         (FromJSON, ToJSON)
import qualified Data.ByteString.Lazy               as LB
import           Data.List                          (find)
import           Data.Maybe                         (mapMaybe)
import qualified Data.Text.Lazy                     as LT
import           Data.Text.Lazy.Encoding            (decodeUtf8)
import           GHC.Generics                       (Generic)
import           Network.HaskellNet.Auth            (Password, UserName)
import qualified Network.HaskellNet.IMAP            as I
import           Network.HaskellNet.IMAP.Connection (IMAPConnection)
import           Network.HaskellNet.IMAP.SSL        (connectIMAPSSL)
import           Network.HaskellNet.IMAP.Types      (UID)
import           Text.Printf                        (printf)
import           Text.Read                          (readMaybe)


data Contact = Contact { cName    :: Maybe LT.Text
                       , cAddress :: LT.Text
                       } deriving (Generic)
instance ToJSON Contact
instance FromJSON Contact
instance Show Contact where
    show (Contact Nothing address) = LT.unpack address
    show (Contact (Just name) address) =
        printf "%s <%s>" (LT.unpack name) $ LT.unpack address
instance Read Contact where
    -- TODO: maybe add some more validation
    readsPrec _ string = case break (== '<') string of
        (_, []) -> [(Contact Nothing $ LT.pack string, "")]
        (name, address) -> case break (== '>') address of
            (address', ">") -> [(Contact (Just $ LT.pack name) $ LT.pack address', "")]
            _ -> []

data Message = Message { mUid      :: Maybe UID
                       , mCc       :: [Contact]
                       , mBcc      :: [Contact]
                       , mDate     :: Maybe LT.Text
                       , mSender   :: Maybe Contact
                       , mSubject  :: Maybe LT.Text
                       , mTo       :: [Contact]
                       , mContents :: [LT.Text]
                       } deriving (Show, Generic)
instance ToJSON Message
instance FromJSON Message

data Credentials = Credentials { cHost     :: String
                               , cEmail    :: UserName
                               , cPassword :: Password
                               } deriving (Show, Generic)
instance ToJSON Credentials
instance FromJSON Credentials


imapConnect :: Credentials -> IO IMAPConnection
imapConnect _credentials@Credentials{..} = do
    connection <- connectIMAPSSL cHost
    I.login connection cEmail cPassword
    -- TODO: handle authentication failure
    return connection

getPage :: [a] -> Int -> [a]
getPage items pageNumber = take messagesPerPage $ drop before items
    where before = messagesPerPage * (pageNumber - 1)

mimeContents :: CT.MIMEValue -> [LT.Text]
mimeContents message =
    case CT.mime_val_content message of
        CT.Single content -> [LT.fromStrict content]
        CT.Multi subValues -> concatMap mimeContents subValues

parseContacts :: Maybe LT.Text -> [Contact]
parseContacts = maybe [] (mapMaybe (parseContact . Just) . LT.splitOn ",")

headerValue :: [CT.MIMEParam] -> LT.Text -> Maybe LT.Text
headerValue headers headerName = fmap (LT.fromStrict . CT.paramValue) header
    where header = find (\h -> CT.paramName h == LT.toStrict headerName) headers

parseContact :: Maybe LT.Text -> Maybe Contact
parseContact = maybe Nothing $ readMaybe . LT.unpack

parseMessage :: UID -> LT.Text -> Message
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
        mimeValue = parseMIMEMessage $ LT.toStrict message
        headers = CT.mime_val_headers mimeValue

fetchMessage :: IMAPConnection -> UID -> IO Message
fetchMessage connection uid = do
    message <- I.fetch connection uid
    return $ parseMessage uid $ decodeUtf8 $ LB.fromStrict message

messagesPerPage :: Int
messagesPerPage = 10

-- See https://github.com/jtdaugherty/HaskellNet/issues/34
readMailboxName :: String -> String
readMailboxName string | head string == '"' = read string
                       | otherwise          = string
