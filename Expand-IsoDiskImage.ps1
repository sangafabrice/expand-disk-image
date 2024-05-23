<#
.SYNOPSIS
Expand an ISO file.
.DESCRIPTION
The script extract all files from a .iso file to a destination directory.
.PARAMETER ImagePath
Specifies the path to an existing ISO file.
.PARAMETER DestinationPath
Specifies the destination directory where the files are extracted.
The default destination folder path is the path to the ISO file without the extension.
.PARAMETER Open
Specifies that the script opens the destination folder when the extraction completes.
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory)]
  [ValidatePattern('\.iso$')]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string] $ImagePath,
  [ValidateNotNullOrEmpty()]
  [string] $DestinationPath = $ImagePath -ireplace '\.iso$',
  [switch] $Open
)
# Convert the ISO file path to absolute path.
$ImagePath = (Get-Item $ImagePath).FullName
# Modify the destination path if it carries info of a file.
$SkipIndex = 0
While (Test-Path $DestinationPath -PathType Leaf) {
  $DestinationPath = "$DestinationPath ($((++$SkipIndex)))"
}
# Create the destination folder and convert its path to absolute.
$DestinationPath = (New-Item $DestinationPath -ItemType Directory -Force -ErrorAction Stop).FullName
# Mount the ISO disk image and copy the subsequent virtual drive root to the destination folder.
# The CopyHere() method of the Windows Shell COM API is responsible for checking the 
# available space in the destination folder, handling file overwrites, and displaying a progress bar.
(New-Object -ComObject Shell.Application).
NameSpace($DestinationPath).
CopyHere("$((($DiskImage = Mount-DiskImage $ImagePath) | Get-Volume).DriveLetter):\")
[void] ($DiskImage | Dismount-DiskImage)
# Open the destination folder if required.
If ($Open) {
  explorer.exe $DestinationPath
}