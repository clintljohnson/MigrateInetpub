[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Export", "Import")]
    [string]$Mode,
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "C:\Inetpub",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetPath = "C:\Inetpub",
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = "C:\Temp\InetpubPermissions.csv"
)

# Display usage if no parameters are provided
function Show-Usage {
    Write-Host "IIS Permissions Migration Tool" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host ".\InetpubPermissions.ps1 -Mode Export -SourcePath C:\Inetpub -CsvPath C:\Temp\InetpubPermissions.csv" -ForegroundColor White
    Write-Host ".\InetpubPermissions.ps1 -Mode Import -TargetPath C:\Inetpub -CsvPath C:\Temp\InetpubPermissions.csv" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Mode        : Required. Either 'Export' or 'Import'" -ForegroundColor White
    Write-Host "  -SourcePath  : Path to export permissions from (default: C:\Inetpub)" -ForegroundColor White
    Write-Host "  -TargetPath  : Path to import permissions to (default: C:\Inetpub)" -ForegroundColor White
    Write-Host "  -CsvPath     : Path for the CSV file (default: C:\Temp\InetpubPermissions.csv)" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  Export permissions:" -ForegroundColor White
    Write-Host "    .\InetpubPermissions.ps1 -Mode Export" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Export permissions with custom paths:" -ForegroundColor White
    Write-Host "    .\InetpubPermissions.ps1 -Mode Export -SourcePath D:\WebSites -CsvPath D:\Backup\Permissions.csv" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Import permissions:" -ForegroundColor White
    Write-Host "    .\InetpubPermissions.ps1 -Mode Import" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Import permissions with custom paths:" -ForegroundColor White
    Write-Host "    .\InetpubPermissions.ps1 -Mode Import -TargetPath E:\NewWebSites -CsvPath D:\Backup\Permissions.csv" -ForegroundColor Gray
}

# If no mode specified, show usage and exit
if (-not $Mode) {
    Show-Usage
    exit
}

