/*
 * Launches a hidden Windows PowerShell console that executes the target
 * "Expand-IsoDiskImage.ps1" script. The ISO file path string is passed to
 * that script as its argument and an optional switch parameter that specifies
 * if the transient virtual drive should be hidden from the file explorer.
 * The arguments must be input in this order.
 * @param imagePath The specified ISO file path string.
 * @param paramHideDrive The -HideDrive parameter to the target script. 
*/
import System;
import System.IO;
import System.Diagnostics;
import System.Security.Principal;
// Store the command line arguments of the current assembly call.
var commandLineArguments:String[] = Environment.GetCommandLineArgs();
// Store command line arguments to parameter variables.
var imagePath:String = commandLineArguments[1];
var paramHideDrive:String = commandLineArguments.length == 3  &&
  '-HideDrive'.StartsWith(
    commandLineArguments[2],
    StringComparison.InvariantCultureIgnoreCase
  ) ? commandLineArguments[2]:'';
// Build the powershell process start info object.
var powershellProcessStartInfo:ProcessStartInfo = new ProcessStartInfo(
  'powershell.exe',
  String.Format(
    '-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden' + 
    ' -File "{0}\\Expand-IsoDiskImage.ps1" -ImagePath "{1}" {2}',
    Path.GetDirectoryName(commandLineArguments[0]),
    imagePath,
    paramHideDrive
  ));
// Hide the flashing powershell console window.
powershellProcessStartInfo.WindowStyle = ProcessWindowStyle.Hidden;
// Set the powershell process to run with elevated privileges when the
// -HideDrive switch is present and the current process is not elevated.
if (
  paramHideDrive.length > 0 && 
  !(new WindowsPrincipal(WindowsIdentity.GetCurrent())).
  IsInRole(WindowsBuiltInRole.Administrator)
) powershellProcessStartInfo.Verb = 'runas';
// Start the the hidden powershell console windows.
Process.Start(powershellProcessStartInfo);