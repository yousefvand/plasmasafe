module PlasmaSafe.CLI
  ( runCLI
  ) where

import Options.Applicative
import PlasmaSafe.Archive
import PlasmaSafe.Doctor
import PlasmaSafe.Profile
import PlasmaSafe.Restore
import PlasmaSafe.Snapshot
import PlasmaSafe.Types
import PlasmaSafe.Verify
import System.Exit

data Command
  = CmdSave String String
  | CmdList Bool
  | CmdShow String Bool
  | CmdDiff String String
  | CmdRestore String Bool Bool String
  | CmdVerify String Bool
  | CmdDelete String Bool
  | CmdDoctor
  | CmdExport String FilePath
  | CmdImport FilePath
  | CmdProfiles
  deriving (Show)

runCLI :: IO ()
runCLI = do
  command <- execParser parserInfo
  runCommand command

runCommand :: Command -> IO ()
runCommand command =
  case command of
    CmdSave name profileName -> do
      profile <- resolveProfileOrExit profileName
      saveSnapshot name profile

    CmdList asJson ->
      if asJson
        then listSnapshotsJson
        else listSnapshots

    CmdShow name asJson ->
      if asJson
        then showSnapshotJson name
        else showSnapshot name

    CmdDiff oldName newName ->
      diffSnapshots oldName newName

    CmdRestore name dryRun force profileName ->
      case (dryRun, force) of
        (True, False) ->
          restoreSnapshotDryRun name

        (False, True) -> do
          profile <- resolveProfileOrExit profileName
          restoreSnapshotForce name profile

        (False, False) -> do
          putStrLn "Restore requires either --dry-run or --force."
          putStrLn "Use one of:"
          putStrLn "  plasmasafe restore SNAPSHOT --dry-run"
          putStrLn "  plasmasafe restore SNAPSHOT --force"
          exitFailure

        (True, True) -> do
          putStrLn "Use either --dry-run or --force, not both."
          exitFailure

    CmdVerify name asJson -> do
      report <- verifySnapshotReport name

      if asJson
        then printVerificationReportJson report
        else printVerificationReport report

      if verificationOk report
        then exitSuccess
        else exitFailure

    CmdDelete name force ->
      if force
        then deleteSnapshotForce name
        else deleteSnapshotPreview name

    CmdDoctor ->
      runDoctor

    CmdExport name outputPath ->
      exportSnapshot name outputPath

    CmdImport archivePath ->
      importSnapshot archivePath

    CmdProfiles ->
      listProfiles

resolveProfileOrExit :: String -> IO Profile
resolveProfileOrExit profileName =
  case profileByName profileName of
    Right profile ->
      pure profile

    Left err -> do
      putStrLn err
      exitFailure

parserInfo :: ParserInfo Command
parserInfo =
  info
    (helper <*> commandParser)
    ( fullDesc
   <> progDesc "KDE Plasma configuration backup, restore, diff, verify, export and import tool"
   <> header "PlasmaSafe"
    )

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "save"
        (info saveParser
          (progDesc "Save a new Plasma configuration snapshot"))

   <> command "list"
        (info listParser
          (progDesc "List saved snapshots"))

   <> command "show"
        (info showParser
          (progDesc "Show snapshot manifest and saved entries"))

   <> command "diff"
        (info diffParser
          (progDesc "Compare two snapshots"))

   <> command "restore"
        (info restoreParser
          (progDesc "Restore a snapshot. Use --dry-run first."))

   <> command "verify"
        (info verifyParser
          (progDesc "Verify snapshot structure and saved files"))

   <> command "delete"
        (info deleteParser
          (progDesc "Delete a snapshot. Requires --force to actually delete."))

   <> command "doctor"
        (info doctorParser
          (progDesc "Check PlasmaSafe environment and KDE profile paths"))

   <> command "export"
        (info exportParser
          (progDesc "Export a snapshot to a .tar.gz archive"))

   <> command "import"
        (info importParser
          (progDesc "Import a snapshot from a .tar.gz archive"))

   <> command "profiles"
        (info profilesParser
          (progDesc "List available backup profiles"))
    )

profileOption :: Parser String
profileOption =
  strOption
    ( long "profile"
   <> short 'p'
   <> metavar "PROFILE"
   <> value "desktop"
   <> showDefault
   <> help "Profile to use: minimal, desktop, or full"
    )

jsonSwitch :: Parser Bool
jsonSwitch =
  switch
    ( long "json"
   <> help "Output JSON"
    )

dryRunSwitch :: Parser Bool
dryRunSwitch =
  switch
    ( long "dry-run"
   <> help "Show what would happen without changing files"
    )

forceSwitch :: Parser Bool
forceSwitch =
  switch
    ( long "force"
   <> help "Actually perform the destructive action"
    )

saveParser :: Parser Command
saveParser =
  CmdSave
    <$> argument str
      ( metavar "NAME"
     <> help "Snapshot name, for example before-theme-change"
      )
    <*> profileOption

listParser :: Parser Command
listParser =
  CmdList
    <$> jsonSwitch

showParser :: Parser Command
showParser =
  CmdShow
    <$> argument str
      ( metavar "SNAPSHOT"
     <> help "Snapshot name or full snapshot ID"
      )
    <*> jsonSwitch

diffParser :: Parser Command
diffParser =
  CmdDiff
    <$> argument str
      ( metavar "OLD"
     <> help "Old snapshot name or full snapshot ID"
      )
    <*> argument str
      ( metavar "NEW"
     <> help "New snapshot name or full snapshot ID"
      )

restoreParser :: Parser Command
restoreParser =
  CmdRestore
    <$> argument str
      ( metavar "SNAPSHOT"
     <> help "Snapshot name or full snapshot ID"
      )
    <*> dryRunSwitch
    <*> forceSwitch
    <*> profileOption

verifyParser :: Parser Command
verifyParser =
  CmdVerify
    <$> argument str
      ( metavar "SNAPSHOT"
     <> help "Snapshot name or full snapshot ID"
      )
    <*> jsonSwitch

deleteParser :: Parser Command
deleteParser =
  CmdDelete
    <$> argument str
      ( metavar "SNAPSHOT"
     <> help "Snapshot name or full snapshot ID"
      )
    <*> forceSwitch

doctorParser :: Parser Command
doctorParser =
  pure CmdDoctor

exportParser :: Parser Command
exportParser =
  CmdExport
    <$> argument str
      ( metavar "SNAPSHOT"
     <> help "Snapshot name or full snapshot ID"
      )
    <*> argument str
      ( metavar "OUTPUT"
     <> help "Output archive path, for example /tmp/snapshot.tar.gz"
      )

importParser :: Parser Command
importParser =
  CmdImport
    <$> argument str
      ( metavar "ARCHIVE"
     <> help "Archive path, for example /tmp/snapshot.tar.gz"
      )

profilesParser :: Parser Command
profilesParser =
  pure CmdProfiles
