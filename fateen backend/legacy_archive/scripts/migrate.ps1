# =============================================================================
# migrate.ps1 - apply versioned Fateen migrations to PostgreSQL with a ledger
# -----------------------------------------------------------------------------
# Purpose:       Apply migrations/ in strict numeric order, inside one transaction
#                each, and record them in the schema_migrations ledger with an
#                MD5 content checksum. Already-applied migrations are skipped and
#                their checksums verified, so an edited (tampered) migration is
#                rejected instead of silently diverging.
#
# Usage:         powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1
#                    -Database fateen [-MigrationsDir <dir>] [-PsqlPath psql]
#
# Connection:    Uses standard libpq environment: PGHOST, PGPORT, PGUSER,
#                PGPASSWORD (or .pgpass). Runs as the connecting user.
#
# Note:          This file must stay ASCII-only (PowerShell 5.1 parses .ps1 as
#                ANSI without a BOM).
# =============================================================================
param(
    [string]$Database = 'fateen',
    [string]$MigrationsDir = '',
    [string]$PsqlPath = 'psql'
)

$ErrorActionPreference = 'Stop'

if (-not $MigrationsDir) {
    $MigrationsDir = Join-Path ($PSScriptRoot | Split-Path -Parent) 'migrations'
}
if (-not (Test-Path -LiteralPath $MigrationsDir)) {
    throw "Migrations directory not found: $MigrationsDir"
}

function Get-Md5([string]$path) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hex = [BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', ''
    return $hex.ToLowerInvariant()
}

# Migrations are named NNNN_description.sql; anything else is not applied.
$files = Get-ChildItem -LiteralPath $MigrationsDir -Filter '*.sql' |
    Where-Object { $_.Name -match '^\d{4}_.+\.sql$' } |
    Sort-Object Name

if (-not $files) {
    throw "No migration files (NNNN_*.sql) found in $MigrationsDir"
}

# Ensure the ledger exists (idempotent bootstrap).
& $PsqlPath -v ON_ERROR_STOP=1 -d $Database -c `
    "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now());"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to ensure schema_migrations ledger"
}

# Load applied migrations: one line "version|checksum" per row.
$appliedOutput = & $PsqlPath -t -A -d $Database -c "SELECT version || '|' || checksum FROM schema_migrations ORDER BY version;"
$appliedMap = @{}
foreach ($line in $appliedOutput) {
    if (-not $line) { continue }
    $parts = $line -split '\|', 2
    if ($parts.Length -eq 2) {
        $appliedMap[$parts[0]] = $parts[1]
    }
}

$tmpWrapper = Join-Path $env:TEMP ("fateen_migrate_" + [guid]::NewGuid().ToString('N') + ".sql")
try {
    foreach ($f in $files) {
        $checksum = Get-Md5 $f.FullName

        if ($appliedMap.ContainsKey($f.Name)) {
            if ($appliedMap[$f.Name] -ne $checksum) {
                throw "Migration $($f.Name) was applied with a different checksum. Migrations are immutable; restore the original file or ship a new migration instead."
            }
            Write-Host "skip   $($f.Name)"
            continue
        }

        $fwd = $f.FullName.Replace('\', '/')
        $wrapper = '\i ' + "'" + $fwd + "'" + "`n" +
            "INSERT INTO schema_migrations (version, checksum) VALUES ('$($f.Name)', '$checksum');"

        [System.IO.File]::WriteAllText($tmpWrapper, $wrapper)
        Write-Host "apply  $($f.Name)"
        & $PsqlPath -v ON_ERROR_STOP=1 --single-transaction -f $tmpWrapper -d $Database
        if ($LASTEXITCODE -ne 0) {
            throw "Migration $($f.Name) failed and was rolled back"
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tmpWrapper) {
        Remove-Item -LiteralPath $tmpWrapper -Force
    }
}

Write-Host "Migration run complete."
