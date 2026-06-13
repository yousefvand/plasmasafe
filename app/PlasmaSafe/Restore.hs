{-# LANGUAGE OverloadedStrings #-}

module PlasmaSafe.Restore
  ( restoreSnapshotDryRun
  , restoreSnapshotForce
  ) where

import Control.Monad
import qualified Data.Text.IO as TIO
import PlasmaSafe.Copy
import PlasmaSafe.Manifest
import PlasmaSafe.Paths
import PlasmaSafe.Snapshot (saveSnapshot)
import PlasmaSafe.SnapshotStore
import PlasmaSafe.Types
import System.Directory
import System.FilePath

restoreSnapshotDryRun :: SnapshotName -> IO ()
restoreSnapshotDryRun wanted = do
  home <- getHomeDir
  match <- findSnapshotDir wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      decoded <- readManifest (manifestPath snap)
      case decoded of
        Left err ->
          putStrLn ("Could not read manifest: " ++ err)

        Right manifest -> do
          putStrLn "Restore dry-run only. No files will be changed."
          putStrLn ""
          putStrLn ("Snapshot ID: " ++ snapshotId manifest)
          putStrLn ("Name:        " ++ snapshotName manifest)
          TIO.putStrLn ("Profile:     " <> profileName manifest)
          putStrLn ""

          let existingEntries = filter entryExists (entries manifest)
          let missingEntries = filter (not . entryExists) (entries manifest)

          putStrLn "Would restore:"
          mapM_ (printRestorePlan home snap) existingEntries

          unless (null missingEntries) $ do
            putStrLn ""
            putStrLn "These entries were missing when the snapshot was created, so they would not be restored:"
            mapM_ printEntry missingEntries

          putStrLn ""
          putStrLn "Nothing was changed."

restoreSnapshotForce :: SnapshotName -> Profile -> IO ()
restoreSnapshotForce wanted profile = do
  home <- getHomeDir
  match <- findSnapshotDir wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      decoded <- readManifest (manifestPath snap)
      case decoded of
        Left err ->
          putStrLn ("Could not read manifest: " ++ err)

        Right manifest -> do
          putStrLn "Creating automatic safety snapshot before restore..."
          saveSnapshot ("auto-before-restore-" ++ wanted) profile
          putStrLn ""

          putStrLn ("Restoring snapshot: " ++ snapshotId manifest)
          let existingEntries = filter entryExists (entries manifest)

          mapM_ (restoreEntry home snap) existingEntries

          putStrLn ""
          putStrLn "Restore completed."
          putStrLn "For real KDE Plasma use, log out/in or restart Plasma after restore."

restoreEntry :: FilePath -> FilePath -> SnapshotEntry -> IO ()
restoreEntry home snap entry = do
  let source = snapshotFilesDir snap </> entryStoredRelative entry
  let destination = home </> entrySourceRelative entry

  sourceFileExists <- doesFileExist source
  sourceDirExists <- doesDirectoryExist source

  case entryType entry of
    EntryFile ->
      if sourceFileExists
        then do
          createDirectoryIfMissing True (takeDirectory destination)
          copyFile source destination
          putStrLn ("Restored file: " ++ entrySourceRelative entry)
        else
          putStrLn ("Skipped missing file in snapshot: " ++ entrySourceRelative entry)

    EntryDirectory ->
      if sourceDirExists
        then do
          destinationExists <- doesDirectoryExist destination
          when destinationExists $
            removeDirectoryRecursive destination
          createDirectoryIfMissing True destination
          copyDirectoryRecursiveSafe source destination
          putStrLn ("Restored dir:  " ++ entrySourceRelative entry)
        else
          putStrLn ("Skipped missing directory in snapshot: " ++ entrySourceRelative entry)

printRestorePlan :: FilePath -> FilePath -> SnapshotEntry -> IO ()
printRestorePlan home snap entry = do
  let source = snapshotFilesDir snap </> entryStoredRelative entry
  let destination = home </> entrySourceRelative entry

  sourceFileExists <- doesFileExist source
  sourceDirExists <- doesDirectoryExist source
  destinationFileExists <- doesFileExist destination
  destinationDirExists <- doesDirectoryExist destination

  let sourceStatus =
        if sourceFileExists || sourceDirExists
          then "OK"
          else "MISSING-IN-SNAPSHOT"

  let destinationStatus =
        if destinationFileExists || destinationDirExists
          then "will overwrite"
          else "will create"

  let kind =
        case entryType entry of
          EntryFile      -> "file"
          EntryDirectory -> "dir "

  putStrLn ("  [" ++ kind ++ "] " ++ sourceStatus ++ " | " ++ destinationStatus)
  putStrLn ("      from: " ++ source)
  putStrLn ("      to:   " ++ destination)

printEntry :: SnapshotEntry -> IO ()
printEntry entry = do
  let kind =
        case entryType entry of
          EntryFile      -> "file"
          EntryDirectory -> "dir "

  putStrLn ("  [" ++ kind ++ "] " ++ entrySourceRelative entry)
