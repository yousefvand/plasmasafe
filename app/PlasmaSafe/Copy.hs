module PlasmaSafe.Copy
  ( copyPathIfExists
  , copyDirectoryRecursiveSafe
  ) where

import Control.Monad
import System.Directory
import System.FilePath

copyPathIfExists :: FilePath -> FilePath -> IO Bool
copyPathIfExists source destination = do
  fileExists <- doesFileExist source
  dirExists  <- doesDirectoryExist source

  case (fileExists, dirExists) of
    (True, _) -> do
      createDirectoryIfMissing True (takeDirectory destination)
      copyFile source destination
      pure True

    (_, True) -> do
      createDirectoryIfMissing True destination
      copyDirectoryRecursiveSafe source destination
      pure True

    _ -> pure False

copyDirectoryRecursiveSafe :: FilePath -> FilePath -> IO ()
copyDirectoryRecursiveSafe source destination = do
  createDirectoryIfMissing True destination
  names <- listDirectory source
  forM_ names $ \name -> do
    let src = source </> name
    let dst = destination </> name

    isFile <- doesFileExist src
    isDir  <- doesDirectoryExist src

    if isFile
      then do
        createDirectoryIfMissing True (takeDirectory dst)
        copyFile src dst
      else when isDir $
        copyDirectoryRecursiveSafe src dst
