-- Copyright (c) 2016-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


{-# LANGUAGE NoRebindableSyntax #-}
{-# LANGUAGE RecordWildCards #-}

module Duckling.Ranking.Generate
  ( 
   regenAllClassifiers
   
  , regenClassifiers
  ) where

import qualified Data.HashMap.Strict as HashMap
import qualified Data.HashSet as HashSet
import qualified Data.Text as Text
import Prelude
import Language.Haskell.Exts as F

import Duckling.Dimensions.Types
import Duckling.Lang
import Duckling.Ranking.Train
import Duckling.Ranking.Types
import Duckling.Rules
import Duckling.Testing.Types

import qualified Duckling.Time.EN.Corpus as ENTime
 
import qualified Duckling.Time.DA.Corpus as DATime
import qualified Duckling.Time.DE.Corpus as DETime
import qualified Duckling.Time.ES.Corpus as ESTime
import qualified Duckling.Time.FR.Corpus as FRTime
import qualified Duckling.Time.GA.Corpus as GATime
import qualified Duckling.Time.HR.Corpus as HRTime
import qualified Duckling.Time.HE.Corpus as HETime
import qualified Duckling.Time.HU.Corpus as HUTime
import qualified Duckling.Time.IT.Corpus as ITTime
import qualified Duckling.Time.KO.Corpus as KOTime
import qualified Duckling.Time.NB.Corpus as NBTime
import qualified Duckling.Time.PL.Corpus as PLTime
import qualified Duckling.Time.PT.Corpus as PTTime
import qualified Duckling.Time.RO.Corpus as ROTime
import qualified Duckling.Time.SV.Corpus as SVTime
import qualified Duckling.Time.VI.Corpus as VITime
import qualified Duckling.Time.ZH.Corpus as ZHTime



-- -----------------------------------------------------------------
-- Main

regenAllClassifiers :: IO ()
regenAllClassifiers = mapM_ regenClassifiers [EN]
-- regenAllClassifiers = mapM_ regenClassifiers [minBound .. maxBound] 

-- | Run this function to overwrite the file with Classifiers data
regenClassifiers :: Lang -> IO ()
regenClassifiers lang = do
  putStrLn $ "Regenerating " ++ filepath ++ "..."
  writeFile filepath $
    (headerComment ++) $
    prettyPrintWithMode baseMode $ (noLoc <$) m
  putStrLn "Done!"
  where
    filepath = "Duckling/Ranking/Classifiers/" ++ show lang ++ ".hs"

    rules = rulesFor lang . HashSet.singleton $ This Time

    -- | The trained classifier to write out
    classifiers = makeClassifiers rules trainSet

    -- | The training set (corpus)
    trainSet = case lang of
      AR -> (testContext, [])
      BG -> (testContext, [])
      CS -> (testContext, [])
      DA -> DATime.corpus
      DE -> DETime.corpus
      EN -> ENTime.corpus
      {-|
      ES -> ESTime.corpus
      ET -> (testContext, [])
      FR -> FRTime.corpus
      GA -> GATime.corpus
      HR -> HRTime.corpus
      HE -> HETime.corpus
      HU -> HUTime.corpus
      ID -> (testContext, [])
      IT -> ITTime.corpus
      JA -> (testContext, [])
      KA -> (testContext, [])
      KO -> KOTime.corpus
      MY -> (testContext, [])
      NB -> NBTime.corpus
      NL -> (testContext, [])
      PL -> PLTime.corpus
      PT -> PTTime.corpus
      RO -> ROTime.corpus
      RU -> (testContext, [])
      SV -> SVTime.corpus
      TR -> (testContext, [])
      UK -> (testContext, [])
      VI -> VITime.corpus
      ZH -> ZHTime.corpus
      -}

    -- Data structure for the module
    m = Module () (Just header) pragmas imports decls

    -- Declares the top level options pragma
    pragmas = [ LanguagePragma () [Ident () "OverloadedStrings"] ]

    -- Declares the header for the module
    -- "module Duckling.Ranking.Classifiers (classifiers) where"
    header = ModuleHead ()
      (ModuleName () $ "Duckling.Ranking.Classifiers." ++ show lang)
      Nothing $
      Just $ ExportSpecList ()
       [ EVar () (unQual "classifiers")
       ]

    -- All imports the file will need
    imports =
      [ genImportModule "Prelude"
      , genImportModule "Duckling.Ranking.Types"
      , (genImportModule "Data.HashMap.Strict")
        { importQualified = True
        , importAs = Just (ModuleName () "HashMap")
        }
      , genImportModule "Data.String"
      ]

    -- The code body
    decls =
      [ -- Type Signature
        TypeSig () [Ident () "classifiers"] (TyCon () (unQual "Classifiers"))
        -- function body
      , FunBind ()
          [ Match () (Ident () "classifiers") []
              (UnGuardedRhs () (genList classifiers)) Nothing
          ]
      ]

    headerComment :: String
    headerComment = "\
\-- Copyright (c) 2016-present, Facebook, Inc.\n\
\-- All rights reserved.\n\
\--\n\
\-- This source code is licensed under the BSD-style license found in the\n\
\-- LICENSE file in the root directory of this source tree. An additional grant\n\
\-- of patent rights can be found in the PATENTS file in the same directory.\n\n\
\-----------------------------------------------------------------\n\
\-- Auto-generated by regenClassifiers\n\
\--\n\
\-- DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING\n\
\--  @" ++ "generated\n\
\-----------------------------------------------------------------\n"

-- -----------------------------------------------------------------
-- Source generators

-- | Generates a line for an import
--
-- `genImportModule "Foo.Bar"` spits out:
-- "import Foo.Bar" in the code
genImportModule :: String -> ImportDecl ()
genImportModule name = ImportDecl
  { importAnn = ()
  , importModule = ModuleName () name
  , importQualified = False
  , importSrc = False
  , importSafe = False
  , importPkg = Nothing
  , importAs = Nothing
  , importSpecs = Nothing
  }

-- | Creates the expression to build the HashMap object
genList :: Classifiers -> Exp ()
genList cs = appFromList $ map genClassifier $ HashMap.toList cs
  where
    -- "fromList ..."
    appFromList exprs = App ()
      (Var () (Qual () (ModuleName () "HashMap") (Ident () "fromList")))
      (List () exprs)

    -- ("name", Classifier { okData ....
    genClassifier (name, Classifier{..}) =
      let uname = Text.unpack name in
      Tuple () Boxed
        [ Lit () $ F.String () uname uname
        , RecConstr () (unQual "Classifier")
            [ genClassData okData "okData"
            , genClassData koData "koData"
            ]
        ]

    -- ClassData { prior = -0.123, unseen = ...
    genClassData ClassData{..} name = FieldUpdate () (unQual name) $
      RecConstr () (unQual "ClassData")
        [ FieldUpdate () (unQual "prior") $ floatSym prior
        , FieldUpdate () (unQual "unseen") $ floatSym unseen
        , FieldUpdate () (unQual "likelihoods") $
            appFromList $ map genLikelihood $ HashMap.toList likelihoods
        , FieldUpdate () (unQual "n") $
            Lit () (Int () (fromIntegral n) (show n))
        ]

    -- ("feature", 0.0)
    genLikelihood (f, d) =
      let uf = Text.unpack f in
      Tuple () Boxed
        [ Lit () $ F.String () uf uf
        , floatSym d
        ]

-- Helper to print out doubles
floatSym :: Double -> Exp ()
floatSym val
  | isInfinite val = if val < 0
      then NegApp () inf
      else inf
  | otherwise = Lit () (Frac () (realToFrac val) $ show val)
  where
    inf = Var () $ unQual "infinity"

-- Helper for unqualified things
unQual :: String -> QName ()
unQual name = UnQual () (Ident () name)


-- -----------------------------------------------------------------
-- Printing helpers

baseMode :: PPHsMode
baseMode = PPHsMode
  { classIndent   = 2
  , doIndent      = 3
  , multiIfIndent = 3
  , caseIndent    = 2
  , letIndent     = 2
  , whereIndent   = 2
  , onsideIndent  = 2
  , spacing       = True
  , layout        = PPOffsideRule
  , linePragmas   = False
  }
