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
.PARAMETER HideDrive
Specifies that the virtual drive be hidden from the file explorer application.
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
  [switch] $HideDrive,
  [switch] $Open
)
# Convert the ISO file path to absolute path.
$ImagePath = (Get-Item $ImagePath).FullName
If ($HideDrive) {
# The Temp folder must be NTS formated for mounting disk images.
# This is a design decision since we can assign a drive letter to the internal volumes
# of the disk image and use the roots of those volumes as temporary mount directories.
# The goal of this design decision is to avoid visible changes of the system.
If ((Get-Volume -DriveLetter (Get-Item $Env:TEMP).PSDrive.Name).FileSystem -ine 'NTFS') {
  Throw 'Intermediate folder is not NTFS formatted.'
}
# Create an empty temporary directory where the mount point will reside.
While (Test-Path ($TempMountDirPath = "$Env:Temp\MountDir-$(New-Guid)")) { }
# The TEMP subdirectory is created here to check write right access.
[void] (New-Item -Path $TempMountDirPath -ItemType Directory -ErrorAction Stop)
}
# Modify the destination path if it carries info of a file.
$SkipIndex = 0
While (Test-Path $DestinationPath -PathType Leaf) {
  $DestinationPath = "$DestinationPath ($((++$SkipIndex)))"
}
# Create the destination folder and convert its path to absolute.
$DestinationPath = (New-Item $DestinationPath -ItemType Directory -Force -ErrorAction Stop).FullName
# Mount the ISO disk image and store objects to variables.
$DiskImageVolume = ($DiskImage = Mount-DiskImage $ImagePath -NoDriveLetter:$HideDrive) | Get-Volume
If ($HideDrive) {
Try {
  # Append to the temporary mount directory path the disk label segment.
  $TempMountDirPath = (New-Item -Path "$TempMountDirPath\$($DiskImageVolume.FileSystemLabel)" -ItemType Directory -ErrorAction Stop).FullName
}
Catch { }
# Mount the disk image volume in the temporary mount directory.
mountvol.exe $TempMountDirPath $($DiskImageVolume.Path)
} Else {
  $TempMountDirPath = $DiskImageVolume.DriveLetter + ':\'
}
# Copy the temporary mount directory to the destination folder.
# The CopyHere() method of the Windows Shell COM API is responsible for checking the 
# available space in the destination folder, handling file overwrites, and displaying a progress bar.
(New-Object -ComObject Shell.Application).
NameSpace($DestinationPath).
CopyHere($TempMountDirPath)
# Clean up disk and volume settings.
[void] ($DiskImage | Dismount-DiskImage)
If ($HideDrive) {
mountvol.exe /r
}
# Open the destination folder if required.
If ($Open) {
  explorer.exe $DestinationPath
}