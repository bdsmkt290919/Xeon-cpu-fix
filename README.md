# Xeon CPU Fix Tool

A hybrid monitoring and auto-balancing tool for Xeon processors on Linux and Windows.

## Features

- **Real-time Monitoring**: Monitor CPU load per core
- **Auto-balancing**: Automatic load distribution across cores
- **Cross-platform**: Linux (Bash) and Windows (PowerShell) support
- **Common Configuration**: Unified YAML config for both platforms
- **Detailed Logging**: Comprehensive logs for all operations

## Quick Start

### Linux
```bash
chmod +x linux/*.sh
./linux/monitor.sh           # Start monitoring
./linux/auto-balance.sh      # Start auto-balancing
```

### Windows
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\windows\Monitor.ps1
.\windows\AutoBalance.ps1
```

## Configuration

Edit `config/config.yaml` to customize:
- Monitoring interval
- Load threshold
- Log level
- Platform-specific settings

## Documentation

- [Installation Guide](docs/INSTALL.md)
- [Usage Guide](docs/USAGE.md)

## Project Structure

```
xeon-cpu-fix/
├── config/config.yaml       # Shared configuration
├── linux/
│   ├── monitor.sh           # Linux monitoring
│   ├── auto-balance.sh      # Linux auto-balancing
│   └── utils.sh             # Shared utilities
├── windows/
│   ├── Monitor.ps1          # Windows monitoring
│   ├── AutoBalance.ps1      # Windows auto-balancing
│   └── Utils.ps1            # Shared utilities
├── docs/
│   ├── INSTALL.md
│   └── USAGE.md
└── logs/                    # Log directory
```

## License

MIT License
