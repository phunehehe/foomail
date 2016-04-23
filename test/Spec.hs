import           Data.Text.Lazy          (pack)
import           Network.HaskellNet.IMAP (Attribute (Noselect))
import           Test.Hspec              (describe, hspec, it, shouldBe)

import           Helper


main :: IO ()
main = hspec $ do

    describe "Helper.filterMailboxes" $ do
        it "removes mailboxes marked as NoSelect" $ do
            let input =
                    [ ([], "normal")
                    , ([Noselect], "noselect")
                    ]
            filterMailboxes input `shouldBe` ["normal"]

    describe "Helper.Contact.readsprec" $ do

        let address = "example@example.com"

        it "omits the name if not supplied" $ do
            let contact = Contact Nothing $ pack address
            reads address `shouldBe` [(contact, "")]

        it "adds the name if supplied" $ do
            let
                name = "Example Com"
                input = name ++ " <" ++ address ++ ">"
                contact = Contact (Just $ pack name) (pack address)
            reads input `shouldBe` [(contact, "")]
