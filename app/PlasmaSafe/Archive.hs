module PlasmaSafe.Archive
  ( exportSnapshot
  , importSnapshot
  ) where

import PlasmaSafe.Paths
import PlasmaSafe.SnapshotStore
import PlasmaSafe.Types
import System.Directory
import System.Exit
import System.FilePath
import System.Process

exportSnapshot :: SnapshotName -> FilePath -> IO ()
exportSnapshot wanted outputPath = do
  root <- getSnapshotRoot
  match <- findSnapshotDirInRoot root wanted

  case match of
    Nothing ->
      putStrLn ("Snapshot not found: " ++ wanted)

    Just snap -> do
      manifestExists <- doesFileExist (manifestPath snap)
      filesDirExists <- doesDirectoryExist (snapshotFilesDir snap)

      if not manifestExists || not filesDirExists
        then do
          putStrLn "Snapshot is not valid enough to export."
          putStrLn ("manifest.json exists: " ++ show manifestExists)
          putStrLn ("files directory exists: " ++ show filesDirExists)
        else do
          createDirectoryIfMissing True (takeDirectory outputPath)

          let parentDir = takeDirectory snap
          let snapName = takeFileName snap

          putStrLn ("Exporting snapshot: " ++ snapName)
          putStrLn ("Output: " ++ outputPath)

          result <- readProcessWithExitCode
            "tar"
            ["-czf", outputPath, "-C", parentDir, snapName]
            ""

          case result of
            (ExitSuccess, _, _) -> do
              putStrLn "Export completed."
              putStrLn outputPath

            (ExitFailure code, _out, err) -> do
              putStrLn ("Export failed with exit code: " ++ show code)
              putStrLn err

importSnapshot :: FilePath -> IO ()
importSnapshot archivePath = do
  archiveExists <- doesFileExist archivePath

  if not archiveExists
    then putStrLn ("Archive not found: " ++ archivePath)
    else do
      root <- getSnapshotRoot
      createDirectoryIfMissing True root

      resultList <- readProcessWithExitCode "tar" ["-tzf", archivePath] ""

      case resultList of
        (ExitFailure code, _out, err) -> do
          putStrLn ("Could not read archive. tar exited with code: " ++ show code)
          putStrLn err

        (ExitSuccess, out, _) -> do
          case firstTopLevelDirectory out of
            Nothing ->
              putStrLn "Archive does not appear to contain a snapshot directory."

            Just snapshotName -> do
              let destination = root </> snapshotName

              destinationExists <- doesDirectoryExist destination
              if destinationExists
                then do
                  putStrLn ("Refusing to overwrite existing snapshot: " ++ snapshotName)
                  putStrLn ("Path: " ++ destination)
                else do
                  putStrLn ("Importing snapshot: " ++ snapshotName)
                  putStrLn ("Into: " ++ root)

                  resultExtract <- readProcessWithExitCode
                    "tar"
                    ["-xzf", archivePath, "-C", root]
                    ""

                  case resultExtract of
                    (ExitFailure code, _out2, err2) -> do
                      putStrLn ("Import failed with exit code: " ++ show code)
                      putStrLn err2

                    (ExitSuccess, _, _) -> do
                      validateImportedSnapshot destination

validateImportedSnapshot :: FilePath -> IO ()
validateImportedSnapshot snap = do
  manifestExists <- doesFileExist (manifestPath snap)
  filesDirExists <- doesDirectoryExist (snapshotFilesDir snap)

  if manifestExists && filesDirExists
    then do
      putStrLn "Import completed."
      putStrLn ("Snapshot: " ++ takeFileName snap)
    else do
      putStrLn "Import finished, but snapshot looks incomplete."
      putStrLn ("manifest.json exists: " ++ show manifestExists)
      putStrLn ("files directory exists: " ++ show filesDirExists)

firstTopLevelDirectory :: String -> Maybe FilePath
firstTopLevelDirectory archiveListing =
  case lines archiveListing of
    [] -> Nothing
    firstLine : _ ->
      case splitDirectories firstLine of
        [] -> Nothing
        top : _ ->
          if safeSnapshotName top
            then Just top
            else Nothing

safeSnapshotName :: FilePath -> Bool
safeSnapshotName name =
  not (null name)
  && name /= "."
  && name /= ".."
  && not (isAbsolute name)
  && notElem ".." (splitDirectories name)
  && notElem '/' name
