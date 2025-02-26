# IIS Permission Migration Tool

A PowerShell tool for exporting and importing IIS/Inetpub directory permissions between Windows servers.

## Overview

This script provides a simple way to migrate IIS website permissions when setting up a new web server or moving websites between servers. It captures all file and directory permissions from Inetpub (or any specified directory) and allows you to apply the exact same permission structure on a target server.

## Features

- **Export Mode**: Dumps all file and directory permissions to a CSV file
- **Import Mode**: Recreates directory structure and applies permissions from the CSV
- **Flexible Paths**: Specify custom source, target, and CSV file paths
- **Progress Tracking**: Visual progress bars during long-running operations
- **Detailed Logging**: Logs all operations with color-coded status messages
- **Directory Creation**: Automatically creates any missing directories in the path

## Requirements

- Windows PowerShell 5.1 or higher
- Administrator rights on both source and target servers

## Installation

1. Download `InetpubPermissions.ps1` to your server
2. Ensure execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

Display help and usage information:
```powershell
.\InetpubPermissions.ps1
```

### Export Permissions

Export permissions from the default Inetpub directory:
```powershell
.\InetpubPermissions.ps1 -Mode Export
```

Export permissions with custom paths:
```powershell
.\InetpubPermissions.ps1 -Mode Export -SourcePath D:\WebSites -CsvPath D:\Backup\Permissions.csv
```

### Import Permissions

Import permissions to the default Inetpub directory:
```powershell
.\InetpubPermissions.ps1 -Mode Import
```

Import permissions with custom paths:
```powershell
.\InetpubPermissions.ps1 -Mode Import -TargetPath E:\NewWebSites -CsvPath D:\Backup\Permissions.csv
```

## Parameters

| Parameter   | Description                                         | Default Value               |
|-------------|-----------------------------------------------------|----------------------------|
| `-Mode`     | Operation mode: "Export" or "Import" (Required)     | None (must be specified)   |
| `-SourcePath` | Path to export permissions from                    | C:\Inetpub                 |
| `-TargetPath` | Path to import permissions to                      | C:\Inetpub                 |
| `-CsvPath`    | Path for the CSV permissions file                  | C:\Temp\InetpubPermissions.csv |

## Migration Process

1. **On the source server**:
   - Run the script in Export mode
   - Copy the generated CSV file to the target server
   
2. **On the target server**:
   - Run the script in Import mode, pointing to the CSV file
   - Verify permissions after import

## Sample Output

### Export Mode
```
IIS Permissions Migration Tool
=============================
Starting permission export from C:\Inetpub to C:\Temp\InetpubPermissions.csv
Scanning directory structure...
Found 1563 items to process
Successfully exported 8721 permission entries to C:\Temp\InetpubPermissions.csv
```

### Import Mode
```
IIS Permissions Migration Tool
=============================
Starting permission import from C:\Temp\InetpubPermissions.csv to C:\Inetpub
Importing permission data from CSV...
Found 8721 permission entries to process
Permission import completed successfully
```

## Troubleshooting

- **Access Denied Errors**: Run PowerShell as Administrator
- **Account Not Found**: Ensure user accounts referenced in permissions exist on the target server
- **Long Execution Time**: For large directories, the script may take several minutes to complete

## License

MIT License

## Author

Clint L. Johnson / Mississippi Department of Transportation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
