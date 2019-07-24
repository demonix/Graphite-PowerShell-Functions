if( $Host -and $Host.UI -and $Host.UI.RawUI ) {
    $rawUI = $Host.UI.RawUI
    $oldSize = $rawUI.BufferSize
    $typeName = $oldSize.GetType( ).FullName
    $newSize = New-Object $typeName (500, $oldSize.Height)
    $rawUI.BufferSize = $newSize
    $newSize = New-Object $typeName ([Math]::min($rawUI.MaxPhysicalWindowSize.Width,500), [Math]::min($rawUI.MaxPhysicalWindowSize.Height, $oldSize.Height))
    $rawUI.WindowSize = $newSize
}
