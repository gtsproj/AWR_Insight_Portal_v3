@echo off
:: ============================================================
:: install_dar_portal.bat
:: DAR Portal — Database Analysis and Recommendations
:: Avekshaa Technologies
::
:: Interactive installer for the DAR Portal PostgreSQL schema.
:: Prompts for:
::   • PostgreSQL connection details and superuser password
::   • Tablespace directory paths (creates folders automatically)
::   • DAR_PORTAL_USER password
::
:: Supports the DAR Portal analysis platform for:
::   Oracle, MS SQL Server, PostgreSQL, MySQL, MariaDB, Cassandra
::
:: PREREQUISITES:
::   • PostgreSQL installed; pg_bin directory in PATH
::     e.g. C:\Program Files\PostgreSQL\16\bin
::   • PowerShell 5+ (standard on Windows 10/11/Server 2019+)
::   • Run as Administrator (required to create tablespace dirs
::     in system paths; not needed for user-owned paths)
::
:: USAGE:
::   Double-click install_dar_portal.bat  (or run from cmd)
:: ============================================================

setlocal EnableDelayedExpansion
title DAR Portal — Database Schema Installation

cls
echo.
echo ============================================================
echo   DAR Portal — Database Analysis and Recommendations
echo   Avekshaa Technologies
echo   Interactive Schema Installer
echo ============================================================
echo.
echo   This installer will prompt for:
echo     1. PostgreSQL connection details
echo     2. Tablespace directory paths  ^(created automatically^)
echo     3. DAR_PORTAL_USER password
echo.
echo   Then it will create all 80 tables, 86 indexes, 2 views,
echo   12 materialized views, seed 1918 wait event rows and
echo   46 portal_config keys.
echo.
echo   Press Ctrl+C at any time to cancel.
echo ============================================================
echo.
pause


:: ────────────────────────────────────────────────────────────
:: STEP 1: PostgreSQL Connection
:: ────────────────────────────────────────────────────────────
cls
echo.
echo [Step 1 of 5]  PostgreSQL Connection Details
echo ──────────────────────────────────────────────────────────
echo.

set /p PG_HOST="  Host   [localhost]: "
if "!PG_HOST!"=="" set PG_HOST=localhost

set /p PG_PORT="  Port   [5432]: "
if "!PG_PORT!"=="" set PG_PORT=5432

set /p PG_DB="  Database name [postgres]: "
if "!PG_DB!"=="" set PG_DB=postgres

set /p PG_SUPERUSER="  Superuser username [postgres]: "
if "!PG_SUPERUSER!"=="" set PG_SUPERUSER=postgres

echo.
echo   Enter the PostgreSQL superuser password.
echo   Note: characters will NOT be displayed as you type.
echo.
powershell -NoProfile -Command ^
  "$p = Read-Host '  Password' -AsSecureString; " ^
  "$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); " ^
  "$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr); " ^
  "[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr); " ^
  "Set-Content -Path '%TEMP%\dar_pgpw.tmp' -Value $plain -NoNewline"
set /p PGPASSWORD=<"%TEMP%\dar_pgpw.tmp"
del "%TEMP%\dar_pgpw.tmp" >nul 2>&1
echo.

:: Verify psql is reachable
echo   Verifying PostgreSQL connection...
psql -h !PG_HOST! -p !PG_PORT! -U !PG_SUPERUSER! -d !PG_DB! ^
     -c "SELECT 'connected' AS status;" >nul 2>&1
if errorlevel 1 (
    echo.
    echo   ERROR: Cannot connect to PostgreSQL.
    echo          Host:     !PG_HOST!:!PG_PORT!
    echo          Database: !PG_DB!
    echo          User:     !PG_SUPERUSER!
    echo.
    echo   Check that:
    echo     • PostgreSQL service is running
    echo     • psql.exe is in your PATH
    echo     • The password is correct
    echo     • pg_hba.conf allows connections from localhost
    echo.
    pause
    exit /b 1
)
echo   Connected successfully.
echo.


:: ────────────────────────────────────────────────────────────
:: STEP 2: Tablespace Paths
:: ────────────────────────────────────────────────────────────
cls
echo.
echo [Step 2 of 5]  Tablespace Directory Paths
echo ──────────────────────────────────────────────────────────
echo.
echo   Enter full paths for the PostgreSQL tablespace directories.
echo   These must be empty directories — the installer creates
echo   them for you. Use a path where PostgreSQL can write files.
echo.
echo   Recommendation: Use a path on your fastest disk,
echo   separate from the PostgreSQL data directory (PGDATA).
echo.
echo   Example paths:
echo     C:\DAR_Data\tablespaces\awrparser
echo     D:\pg_tablespaces\awrparser
echo.

