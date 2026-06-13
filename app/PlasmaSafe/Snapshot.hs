{-# LANGUAGE OverloadedStrings #-}

module PlasmaSafe.Snapshot
  ( saveSnapshot
  , listSnapshots
  , listSnapshotsJson
  , showSnapshot
  , showSnapshotJson
  , diffSnapshots
  , verifySnapshot
  , deleteSnapshotPreview
  , deleteSnapshotForce
  ) where

import Control.Monad
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.Aeson.Encode.Pretty (encodePretty)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time
import PlasmaSafe.Copy
import PlasmaSafe.Manifest
import PlasmaSafe.Paths
import PlasmaSafe.SnapshotStore
import PlasmaSafe.Types
import PlasmaSafe.Verify
import System.Directory
import System.Environment
import System.Exit
import System.FilePath
import System.Process

saveSnapshot :: SnapshotName -> Profile -> IO ()
saveSnapshot name profile = do
  home <- getHomeDir
  root <- getSnapshotRoot
  createDirectoryIfMissing True root

  now <- getCurrentTime
  tz  <- getCurrentTimeZone
  let localTime = utcToLocalTime tz now
  let sid = formatTime defaultTimeLocale "%Y-%m-%d_%H-%M-%S" localTime ++ "_" ++ sanitizeName name

  let snap = snapshotDir root sid
  let filesDir = snapshotFilesDir snap

  createDirectoryIfMissing True filesDir

  fileEntries <- forM (profileFiles profile) $ \rel -> do
    let source = home </> rel
    let destination = filesDir </> rel
    exists <- copyPathIfExists source destination
    pure SnapshotEntry
      { entrySourceRelative = rel
      , entryStoredRelative = rel
      , entryType = EntryFile
      , entryExists = exists
      }

  dirEntries <- forM (profileDirs profile) $ \rel -> do
    let source = home </> rel
    let destination = filesDir </> rel
    exists <- copyPathIfExists source destination
    pure SnapshotEntry
      { entrySourceRelative = rel
      , entryStoredRelative = rel
      , entryType = EntryDirectory
      , entryExists = exists
      }

  host <- getHostNameSafe

  let manifest = SnapshotManifest
        { manifestVersion = 1
        , snapshotId = sid
        , snapshotName = name
        , createdAt = now
        , hostName = T.pack host
        , profileName = profileLabel profile
        , entries = fileEntries ++ dirEntries
        }

  writeManifest (manifestPath snap) manifest
  writePacmanList snap

  putStrLn ("Saved snapshot: " ++ sid)
  putStrLn ("Location: " ++ snap)

listSnapshots :: IO ()
listSnapshots = do
  root <- getSnapshotRoot
  exists <- doesDirectoryExist root
  if not exists
    then putStrLn "No snapshots found."
    else do
      names <- listDirectory root
      if null names
        then putStrLn "No snapshots found."
        else mapM_ putStrLn names

listSnapshotsJson :: IO ()
listSnapshotsJson = do
  root <- getSnapshotRoot
  exists <- doesDirectoryExist root
  if not exists
    then BL8.putStrLn (encodePretty ([] :: [SnapshotManifest]))
    else do
      names <- listDirectory root
      manifests <- readValidManifests root names
      BL8.putStrLn (encodePretty manifests)

readValidManifests :: FilePath -> [FilePath] -> IO [SnapshotManifest]
readValidManifests root names = do
  found <- mapM readOne names
  pure [manifest | Just manifest <- found]
  where
    readOne name = do
      let snap = root </> name
      isDir <- doesDirectoryExist snap
      if not isDir
        then pure Nothing
        else do
          manifestFileExists <- doesFileExist (manifestPath snap)
          if not manifestFileExists
            then pure Nothing
            else do
              decoded <- readManifest (manifestPath snap)
              case decoded of
                Left _err -> pure Nothing
                Right manifest -> pure (Just manifest)

showSnapshot :: SnapshotName -> IO ()
showSnapshot wanted = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      decoded <- readManifest (manifestPath snap)
      case decoded of
        Left err ->
          putStrLn ("Could not read manifest: " ++ err)

        Right manifest ->
          printManifest manifest

showSnapshotJson :: SnapshotName -> IO ()
showSnapshotJson wanted = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      decoded <- readManifest (manifestPath snap)
      case decoded of
        Left err ->
          putStrLn ("Could not read manifest: " ++ err)

        Right manifest ->
          BL8.putStrLn (encodePretty manifest)

diffSnapshots :: SnapshotName -> SnapshotName -> IO ()
diffSnapshots leftName rightName = do
  root <- getSnapshotRoot
  leftMatch <- findSnapshotDirInRoot root leftName
  rightMatch <- findSnapshotDirInRoot root rightName

  case (leftMatch, rightMatch) of
    (Nothing, _) ->
      putStrLn ("Snapshot not found: " ++ leftName)

    (_, Nothing) ->
      putStrLn ("Snapshot not found: " ++ rightName)

    (Just leftSnap, Just rightSnap) -> do
      let leftFiles = snapshotFilesDir leftSnap
      let rightFiles = snapshotFilesDir rightSnap

      putStrLn "Comparing:"
      putStrLn ("  OLD: " ++ takeFileName leftSnap)
      putStrLn ("  NEW: " ++ takeFileName rightSnap)
      putStrLn ""

      leftExists <- doesDirectoryExist leftFiles
      rightExists <- doesDirectoryExist rightFiles

      if not leftExists || not rightExists
        then putStrLn "One of the snapshots has no files directory."
        else runDiff leftFiles rightFiles

verifySnapshot :: SnapshotName -> IO ()
verifySnapshot wanted = do
  report <- verifySnapshotReport wanted
  printVerificationReport report

deleteSnapshotPreview :: SnapshotName -> IO ()
deleteSnapshotPreview wanted = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      putStrLn "Delete preview only. No files will be changed."
      putStrLn ""
      putStrLn ("Would delete snapshot: " ++ takeFileName snap)
      putStrLn ("Path: " ++ snap)
      putStrLn ""
      putStrLn "To actually delete it, run:"
      putStrLn ("  plasmasafe delete " ++ wanted ++ " --force")

deleteSnapshotForce :: SnapshotName -> IO ()
deleteSnapshotForce wanted = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      removeDirectoryRecursive snap
      putStrLn ("Deleted snapshot: " ++ takeFileName snap)

verifyEntry :: FilePath -> SnapshotEntry -> IO Bool
verifyEntry snap entry =
  if not (entryExists entry)
    then do
      putStrLn ("  [skip] " ++ entrySourceRelative entry ++ " was missing when saved")
      pure True
    else do
      let stored = snapshotFilesDir snap </> entryStoredRelative entry
      fileExists <- doesFileExist stored
      dirExists <- doesDirectoryExist stored

      let ok =
            case entryType entry of
              EntryFile      -> fileExists
              EntryDirectory -> dirExists

      putCheck ("saved entry: " ++ entrySourceRelative entry) ok
      pure ok

runDiff :: FilePath -> FilePath -> IO ()
runDiff leftFiles rightFiles = do
  result <- readProcessWithExitCode "diff" ["-ru", leftFiles, rightFiles] ""

  case result of
    (ExitSuccess, _, _) ->
      putStrLn "No differences found."

    (ExitFailure 1, out, _) ->
      putStr out

    (ExitFailure code, _, err) -> do
      putStrLn ("diff failed with exit code: " ++ show code)
      putStrLn err

printManifest :: SnapshotManifest -> IO ()
printManifest manifest = do
  putStrLn ("Snapshot ID:   " ++ snapshotId manifest)
  putStrLn ("Name:          " ++ snapshotName manifest)
  putStrLn ("Created at:    " ++ show (createdAt manifest))
  TIO.putStrLn ("Host:          " <> hostName manifest)
  TIO.putStrLn ("Profile:       " <> profileName manifest)
  putStrLn ""

  let existing = filter entryExists (entries manifest)
  let missing  = filter (not . entryExists) (entries manifest)

  putStrLn ("Saved entries: " ++ show (length existing))
  putStrLn ("Missing:       " ++ show (length missing))
  putStrLn ""

  putStrLn "Saved:"
  mapM_ printEntry existing

  unless (null missing) $ do
    putStrLn ""
    putStrLn "Missing:"
    mapM_ printEntry missing

printEntry :: SnapshotEntry -> IO ()
printEntry entry = do
  let kind =
        case entryType entry of
          EntryFile      -> "file"
          EntryDirectory -> "dir "

  putStrLn ("  [" ++ kind ++ "] " ++ entrySourceRelative entry)

putCheck :: String -> Bool -> IO ()
putCheck label ok =
  putStrLn (status ++ " " ++ label)
  where
    status =
      if ok
        then "[OK]  "
        else "[FAIL]"

sanitizeName :: String -> String
sanitizeName =
  map replaceBadChar
  where
    replaceBadChar c
      | c `elem` (" /\\:*?\"'<>|" :: String) = '-'
      | otherwise = c

getHostNameSafe :: IO String
getHostNameSafe = do
  envHost <- lookupEnv "HOSTNAME"
  case envHost of
    Just h | not (null h) -> pure h
    _ -> pure "unknown-host"

writePacmanList :: FilePath -> IO ()
writePacmanList snap = do
  result <- readProcessWithExitCode "pacman" ["-Q"] ""
  case result of
    (_, out, _) -> writeFile (pacmanPath snap) out
