@echo off
docker build --no-cache -t uvk5 .
docker run --rm -v %CD%\compiled-firmware:/app/compiled-firmware uvk5 bash -c "cd /app && make clean && make && cp n7six* compiled-firmware/"
pause
