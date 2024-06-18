Function Set-ExpandDiskImageShortcut {
  <#
  .SYNOPSIS
  Install the context menu shortcut to extract ISO files.
  .DESCRIPTION
  This function creates a context menu shortcut to extract ISO files by setting up the Windows Registry.
  #>
  [CmdletBinding(DefaultParameterSetName='DefaultSetup',SupportsShouldProcess)]
  Param (
    [Parameter(ParameterSetName='HideDriveSetup',Mandatory)]
    [switch] $AlwaysHideDrive,
    [Parameter(ParameterSetName='HideDriveSetup')]
    [switch] $UseRunAs
  )

  # Compile the JScript.NET scripts to an executable.
  If (
    ($CompilerResult = Start-Job {
      Add-Type -AssemblyName Microsoft.JScript
      [Microsoft.JScript.JScriptCodeProvider]::New().CompileAssemblyFromFile(
        ([System.CodeDom.Compiler.CompilerParameters]::New(
          @('System.dll','System.Diagnostics.Process.dll'),
          "$Using:PSScriptRoot\ExpandDiskImage.exe",
          $false
        ) | ForEach-Object {
          $_.GenerateExecutable = $true
          $_.GenerateInMemory = $false
          $_.WarningLevel = 3
          $_.TreatWarningsAsErrors = $false
          $_.CompilerOptions = "/t:winexe";
          $_.Win32Resource = "$Using:PSScriptRoot\winres.res";
          Return $_
        }),
        ("$Using:PSScriptRoot\ExpandDiskImage{0}.js" -f $(
          If ($Using:UseRunAs) {
            'RunAs'
          }
        ))
      )
    } | Receive-Job -Wait -AutoRemoveJob).NativeCompilerReturnValue -ne 0
  ) {
    # Stop if compilation threw an error. 
    Return
  }
  $VerbPattern = 'HKCU:\SOFTWARE\Classes\SystemFileAssociations\.iso\shell\{0}'
  $CommandKeyPattern = $VerbPattern + '\command'
  $RunAsCommandKey = $CommandKeyPattern -f 'runas'
  $RunAsKey = $VerbPattern -f 'runas'
  $ExtractAllCommandKey = $CommandKeyPattern -f 'extractall'
  $ExtractAllKey = $VerbPattern -f 'extractall'
  # The arguments to Set-Item and New-Item cmdlets.
  $Arguments = @{
    # The registry key of the command executed by the shortcut.
    Path = $(
        If ($UseRunAs) {
          $RunAsCommandKey
        } Else {
          $ExtractAllCommandKey
        }
      )
    # %1 is the path to the selected mardown file to convert.
    Value = '"{0}" "%1"{1}' -f $CompilerResult.PathToAssembly,$(
        If ($AlwaysHideDrive -and -not $UseRunAs) {
          ' -HideDrive'
        }
      )
  }
  $ConfirmPreference = 'None'
  # Overwrite the key value if it already exists.
  # Otherwise, create it.
  If (Test-Path $Arguments.Path -PathType Container) {
    $ConfirmPreference = 'Low'
    If (
      $Arguments.Path -like $RunAsCommandKey -and
      (Get-ItemPropertyValue $RunAsCommandKey -Name '(default)') -ne $Arguments.Value -and
      -not $PSCmdlet.ShouldProcess(($RunAsCommandKey -replace ':'), 'Overwrite key value')
      ) {
      Return
    }
    $ConfirmPreference = 'None'
    Set-Item @Arguments
    $CommandKey = Get-Item $Arguments.Path
  }
  Else {
    $CommandKey = New-Item @Arguments -Force
  }
  # Set/reset the text on the menu and the icon using the parent of the command key.
  Clear-Item -Path $CommandKey.PSParentPath -Force
  Set-Item -Path $CommandKey.PSParentPath -Value 'Ex&tract All...' -Force
  If ($PSCmdlet.ParameterSetName -like 'HideDriveSetup') {
    Set-ItemProperty -Path $CommandKey.PSParentPath -Value '' -Name 'HasLUAShield' -Force
  }
  # Remove the alternate verb key.
  If ($Arguments.Path -like $RunAsCommandKey) {
    Remove-Item $ExtractAllKey -Recurse -ErrorAction SilentlyContinue
  } Else {
    If ((Get-ItemPropertyValue $RunAsCommandKey -Name '(default)' -ErrorAction SilentlyContinue) -like '"*\ExpandDiskImage.exe" "%1"*') {
      Remove-Item $RunAsKey -Recurse -ErrorAction SilentlyContinue
    }
  }
}

Function Remove-ExpandDiskImageShortcut {
  <#
  .SYNOPSIS
  Remove the context menu shortcut to extract ISO files .
  .DESCRIPTION
  This function removes the context menu shortcut to extract ISO files  by setting up the Windows Registry.
  #>
  [CmdletBinding()]
  Param ()

  # Remove the registry key of the shortcut verb.
  $VerbPattern = 'HKCU:\SOFTWARE\Classes\SystemFileAssociations\.iso\shell\'
  Remove-Item ($VerbPattern + 'extractall')  -Recurse -ErrorAction SilentlyContinue
  $RunAsKey = $VerbPattern + 'runas'
  If ((Get-ItemPropertyValue ($RunAsKey + '\command') -Name '(default)' -ErrorAction SilentlyContinue) -like '"*\ExpandDiskImage.exe" "%1"*') {
    Remove-Item $RunAsKey -Recurse -ErrorAction SilentlyContinue
  }
}