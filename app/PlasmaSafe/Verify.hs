{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module PlasmaSafe.Verify
  ( VerificationReport(..)
  , VerificationCheck(..)
  , verifySnapshotReport
  , printVerificationReport
  , printVerificationReportJson
  ) where

import Data.Aeson
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.Aeson.Encode.Pretty
import GHC.Generics
import PlasmaSafe.Manifest
import PlasmaSafe.Paths
import PlasmaSafe.SnapshotStore
import PlasmaSafe.Types
import System.Directory
import System.FilePath

data VerificationCheck = VerificationCheck
  { checkName :: String
  , checkOk :: Bool
  , checkDetail :: String
  } deriving (Show, Eq, Generic)

instance ToJSON VerificationCheck
instance FromJSON VerificationCheck

data VerificationReport = VerificationReport
  { verificationSnapshot :: SnapshotName
  , verificationPath :: FilePath
  , verificationOk :: Bool
  , verificationChecks :: [VerificationCheck]
  } deriving (Show, Eq, Generic)

instance ToJSON VerificationReport
instance FromJSON VerificationReport

verifySnapshotReport :: SnapshotName -> IO VerificationReport
verifySnapshotReport wanted = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      pure VerificationReport
        { verificationSnapshot = wanted
        , verificationPath = ""
        , verificationOk = False
        , verificationChecks =
            [ VerificationCheck
                { checkName = "snapshot exists"
                , checkOk = False
                , checkDetail = "Snapshot not found"
                }
            ]
        }

    Just snap -> do
      manifestExists <- doesFileExist (manifestPath snap)
      filesDirExists <- doesDirectoryExist (snapshotFilesDir snap)
      pacmanExists <- doesFileExist (pacmanPath snap)

      baseChecks <- pure
        [ VerificationCheck "manifest.json exists" manifestExists (manifestPath snap)
        , VerificationCheck "files directory exists" filesDirExists (snapshotFilesDir snap)
        , VerificationCheck "pacman.txt exists" pacmanExists (pacmanPath snap)
        ]

      manifestChecks <-
        if not manifestExists
          then pure
            [ VerificationCheck
                { checkName = "manifest is readable"
                , checkOk = False
                , checkDetail = "manifest.json does not exist"
                }
            ]
          else do
            decoded <- readManifest (manifestPath snap)
            case decoded of
              Left err ->
                pure
                  [ VerificationCheck
                      { checkName = "manifest is readable"
                      , checkOk = False
                      , checkDetail = err
                      }
                  ]

              Right manifest -> do
                entryChecks <- mapM (verifyEntry snap) (entries manifest)
                pure
                  ( VerificationCheck
                      { checkName = "manifest is readable"
                      , checkOk = True
                      , checkDetail = "manifest.json parsed successfully"
                      }
                    : entryChecks
                  )

      let checks = baseChecks ++ manifestChecks
      pure VerificationReport
        { verificationSnapshot = wanted
        , verificationPath = snap
        , verificationOk = all checkOk checks
        , verificationChecks = checks
        }

verifyEntry :: FilePath -> SnapshotEntry -> IO VerificationCheck
verifyEntry snap entry =
  if not (entryExists entry)
    then pure VerificationCheck
      { checkName = "saved entry skipped"
      , checkOk = True
      , checkDetail = entrySourceRelative entry ++ " was missing when snapshot was created"
      }
    else do
      let stored = snapshotFilesDir snap </> entryStoredRelative entry
      fileExists <- doesFileExist stored
      dirExists <- doesDirectoryExist stored

      let ok =
            case entryType entry of
              EntryFile -> fileExists
              EntryDirectory -> dirExists

      pure VerificationCheck
        { checkName = "saved entry exists"
        , checkOk = ok
        , checkDetail = stored
        }

printVerificationReport :: VerificationReport -> IO ()
printVerificationReport report = do
  putStrLn ("Verifying snapshot: " ++ verificationSnapshot report)
  if null (verificationPath report)
    then pure ()
    else putStrLn ("Path: " ++ verificationPath report)

  putStrLn ""
  mapM_ printCheck (verificationChecks report)
  putStrLn ""

  if verificationOk report
    then putStrLn "OK: snapshot passed verification."
    else putStrLn "FAILED: snapshot did not pass verification."

printVerificationReportJson :: VerificationReport -> IO ()
printVerificationReportJson =
  BL8.putStrLn . encodePretty

printCheck :: VerificationCheck -> IO ()
printCheck check =
  putStrLn (status ++ " " ++ checkName check ++ " - " ++ checkDetail check)
  where
    status =
      if checkOk check
        then "[OK]  "
        else "[FAIL]"