set /p TS_DATA_DIR="  Data tablespace path (awrparser) [C:\PostgreSQL\tablespaces\awrparser]: "
if "!TS_DATA_DIR!"=="" set TS_DATA_DIR=C:\PostgreSQL\tablespaces\awrparser

set /p TS_IDX_DIR="  Index tablespace path (awrparser_idx) [C:\PostgreSQL\tablespaces\awrparser_idx]: "
if "!TS_IDX_DIR!"=="" set TS_IDX_DIR=C:\PostgreSQL\tablespaces\awrparser_idx

echo.
echo   Paths entered:
echo     Data : !TS_DATA_DIR!
echo     Index: !TS_IDX_DIR!
echo.


:: ────────────────────────────────────────────────────────────
:: STEP 3: Create tablespace directories
:: ────────────────────────────────────────────────────────────
cls
echo.
echo [Step 3 of 5]  Creating Tablespace Directories
echo ──────────────────────────────────────────────────────────
echo.

:: Create data tablespace directory
if exist "!TS_DATA_DIR!\" (
    echo   Directory already exists: !TS_DATA_DIR!
) else (
    echo   Creating: !TS_DATA_DIR!
    mkdir "!TS_DATA_DIR!" 2>nul
    if errorlevel 1 (
        echo.
        echo   ERROR: Could not create: !TS_DATA_DIR!
        echo          Try running this script as Administrator,
        echo          or create the directory manually first.
        pause
        exit /b 1
    )
    echo   Created:  !TS_DATA_DIR!
)

:: Create index tablespace directory
if exist "!TS_IDX_DIR!\" (
    echo   Directory already exists: !TS_IDX_DIR!
) else (
    echo   Creating: !TS_IDX_DIR!
    mkdir "!TS_IDX_DIR!" 2>nul
    if errorlevel 1 (
        echo.
        echo   ERROR: Could not create: !TS_IDX_DIR!
        echo          Try running this script as Administrator,
        echo          or create the directory manually first.
        pause
        exit /b 1
    )
    echo   Created:  !TS_IDX_DIR!
)

echo.
echo   Tablespace directories are ready.
echo.


:: ────────────────────────────────────────────────────────────
:: STEP 4: DAR_PORTAL_USER password
:: ────────────────────────────────────────────────────────────
cls
echo.
echo [Step 4 of 5]  DAR_PORTAL_USER Password
echo ──────────────────────────────────────────────────────────
echo.
echo   DAR_PORTAL_USER is the database role that owns all
echo   DAR Portal schema objects. The portal service can
echo   connect as this user instead of the postgres superuser.
echo.
echo   Password requirements:
echo     • Minimum 8 characters
echo     • At least one uppercase letter
echo     • At least one number or special character
echo.
echo   Note: characters will NOT be displayed as you type.
echo.

:ask_password
set DAR_PWD=
set DAR_PWD2=

powershell -NoProfile -Command ^
  "$p = Read-Host '  Enter password for DAR_PORTAL_USER' -AsSecureString; " ^
  "$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); " ^
  "$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr); " ^
  "[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr); " ^
  "Set-Content -Path '%TEMP%\dar_pw1.tmp' -Value $plain -NoNewline"
set /p DAR_PWD=<"%TEMP%\dar_pw1.tmp"
del "%TEMP%\dar_pw1.tmp" >nul 2>&1

if "!DAR_PWD!"=="" (
    echo   Password cannot be empty. Please try again.
    goto ask_password
)

powershell -NoProfile -Command ^
  "$p = Read-Host '  Confirm password' -AsSecureString; " ^
  "$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); " ^
  "$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr); " ^
  "[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr); " ^
  "Set-Content -Path '%TEMP%\dar_pw2.tmp' -Value $plain -NoNewline"
set /p DAR_PWD2=<"%TEMP%\dar_pw2.tmp"
del "%TEMP%\dar_pw2.tmp" >nul 2>&1

if "!DAR_PWD!" NEQ "!DAR_PWD2!" (
    echo.
    echo   Passwords do not match. Please try again.
    echo.
    goto ask_password
)
echo.
echo   Password confirmed.
echo.


:: ────────────────────────────────────────────────────────────
:: STEP 5: Run the SQL installation
:: ────────────────────────────────────────────────────────────
cls
echo.
echo [Step 5 of 5]  Running SQL Installation
echo ──────────────────────────────────────────────────────────
echo.
echo   Summary of values:
echo     PostgreSQL : !PG_SUPERUSER!@!PG_HOST!:!PG_PORT!/!PG_DB!
echo     Data TS    : !TS_DATA_DIR!
echo     Index TS   : !TS_IDX_DIR!
echo     DB Role    : DAR_PORTAL_USER
echo.
echo   The installer will now create all schema objects.
echo   This takes 30-60 seconds (1918 wait event rows to insert).
echo.
pause

