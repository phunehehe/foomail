{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}

import Control.Applicative
import Control.Monad.IO.Class
import Data.Aeson
import Data.Proxy
import Data.Text (Text)
import GHC.Generics
import Network.Wai.Handler.Warp (run)
import Servant

data Book = Book
  { title  :: Text
  , author :: Text
  } deriving Generic

-- JSON instances
instance FromJSON Book
instance ToJSON Book

             -- we explicitly say we expect a request body,
             -- of type Book
type BookApi = "books" :> ReqBody Book :> Post Book  -- POST /books
          :<|> "books" :> Get [Book]                 -- GET /books

server :: Server BookApi
server = postBook
    :<|> getBooks

  where -- the aforementioned 'ReqBody' automatically makes this handler
        -- receive a Book argument
        postBook book = liftIO $ do
            print "insert into books values (?, ?)"
            return $ Book "test" "test"
        getBooks      = liftIO $ print "select * from books" >> return [Book "test" "test"]

bookApi :: Proxy BookApi
bookApi = Proxy

main :: IO ()
main = do
  run 8080 (serve bookApi $ server)