# EXPORT MODE: Export permissions from source path
function Export-Permissions {
    param(
        [string]$SourcePath,
        [string]$OutputFile
    )
    
    Write-Host "Starting permission export from $SourcePath to $OutputFile" -ForegroundColor Cyan
    
    # Create directory for the CSV if it doesn't exist
    $csvDir = Split-Path -Parent $OutputFile
    if (!(Test-Path $csvDir)) {
        try {
            New-Item -Path $csvDir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $csvDir" -ForegroundColor Yellow
        }
        catch {
            Write-Error "Failed to create directory for CSV file: $csvDir"
            Write-Error $_.Exception.Message
            exit 1
        }
    }
    
    # Validate source path
    if (!(Test-Path $SourcePath)) {
        Write-Error "Source path does not exist: $SourcePath"
        exit 1
    }
    
    # Get all items (folders and files) recursively
    Write-Host "Scanning directory structure..." -ForegroundColor Yellow
    $items = Get-ChildItem -Path $SourcePath -Recurse -Force
    
    # Add the root folder to the collection
    $items = @([PSCustomObject]@{FullName = $SourcePath}) + $items
    Write-Host "Found $($items.Count) items to process" -ForegroundColor Green
    
    # Create an array to store the permissions
    $permissionsData = @()
    $processedCount = 0
    $totalCount = $items.Count
    
    # Process each item
    foreach ($item in $items) {
        $processedCount++
        $percentComplete = [math]::Round(($processedCount / $totalCount) * 100, 1)
        Write-Progress -Activity "Exporting Permissions" -Status "Processing $($item.FullName)" -PercentComplete $percentComplete
        
        # Get ACL for the current item
        $acl = Get-Acl -Path $item.FullName -ErrorAction SilentlyContinue
        
        if ($acl) {
            # Process each access rule
            foreach ($accessRule in $acl.Access) {
                # Create a custom object with the permission details
                $permissionEntry = [PSCustomObject]@{
                    Path = $item.FullName.Replace($SourcePath, "").TrimStart("\")
                    IdentityReference = $accessRule.IdentityReference.Value
                    FileSystemRights = $accessRule.FileSystemRights
                    AccessControlType = $accessRule.AccessControlType
                    IsInherited = $accessRule.IsInherited
                    InheritanceFlags = $accessRule.InheritanceFlags
                    PropagationFlags = $accessRule.PropagationFlags
                    ItemType = if (Test-Path -Path $item.FullName -PathType Container) { "Directory" } else { "File" }
                }
                
                # Add to the array
                $permissionsData += $permissionEntry
            }
        }
        else {
            Write-Warning "Could not retrieve ACL for: $($item.FullName)"
        }
    }
    
    # Export the permissions data to CSV
    $permissionsData | Export-Csv -Path $OutputFile -NoTypeInformation
    Write-Progress -Activity "Exporting Permissions" -Completed
    Write-Host "Successfully exported $($permissionsData.Count) permission entries to $OutputFile" -ForegroundColor Green
}

# IMPORT MODE: Import permissions to target path
function Import-Permissions {
    param(
        [string]$TargetPath,
        [string]$InputFile
    )
    
    Write-Host "Starting permission import from $InputFile to $TargetPath" -ForegroundColor Cyan
    
    # Validate input file
    if (!(Test-Path $InputFile)) {
        Write-Error "CSV file does not exist: $InputFile"
        exit 1
    }
    
    # Ensure the directory for any log files or reports exists
    $outputDir = Split-Path -Parent $InputFile
    if (!(Test-Path $outputDir)) {
        try {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $outputDir" -ForegroundColor Yellow
        }
        catch {
            Write-Warning "Unable to create directory: $outputDir. Will continue with import operation."
        }
    }
    
    # Create target directory if it doesn't exist
    if (!(Test-Path $TargetPath)) {
        New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
        Write-Host "Created target directory: $TargetPath" -ForegroundColor Yellow
    }
    
    # Import the permissions data from CSV
    Write-Host "Importing permission data from CSV..." -ForegroundColor Yellow
    $permissionsData = Import-Csv -Path $InputFile
    Write-Host "Found $($permissionsData.Count) permission entries to process" -ForegroundColor Green
    
    # Group the permissions by path to process each path only once
    $groupedPermissions = $permissionsData | Group-Object -Property Path
    
    $processedCount = 0
    $totalCount = $groupedPermissions.Count
    
    # Process each path
    foreach ($group in $groupedPermissions) {
        $processedCount++
        $percentComplete = [math]::Round(($processedCount / $totalCount) * 100, 1)
        
        $relativePath = $group.Name
        
        # Construct the full path
        $fullPath = if ([string]::IsNullOrEmpty($relativePath)) {
            $TargetPath
        } else {
            Join-Path -Path $TargetPath -ChildPath $relativePath
        }
        
        Write-Progress -Activity "Importing Permissions" -Status "Processing $fullPath" -PercentComplete $percentComplete
        
        # Determine item type (file or directory)
        $itemType = ($group.Group | Select-Object -First 1).ItemType
        
        # Ensure the path exists
        if (!(Test-Path $fullPath)) {
            if ($itemType -eq "File") {
                # Create parent directory if needed
                $parentDir = Split-Path -Parent $fullPath
                if (!(Test-Path $parentDir)) {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                }
                # Create empty file
                New-Item -Path $fullPath -ItemType File -Force | Out-Null
                Write-Host "  Created file: $fullPath" -ForegroundColor Yellow
            } else {
                # Create directory
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                Write-Host "  Created directory: $fullPath" -ForegroundColor Yellow
            }
        }
        
        # Get current ACL
        $acl = Get-Acl -Path $fullPath
        
        # Process all permission entries for this path
        foreach ($permission in $group.Group) {
            if (-not $permission.IsInherited) {  # Skip inherited permissions
                try {
                    # Create a new access rule
                    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $permission.IdentityReference,
                        $permission.FileSystemRights,
                        $permission.InheritanceFlags,
                        $permission.PropagationFlags,
                        $permission.AccessControlType
                    )
                    
                    # Add the access rule to the ACL
                    $acl.AddAccessRule($accessRule)
                }
                catch {
                    Write-Warning "Error creating access rule for $($permission.IdentityReference) on $fullPath"
                    Write-Warning $_.Exception.Message
                }
            }
        }
        
        # Apply the modified ACL
        try {
            Set-Acl -Path $fullPath -AclObject $acl
            Write-Verbose "Successfully applied permissions to: $fullPath"
        }
        catch {
            Write-Warning "Failed to apply permissions to: $fullPath"
            Write-Warning $_.Exception.Message
        }
    }
    
    Write-Progress -Activity "Importing Permissions" -Completed
    Write-Host "Permission import completed successfully" -ForegroundColor Green
}

# Main script execution
try {
    switch ($Mode) {
        "Export" {
            Export-Permissions -SourcePath $SourcePath -OutputFile $CsvPath
        }
        "Import" {
            Import-Permissions -TargetPath $TargetPath -InputFile $CsvPath
        }
    }
}
catch {
    Write-Error "An error occurred during execution: $_"
    exit 1
}