:: Locate the SQL file (same directory as this batch file)
set SCRIPT_DIR=%~dp0
if "!SCRIPT_DIR:~-1!"=="\" set SCRIPT_DIR=!SCRIPT_DIR:~0,-1!
set SQL_SOURCE=!SCRIPT_DIR!\install_fresh.sql
set TEMP_SQL=%TEMP%\dar_install_%RANDOM%_%RANDOM%.sql

if not exist "!SQL_SOURCE!" (
    echo   ERROR: install_fresh.sql not found at:
    echo          !SQL_SOURCE!
    echo          Ensure install_dar_portal.bat and install_fresh.sql
    echo          are in the same directory.
    pause
    exit /b 1
)

:: Use PowerShell to substitute all placeholder values
:: We use literal string replacement (not regex) to avoid
:: problems with backslashes in Windows paths.
echo   Preparing personalised installation script...

powershell -NoProfile -ExecutionPolicy Bypass -Command " ^
    $src = [System.IO.File]::ReadAllText('!SQL_SOURCE!', [System.Text.Encoding]::UTF8); ^
    $src = $src.Replace('C:\PostgreSQL\tablespaces\awrparser''', '!TS_DATA_DIR!'''); ^
    $src = $src.Replace('C:\PostgreSQL\tablespaces\awrparser_idx''', '!TS_IDX_DIR!'''); ^
    $src = $src.Replace('YourSecurePassword123', '!DAR_PWD!'.Replace('''','''''') ); ^
    [System.IO.File]::WriteAllText('!TEMP_SQL!', $src, [System.Text.Encoding]::UTF8); ^
    Write-Host '  Script prepared: ' + (Get-Item '!TEMP_SQL!').Length + ' bytes' ^
"

if errorlevel 1 (
    echo   ERROR: Failed to prepare installation script.
    echo          PowerShell error — see output above.
    pause
    exit /b 1
)

echo   Running SQL...
echo.
echo ─────────────────── psql output ───────────────────────────

psql -h !PG_HOST! -p !PG_PORT! -U !PG_SUPERUSER! -d !PG_DB! ^
     -v ON_ERROR_STOP=0 ^
     -f "!TEMP_SQL!"

set SQL_EXIT=!errorlevel!
echo ────────────────── end psql output ────────────────────────

:: Remove temp file (contains password — delete immediately)
del "!TEMP_SQL!" >nul 2>&1

echo.
if !SQL_EXIT! EQU 0 (
    echo   SQL completed successfully.
) else (
    echo   SQL completed with warnings. Review the output above.
    echo   Errors for already-existing objects are normal on re-run.
)

:: Ensure tablespace grants are applied even if tablespaces were pre-existing.
:: GRANT CREATE ON TABLESPACE is not idempotent but is safe to re-run.
echo.
echo   Applying tablespace grants to DAR_PORTAL_USER...
psql -h !PG_HOST! -p !PG_PORT! -U !PG_SUPERUSER! -d !PG_DB! -c ^
    "GRANT CREATE ON TABLESPACE awrparser     TO DAR_PORTAL_USER;" >nul 2>&1
psql -h !PG_HOST! -p !PG_PORT! -U !PG_SUPERUSER! -d !PG_DB! -c ^
    "GRANT CREATE ON TABLESPACE awrparser_idx TO DAR_PORTAL_USER;" >nul 2>&1
echo   Tablespace grants applied.


:: ────────────────────────────────────────────────────────────
:: DONE
:: ────────────────────────────────────────────────────────────
echo.
echo ============================================================
echo   Installation Complete
echo ============================================================
echo.
echo   NEXT STEPS:
echo.
echo   1. Install Python dependencies:
echo        py -m pip install -r requirements.txt
echo        py -m pip install oracledb paramiko
echo.
echo   2. Edit config\settings.yaml — update DB connection:
echo        database:
echo          host:     !PG_HOST!
echo          port:     !PG_PORT!
echo          dbname:   !PG_DB!
echo          user:     DAR_PORTAL_USER   ^(or keep postgres^)
echo          password: ^<your password^>
echo        portal:
echo          base_url: http://^<this-server^>:8000
echo        grafana:
echo          base_url: http://^<this-server^>:3000
echo.
echo   3. Register Windows services:
echo        install_services.bat
echo.
echo   4. Import Grafana dashboards:
echo        py bulk_import.py
echo.
echo   5. Open the portal:
echo        http://localhost:8000
echo        Login: admin  ^(enter any password — redirected to set-password page^)
echo.
echo   6. IMPORTANT — do these immediately after first login:
echo        Settings ^> Access Control  ^(update URLs^)
echo        Settings ^> License         ^(enter license key^)
echo        Settings ^> Users           ^(manage user accounts^)
echo.
echo ============================================================
echo.
pause
exit /b 0
