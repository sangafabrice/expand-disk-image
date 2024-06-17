/*
 * Launches a hidden Windows PowerShell console that executes
 * the target "Expand-IsoDiskImage.ps1" script. The ISO file
 * path string is passed to that script as its argument.
 * @param imagePath The specified ISO file path string.
*/
import System;
import System.IO;
import System.Diagnostics;
// Store the command line arguments of the current assembly call.
var commandLineArguments:String[] = Environment.GetCommandLineArgs();
// Store command line arguments to parameter variables.
var imagePath:String = commandLineArguments[1];
// Build the powershell process start info object.
var powershellProcessStartInfo:ProcessStartInfo = new ProcessStartInfo(
  'powershell.exe',
  String.Format(
    '-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden' + 
    ' -File "{0}\\Expand-IsoDiskImage.ps1" -ImagePath "{1}" -HideDrive',
    Path.GetDirectoryName(commandLineArguments[0]),
    imagePath
  ));
// Hide the flashing powershell console window.
powershellProcessStartInfo.WindowStyle = ProcessWindowStyle.Hidden;
// Start the the hidden powershell console windows.
Process.Start(powershellProcessStartInfo);