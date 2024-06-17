using namespace System.Windows.Forms
using namespace System.Drawing
using assembly System.Windows.Forms
using assembly System.Drawing
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
# Initialize Error Message variables.
$ErrorMessage = ''
$DefaultErrorMessageText = 'The destination folder path string is not valid.'
# Specifies that a non-critical destination path error occured and was handled.
$HandledDestinationPathError = $(
  If ('DestinationPath' -inotin $PSBoundParameters.Keys) {
    $True
  } Else {
    $False
  }
)
# Unify the destination path string.
Function UnifyValidDestinationPath {
  If (-not (Split-Path $Args[0] -IsAbsolute)) {
    If (
      $Args[0] -match '(?<ShareRoot>\\\\[^\\]+\\[^\\]+)(\\|$)' -and
      (Test-Path $Matches.ShareRoot)
    ) {
      Return "\$($Args[0] -replace '\\+','\')"
    }
    Return Join-Path $PWD.ProviderPath ($Args[0] -replace '\\+','\')
  }
  Return $Args[0] -replace '\\+','\'
}
Function UnifyBeforeValidationDestinationPath {
  Return $Args[0].TrimEnd() -replace '/','\'
}
Try {
  $DestinationPath = UnifyBeforeValidationDestinationPath $DestinationPath
}
Catch {
  Throw $_
}
If (Test-Path $DestinationPath -IsValid) {
  $DestinationPath = UnifyValidDestinationPath $DestinationPath
} Else {
  $ErrorMessage = $DefaultErrorMessageText
  $HandledDestinationPathError = $True
}
# Modify the destination path if it carries info of a file.
$SkipIndex = 0
While (Test-Path $DestinationPath -PathType Leaf) {
  $DestinationPath = "$DestinationPath ($((++$SkipIndex)))"
  $HandledDestinationPathError = $True
}
# The Expand Disk Image form.
$ExpandDiskImageDialog = [Form]::New() | ForEach-Object {
  $_.Size = '500, 365'
  $_.Text = 'Extract ISO Disk Image'
  $_.Icon = "$PSScriptRoot\logo.ico"
  $_.BackColor = 'White'
  $_.Font = 'Segoe UI,10'
  $_.StartPosition = 'CenterScreen'
  $_.MinimumSize = $_.Size
  $_.MaximumSize = $_.Size
  $_.MaximizeBox = $False
  Return $_
}
$SelectDestinationFolderDialog = [FolderBrowserDialog]::New() | ForEach-Object {
  $_.Description  = 'Select a Folder'
  $_.ShowNewFolderButton = $True
  If (-not $DestinationPath.StartsWith('\\')) {
    $_.SelectedPath = $DestinationPath
  }
  Return $_
}
$ExpandDiskImageDialog.Controls.AddRange(@(
  [Label]::New() | ForEach-Object {
    $_.AutoSize = $True
    $_.Text = 'Select a Destination and Extract Files'
    $_.Font = 'Segoe UI,11'
    $_.ForeColor = 'DarkBlue'
    $_.Location = '20, 20'
    Return $_
  }
  ($DestinationFolderPathTextBox = [TextBox]::New() | ForEach-Object {
    $_.Width = 340
    $_.BorderStyle = 'FixedSingle'
    $_.Location = '22, 80'
    $_.Text = $DestinationPath
    Return $_
  })
  [Label]::New() | ForEach-Object {
    $_.AutoSize = $True
    $_.Text = 'Files will be extracted to this folder:'
    $_.Font = 'Segoe UI,9'
    $_.Location = '20, 60'
    Return $_
  }
  [Button]::New() | ForEach-Object {
    $_.Width = 90
    $_.Height += 2
    $_.Text = 'Browse...'
    $_.FlatStyle = 'Flat'
    $_.Location = '372, 80'
    $_.BackColor = '#F0F0F0'
    $_.add_Paint({
      Param($EvtSrc, $Evt)
      [ControlPaint]::DrawBorder($Evt.Graphics, $EvtSrc.DisplayRectangle, 'Gray', 'Solid')
    })
    $_.add_Click({
      If ($SelectDestinationFolderDialog.ShowDialog() -ieq 'OK') {
        $DestinationFolderPathTextBox.Text = $SelectDestinationFolderDialog.SelectedPath
      }
    })
    Return $_
  }
  ($OpenDestinationFolderCheckBox = [CheckBox]::New() | ForEach-Object {
    $_.AutoSize = $True
    $_.FlatStyle = 'Flat'
    $_.Location = '22, 120'
    $_.Text = 'Show extracted files when complete'
    $_.Font = 'Segoe UI,9'
    $_.Checked = $Open
    Return $_
  })
  [Button]::New() | ForEach-Object {
    $_.Width = 90
    $_.Text = 'Extract'
    $_.FlatStyle = 'Flat'
    $_.Location = '372, 288'
    $_.BackColor = '#F0F0F0'
    $_.add_Paint({
      Param($EvtSrc, $Evt)
      [ControlPaint]::DrawBorder($Evt.Graphics, $EvtSrc.DisplayRectangle, 'Gray', 'Solid')
    })
    $ExpandDiskImageDialog.AcceptButton = $_
    $_.DialogResult = 'None'
    $_.add_Click({
      If ($This.DialogResult -ieq 'Yes') {
        Return
      }
      $DestinationFolderPathTextBox.Text = UnifyBeforeValidationDestinationPath $DestinationFolderPathTextBox.Text
      If (
        [string]::IsNullOrWhiteSpace($DestinationFolderPathTextBox.Text) -or
        -not (Test-Path $DestinationFolderPathTextBox.Text -IsValid)
      ) {
        $ErrorMessageLabel.Text = $DefaultErrorMessageText
        Return
      }
      If (Test-Path $DestinationFolderPathTextBox.Text -PathType Leaf) {
        $ErrorMessageLabel.Text = 'The selected path is an existing file.'
        Return
      }
      $DestinationFolderPathTextBox.Text = UnifyValidDestinationPath $DestinationFolderPathTextBox.Text
      $ErrorMessageLabel.Text = ''
      $This.DialogResult = 'Yes'
      $This.PerformClick()
    })
    Return $_
  }
  ($ErrorMessageLabel = [Label]::New() | ForEach-Object {
    $_.Width = 400
    $_.Font = 'Segoe UI,7'
    $_.ForeColor = 'Red'
    $_.TextAlign = 'TopLeft'
    $_.BackColor = '#F0F0F0'
    $_.Location = '20, 290'
    $_.Text = $ErrorMessage
    Return $_
  })
  [Label]::New() | ForEach-Object {
    $_.Size = '500,55'
    $_.BackColor = '#F0F0F0'
    $_.Location = '0, 272'
    Return $_
  }
))
$DestinationFolderPathTextBox.add_TextChanged({
  $ErrorMessageLabel.Text = ''
})
If (
  $HandledDestinationPathError -and
  $ExpandDiskImageDialog.ShowDialog() -ieq 'Cancel'
) { Return }
# Set the DestinationPath to the destination folder text box text.
$DestinationPath = $DestinationFolderPathTextBox.Text
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
If ($OpenDestinationFolderCheckBox.Checked) {
  explorer.exe $DestinationPath
}