{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

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
import qualified Network.HaskellNet.IMAP            as I
import           Network.HaskellNet.IMAP.Connection (IMAPConnection)
import           Network.HaskellNet.IMAP.Types      (UID)
import           Text.Printf                        (printf)


data Contact = Contact { cName    :: Maybe LT.Text
                       , cAddress :: LT.Text
                       } deriving (Generic)
instance ToJSON Contact
instance FromJSON Contact
instance Show Contact where
    show (Contact Nothing address) = LT.unpack address
    show (Contact (Just name) address) =
        printf "%s <%s>" (LT.unpack name) $ LT.unpack address

data Credential = Credential { email    :: LT.Text
                             , password :: LT.Text
                             } deriving (Show, Generic)
instance ToJSON Credential
instance FromJSON Credential

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


-- Because converting to Float and then using ceiling feels weird
pages :: Integral a => a -> a -> a
pages size total = case divMod total size of
    (p, 0) -> p
    (p, _) -> p + 1

getPage :: [a] -> Int -> Int -> [a]
getPage items pageSize pageNumber = take pageSize $ drop before items
    where before = pageSize * (pageNumber -1)

mimeContents :: CT.MIMEValue -> [LT.Text]
mimeContents message =
    case CT.mime_val_content message of
        CT.Single content -> [LT.fromStrict content]
        CT.Multi subValues -> concatMap mimeContents subValues

parseContacts :: Maybe LT.Text -> [Contact]
parseContacts Nothing = []
parseContacts (Just header) = mapMaybe (parseContact . Just) $ LT.splitOn "," header

headerValue :: [CT.MIMEParam] -> LT.Text -> Maybe LT.Text
headerValue headers headerName =
    case find (\h -> CT.paramName h == LT.toStrict headerName) headers of
        Nothing -> Nothing
        Just header -> Just $ LT.fromStrict $ CT.paramValue header

parseContact :: Maybe LT.Text -> Maybe Contact
parseContact Nothing = Nothing
parseContact (Just header) = Just $ Contact name address
    where
        -- TODO: maybe add some validation
        parts = LT.words header
        address = last parts
        -- TODO: omit name when not given
        name = Just $ LT.unwords $ init parts

parseMessage :: UID -> LT.Text -> Message
parseMessage _uid message = Message {
    mUid = Just _uid,
    mCc = cc,
    mBcc = bcc,
    mDate = _date,
    mSender = _sender,
    mSubject = _subject,
    mTo = _to,
    mContents = _contents
}
    where
        mimeValue = parseMIMEMessage $ LT.toStrict message
        headers = CT.mime_val_headers mimeValue
        cc = parseContacts $ headerValue headers "cc"
        bcc = parseContacts $ headerValue headers "bcc"
        _date = headerValue headers "date"
        _sender = parseContact $ headerValue headers "from"
        _subject = headerValue headers "subject"
        _to = parseContacts $ headerValue headers "to"
        _contents = mimeContents mimeValue


fetchMessage :: IMAPConnection -> UID -> IO Message
fetchMessage connection uid = do
    message <- I.fetch connection uid
    return $ parseMessage uid $ decodeUtf8 $ LB.fromStrict message

messagesPerPage  :: Int
messagesPerPage = 10
