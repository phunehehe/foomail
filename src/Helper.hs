{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Helper where

import Text.Printf (printf)

import Data.Aeson
import GHC.Generics
import qualified Data.Text.Lazy as LT
import Network.HaskellNet.IMAP.Types (UID)
import Data.Maybe (mapMaybe)
import Data.List (find, sort)
import Codec.MIME.Parse (parseMIMEMessage)
import Network.HaskellNet.IMAP.Connection (IMAPConnection)
import qualified Network.HaskellNet.IMAP as I
import Data.Text.Lazy.Encoding (decodeUtf8, encodeUtf8)
import qualified Data.ByteString.Lazy as LB
import qualified Codec.MIME.Type as CT


data Contact = Contact { contact_name :: Maybe LT.Text
                       , contact_address :: LT.Text
                       } deriving (Generic)
instance ToJSON Contact
instance FromJSON Contact
instance Show Contact where
    show (Contact Nothing address) = LT.unpack $ address
    show (Contact (Just name) address) =
        printf "%s <%s>" (LT.unpack $ name) (LT.unpack $ address)

data Credential = Credential { email :: LT.Text
                             , password :: LT.Text
                             } deriving (Show, Generic)
instance ToJSON Credential
instance FromJSON Credential

data Message = Message { uid :: Maybe UID
                       , message_cc :: [Contact]
                       , message_bcc :: [Contact]
                       , date :: Maybe LT.Text
                       , message_sender :: Maybe Contact
                       , message_subject :: Maybe LT.Text
                       , message_to :: [Contact]
                       , message_contents :: [LT.Text]
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
    uid = Just _uid,
    message_cc = cc,
    message_bcc = bcc,
    date = _date,
    message_sender = _sender,
    message_subject = _subject,
    message_to = _to,
    message_contents = _contents
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

messagesPerPage = 10 :: Int
