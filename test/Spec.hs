import qualified Network.HaskellNet.IMAP as I

import qualified Helper                  as H

import           Test.Hspec              (describe, hspec, it, shouldBe)

main :: IO ()
main = hspec $ do
    describe "Helper.filterMailboxes" $ do
        it "removes mailboxes marked as NoSelect" $ do
            let
                input =
                    [ ([], "normal")
                    , ([I.Noselect], "noselect")
                    ]
            H.filterMailboxes input `shouldBe` ["normal"]
