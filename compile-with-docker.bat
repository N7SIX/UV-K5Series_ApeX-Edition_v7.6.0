@echo off
docker build --no-cache -t uvk5 .
set BUILD_COMMIT=
for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set BUILD_COMMIT=%%i
if "%BUILD_COMMIT%"=="" set BUILD_COMMIT=N/A
docker run --rm -v %CD%\compiled-firmware:/app/compiled-firmware uvk5 bash -c "cd /app && make clean && make BUILD_COMMIT=%BUILD_COMMIT% && cp n7six* compiled-firmware/"
pause
