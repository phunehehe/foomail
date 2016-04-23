{-# LANGUAGE PackageImports  #-}
{-# LANGUAGE TemplateHaskell #-}

-- https://github.com/ndmitchell/hlint/blob/master/data/HLint.hs

module HLint.HLint where

import           "hint" HLint.Builtin.All
import           "hint" HLint.Default
import           "hint" HLint.Generalise

ignore "Use mappend"

ignore "Redundant do" = Main.main
